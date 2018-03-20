# k8s-deploy

k8s version: v1.9.5

Components to be deployed:

- k8s suite
  - kube-apiserver-amd64:v1.9.5
  - kube-controller-manager-amd64:v1.9.5
  - kube-scheduler-amd64:v1.9.5
  - kube-proxy-amd64:v1.9.5
  - etcd-amd64:3.1.12
  - pause-amd64:3.0
  - k8s-dns-sidecar-amd64:1.14.7
  - k8s-dns-kube-dns-amd64:1.14.7
  - k8s-dns-dnsmasq-nanny-amd64:1.14.7
  - kubernetes-dashboard-amd64:v1.8.3
- ingress-nginx
- keepalived
- istio
  - v0.5.0
- prometheus
- grafana
- elk
- netflix suite
- habor
- nexus
- jenkins
- gitlab