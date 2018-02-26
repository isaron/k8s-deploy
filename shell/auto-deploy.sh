#!/bin/bash
set -x
set -e
 
HTTP_SERVER=172.30.80.88:8000
MASTER_IP=172.30.80.31
KUBE_HA=true
 
KUBE_REPO_PREFIX=gcr.io/google_containers
KUBE_VERSION=v1.9.3
ETCD_VERSION=v3.1.11
 
MASTERS=(
    rdp-mgr1.k8s
    rdp-mgr2.k8s
    rdp-mgr3.k8s
)

root=$(id -u)
if [ "$root" -ne 0 ] ;then
    echo must run as root
    exit 1
fi

kube::set_env()
{
    echo "Asia/Chongqing" > /etc/timezone
    swapoff -a && sed -i 's/.*swap.*/#&/' /etc/fstab

    sed -i s/"deb cdrom"/"#deb cdrom"/g /etc/apt/sources.list
    sed -i 's/us.archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
    apt update && apt purge open-vm-tools-desktop -y && apt full-upgrade -yy && apt autoremove -y && apt autoclean
    # apt install ssh vim htop curl ntp ntpdate -y && systemctl stop ntp && ntpdate 172.30.80.88
    apt install ssh vim htop curl -y

    kube::config_ntp

    # passwd root
    # passwd -u root 
    # sed -i s/"PermitRootLogin prohibit-password"/"PermitRootLogin yes"/g /etc/ssh/sshd_config
    # service ssh restart
}
kube::config_ntp()
{
    apt purge ntp -y && apt install ntp -y && systemctl stop ntp
    # mv /etc/ntp.conf /etc/net.conf.bak

cat > /etc/ntp.conf <<EOF
# /etc/ntp.conf, configuration for ntpd; see ntp.conf(5) for help

driftfile /var/lib/ntp/ntp.drift

# Enable this if you want statistics to be logged.
#statsdir /var/log/ntpstats/

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# Specify one or more NTP servers.
server 172.30.80.88
restrict 172.30.80.88 nomodify notrap noquery

# Use servers from the NTP Pool Project. Approved by Ubuntu Technical Board
# on 2011-02-08 (LP: #104525). See http://www.pool.ntp.org/join.html for
# more information.
#pool 0.ubuntu.pool.ntp.org iburst
#pool 1.ubuntu.pool.ntp.org iburst
#pool 2.ubuntu.pool.ntp.org iburst
#pool 3.ubuntu.pool.ntp.org iburst

# Use Ubuntu's ntp server as a fallback.
#pool ntp.ubuntu.com

server 127.127.1.0
fudge 127.127.1.0 stratum 10

# Access control configuration; see /usr/share/doc/ntp-doc/html/accopt.html for
# details.  The web page <http://support.ntp.org/bin/view/Support/AccessRestrictions>
# might also be helpful.
#
# Note that "restrict" applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Needed for adding pool entries
restrict source notrap nomodify noquery

# Clients from this (example!) subnet have unlimited access, but only if
# cryptographically authenticated.
#restrict 192.168.123.0 mask 255.255.255.0 notrust


# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
#broadcast 192.168.123.255

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient

#Changes recquired to use pps synchonisation as explained in documentation:
#http://www.ntp.org/ntpfaq/NTP-s-config-adv.htm#AEN3918

#server 127.127.8.1 mode 135 prefer    # Meinberg GPS167 with PPS
#fudge 127.127.8.1 time1 0.0042        # relative to PPS for my hardware

#server 127.127.22.1                   # ATOM(PPS)
#fudge 127.127.22.1 flag3 1            # enable PPS API

EOF

    # ntpdate 172.30.80.88
    systemctl daemon-reload && systemctl start ntp
    hwclock -w
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
cat >>/etc/sysctl.conf <<EOF
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
    # HA_STATE=$1
    if [ $1 == "master" ]; then
        HA_STATE="MASTER"
    fi
    if [ $1 == "replica" ]; then
        HA_STATE="BACKUP"
    fi
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
            # ETCD_PODNAME=etcd$j
            ETCD_PODNAME=${MASTERS[$j]}
            break
        fi
        let j+=1
    done
}
 
kube::install_keepalived()
{
    kube::get_env $@
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
cat >/etc/keepalived/keepalived.conf <<EOF
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

cat >ca-config.json <<EOF
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

cat >ca-csr.json <<EOF
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

cat >client.json <<EOF
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

# cat > config.json <<EOF
# {
#     "CN": "$PEER_NAME",
#     "hosts": [
#         "172.30.80.31",
#         "172.30.80.32",
#         "172.30.80.33",
#         "172.30.80.30"
#     ],
#     "key": {
#         "algo": "ecdsa",
#         "size": 256
#     },
#     "names": [
#         {
#             "C": "CN",
#             "ST": "ChengDu",
#             "L": "ChengDu",
#             "O": "k8s",
#             "OU": "System"
#     	}
#     ]
# }

# EOF

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
 
kube::copy_etcd_config()
{
    kube::get_env $@

    curl -o /usr/local/bin/cfssl http://$HTTP_SERVER/certs/cfssl
    curl -o /usr/local/bin/cfssljson http://$HTTP_SERVER/certs/cfssljson
    chmod +x /usr/local/bin/cfssl*

    #local master_ip=$(etcdctl get ha_master)
    mkdir -p /etc/kubernetes/pki/etcd && cd /etc/kubernetes/pki/etcd
    scp -r root@${MASTER_IP}:/etc/kubernetes/pki/* /etc/kubernetes/pki
    #rm apiserver.crt

    cfssl print-defaults csr > config.json
    sed -i '0,/CN/{s/example\.net/'"$PEER_NAME"'/}' config.json
    sed -i 's/www\.example\.net/'"$LOCAL_IP"'/' config.json
    sed -i 's/example\.net/'"$LOCAL_IP"'/' config.json

# cat > config.json <<EOF
# {
#     "CN": "$PEER_NAME",
#     "hosts": [
#         "172.30.80.31",
#         "172.30.80.32",
#         "172.30.80.33",
#         "172.30.80.30"
#     ],
#     "key": {
#         "algo": "ecdsa",
#         "size": 256
#     },
#     "names": [
#         {
#             "C": "CN",
#             "ST": "ChengDu",
#             "L": "ChengDu",
#             "O": "k8s",
#             "OU": "System"
#     	}
#     ]
# }

# EOF

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer
}

kube::copy_master_config()
{
    kube::get_env $@

    scp -r root@${MASTER_IP}:/etc/kubernetes/pki/* /etc/kubernetes/pki
    # rm apiserver.crt
}

kube::install_etcd()
{
    # kube::get_env $@

    curl -sSL http://$HTTP_SERVER/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz | tar -xzv --strip-components=1 -C /usr/local/bin/
    rm -rf etcd-$ETCD_VERSION-linux-amd64*

    touch /etc/etcd.env
    echo "" > /etc/etcd.env
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
    --listen-client-urls https://${LOCAL_IP}:2379,http://127.0.0.1:2379 \
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
    --initial-cluster ${MASTERS[0]}=https://${MASTER_NODES[0]}:2380,${MASTERS[1]}=https://${MASTER_NODES[1]}:2380,${MASTERS[2]}=https://${MASTER_NODES[2]}:2380 \
    --initial-cluster-token rdpetcd \
    --initial-cluster-state new

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl start etcd &
    # systemctl status etcd
}

kube::install_etcd_pod()
{
    # kube::get_env $@

    mkdir -p /etc/kubernetes/manifests

cat >/etc/kubernetes/manifests/etcd.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
labels:
    component: etcd
    tier: control-plane
name: ${ETCD_PODNAME}
namespace: kube-system
spec:
containers:
- command:
    - etcd --name ${PEER_NAME} \
    - --data-dir /var/lib/etcd \
    - --listen-client-urls https://${LOCAL_IP}:2379 \
    - --advertise-client-urls https://${LOCAL_IP}:2379 \
    - --listen-peer-urls https://${LOCAL_IP}:2380 \
    - --initial-advertise-peer-urls https://${LOCAL_IP}:2380 \
    - --cert-file=/certs/server.pem \
    - --key-file=/certs/server-key.pem \
    - --client-cert-auth \
    - --trusted-ca-file=/certs/ca.pem \
    - --peer-cert-file=/certs/peer.pem \
    - --peer-key-file=/certs/peer-key.pem \
    - --peer-client-cert-auth \
    - --peer-trusted-ca-file=/certs/ca.pem \
    - --initial-cluster ${MASTERS[0]}=https://${MASTER_NODES[0]}:2380,${MASTERS[1]}=https://${MASTER_NODES[1]}:2380,${MASTERS[2]}=https://${MASTER_NODES[2]}:2380 \
    - --initial-cluster-token rdpetcd \
    - --initial-cluster-state new
    image: gcr.io/google_containers/etcd-amd64:3.1.11
    livenessProbe:
    httpGet:
        path: /health
        port: 2379
        scheme: HTTP
    initialDelaySeconds: 15
    timeoutSeconds: 15
    name: etcd
    env:
    - name: PUBLIC_IP
    valueFrom:
        fieldRef:
        fieldPath: status.hostIP
    - name: PRIVATE_IP
    valueFrom:
        fieldRef:
        fieldPath: status.podIP
    - name: PEER_NAME
    valueFrom:
        fieldRef:
        fieldPath: metadata.name
    volumeMounts:
    - mountPath: /var/lib/etcd
    name: etcd
    - mountPath: /certs
    name: certs
hostNetwork: true
volumes:
- hostPath:
    path: /var/lib/etcd
    type: DirectoryOrCreate
    name: etcd
- hostPath:
    path: /etc/kubernetes/pki/etcd
    name: certs
EOF

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

kube::env_up()
{
    kube::set_env
    
    kube::install_docker
 
    kube::load_images
 
    kube::install_bin
}

kube::etcd_up()
{
    # shift
 
    # kube::install_docker
 
    # kube::load_images
 
    # kube::install_bin

    if [ $(hostname) == ${MASTERS[0]} ]; then
        kube::install_etcd_cert $@
    else
        kube::copy_etcd_config $@
    fi

    kube::install_etcd
    
}

kube::master_up()
{
    # shift
 
    # kube::install_docker
 
    # kube::load_images
 
    # kube::install_bin

    # kube::install_etcd_cert $@

    # kube::install_etcd
 
    [ ${KUBE_HA} == true ] && kube::install_keepalived $@
 
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
 
    # kube::install_docker
 
    # kube::load_images
 
    # kube::install_bin
 
    # kube::copy_etcd_config $@
 
    # kube::install_etcd

    kube::copy_master_config $@

    kube::init_master
 
    kube::install_keepalived

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
    "e" | "etcd" )
        kube::etcd_up $@
        ;;
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
    "v" | "env" )
        kube::env_up
        ;;
    "c" | "config_node" )
        kube::config_node
        ;;
    "g" | "get_env" )
        kube::get_env $@
        ;;
    *)
        echo "usage: $0 e[etcd] m[master] | r[replica] | j[join] token | d[down] s[setenv] c[config_node] g[get_env] "
        echo "       $0 etcd            to setup etcd "
        echo "       $0 master          to setup master "
        echo "       $0 replica         to setup replica master "
        echo "       $0 join            to join master with token "
        echo "       $0 down            to tear all down ,inlude all data! so becarefull "
        echo "       $0 env             to setup environment "
        echo "       $0 config_node     to config nodes "
        echo "       $0 get_env         to get environment "
        echo "       unkown command $0 $@ "
        ;;
    esac
}
 
main $@