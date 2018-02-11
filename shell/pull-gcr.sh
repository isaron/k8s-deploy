#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.9.3
    kube-controller-manager-amd64:v1.9.3
    kube-scheduler-amd64:v1.9.3
    kube-proxy-amd64:v1.9.3
    etcd-amd64:3.1.11
    pause-amd64:3.0
    k8s-dns-sidecar-amd64:1.14.7
    k8s-dns-kube-dns-amd64:1.14.7
    k8s-dns-dnsmasq-nanny-amd64:1.14.7
    kubenetes-dashboard-amd64:v1.8.2
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
# docker pull arborhuang/dashboard:v1.8.2
# docker tag arborhuang/dashboard:v1.8.2 gcr.io/google_containers/kubenetes-dashboard-amd64:v1.8.2
# docker save gcr.io/google_containers/kubenetes-dashboard-amd64:v1.8.2 -o kubenetes-dashboard-amd64:v1.8.2.tar
# docker rmi arborhuang/dashboard:v1.8.2

set +x
