# k8s-deploy

k8s version: v1.9.2

Components to be deployed:

- k8s suite
  - kube-apiserver-amd64:v1.9.2
  - kube-controller-manager-amd64:v1.9.2
  - kube-scheduler-amd64:v1.9.2
  - kube-proxy-amd64:v1.9.2
  - etcd-amd64:3.1.11
  - pause-amd64:3.0
  - k8s-dns-sidecar-amd64:1.14.7
  - k8s-dns-kube-dns-amd64:1.14.7
  - k8s-dns-dnsmasq-nanny-amd64:1.14.7
  - kubenetes-dashboard-amd64:v1.8.2
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