#!/bin/bash
set -x
set -e

HTTP_SERVER=172.30.80.88:8000
MASTER_IP=172.30.80.31
KUBE_HA=true

KUBE_REPO_PREFIX=k8s.gcr.io
KUBE_VERSION=v1.11.3
ETCD_VERSION=v3.2.24

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
    apt install ssh vim htop curl nethogs nfs-common -y

    # enable ipvs by default
    modprobe ip_vs
    modprobe ip_vs_wrr
    modprobe ip_vs_sh
    modprobe ip_vs_rr
    modprobe nf_conntrack_ipv4

    # echo "up route del default gw 192.168.52.2" >> /etc/network/interfaces
    # echo "up route add default gw 172.30.80.88" >> /etc/network/interfaces

    ln -fs /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service

cat > /etc/systemd/system/rc-local.service <<EOF
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

# This unit gets pulled automatically into multi-user.target by
# systemd-rc-local-generator if /etc/rc.local is executable.
[Unit]
Description=/etc/rc.local Compatibility
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
Alias=rc-local.service

EOF

cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

modprobe ip_vs
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe ip_vs_rr
modprobe nf_conntrack_ipv4

ip addr add ${KUBE_VIP}/32 dev lo
route add -host ${KUBE_VIP} lo

exit 0

EOF

    chmod 755 /etc/rc.local

    kube::config_ntp

    # passwd root
    # passwd -u root
    # sed -i s/"PermitRootLogin prohibit-password"/"PermitRootLogin yes"/g /etc/ssh/sshd_config
    # service ssh restart
}
kube::config_ntp()
{
    apt purge ntp -y && apt install ntp -y && systemctl stop ntp
    # mv /etc/ntp.conf /etc/ntp.conf.bak

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

    # sysctl net.bridge.bridge-nf-call-iptables=1
    # sysctl net.bridge.bridge-nf-call-ip6tables=1
cat >>/etc/sysctl.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

    apt-mark hold docker-ce
    usermod -aG docker $USER
    curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://e24ee5b3.m.daocloud.io
    systemctl daemon-reload && systemctl restart docker.service
}

kube::load_images()
{
    mkdir -p /tmp/k8s

    images0=(
        kube-apiserver-amd64_v1.11.3
        kube-controller-manager-amd64_v1.11.3
        kube-scheduler-amd64_v1.11.3
        kube-proxy-amd64_v1.11.3
        pause-amd64_3.1
        pause_3.1
        kubernetes-dashboard-amd64_v1.10.0
        cluster-autoscaler_v1.3.1
        coredns_1.2.2

        heapster_v1.3.0
        heapster-amd64_v1.5.4
        heapster-grafana-amd64_v5.0.4
        heapster-influxdb-amd64_v1.5.2
        kube-addon-manager_v8.6
        addon-resizer_1.7
    )

    for i in "${!images0[@]}"; do
        ret=$(docker images | awk 'NR!=1{print $1"_"$2}'| grep $KUBE_REPO_PREFIX/${images0[$i]} | wc -l)
        if [ $ret -lt 1 ];then
            curl -L http://$HTTP_SERVER/images/${images0[$i]}.tar > /tmp/k8s/${images0[$i]}.tar
            docker load -i /tmp/k8s/${images0[$i]}.tar
        fi
    done

    images1=(
        defaultbackend_1.4
        tiller_v2.10.0
        nginx-ingress-controller_0.19.0
        flannel_v0.10.0-amd64
    )

    for i in "${!images1[@]}"; do
        ret=$(docker images | awk 'NR!=1{print $1"_"$2}'| grep ${images1[$i]} | wc -l)
        if [ $ret -lt 1 ];then
            curl -L http://$HTTP_SERVER/images/${images1[$i]}.tar > /tmp/k8s/${images1[$i]}.tar
            docker load -i /tmp/k8s/${images1[$i]}.tar
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
#         apt update && apt install -y apt-transport-https
#         curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -

# cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
# deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
# EOF

#         apt update && apt install socat ebtables ethtool cri-tools -y
        # apt install -y kubelet kubeadm kubectl kubernetes-cni
        # apt install -y kubelet kubeadm kubectl

        systemctl enable kubelet.service && systemctl start kubelet.service && rm -rf /etc/kubernetes
    fi
    kube::config_cni
}

kube::config_cni()
{
    mkdir -p /etc/cni/net.d
cat >/etc/cni/net.d/10-mynet.conf <<EOF
{
    "cniVersion": "0.6.0",
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-gw",
        "subnet": "10.244.0.0/16",
        "routes": [
            {"dst": "0.0.0.0/0"}
        ]
    }
}
EOF
cat >/etc/cni/net.d/99-loopback.conf <<EOF
{
    "cniVersion": "0.6.0",
    "type": "loopback"
}
EOF
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
    LOCAL_IP=$(ip addr show | grep ens | grep ${VIP_PREFIX} | awk -F / '{print $1}' | awk -F ' ' '{print $2}' | head -1)
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

vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 3
    weight -2
    fall 10
    rise 2
}

vrrp_instance VI_1 {
    state ${HA_STATE}
    interface ${VIP_INTERFACE}
    virtual_router_id 61
    priority ${HA_PRIORITY}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass rdpha
    }
    virtual_ipaddress {
        ${KUBE_VIP}
    }
    track_script {
        check_apiserver
    }
}

EOF

cat > /etc/keepalived/check_apiserver.sh <<EOF
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q ${KUBE_VIP}; then
    curl --silent --max-time 2 --insecure https://${KUBE_VIP}:6443/ -o /dev/null || errorExit "Error GET https://${KUBE_VIP}:6443/"
fi
EOF

    chmod +x /etc/keepalived/check_apiserver.sh
    modprobe ip_vs
    systemctl daemon-reload && systemctl restart keepalived.service
}

kube::config_loadbalancer()
{
    kube::get_env $@

    modprobe ip_vs
    ln -fs /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service

cat > /etc/systemd/system/rc-local.service <<EOF
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

# This unit gets pulled automatically into multi-user.target by
# systemd-rc-local-generator if /etc/rc.local is executable.
[Unit]
Description=/etc/rc.local Compatibility
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
Alias=rc-local.service

EOF

cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

modprobe ip_vs
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe ip_vs_rr
modprobe nf_conntrack_ipv4

ip addr add ${KUBE_VIP}/32 dev lo
route add -host ${KUBE_VIP} lo

exit 0

EOF

    chmod 755 /etc/rc.local

cat >> /etc/sysctl.conf <<EOF
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.lo.arp_ignore = 1
net.ipv4.conf.lo.arp_announce = 2
EOF

    # sysctl -p

}

kube::install_etcd_cert()
{
    kube::get_env $@

    curl -o /usr/local/bin/cfssl http://$HTTP_SERVER/bin/cfssl
    curl -o /usr/local/bin/cfssljson http://$HTTP_SERVER/bin/cfssljson
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
            "L": "SiChuan",
            "ST": "ChengDu",
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
            "L": "SiChuan",
            "ST": "ChengDu",
            "O": "k8s",
            "OU": "System"
    	}
    ]
}
EOF

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client.json | cfssljson -bare client

    cfssl print-defaults csr > config.json
    # sed -i '0,/CN/{s/example\.net/'"$PEER_NAME"'/}' config.json
    # sed -i 's/www\.example\.net/'"$LOCAL_IP"'/' config.json
    # sed -i 's/example\.net/'"$LOCAL_IP"'/' config.json

cat > config.json <<EOF
{
    "CN": "$PEER_NAME",
    "hosts": [
        "127.0.0.1",
        "k8s.rdp.dev",
        "rdp.dev",
        "10.244.0.1",
        "10.96.0.1",
        "172.30.80.88",
        "172.30.80.89",
        "172.30.80.21",
        "172.30.80.22",
        "172.30.80.23",
        "172.30.80.24",
        "172.30.80.25",
        "172.30.80.26",
        "172.30.80.27",
        "172.30.80.28",
        "172.30.80.31",
        "172.30.80.32",
        "172.30.80.33",
        "172.30.80.34",
        "172.30.80.35",
        "172.30.80.36",
        "172.30.80.61",
        "172.30.80.62",
        "172.30.80.63",
        "172.30.80.64",
        "172.30.80.65",
        "172.30.80.81",
        "kubernetes",
        "kubernetes.default",
        "kubernetes.default.svc",
        "kubernetes.default.svc.cluster",
        "kubernetes.default.svc.cluster.local",
        "k8s.local"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "CN",
            "L": "SiChuan",
            "ST": "ChengDu",
            "O": "k8s",
            "OU": "System"
    	}
    ]
}

EOF

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

    curl -o /usr/local/bin/cfssl http://$HTTP_SERVER/bin/cfssl
    curl -o /usr/local/bin/cfssljson http://$HTTP_SERVER/bin/cfssljson
    chmod +x /usr/local/bin/cfssl*

    #local master_ip=$(etcdctl get ha_master)
    mkdir -p /etc/kubernetes/pki/etcd && cd /etc/kubernetes/pki/etcd
    scp -r root@${MASTER_IP}:/etc/kubernetes/pki/etcd/ca* /etc/kubernetes/pki/etcd
    scp -r root@${MASTER_IP}:/etc/kubernetes/pki/etcd/client* /etc/kubernetes/pki/etcd
    #rm apiserver.crt

    cfssl print-defaults csr > config.json
    # sed -i '0,/CN/{s/example\.net/'"$PEER_NAME"'/}' config.json
    # sed -i 's/www\.example\.net/'"$LOCAL_IP"'/' config.json
    # sed -i 's/example\.net/'"$LOCAL_IP"'/' config.json

cat > config.json <<EOF
{
    "CN": "$PEER_NAME",
    "hosts": [
        "127.0.0.1",
        "k8s.rdp.dev",
        "rdp.dev",
        "10.244.0.1",
        "10.96.0.1",
        "172.30.80.88",
        "172.30.80.89",
        "172.30.80.21",
        "172.30.80.22",
        "172.30.80.23",
        "172.30.80.24",
        "172.30.80.25",
        "172.30.80.26",
        "172.30.80.27",
        "172.30.80.28",
        "172.30.80.31",
        "172.30.80.32",
        "172.30.80.33",
        "172.30.80.34",
        "172.30.80.35",
        "172.30.80.36",
        "172.30.80.61",
        "172.30.80.62",
        "172.30.80.63",
        "172.30.80.64",
        "172.30.80.65",
        "172.30.80.81",
        "kubernetes",
        "kubernetes.default",
        "kubernetes.default.svc",
        "kubernetes.default.svc.cluster",
        "kubernetes.default.svc.cluster.local",
        "k8s.local"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "CN",
            "L": "SiChuan",
            "ST": "ChengDu",
            "O": "k8s",
            "OU": "System"
    	}
    ]
}

EOF

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server config.json | cfssljson -bare server
    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer config.json | cfssljson -bare peer
}

kube::copy_master_config()
{
    # kube::get_env $@

    scp root@${MASTER_IP}:/etc/kubernetes/pki/ca.crt /etc/kubernetes/pki
    scp root@${MASTER_IP}:/etc/kubernetes/pki/ca.key /etc/kubernetes/pki
    scp root@${MASTER_IP}:/etc/kubernetes/pki/sa.key /etc/kubernetes/pki
    scp root@${MASTER_IP}:/etc/kubernetes/pki/sa.pub /etc/kubernetes/pki
    scp root@${MASTER_IP}:/etc/kubernetes/pki/front-proxy-ca.crt /etc/kubernetes/pki
    scp root@${MASTER_IP}:/etc/kubernetes/pki/front-proxy-ca.key /etc/kubernetes/pki
    scp root@${MASTER_IP}:/etc/kubernetes/admin.conf /etc/kubernetes
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
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos/etcd

[Service]
EnvironmentFile=/etc/etcd.env
Type=notify
Restart=always
RestartSec=5
LimitNOFILE=40000
TimeoutStartSec=0

ExecStart=/usr/local/bin/etcd --name ${PEER_NAME} \
    --data-dir /var/lib/etcd \
    --listen-client-urls https://${LOCAL_IP}:2379,https://127.0.0.1:2379 \
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
    # sed -i s/"--initial-cluster-state new "/"--initial-cluster-state existing "/g /etc/systemd/system/etcd.service
    # systemctl daemon-reload && systemctl restart etcd
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
    - --listen-client-urls https://${LOCAL_IP}:2379,http://127.0.0.1:2379 \
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
    image: gcr.io/google_containers/etcd-amd64:3.2.18
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

kube::config_master()
{
    # kube::get_env $@
    # KUBE_VIP=172.30.80.30

    # on master
    kubectl get configmap -n kube-system kube-proxy -o yaml > kube-proxy-cm.yaml
    sed -i 's#server:.*#server: https://172.30.80.30:6443#g' kube-proxy-cm.yaml
    kubectl apply -f kube-proxy-cm.yaml --force
    # restart all kube-proxy pods to ensure that they load the new configmap
    kubectl delete pod -n kube-system -l k8s-app=kube-proxy

    # kubectl get cm -n kube-public cluster-info -o yaml > cluster-info-cm.yaml
    # sed -i 's#server:.*#server: https://172.30.80.30:6443#g' kube-proxy-cm.yaml
    # kubectl apply -f cluster-info-cm.yaml --force
}

kube::config_node()
{
    # kube::get_env $@
    # KUBE_VIP=172.30.80.30

    # on node
    # sed -i 's#server:.*#server: https://172.30.80.30:6443#g' /etc/kubernetes/kubelet.conf
    # systemctl restart kubelet
    mkdir -p $HOME/.kube && scp root@172.30.80.31:/etc/kubernetes/admin.conf $HOME/.kube/config
}

kube::set_label()
{
  until kubectl get no | grep `hostname`; do sleep 1; done
  kubectl label node `hostname` kubeadm.beta.kubernetes.io/role=master
#   kubectl label node `hostname` node-role.kubernetes.io/master=""
  kubectl label node `hostname` node-type=master
  kubectl label node `hostname` node-role=mgr
}

kube::set_label_node()
{
  until kubectl get no | grep `hostname`; do sleep 1; done
  kubectl label node `hostname` node-role.kubernetes.io/node=""
  kubectl label node `hostname` node-role=mgr
}

kube::init_master()
{
    # kube::get_env $@

    cd ~ && mkdir -p $(hostname)-deploy && cd $(hostname)-deploy

# for k8s <1.11
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

# for k8s 1.11

cat >kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: ${KUBE_VERSION}
apiServerCertSANs:
- ${KUBE_VIP}
- ${MASTER_NODES[0]}
- ${MASTER_NODES[1]}
- ${MASTER_NODES[2]}
- ${MASTERS[0]}
- ${MASTERS[1]}
- ${MASTERS[2]}
- "127.0.0.1"
api:
    advertiseAddress: ${LOCAL_IP}
    controlPlaneEndpoint: ${KUBE_VIP}:6443
apiServerExtraArgs:
    endpoint-reconciler-type: lease
    disable-admission-plugins: AlwaysPullImages
etcd:
    external:
        endpoints:
        - https://${MASTER_NODES[0]}:2379
        - https://${MASTER_NODES[1]}:2379
        - https://${MASTER_NODES[2]}:2379
        caFile: /etc/kubernetes/pki/etcd/ca.pem
        certFile: /etc/kubernetes/pki/etcd/client.pem
        keyFile: /etc/kubernetes/pki/etcd/client-key.pem
controllerManagerExtraArgs:
    node-monitor-grace-period: 10s
    pod-eviction-timeout: 10s
networking:
    podSubnet: 10.244.0.0/16
kubeProxy:
    config:
        mode: ipvs
        # mode: iptables
EOF

    systemctl daemon-reload && systemctl start kubelet.service
    # kubeadm init --config=config.yaml --feature-gates=CoreDNS=true
    # kubeadm init --config=config.yaml
    kubeadm init --config kubeadm-config.yaml
     #--ignore-preflight-errors=all
    mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
}

kube::init_replica()
{
    # kube::get_env $@

    cd ~ && mkdir -p $(hostname)-deploy && cd $(hostname)-deploy

# for k8s 1.11

cat >kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: ${KUBE_VERSION}
apiServerCertSANs:
- ${KUBE_VIP}
- ${MASTER_NODES[0]}
- ${MASTER_NODES[1]}
- ${MASTER_NODES[2]}
- ${MASTERS[0]}
- ${MASTERS[1]}
- ${MASTERS[2]}
- "127.0.0.1"
api:
    advertiseAddress: ${LOCAL_IP}
    controlPlaneEndpoint: ${KUBE_VIP}:6443
apiServerExtraArgs:
    endpoint-reconciler-type: lease
    disable-admission-plugins: AlwaysPullImages
etcd:
    external:
        endpoints:
        - https://${MASTER_NODES[0]}:2379
        - https://${MASTER_NODES[1]}:2379
        - https://${MASTER_NODES[2]}:2379
        caFile: /etc/kubernetes/pki/etcd/ca.pem
        certFile: /etc/kubernetes/pki/etcd/client.pem
        keyFile: /etc/kubernetes/pki/etcd/client-key.pem
controllerManagerExtraArgs:
    node-monitor-grace-period: 10s
    pod-eviction-timeout: 10s
networking:
    podSubnet: 10.244.0.0/16
kubeProxy:
    config:
        mode: ipvs
        # mode: iptables
EOF

    # 配置kubelet
    kubeadm alpha phase certs all --config kubeadm-config.yaml
    kubeadm alpha phase kubelet config write-to-disk --config kubeadm-config.yaml
    kubeadm alpha phase kubelet write-env-file --config kubeadm-config.yaml
    kubeadm alpha phase kubeconfig kubelet --config kubeadm-config.yaml
    systemctl daemon-reload && systemctl start kubelet.service

    # 部署
    kubeadm alpha phase kubeconfig all --config kubeadm-config.yaml
    kubeadm alpha phase controlplane all --config kubeadm-config.yaml
    kubeadm alpha phase mark-master --config kubeadm-config.yaml

    # systemctl daemon-reload && systemctl start kubelet.service
    # kubeadm init --config=config.yaml --feature-gates=CoreDNS=true
    # kubeadm init --config=config.yaml
    # kubeadm init --config kubeadm-config.yaml
     #--ignore-preflight-errors=all
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

    [ ${KUBE_HA} == true ] && kube::config_loadbalancer $@

    # 存储master_ip，master02和master03需要用这个信息来copy配置
    #kube::save_master_ip

    # 这里一定要带上--pod-network-cidr参数，不然后面的flannel网络会出问题
    #kubeadm init --kubernetes-version=v1.11.3 --pod-network-cidr=10.244.0.0/16 $@

    kube::init_master

    echo -e "\033[32m 注意记录下token信息，node加入集群时需要使用！\033[0m"

    # install flannel network
    kubectl apply -f http://172.30.80.88:8000/config/kube-flannel.yml

    # kube::set_label

    # show pods
    kubectl get pods --all-namespaces

    # 更新配置使kube-proxy通过VIP访问apiserver
    # don't need for v1.11
    # kube::config_master

    # 使master节点可以被调度
    # kubectl taint nodes --all node-role.kubernetes.io/master-
}

kube::replica_up()
{
    # shift

    # kube::install_docker

    # kube::load_images

    # kube::install_bin

    # kube::copy_etcd_config $@

    # kube::install_etcd

    kube::config_loadbalancer $@

    kube::copy_master_config

    # kube::init_master
    kube::init_replica

    kube::set_label

    # 更新配置使kube-proxy通过VIP访问apiserver
    # don't need for v1.11
    # kube::config_master

    kubectl taint nodes --all node-role.kubernetes.io/master-

}

kube::node_up()
{
    # shift

    kube::install_docker

    kube::load_images

    kube::install_bin

    kube::disable_static_pod

    kubeadm $@

    kube::config_node

    kube::set_label_node
}

kube::tear_down()
{
    kubectl drain $(hostname) --delete-local-data --force --ignore-daemonsets
    kubectl delete node $(hostname)
    kubeadm reset
    systemctl daemon-reload && systemctl stop kubelet.service
     #etcd.service
    docker ps -aq|xargs -I '{}' docker stop {}
    docker ps -aq|xargs -I '{}' docker rm {}
    df |grep /var/lib/kubelet|awk '{ print $6 }'|xargs -I '{}' umount {}
    rm -rf /var/lib/kubelet && rm -rf /etc/kubernetes/ && rm -rf /var/lib/etcd
     #&& rm -rf /etc/systemd/system/kubelet.service.d
    # kubeadm reset -f
    apt purge -y kubectl kubeadm kubelet kubernetes-cni cri-tools
    # if [ ${KUBE_HA} == true ]
    # then
    #   apt purge -y keepalived
    #   rm -rf /etc/keepalived/keepalived.conf
    #   ip addr del ${KUBE_VIP} dev ${VIP_INTERFACE}
    # fi
    rm -rf /var/lib/cni
    rm -rf ~/.kube
    # ip link del cni0
    service networking restart
    curl -L http://172.30.80.88:8000/shell/del-old.sh -o del-old.sh
    chmod +x del-old.sh && ./del-old.sh
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
    "l" | "load_images" )
        kube::load_images
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
        echo "       $0 load_images     to load docker images "
        echo "       $0 get_env         to get environment "
        echo "       unkown command $0 $@ "
        ;;
    esac
}

main $@
