# k8s-deploy

Mannual deploying HA k8s cluster. Base configes and process.

Current supported k8s version: v1.11.6

### Components to be deployed:

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
- network
    - pdns
    - lvs + keepalived
    - coredns:1.5.2 (replacing k8s-dns)
    - flannel
    - ingress-nginx:0.25.0
    - metallb
    - external-dns
- storage
    - nfs-client-provision
    - postgresql
    - mariadb/mysql
- security
    - OpenLDAP
    - cert-manager
    - kubeseal
    - keycloak
- metrics
    - heapster
    - metrics-server
    - fluentd-es
    - prometheus
    - grafana
    - efk stack
- service mesh
    - istio:v1.2.2
    - conduit:v0.5.0 (removed)
- devops infra
    - habor + dragonfly
    - nexus
    - jenkins/gocd
    - gogs/gitea
    - helm + draft
    - kubeapps
    - chartmuseum
    - sonarqube
- other tools
    - netflix suite

### Deploy process and steps:
#### Plan
Always, it's a good idea that make a global planning before doing something. 
#### Prepare
1. Prepare server's os, here the oses based on Ubuntu 16.04 LTS. And define server's IP, DNS, other os configs could be modified by shells as later setps.
2. Setup a http-server to locate files such as `config`, `certs`, `docker images`, `debs` and some bins like `cfssl` etc. 
3. Pre download debs, kube-* bins, docker images, configs, tar/modify them and upload them to the http-server. Pre make certs and upload them too.
#### Base deploy
0. Define some 
```
HTTP_SERVER: the http-server's IP address or FQDN 
KUBE_VIP: the vip address of k8s masters
```
1. Setup environment for master/nodes.
```
curl -L http://$HTTP_SERVER/shell/auto-deploy.sh | bash -s env
```
This step will install needed tools like ssh, curl, ntp, docker runtime, kubelet/kubeadm/kubectl, and upgrade the os to newest stable. Also modify the server's configs like swap, network protocal, ntp configs. 
Check if all correct. 

2. Deploy external etcd cluster
Suggest deploy etcd cluster on the same master servers. On all masters:
```
curl -L http://$HTTP_SERVER/shell/auto-deploy.sh | bash -s etcd \
    --api-advertise-addresses=$KUBE_VIP \
    --etcd-endpoints=https://${ETCD_NODES[0]}:2379,https://${ETCD_NODES[1]}:2379,https://${ETCD_NODES[2]}:2379
```
Wait etcd service active on all masters, etcd cluster could be ready.

3. Deploy the first master
On the first master:
```
curl -L http://$HTTP_SERVER/shell/auto-deploy.sh | bash -s master \
    --api-advertise-addresses=$KUBE_VIP \
    --etcd-endpoints=https://${ETCD_NODES[0]}:2379,https://${ETCD_NODES[1]}:2379,https://${ETCD_NODES[2]}:2379
```
When ready, record the `token` `sha256` from deploy log.

4. Deploy other masters
On other masters:
```
curl -L http://$HTTP_SERVER/shell/auto-deploy.sh | bash -s reploca \
    --api-advertise-addresses=$KUBE_VIP \
    --etcd-endpoints=https://${ETCD_NODES[0]}:2379,https://${ETCD_NODES[1]}:2379,https://${ETCD_NODES[2]}:2379
```
When all masters ready, the HA is okay.

5. Deploy nodes
On all nodes:
```
curl -L http://$HTTP_SERVER/shell/auto-deploy.sh | bash -s node \
    --api-advertise-addresses=$KUBE_VIP \
    --token <token> --discovery-token-ca-cert-hash sha256:<sha256>
```
Replace the `token` `sha256` recorded at setp 3.

6. Check cluster
- view k8s cluster info
```
kubectl cluster-info 
```
- check k8s pods, services, etc.
```
kubectl get pods,svc --all-namespaces
```
- check k8s netwoking
```
route -n
```
#### Deploy other k8s apps
1. Setup netwoks
2. Setup storage
3. Setup secrurity
4. Setup metrics
5. Setup devops infra tools
6. Setup service mesh
7. Setup other tools

### Future planning
It's a better solution if using Ansible playbook to reduce manual operation. And it would be the goal that building the deploy process as a service.