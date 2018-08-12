#!/bin/bash

set -x
dockerimages=(
    kube-apiserver-amd64:v1.11.2
    kube-controller-manager-amd64:v1.11.2
    kube-scheduler-amd64:v1.11.2
    kube-proxy-amd64:v1.11.2
    # etcd-amd64:3.2.18
    pause-amd64:3.1
    # k8s-dns-sidecar-amd64:1.14.10
    # k8s-dns-kube-dns-amd64:1.14.10
    # k8s-dns-dnsmasq-nanny-amd64:1.14.10
    kubernetes-dashboard-amd64:v1.8.3
    cluster-autoscaler:v1.3.1
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

#     docker rmi arborhuang/runconduit-$i
#     docker rmi gcr.io/runconduit/$i

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

#     docker rmi arborhuang/spinnaker-$i
#     docker rmi gcr.io/spinnaker-marketplace/$i

#     let j+=1
# done

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

#     docker rmi $i

#     let j+=1
# done

set +x
