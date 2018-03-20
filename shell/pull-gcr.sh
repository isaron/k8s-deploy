#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.9.5
    kube-controller-manager-amd64:v1.9.5
    kube-scheduler-amd64:v1.9.5
    kube-proxy-amd64:v1.9.5
    etcd-amd64:3.1.12
    flannel:v0.9.1-amd64
    pause-amd64:3.0
    k8s-dns-sidecar-amd64:1.14.7
    k8s-dns-kube-dns-amd64:1.14.7
    k8s-dns-dnsmasq-nanny-amd64:1.14.7
    kubernetes-dashboard-amd64:v1.8.3
)

j=1
for i in ${dockerimages[@]}
do
    echo $i
    echo $j

    docker pull arborhuang/$i
    docker tag arborhuang/$i gcr.io/google_containers/$i 
    docker save gcr.io/google_containers/$i -o $i.tar
    docker rmi arborhuang/$i

    let j+=1
done

# dashboard: if pull dashboard error
# docker pull arborhuang/dashboard:v1.8.3
# docker tag arborhuang/dashboard:v1.8.3 k8s.gcr.io/kubernetes-dashboard-amd64:v1.8.3
# docker save k8s.gcr.io/kubernetes-dashboard-amd64:v1.8.3 -o kubernetes-dashboard-amd64:v1.8.3.tar
# docker rmi arborhuang/dashboard:v1.8.3

set +x
