#!/bin/bash
set -x
set -e
 
HTTP_SERVER=172.30.80.88:8000

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
    [ $HA_STATE == "MASTER" ] && HA_PRIORITY=100 || HA_PRIORITY=`expr 200 - ${RANDOM} / 1000 + 1`
    KUBE_VIP=$(echo $2 |awk -F= '{print $2}')
    VIP_PREFIX=$(echo ${KUBE_VIP} | cut -d . -f 1,2,3)
    #dhcp和static地址的不同取法
    VIP_INTERFACE=$(ip addr show | grep ${VIP_PREFIX} | awk -F 'dynamic' '{print $2}' | head -1)
    [ -z ${VIP_INTERFACE} ] && VIP_INTERFACE=$(ip addr show | grep ${VIP_PREFIX} | awk -F 'global' '{print $2}' | head -1)
}
 
kube::install_keepalived()
{
    kube::get_env $@
    set +e
    which keepalived > /dev/null 2>&1
    i=$?
    set -e
    if [ $i -ne 0 ]; then
        # ip addr add ${KUBE_VIP}/16 dev ${VIP_INTERFACE}
        apt install keepalived ipvsadm -y
        systemctl enable keepalived.service && systemctl start keepalived.service
        kube::config_keepalived
    fi
}
 
kube::config_keepalived()
{
  echo "gen keepalived configuration"
cat >/etc/keepalived/keepalived.conf <<EOF
global_defs {
   router_id LVS_k8s_lb
}

vrrp_instance VI_1 {
    state ${HA_STATE}
    interface ${VIP_INTERFACE}
    virtual_router_id 51
    priority ${HA_PRIORITY}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass rdplbha
    }
    virtual_ipaddress {
        ${KUBE_VIP}
    }
}

virtual_server 172.30.80.30 6443 {
    delay_loop 6
    lb_algo wrr
    lb_kind DR
    persistence_timeout 0
    protocol TCP

    real_server 172.30.80.31 6443 {
        weight 1
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
            connect_port 6443
        }
    }

    real_server 172.30.80.32 6443 {
        weight 1
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
            connect_port 6443
        }
    }

    real_server 172.30.80.33 6443 {
        weight 1
        TCP_CHECK {
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
            connect_port 6443
        }
    }
}

EOF

    modprobe ip_vs
    systemctl daemon-reload && systemctl restart keepalived.service
    ipvsadm -ln
}

main()
{
    case $1 in
    "m" | "master" )
        kube::install_keepalived $@
        ;;
    "r" | "replica" )
        kube::install_keepalived $@
        ;;
    *)
        echo "usage: $0 m[master] | r[replica]"
        echo "       $0 master          to setup loadbalancer master "
        echo "       $0 replica         to setup loadbalancer replica "
        echo "       unkown command $0 $@ "
        ;;
    esac
}
 
main $@