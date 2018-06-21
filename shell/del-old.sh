#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.10.3
    kube-controller-manager-amd64:v1.10.3
    kube-scheduler-amd64:v1.10.3
    kube-proxy-amd64:v1.10.3
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
    controller:v0.4.2
    proxy:v0.4.2
    proxy-init:v0.4.2
    web:v0.4.2
    grafana:v0.4.2
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

spinnakerimages=(
    clouddriver:2.0.0-20180221152902
    echo:0.8.0-20180221133510
    deck:2.1.0-20180221143146
    igor:0.9.0-20180221133510
    orca:0.10.0-20180221133510
    gate:0.10.0-20180221133510
    front50:0.9.0-20180221133510
    rosco:0.5.0-20180221133510
)

j=1
for i in ${conduitimages[@]}
do
    echo $i
    echo $j

    docker rmi arborhuang/spinnaker-$i
    docker rmi gcr.io/spinnaker-marketplace/$i

    let j+=1
done

set +x
