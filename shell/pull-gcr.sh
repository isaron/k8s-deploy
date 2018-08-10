#!/bin/bash

set -x
k8simages=(
    kube-apiserver-amd64:v1.10.6
    kube-controller-manager-amd64:v1.10.6
    kube-scheduler-amd64:v1.10.6
    kube-proxy-amd64:v1.10.6
    # etcd-amd64:3.1.12
    pause-amd64:3.1
    # k8s-dns-sidecar-amd64:1.14.10
    # k8s-dns-kube-dns-amd64:1.14.10
    # k8s-dns-dnsmasq-nanny-amd64:1.14.10
    kubernetes-dashboard-amd64:v1.8.3
    cluster-autoscaler:v1.2.2
    defaultbackend:1.4
)

j=1
for i in ${k8simages[@]}
do
    echo $i
    echo $j

    docker pull arborhuang/$i
    docker tag arborhuang/$i k8s.gcr.io/$i
    docker save k8s.gcr.io/$i -o $i.tar
    docker rmi arborhuang/$i

    let j+=1
done

docker pull quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.17.1
docker save quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.17.1 -o nginx-ingress-controller:0.17.1.tar

docker pull quay.io/coreos/flannel:v0.10.0-amd64
docker save quay.io/coreos/flannel:v0.10.0-amd64 -o flannel:v0.10.0-amd64.tar

docker pull arborhuang/tiller:v2.9.1
docker tag arborhuang/tiller:v2.9.1 gcr.io/kubernetes-helm/tiller:v2.9.1
docker save gcr.io/kubernetes-helm/tiller:v2.9.1 -o tiller:v2.9.1.tar
docker rmi arborhuang/tiller:v2.9.1

docker pull coredns/coredns:1.1.2
docker save coredns/coredns:1.1.2 -o coredns:1.1.2.tar

# conduitimages=(
#     controller:v0.5.0
#     proxy:v0.5.0
#     proxy-init:v0.5.0
#     web:v0.5.0
#     grafana:v0.5.0
# )

# j=1
# for i in ${conduitimages[@]}
# do
#     echo $i
#     echo $j

#     docker pull arborhuang/runconduit-$i
#     docker tag arborhuang/runconduit-$i gcr.io/runconduit/$i
#     docker save gcr.io/runconduit/$i -o runconduit-$i.tar
#     docker rmi arborhuang/runconduit-$i

#     let j+=1
# done

# spinnakerimages=(
#     clouddriver:2.0.0-20180221152902
#     echo:0.8.0-20180221133510
#     deck:2.1.0-20180221143146
#     igor:0.9.0-20180221133510
#     orca:0.10.0-20180221133510
#     gate:0.10.0-20180221133510
#     front50:0.9.0-20180221133510
#     rosco:0.5.0-20180221133510
# )

# j=1
# for i in ${spinnakerimages[@]}
# do
#     echo $i
#     echo $j

#     docker pull arborhuang/spinnaker-$i
#     docker tag arborhuang/spinnaker-$i gcr.io/spinnaker-marketplace/$i
#     docker save gcr.io/spinnaker-marketplace/$i -o spinnaker-$i.tar
#     docker rmi arborhuang/spinnaker-$i

#     let j+=1
# done

jximages=(
    heapster:v1.3.0
    heapster-amd64:v1.5.0
    heapster-grafana-amd64:v4.4.3
    heapster-influxdb-amd64:v1.3.3
    kube-addon-manager:v8.6
    addon-resizer:1.7
)

j=1
for i in ${jximages[@]}
do
    echo $i
    echo $j

    docker pull arborhuang/$i
    docker tag arborhuang/$i k8s.gcr.io/$i
    docker save k8s.gcr.io/$i -o $i.tar
    docker rmi arborhuang/$i

    let j+=1
done

# jximages2=(
#     chartmuseum/chartmuseum:v0.2.8
#     jenkinsxio/jenkinsx:0.0.25
#     jenkinsci/jnlp-slave:3.14-1
#     jenkinsxio/builder-maven:0.0.280
#     jenkinsxio/builder-gradle:0.0.163
#     jenkinsxio/builder-scala:0.0.96
#     jenkinsxio/builder-go:0.0.275
#     jenkinsxio/builder-terraform:0.0.52
#     jenkinsxio/builder-rust:0.0.130
#     jenkinsxio/builder-nodejs:0.0.228
#     jenkinsxio/builder-base:0.0.312
#     jenkinsxio/builder-python2:0.0.45
#     jenkinsxio/builder-python:0.0.46
#     jenkinsxio/builder-ruby:0.0.312
#     jenkinsxio/builder-swift:0.0.312
# )

# j=1
# for i in ${jximages2[@]}
# do
#     echo $i
#     echo $j

#     docker pull $i

#     let j+=1
# done

set +x
