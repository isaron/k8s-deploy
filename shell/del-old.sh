#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.9.7
    kube-controller-manager-amd64:v1.9.7
    kube-scheduler-amd64:v1.9.7
    kube-proxy-amd64:v1.9.7
    etcd-amd64:3.1.12
    pause-amd64:3.0
    k8s-dns-sidecar-amd64:1.14.7
    k8s-dns-kube-dns-amd64:1.14.7
    k8s-dns-dnsmasq-nanny-amd64:1.14.7
    kubernetes-dashboard-amd64:v1.8.3
    cluster-autoscaler:v1.1.2
    defaultbackend:1.4
)

j=1
for i in ${dockerimages[@]}
do
    echo $i
    echo $j

    docker rmi arborhuang/$i
    docker rmi k8s.gcr.io/$i
    docker rmi gcr.io/google_containers/$i

    let j+=1
done

conduitimages=(
    controller:v0.4.1
    proxy:v0.4.1
    proxy-init:v0.4.1
    web:v0.4.1
    grafana:v0.4.1
)

j=1
for i in ${conduitimages[@]}
do
    echo $i
    echo $j

    docker rmi arborhuang/runconduit-$i
    docker rmi gcr.io/runconduit/$i

    let j+=1
done

set +x
