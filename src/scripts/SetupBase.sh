# Define Variables
KUBERNETES_VERSION=1.21.0-00
HOSTNAME=c1-base
HOST_NET_ADDRESS=192.168.56.100/24
CLUSTER_IP=172.16.94.100/24

# Update host name
tee <<EOF | sudo tee /etc/hostname
$HOSTNAME
EOF

# Update network configuration
# enp0s3: should be configured as the default NAT in VirtualBox on Adapter 1 for connection to Web
# enp0s8: should be configured as Nat Network in VirtualBox on Adapter 2 for cluster comms
# enp0s9: should be configured as a Host Only Network in VirtualBox on Adapter 3 to allow ssh from host to VM
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

# Reset Network to apply new config
sudo netplan apply

# Disable swap
sudo swapoff -a

# Disable swap in config
sudo sed -i "s/\/swap/#\/swap/" /etc/fstab

# Add extra swap disable?
#echo "vm.swappiness=0" | sudo tee --append /etc/sysctl.conf

# Install packages
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

#Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

#Apply sysctl params without reboot
sudo sysctl --system

#Install containerd
sudo apt-get update 
sudo apt-get install -y containerd

#Create a containerd configuration file
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

#Set the cgroup driver for containerd to systemd which is required for the kubelet.
#For more information on this config file see:
# https://github.com/containerd/cri/blob/master/docs/config.md and also
# https://github.com/containerd/containerd/blob/master/docs/ops.md

#sudo nano /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/' /etc/containerd/config.toml

#Restart containerd with the new configuration
sudo systemctl restart containerd

echo "Containerd Runtime Configured Successfully"

#Install Kubernetes packages - kubeadm, kubelet and kubectl
#Add Google's apt repository gpg key
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

#Add the Kubernetes apt repository
sudo bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'

#Update the package list and use apt-cache policy to inspect versions available in the repository
sudo apt-get update
apt-cache policy kubelet | head -n 20 

sudo apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION
sudo apt-mark hold kubelet kubeadm kubectl containerd

#Ensure both are set to start when the system starts up.
sudo systemctl enable kubelet.service
sudo systemctl enable containerd.service

sudo apt-get install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc
source ~/.bashrc

echo "Common Components Installed"
echo "-------FINISHED--------"