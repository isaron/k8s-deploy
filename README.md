# k8s-deploy

k8s version: v1.10.3

Components to be deployed:

- k8s suite
  - kube-apiserver-amd64:v1.10.3
  - kube-controller-manager-amd64:v1.10.3
  - kube-scheduler-amd64:v1.10.3
  - kube-proxy-amd64:v1.10.3
  - etcd-amd64:3.1.12
  - pause-amd64:3.1
  - k8s-dns-sidecar-amd64:1.14.10
  - k8s-dns-kube-dns-amd64:1.14.10
  - k8s-dns-dnsmasq-nanny-amd64:1.14.10
  - kubernetes-dashboard-amd64:v1.8.3
  - cluster-autoscaler:v1.2.2
  - coredns:1.1.2 (replacing k8s-dns)
- ingress-nginx # disabled, using istio-ingress
- lvs + keepalived
- metallb
- istio
  - v0.8.0 (LTS)
- conduit
  - v0.4.2
- helm + draft
- prometheus
- grafana
- efk stack
- netflix suite
- habor + dragonfly
- nexus
- jenkins
- gitlab (or gogs/gitea)
- ...
