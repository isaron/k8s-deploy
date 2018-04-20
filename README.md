# k8s-deploy

k8s version: v1.9.7

Components to be deployed:

- k8s suite
  - kube-apiserver-amd64:v1.9.7
  - kube-controller-manager-amd64:v1.9.7
  - kube-scheduler-amd64:v1.9.7
  - kube-proxy-amd64:v1.9.7
  - etcd-amd64:3.1.12
  - pause-amd64:3.0
  - k8s-dns-sidecar-amd64:1.14.10
  - k8s-dns-kube-dns-amd64:1.14.10
  - k8s-dns-dnsmasq-nanny-amd64:1.14.10
  - kubernetes-dashboard-amd64:v1.8.3
  - cluster-autoscaler:v1.1.2
- ingress-nginx # disabled, using istio-ingress
- lvs + keepalived
- istio
  - v0.7.1
- helm + draft
- prometheus
- grafana
- elk stack
- netflix suite
- habor + dragonfly
- nexus
- jenkins
- gitlab (or gogs)
- ...