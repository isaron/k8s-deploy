# k8s-deploy

k8s version: v1.11.6

Components to be deployed:

- k8s suite
  - kube-apiserver-amd64:v1.11.6
  - kube-controller-manager-amd64:v1.11.6
  - kube-scheduler-amd64:v1.11.6
  - kube-proxy-amd64:v1.11.6
  - etcd-amd64:3.2.18
  - pause-amd64:3.1
  - k8s-dns-sidecar-amd64:1.14.10 (removed)
  - k8s-dns-kube-dns-amd64:1.14.10 (removed)
  - k8s-dns-dnsmasq-nanny-amd64:1.14.10 (removed)
  - kubernetes-dashboard-amd64:v1.10.1
  - cluster-autoscaler:v1.3.3
  - coredns:1.2.2 (replacing k8s-dns)
- ingress-nginx
  - 0.19.0
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
