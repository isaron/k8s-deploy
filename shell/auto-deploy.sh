#!/bin/bash
set -x
set -e
 
HTTP_SERVER=172.30.80.88:8000
MASTER_IP=172.30.80.31
KUBE_HA=true
 
KUBE_REPO_PREFIX=gcr.io/google_containers
KUBE_VERSION=v1.9.3
ETCD_VERSION=v3.1.11
 
root=$(id -u)
if [ "$root" -ne 0 ] ;then
    echo must run as root
    exit 1
fi

kube::config_env()
{
    echo "Asia/Chongqing" > /etc/timezone
    swapoff -a && sed -i 's/.*swap.*/#&/' /etc/fstab

    sed -i s/"deb cdrom"/"#deb cdrom"/g /etc/apt/sources.list
    sed -i 's/us.archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
    apt update && sudo apt full-upgrade -yy
    apt install ssh vim htop curl ntp ntpdate -y && ntpdate pool.ntp.org

    # passwd root
    # passwd -u root 
    # sed -i s/"PermitRootLogin prohibit-password"/"PermitRootLogin yes"/g /etc/ssh/sshd_config
    # service ssh restart
}

kube::install_docker()
{
    set +e
    docker info> /dev/null 2>&1
    i=$?
    set -e
    if [ $i -ne 0 ]; then
        apt update
        apt -y install apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
        apt update && apt install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
        kube::config_docker
    fi
    echo docker has been installed
}
 
kube::config_docker()
{
    setenforce 0 > /dev/null 2>&1 && sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
 
    # sysctl -w net.bridge.bridge-nf-call-iptables=1
    # sysctl -w net.bridge.bridge-nf-call-ip6tables=1
cat <<EOF >>/etc/sysctl.conf
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
EOF

    apt-mark hold docker-ce
    usermod -aG docker $USER
    curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://e24ee5b3.m.daocloud.io
    systemctl daemon-reload && systemctl restart docker.service
}
 
kube::load_images()
{
    mkdir -p /tmp/k8s
 
    images=(
        kube-apiserver-amd64_v1.9.3
        kube-controller-manager-amd64_v1.9.3
        kube-scheduler-amd64_v1.9.3
        kube-proxy-amd64_v1.9.3
        etcd-amd64_3.1.11
        pause-amd64_3.0
        k8s-dns-sidecar-amd64_1.14.7
        k8s-dns-kube-dns-amd64_1.14.7
        k8s-dns-dnsmasq-nanny-amd64_1.14.7
    )
 
    for i in "${!images[@]}"; do
        ret=$(docker images | awk 'NR!=1{print $1"_"$2}'| grep $KUBE_REPO_PREFIX/${images[$i]} | wc -l)
        if [ $ret -lt 1 ];then
            curl -L http://$HTTP_SERVER/images/${images[$i]}.tar > /tmp/k8s/${images[$i]}.tar
            docker load -i /tmp/k8s/${images[$i]}.tar
        fi
    done
 
    rm /tmp/k8s* -rf
}
 
kube::install_bin()
{
    set +e
    which kubeadm > /dev/null 2>&1
    i=$?
    set -e
    if [ $i -ne 0 ]; then
        apt install socat ebtables ethtool -y
        curl -L http://$HTTP_SERVER/debs/debs.tar.gz > /tmp/debs.tar.gz
        tar zxf /tmp/debs.tar.gz -C /tmp
        dpkg -i /tmp/debs/*.deb
        rm -rf /tmp/debs*
        systemctl enable kubelet.service && systemctl start kubelet.service && rm -rf /etc/kubernetes
    fi
}
 
kube::wait_apiserver()
{
    until curl https://172.30.80.31:6443; do sleep 1; done
}
 
kube::disable_static_pod()
{
    # remove the waring log in kubelet
    sed -i 's/--pod-manifest-path=\/etc\/kubernetes\/manifests//g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    systemctl daemon-reload && systemctl restart kubelet.service
}
 
kube::get_env()
{
    HA_STATE=$1
    [ $HA_STATE == "MASTER" ] && HA_PRIORITY=200 || HA_PRIORITY=`expr 200 - ${RANDOM} / 1000 + 1`
    KUBE_VIP=$(echo $2 |awk -F= '{print $2}')
    VIP_PREFIX=$(echo ${KUBE_VIP} | cut -d . -f 1,2,3)
    #dhcp和static地址的不同取法
    VIP_INTERFACE=$(ip addr show | grep ${VIP_PREFIX} | awk -F 'dynamic' '{print $2}' | head -1)
    [ -z ${VIP_INTERFACE} ] && VIP_INTERFACE=$(ip addr show | grep ${VIP_PREFIX} | awk -F 'global' '{print $2}' | head -1)
    ###
    PEER_NAME=$(hostname)
    LOCAL_IP=$(ip addr show | grep ${VIP_PREFIX} | awk -F / '{print $1}' | awk -F ' ' '{print $2}' | head -1)
    MASTER_NODES=$(echo $3 | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    MASTER_NODES_NO_LOCAL_IP=$(echo ${MASTER_NODES} | sed -e 's/'${LOCAL_IP}'//g')
    MASTER_NODES=(${MASTER_NODES})
    MASTER_IP=${MASTER_NODES[0]}

    j=0
    for i in ${MASTER_NODES[@]}; do
        if [ $i == $LOCAL_IP ]; then
            ETCD_PODNAME=etcd$j
            break
        fi
        let j+=1
    done
}
 
kube::install_keepalived()
{
    # kube::get_env $@
    set +e
    which keepalived > /dev/null 2>&1
    i=$?
    set -e
    if [ $i -ne 0 ]; then
        ip addr add ${KUBE_VIP}/16 dev ${VIP_INTERFACE}
        apt install keepalived -y
        systemctl enable keepalived.service && systemctl start keepalived.service
        kube::config_keepalived
    fi
}
 
kube::config_keepalived()
{
  echo "gen keepalived configuration"
cat <<EOF >/etc/keepalived/keepalived.conf
global_defs {
   router_id LVS_k8s
}
 
vrrp_script CheckK8sMaster {
    script "curl -k https://172.30.80.31:6443"
    interval 3
    timeout 9
    fall 2
    rise 2
}
 
vrrp_instance VI_1 {
    state ${HA_STATE}
    interface ${VIP_INTERFACE}
    virtual_router_id 61
    priority ${HA_PRIORITY}
    advert_int 1
    mcast_src_ip ${LOCAL_IP}
    nopreempt
    authentication {
        auth_type PASS
        auth_pass rdprdp
    }
    unicast_peer {
        ${MASTER_NODES_NO_LOCAL_IP}
    }
    virtual_ipaddress {
        ${KUBE_VIP}
    }
    track_script {
        CheckK8sMaster
    }
}
 
EOF
  modprobe ip_vs
  systemctl daemon-reload && systemctl restart keepalived.service
}

kube::install_etcd_cert()
{
    kube::get_env $@

    curl -o /usr/local/bin/cfssl http://$HTTP_SERVER/certs/cfssl
    curl -o /usr/local/bin/cfssljson http://$HTTP_SERVER/certs/cfssljson
    chmod +x /usr/local/bin/cfssl*

    mkdir -p /etc/kubernetes/pki/etcd && cd /etc/kubernetes/pki/etcd

cat <<EOF >ca-config.json
{
    "signing": {
        "default": {
            "expiry": "43800h"
        },
        "profiles": {
            "server": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            },
            "client": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "43800h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat <<EOF >ca-csr.json
{
    "CN": "etcd",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
    	{
            "C": "CN",
            "ST": "ChengDu",
            "L": "ChengDu",
            "O": "k8s",
            "OU": "System"
    	}
    ]
}
EOF

    cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

cat <<EOF >client.json
{
    "CN": "client",
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
    	{
            "C": "CN",
            "ST": "ChengDu",
            "L": "ChengDu",
            "O": "k8s",
            "OU": "System"
    	}
    ]
}
EOF

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client.json | cfssljson -bare client

    cfssl print-defaults csr > config.json
    sed -i '0,/CN/{s/example\.net/'"$PEER_NAME"'/}' config.json
    sed -i 's/www\.example\.net/'"$LOCAL_IP"'/' config.json
    sed -i 's/example\.net/'"$LOCAL_IP"'/' config.json

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer
}

kube::save_master_ip()
{
    set +e
    # 应该从$2里拿到etcd集群的 --endpoints, 这里默认走的127.0.0.1:2379
    [ ${KUBE_HA} == true ] && etcdctl mk ha_master ${LOCAL_IP}
    set -e
}
 
kube::copy_master_config()
{
    kube::get_env $@

    #local master_ip=$(etcdctl get ha_master)
    mkdir -p /etc/kubernetes/pki/etcd && cd /etc/kubernetes/pki/etcd
    scp -r root@${MASTER_IP}:/etc/kubernetes/pki/* /etc/kubernetes/pki
    #rm apiserver.crt

    cfssl print-defaults csr > config.json
    sed -i '0,/CN/{s/example\.net/'"$PEER_NAME"'/}' config.json
    sed -i 's/www\.example\.net/'"$LOCAL_IP"'/' config.json
    sed -i 's/example\.net/'"$LOCAL_IP"'/' config.json

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer
}

kube::install_etcd()
{
    # kube::get_env $@

    curl -sSL http://$HTTP_SERVER/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz | tar -xzv --strip-components=1 -C /usr/local/bin/
    rm -rf etcd-$ETCD_VERSION-linux-amd64*

    touch /etc/etcd.env
    echo "PEER_NAME=$PEER_NAME" >> /etc/etcd.env
    echo "PRIVATE_IP=$LOCAL_IP" >> /etc/etcd.env

cat >/etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
EnvironmentFile=/etc/etcd.env
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

ExecStart=/usr/local/bin/etcd --name ${PEER_NAME} \
    --data-dir /var/lib/etcd \
    --listen-client-urls https://${LOCAL_IP}:2379 \
    --advertise-client-urls https://${LOCAL_IP}:2379 \
    --listen-peer-urls https://${LOCAL_IP}:2380 \
    --initial-advertise-peer-urls https://${LOCAL_IP}:2380 \
    --cert-file=/etc/kubernetes/pki/etcd/server.pem \
    --key-file=/etc/kubernetes/pki/etcd/server-key.pem \
    --client-cert-auth \
    --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
    --peer-cert-file=/etc/kubernetes/pki/etcd/peer.pem \
    --peer-key-file=/etc/kubernetes/pki/etcd/peer-key.pem \
    --peer-client-cert-auth \
    --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
    --initial-cluster etcd0=https://${MASTER_NODES[0]}:2380,etcd1=https://${MASTER_NODES[1]}:2380,etcd1=https://${MASTER_NODES[2]}:2380 \
    --initial-cluster-token my-etcd-token \
    --initial-cluster-state new

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl start etcd
    systemctl status etcd
}
 
kube::config_node()
{
    # kube::get_env $@
    KUBE_VIP=172.30.80.30

    kubectl get configmap -n kube-system kube-proxy -o yaml > kube-proxy.yaml
    sed -i 's#server:.*#server: https://${KUBE_VIP}:6443#g' kube-proxy.cm
    kubectl apply -f kube-proxy.cm --force
    # restart all kube-proxy pods to ensure that they load the new configmap
    kubectl delete pod -n kube-system -l k8s-app=kube-proxy
    sed -i 's#server:.*#server: https://${KUBE_VIP}:6443#g' /etc/kubernetes/kubelet.conf
    systemctl restart kubelet
}

kube::set_label()
{
  until kubectl get no | grep `hostname`; do sleep 1; done
  kubectl label node `hostname` kubeadm.beta.kubernetes.io/role=master
}
 
kube::init_master()
{
    # kube::get_env $@

    cd ~ && mkdir -p $(hostname)-deploy && cd $(hostname)-deploy

cat >config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
api:
  advertiseAddress: ${LOCAL_IP}
etcd:
  endpoints:
  - https://${MASTER_NODES[0]}:2379
  - https://${MASTER_NODES[1]}:2379
  - https://${MASTER_NODES[2]}:2379
  caFile: /etc/kubernetes/pki/etcd/ca.pem
  certFile: /etc/kubernetes/pki/etcd/client.pem
  keyFile: /etc/kubernetes/pki/etcd/client-key.pem
networking:
  podSubnet: 10.244.0.0/16
apiServerCertSANs:
- ${KUBE_VIP}
kubernetesVersion: ${KUBE_VERSION}
apiServerExtraArgs:
  endpoint-reconciler-type: lease

EOF

    systemctl daemon-reload && systemctl start kubelet.service
    kubeadm init --config=config.yaml
    mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
}

kube::master_up()
{
    # shift
 
    kube::install_docker
 
    kube::load_images
 
    kube::install_bin

    kube::install_etcd_cert $@

    kube::install_etcd
 
    [ ${KUBE_HA} == true ] && kube::install_keepalived "MASTER"
 
    # 存储master_ip，master02和master03需要用这个信息来copy配置
    #kube::save_master_ip
 
    # 这里一定要带上--pod-network-cidr参数，不然后面的flannel网络会出问题
    #kubeadm init --kubernetes-version=v1.9.3 --pod-network-cidr=10.244.0.0/16 $@

    kube::init_master
 
    # 使master节点可以被调度
    kubectl taint nodes --all node-role.kubernetes.io/master-
 
    echo -e "\033[32m 注意记录下token信息，node加入集群时需要使用！\033[0m"
 
    # install flannel network
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml
 
    # show pods
    kubectl get pod --all-namespaces
}
 
kube::replica_up()
{
    # shift
 
    kube::install_docker
 
    kube::load_images
 
    kube::install_bin
 
    kube::copy_master_config $@
 
    kube::install_etcd

    kube::init_master
 
    kube::install_keepalived "BACKUP" 

    #kube::set_label
 
}
 
kube::node_up()
{
    # shift

    kube::install_docker
 
    kube::load_images
 
    kube::install_bin
 
    kube::disable_static_pod
 
    kubeadm join $@

    # 如果加入集群时没有指向VIP则需要配置，否则不需要
    #kube::config_node
}
 
kube::tear_down()
{
    systemctl stop kubelet.service
    docker ps -aq|xargs -I '{}' docker stop {}
    docker ps -aq|xargs -I '{}' docker rm {}
    df |grep /var/lib/kubelet|awk '{ print $6 }'|xargs -I '{}' umount {}
    rm -rf /var/lib/kubelet && rm -rf /etc/kubernetes/ && rm -rf /var/lib/etcd
    kubeadm reset
    apt remove -y kubectl kubeadm kubelet kubernetes-cni
    if [ ${KUBE_HA} == true ]
    then
      apt remove -y keepalived
      rm -rf /etc/keepalived/keepalived.conf
    fi
    rm -rf /var/lib/cni
    # ip link del cni0
}
 
main()
{
    case $1 in
    "m" | "master" )
        kube::master_up $@
        ;;
    "r" | "replica" )
        kube::replica_up $@
        ;;
    "j" | "join" )
        kube::node_up $@
        ;;
    "d" | "down" )
        kube::tear_down
        ;;
    "e" | "env" )
        kube::config_env
        ;;
    "c" | "config_node" )
        kube::config_node
        ;;
    "g" | "get_env" )
        kube::get_env $@
        ;;
    *)
        echo "usage: $0 m[master] | r[replica] | j[join] token | d[down] "
        echo "       $0 master to setup master "
        echo "       $0 replica to setup replica master "
        echo "       $0 join   to join master with token "
        echo "       $0 down   to tear all down ,inlude all data! so becarefull"
        echo "       $0 env   to config environment"
        echo "       unkown command $0 $@"
        ;;
    esac
}
 
main $@