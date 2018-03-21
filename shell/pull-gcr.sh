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

docker pull arborhuang/quay-nginx-ingress-controller:0.12.0
docker tage arborhuang/quay-nginx-ingress-controller:0.12.0 quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.12.0
docker save quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.12.0 -o nginx-ingress-controller:0.12.0.tar
docker rmi arborhuang/quay-nginx-ingress-controller:0.12.0

set +x
