#!/bin/bash
set -x
set -e
 
HTTP_SERVER=172.30.80.88:8000
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