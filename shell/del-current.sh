#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.10.2
    kube-controller-manager-amd64:v1.10.2
    kube-scheduler-amd64:v1.10.2
    kube-proxy-amd64:v1.10.2
    etcd-amd64:3.1.12
    pause-amd64:3.1
    k8s-dns-sidecar-amd64:1.14.10
    k8s-dns-kube-dns-amd64:1.14.10
    k8s-dns-dnsmasq-nanny-amd64:1.14.10
    kubernetes-dashboard-amd64:v1.8.3
    cluster-autoscaler:v1.2.1
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

set +x
