# k8s-deploy

k8s version: v1.11.3

Components to be deployed:

- k8s suite
  - kube-apiserver-amd64:v1.11.3
  - kube-controller-manager-amd64:v1.11.3
  - kube-scheduler-amd64:v1.11.3
  - kube-proxy-amd64:v1.11.3
  - etcd-amd64:3.2.18
  - pause-amd64:3.1
  - k8s-dns-sidecar-amd64:1.14.10
  - k8s-dns-kube-dns-amd64:1.14.10
  - k8s-dns-dnsmasq-nanny-amd64:1.14.10
  - kubernetes-dashboard-amd64:v1.10.0
  - cluster-autoscaler:v1.3.1
  - coredns:1.2.2 (replacing k8s-dns)
- ingress-nginx
  - 0.17.1
- lvs + keepalived
- metallb
- cert-manager
- istio
  - v1.0.2
- conduit (removed)
  - v0.5.0
- helm + draft
- prometheus
- grafana
- efk stack
- netflix suite
- habor + dragonfly
- nexus
- jenkins
- gogs/gitea
- ...
