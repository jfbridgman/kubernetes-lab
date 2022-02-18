# kubernetes-lab
Setup scripts to build a K8s lab using VirtualBox and Ubuntu server.

The instructions below are based on the process followed to configure the lab cluster using a Windows 10 host, you may need to adjust for other host OSes.

## Contents
- [Versions](#versions) - Software versions used to develop this how-to
- [Setup the VirtualBox Environment](#setup-the-virtualbox-environment) - Getting our VirtualBox environment configured
- [Setup the Base VM](#setup-the-base-vm) - Getting the base image for our VMs setup
- [Setting up the Cluster](#setting-up-the-cluster) - Time to setup our cluster

## Versions
The lab environment is setup using the following software versions. Other versions may work, but I can warn you I have run into various issues with other versions. I can certainly advise against using VirtualBox 6.1.32 as I experienced many VMs running very hot on this version and locking up.

- Windows 10 21H2 (Host OS, included for completeness only)
- VirtualBox 6.1.30
- Ubuntu Server 20.4.3
- Kubernetes 1.21.0 (This is configured in the setup scripts)

## Setup the VirtualBox Environment
First we need to get our VirtualBox environment configured correctly, this is mainly about getting the networking stuff sorted.

### NAT Network:
First you will need to configure a NAT Network within VirtualBox which we will later use as our cluster network.

To do this:
- File -> Preferences
- Select Network from the left side options
- Create a new network
- Edit the new network with the following:
  - Enable Network (make sure this is checked)
  - Network Name: `Cluster Network`
  - Network CIDR: `172.16.0.0/16` (we will use this again later)

### Host-Only Network
You will need to make sure you have a Host-Only network configured in VirtualBox which matches the IP configuration provided in these instructions, or things will likely not work and get confusing.

- File -> Host Network Manager
- Verify that you have a host network with the following configuration
  - Adapter
    - **Ipv4 Address:** 192.168.56.2
    - **IPv4 Network Mask:** 255.255.255.0
  - DHCP Server
    - Make sure this is disabled, it won't be needed as we'll control the addresses manually
- > Take note of the name of the host-only network and make sure the adapter of the VM is connected to the correct network in setup below

## Setup the Base VM
We will start by establishing a baseline VM (we can then use this as a master to clone all other mahines from to save setup time).

### VM Specs:
- Name: `cluster-base`
- Processor - 2 CPUs (required by K8s Control Plane node)
- Memory - 2GB (min)
- HDD - Use default of 10GB
- Network
  - Adapter 1:
    - **Attached to:** `NAT`
  - Adapter 2:
    - **Attached to:** `NAT Network`
    - **Name:** `Cluster Network`
  - Adapter 3:
    - **Attached to:** `Host-only Adapter`
    - **Name:** `Name of Host-Only Network configured above`

I have used 3 adapters in order to control the communications within a virtual environment, and this setup avoids the need to involve an external router.

The 3 networks achieve the following:
- Adapter 1: Allows connectivity to the internet
- Adapter 2: Allows the VMs to communicate within a controlled network
- Adapter 3: Allows the host to ssh into the VM

Yes the above can be achieved in other ways, there is no right or wrong way to achieve the networking (actually there are plenty of wrong ways, i.e. setups that don't work).

> :warning: Please note that any alteration to the above networking setup will impact the setup scripts, so if you change this in your environment you will need to edit the scripts as well.

### Setup Ubuntu
I'm aware that most people reading this will know how to install an OS, however I like to provide detailed intructions (mainly so I don't have to think again next time).
- Start VM with Ubuntu 20.04.3 iso
- Select your preferred language, I use English (UK)
- Select `Continue without updating`
- Select `Done` (Or update your keyboard settings if necessary)
- Configure the network adapters (you will need to do this to make life easier later)
  - Adapter 1 (enp0s3): You can leave unchanged (it should have self configured via DHCPV4 and be `10.0.2.15/24`, your setup **MAY** have a different IP)
  - Adapter 2 (enp0s8): You will need to configure manually
    - Select `Edit IPv4`
    - Set **IPv4 Method** to `Manual`
    - Set **Subnet** to `172.16.94.0/24`
    - Set **Address** to `172.16.94.100` (This is a placeholder for the base image)
    - Leave the remaining configurations empty
  - Adapter 3 (enp0s9): You will need to configure manually
    - Select `Edit IPv4`
    - Set **IPv4 Method** to `Manual`
    - Set **Subnet** to `192.168.56.0/24`
    - Set **Address** to `192.168.56.100` (This is a placeholder for the base image, we will ssh to this base machine using this address)
- Select `Done`
- On the **Configure Proxy** screen Select `Done`
- Select `Done`
- We will use the default HDD configuration so select `Done`
- No need to alter partitions, select `Done`
- Select `Continue`
- Profile Setup (this bit is up to you)
- When you have finished setting up a profile (I suggest keep things simple as it's for a lab environment your likely to want to easily log into and kill/rebuild at some point). But I can suggest the following:
  - **Your name:** `user`
  - **Your server's name:** `cluster-base`
  - **Pick a username:** `user`
  - **Choose a password:** `password`
  - **Confirm your password:** `password`

> Note, I'm not aiming for security in the above, please don't use that anywhere near a production environment, or anything you actually want to be secure
- Select `Done`
- Select `Install OpenSSH server` (this will make life easier)
- Select `Done`
- You don't need to install any extra snaps, we will install what is required using the scripts, select `Done`
- Once installion is complete select `Reboot Now`

> This is the end of the **hard** part, but the good news is that we won't need to do this again (providing you keep this base image intact).

### Install Kubernetes

Now, things get a bit less manual.

Pull the contents of this repo onto the newly created VM.

```bash
git clone https://github.com/jfbridgman/kubernetes-lab.git
```

All we are going to do now is install the Kubernetes components to create a cluster base image.

```bash
cd kubernetes-lab/src/scripts
sudo chmod +x *.sh
./SetupBase.sh
```

Once this script has finished your VM will be ready to take on the role of either a master or a worker. To complete the configuration you will need to run the relevant script on the node (VM).

>We now shut down the VM as our base image is ready and we don't need to do anything further with it.

```
sudo shutdown now
```

## Setting up the Cluster
Now that we have a base image setup, we can use this base image as the starting point for all nodes within our cluster.

### Configure the Control Plane Node
- Using VirtualBox, **clone** the `cluster-base` VM
- To clone a VM in VirtualBox using the GUI simply right click the source VM `cluster-base` and select `Clone` (the source VM will need to be turned off in order to do this)

> You will want to perform a full clone of the base vm

- Configure the control plane with the following:
  - **Name:** `cluster-c1-cp1` (feel free to use your own naming convention)
  - Select `Clone`

Once the cloning process is complete we can boot the new VM and turn it into our Control Plane Node.

To do this:
- Login to the VM
- Run the following

```bash
sudo kubernetes-lab/src/scripts/SetupControlPlane.sh
```

This will Configure the VM as the control plane node with the following IP Addresses:
- Cluster: `172.16.94.10`
- Host: `192.168.56.10` (you can ssh to the node using this address from your host machine)

Once the Setup has completed you should be able to retrieve the cluster join command which will look something like this:

```bash
kubeadm join 172.16.94.10:6443 --token ausd2c.yhw8wc7ajbx17gwa --discovery-token-ca-cert-hash sha256:d1d478390a5de34a91bf730894d40abff8dbeb2af15438dfcbe53cc4e9033d5a
```

> You will need this join command to connect nodes to the control plane, however you can also generate new versions of this if required.

If you need to obtain the join details to connect a new node to the cluster you can use the following
```bash
kubeadm token create --print-join-command
```

You can check the nodes currently in the cluster by running the following from the Control Plane Node
```
kubectl get nodes -o wide
```

You can also check the status of the pods running within the cluster using the following
```
kubectl get pods -o wide --all-namespaces
```

### Configure a Worker Node
- Using VirtualBox, **clone** the `cluster-base` VM
- To clone a VM in VirtualBox using the GUI simply right click the source VM `cluster-base` and select `Clone` (the source VM will need to be turned off in order to do this)

> You will want to perform a full clone of the base vm

- Configure the worker with the following (example based on node1):
  - **Name:** `cluster-c1-node1` (feel free to use your own naming convention)
  - Select `Clone`

Once the cloning process is complete we can boot the new VM and turn it into a new worker node.

To do this:
- Login to the VM
- Run the `SetupWorker.sh` script and pass in the number for the workder node (this should be unique for each worker in the cluster)

> The script will require a number between 1-9, this is because it also configures the IP addresses of the worker, and honestly, you won't want too many workers within a local lab environment (you will grind the host to a halt), so 9 is likely far more than necessary.

```bash
sudo kubernetes-lab/src/scripts/SetupWorker.sh <1-9>
```

Once the setup is finished you will need to run the cluster join command as root on the worker.
> Note the below command is an example based on the previous sample command and will not work for your cluster.

```bash
sudo kubeadm join 172.16.94.10:6443 --token ausd2c.yhw8wc7ajbx17gwa --discovery-token-ca-cert-hash sha256:d1d478390a5de34a91bf730894d40abff8dbeb2af15438dfcbe53cc4e9033d5a
``` 