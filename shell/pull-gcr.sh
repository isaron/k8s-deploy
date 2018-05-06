#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.10.2
    kube-controller-manager-amd64:v1.10.2
    kube-scheduler-amd64:v1.10.2
    kube-proxy-amd64:v1.10.2
    etcd-amd64:3.1.12
    pause-amd64:3.0
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

    docker pull arborhuang/$i
    docker tag arborhuang/$i k8s.gcr.io/$i
    docker save k8s.gcr.io/$i -o $i.tar
    docker rmi arborhuang/$i

    let j+=1
done

docker pull arborhuang/quay-nginx-ingress-controller:0.12.0
docker tag arborhuang/quay-nginx-ingress-controller:0.12.0 quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.12.0
docker save quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.12.0 -o nginx-ingress-controller:0.12.0.tar
docker rmi arborhuang/quay-nginx-ingress-controller:0.12.0

docker pull arborhuang/flannel:v0.10.0-amd64
docker tag arborhuang/flannel:v0.10.0-amd64 quay.io/coreos/flannel:v0.10.0-amd64
docker save quay.io/coreos/flannel:v0.10.0-amd64 -o flannel:v0.10.0-amd64.tar
docker rmi arborhuang/flannel:v0.10.0-amd64

docker pull arborhuang/tiller:v2.8.2
docker tag arborhuang/tiller:v2.8.2 gcr.io/kubernetes-helm/tiller:v2.8.2
docker save gcr.io/kubernetes-helm/tiller:v2.8.2 -o tiller:v2.8.2.tar
docker rmi arborhuang/tiller:v2.8.2

set +x
