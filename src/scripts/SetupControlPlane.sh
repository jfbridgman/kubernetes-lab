#! /bin/bash

HOSTNAME=c1-cp1
NODE_IP=172.16.94.10
CLUSTER_IP=$NODE_IP/24
HOST_NET_ADDRESS=192.168.56.10/24

CLUSTER_CIDR_IP=172.16.0.0
CLUSTER_CIDR_MASK=16
CLUSTER_CIDR=$CLUSTER_CIDR_IP/$CLUSTER_CIDR_MASK
NODE_IP=172.16.94.10

# Update host name
tee <<EOF | sudo tee /etc/hostname
$HOSTNAME
EOF

# Update network configuration
tee <<EOF | sudo tee /etc/netplan/00-installer-config.yaml
network:
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses:
      - $CLUSTER_IP
      nameservers:
        addresses: []
        search: []
    enp0s9:
      addresses:
      - $HOST_NET_ADDRESS
      nameservers:
        addresses: []
        search: []
  version: 2
EOF

tee <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS='--node-ip $NODE_IP'
EOF

sudo systemctl daemon-reload
sudo systemctl restart kubelet

sudo hostname $HOSTNAME

sudo sed -i "s/127.0.1.1 ubuntu-base/127.0.1.1 $HOSTNAME/" /etc/hosts

# Reset Network to apply new config
sudo netplan apply

kubeadm init --apiserver-advertise-address $NODE_IP --pod-network-cidr=$CLUSTER_CIDR

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

curl https://docs.projectcalico.org/manifests/calico.yaml -O

kubectl apply -f calico.yaml