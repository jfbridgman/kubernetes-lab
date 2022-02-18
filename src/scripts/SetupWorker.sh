#! /bin/bash

# Will need to run this at the control plane first
#kubeadm token create --print-join-command

if [ -z "$1" ]
  then
    echo "No arguments supplied"
    exit 1
fi

NODE=$1
re='^[0-9]+$'

if ! [[ $NODE =~ $re ]] || ( [ $NODE -lt 1 ] || [ $NODE -gt 9 ] )
  then
  echo "Input invalid, please provide a number in range 1-9"
  exit
fi

HOSTNAME=c1-node$NODE
HOST_NET_ADDRESS=192.168.56.1$NODE/24
NODE_IP=172.16.94.1$NODE
CLUSTER_IP=$NODE_IP/24

# Update host name
tee <<EOF | sudo tee /etc/hostname
$HOSTNAME
EOF

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

sudo hostname $HOSTNAME

sudo sed -i "s/127.0.1.1 ubuntu-base/127.0.1.1 $HOSTNAME/" /etc/hosts

sudo netplan apply

# c1-cp1
#sudo kubeadm join 172.16.94.10:6443 --token ausd2c.yhw8wc7ajbx17gwa \
#  --discovery-token-ca-cert-hash sha256:d1d478390a5de34a91bf730894d40abff8dbeb2af15438dfcbe53cc4e9033d5a

#Insert command obtained from running 'kubeadm token create --print-join-command' 
#on the control plane node here (prefix with sudo), the above command is an example only
#and will not work for your cluster