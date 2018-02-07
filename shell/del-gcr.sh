#!/bin/bash

set -x
dockerimages=(kube-apiserver-amd64:v1.9.2
kube-controller-manager-amd64:v1.9.2
kube-scheduler-amd64:v1.9.2
kube-proxy-amd64:v1.9.2
etcd-amd64:3.1.11
pause-amd64:3.0
k8s-dns-sidecar-amd64:1.14.7
k8s-dns-kube-dns-amd64:1.14.7
k8s-dns-dnsmasq-nanny-amd64:1.14.7
kubenetes-dashboard-amd64:v1.8.2)

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
