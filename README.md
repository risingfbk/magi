# README

This repository contains the following folders:

- `cluster`: contains the Vagrantfile used to create the cluster;
- `registry`: contains the Vagrantfile and docker-compose files used to create the registry;
- `kfiles`: contains the Kubernetes manifests used in the experiments;
- `magi_system`: contains the MAGI system, our PoC implementation of the mitigation system;
- `results`: contains the results and the plots of the experiments.

In the root folder, you will furthermore find some helper scripts we used for exporting data from the cluster and the registry and for plotting the results.

## Usage

For replicating the experiments, first deploy the cluster and the registry, either on your own or by using the instructions that follow in this README. Once it is ready, deploy the MAGI system on the cluster by using the README file in the corresponding folder. Once the MAGI system is deployed, you can run the experiments by using the YAML files in the `kfiles` folder. 

## Installation

### Preliminaries

The installation requires a Linux system with virtualization capabilities. Our experiments were conducted on a machine running Ubuntu 20.04.1 LTS. The following instructions are for Ubuntu, but they should be easily adaptable to other distributions.

- The Vagrant machines use libvirt. Make sure libvirt is installed on your system:

```shell  
sudo apt install build-dep vagrant ruby-libvirt \
  qemu libvirt-daemon-system libvirt-clients ebtables \
  dnsmasq-base libxslt-dev libxml2-dev libvirt-dev \
  zlib1g-dev ruby-dev libguestfs-tools
  sudo systemctl start libvirtd
```

- Important, make sure you _always_ use the system libvirt:

```shell
LIBVIRT_DEFAULT_URI=qemu:///system
```

- Install the vagrant-libvirt and vagrant-scp plugins:

```shell
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-scp
```

- Make sure NFS is installed on your system:

```shell
sudo apt-get install nfs-kernel-server
sudo systemctl start nfs-kernel-server
```

### Cluster

Before starting, make sure you either change the IPs in the `Vagrantfile` or apply the provided `virsh` network configuration. The latter is the preferred option, as it will create a bridge interface on which the cluster will operate.

```shell
virsh net-define ./network.xml
virsh net-start k8s
```

The provided Vagrantfile should be enough to create a 3-node cluster. The nodes are named `master`, `worker1` and `worker2`. The cluster is created using the `kubeadm` tool.
For your convenience, a copy of the `node_exporter` binary is provided in the `./bin` directory. The `node_exporter` is a Prometheus exporter that exposes metrics about the host machine.
Each machine has an NFS share mounted in `/vagrant` that can be used to share files between the host and the VMs. Indeed, it is used to share a `join.sh` script that can be used to join the worker nodes to the cluster. Once finished, you may want to remove it.
Once finished, Vagrant will spit out a `config` file that can be used to interact with the cluster using `kubectl`. Please move it to `$HOME/.kube/config` and use it to interact with the cluster.

Finally, remember to create a namespace for the experiments: `kubectl create namespace limited`.

### Registry

Handling the registry is trickier as it requires some manual steps. Indeed, k8s and Docker strongly dislike self-signed certificates.
First of all, run the `Vagrantfile` and make sure the registry VM is up and running. In alternative, you may boot up another VM or use a physical machine, installing Docker and Docker Compose on it.
You may do so before or after the cluster creation, but remember to perform all the following steps before trying to push something to the registry.
Once the VM is up, connect to it and start the registry container:

```shell
vagrant ssh
```

Within the VM:

```shell
cd /vagrant
docker compose up -d
```

You will now have a fresh registry up and running. It may only be accessed with the credentials found in the `auth` folder.
The default user is `testuser` and the default password is `testpassword`. You may change them by editing the `htpasswd` file. To create a new account and remove the default one, use the `htpasswd` command:

```shell
apt install apache2-utils
htpasswd -cBb ./auth/htpasswd <user> <pass>
```

Now, we need to make sure the registry is accessible from both the host machine and the k8s nodes.
To do so, we need to generate a certificate for the registry. We will use the excellent `nip.io` service to resolve the
registry domain name to the VM IP. Unfortunately, in our setup our host machine was airgapped, and we were unable to use
Let's Encrypt to generate a certificate. Therefore, we will use a self-signed certificate.

Finally, remember to set the `REGISTRY_IP_DOMAIN` variable to the domain name you want to use for the registry. For your convenience, you may change it once in the
`.envrc` file contained in the base repository folder.

```shell
REGISTRY_IP_DOMAIN=${REGISTRY_IP_DOMAIN:-registry-1-2-3.4.nip.io}
openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -addext "subjectAltName = DNS:${REGISTRY_IP_DOMAIN}" \
  -x509 -days 365 -out certs/domain.crt
```

With Let's Encrypt:

```shell
certbot certonly --standalone --preferred-challenges http --non-interactive --staple-ocsp --agree-tos -m mfranzil@fbk.eu -d ${REGISTRY_IP_DOMAIN}
```

After obtaining the certificates, you can convert them to `.crt` and `.key` format using the following commands:

```shell
sudo openssl x509 -in /etc/letsencrypt/live/${REGISTRY_IP_DOMAIN}/fullchain.pem -out certs/domain.crt
sudo openssl rsa -in /etc/letsencrypt/live/${REGISTRY_IP_DOMAIN}/privkey.pem -out certs/domain.key
```

The certificate will be valid for the `${REGISTRY_IP_DOMAIN}` domain. You may change it to whatever you want, but remember to change it everywhere.

Now, copy the certificate in each k8s node:

```shell
vagrant scp ./certs/domain.crt master:domain.crt
vagrant scp ./certs/domain.crt worker1:domain.crt
vagrant scp ./certs/domain.crt worker2:domain.crt
```

and update the certificates on each node:

```shell
vagrant ssh master -c "sudo cp ~/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates && sudo systemctl restart containerd"
vagrant ssh worker1 -c "sudo cp ~/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates && sudo systemctl restart containerd"
vagrant ssh worker2 -c "sudo cp ~/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates && sudo systemctl restart containerd"
```

Finally, update the host machine certificates:

```shell
cp ./certs/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates
```

On the host machine, we will also copy the certificate to the Docker certificates directory. This will allow us to perform a `docker login` with no errors.

```shell
sudo mkdir -p /etc/docker/certs.d/${REGISTRY_IP_DOMAIN}/
sudo cp /home/vbox/kubetests/certs/domain.crt /etc/docker/certs.d/${REGISTRY_IP_DOMAIN}/ca.crt
```

Now, perform a `docker login` and check that everything is ok (default credentials: `testuser:testpassword`):

```shell
docker login ${REGISTRY_IP_DOMAIN}
```

Finally, we can create the k8s secret from the CA cert and apply it to our namespace, saving us from having to include it in every YAML file.

```shell
kubectl create secret generic regcred \
    -n limited \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
kubectl patch sa default -n limited -p '"imagePullSecrets": [{"name": "regcred" }]'
```

After having pushed something, verify the contents of the registry:

```shell
curl -X GET -u testuser:testpassword https://${REGISTRY_IP_DOMAIN}/v2/_catalog
```

## Modifications to the cluster

### k8s v1.27 Parallel Image Pulls

In Kubernetes v1.27, there is an option for parallel image pulls. This option is not enabled by default. To enable it, you need to edit the `kubelet-config` configmap in the `kube-system` namespace. Then, you need to restart the kubelet on each node. This can be done with the following commands:

```shell
kubectl edit cm -n kube-system kubelet-config
```

Add the `maxParallelImagePulls: 1` and `serializeImagePulls: false` options. Then:

```shell
vagrant ssh master -c "sudo kubeadm upgrade node phase kubelet-config; sudo systemctl restart kubelet"
vagrant ssh worker1 -c "sudo kubeadm upgrade node phase kubelet-config; sudo systemctl restart kubelet"
vagrant ssh worker2 -c "sudo kubeadm upgrade node phase kubelet-config; sudo systemctl restart kubelet"
```

This will trigger a reload of the cluster with the new configuration. Once the reload is complete, you can proceed with the experiments.

## Enabling Auditing

For enabling Kubernetes' auditing capabilities, visit [this page](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/). SSH into the master, and
edit the `/etc/kubernetes/manifests/kube-apiserver.yaml`; first, add the bootup flags:

```
  - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
  - --audit-log-path=/var/log/kubernetes/audit/audit.log
```

then mount the volumes:

```yaml
volumeMounts:
  - mountPath: /etc/kubernetes/audit-policy.yaml
    name: audit
    readOnly: true
  - mountPath: /var/log/kubernetes/audit/
    name: audit-log
    readOnly: false
```

and finally configure the hostPath:

```yaml
volumes:
- name: audit
  hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File

- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit/
    type: DirectoryOrCreate
```

Then, copy the `metrics.yaml` file from the `kfiles/audit` folder in this repository to `/etc/kubernetes/` and wait for the Pod to reboot.

## Enabling Kube-Scheduler - Plugins Config File

For enabling kube-scheduler plugin configuration, visit [this page](https://kubernetes.io/docs/reference/scheduling/config/). SSH into the master, and
edit the `/etc/kubernetes/manifests/kube-scheduler.yaml`; first, add the bootup flags:

```
  - --config=/etc/kubernetes/kube-scheduler.yaml
```

then add the following volume to the mounts:

```yaml
volumeMounts:
  - mountPath: /etc/kubernetes/kube-scheduler.yaml
    name: schedconfig
    readOnly: true
```

and finally configure the hostPath:

```yaml
volumes:
- hostPath:
    path: /etc/kubernetes/scheduler-config.yaml
    type: FileOrCreate
  name: schedconfig
```

Then, copy the `scheduler-config.yaml` file from the `kfiles/scheduler` folder in this repository to `/etc/kubernetes/` and wait for the Pod to reboot.

## Running the cluster on a physical enviroment

During our tests, we also used three Raspberry Pi 4B boards with 4GB of RAM each. The Raspberry Pis were interconnected with a dedicated switch, airgapped from the rest of the network, and had a remote access capability through a PC used as a bridge. Everything present in this README still applies, but with the following considerations:

- We used `microk8s` instead of `kubeadm` for running the cluster. This simplified the configuration process, but meant that some configurations were handled differently: 
  - Commands such as `systemctl restart kubelet` do not exist in `microk8s`, and are handled internally. We restarted the cluster using `sudo snap restart microk8s`;
  - The configuration is handled via `/var/snap/microk8s/current/args/kubelet`, and not by a `kubelet-config` configmap; thus, to enable Parallel Image Pulls, we created a `config.yaml` file in `/var/snap/microk8s/current/args/` as in [the docs](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/), and then added a `--config=${SNAP_DATA}/args/config.yaml` option to the `kubelet` service commandline;
  - `crictl` must be installed manually;
- As the Raspberry Pis use the ARM architecture, images had to be rebuilt and the tools had to be downloaded for the correct architecture;
- Tests were reduced in scope, as our cluster was inherently weaker than the one provided by Vagrant; this was exacerbated by the fact that Raspberries use SD cards as the main storage medium;

Finally, we tweaked some parameters to increase the memory reserved for UDP sockets and thus improve network reliability:

```shell
$ sudo sysctl -w net.core.rmem_max=26214400
net.core.rmem_max = 26214400
$ sudo sysctl -w net.core.rmem_default=26214400
net.core.rmem_default = 26214400
```

For using a PC as a bridge, we enabled IPv4 forward:

```shell
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
sudo sysctl -w net.ipv4.ip_forward=1  # alternatively, if the previous command does not work
```

Then we applied the following iptables rules:

```shell
sudo iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o enp0s31f6 -j MASQUERADE
sudo iptables -A FORWARD -i enp0s31f6 -o wlp2s0 -j ACCEPT
sudo iptables -A FORWARD -i wlp2s0 -o enp0s31f6 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

## References

1. ‘A possible reason for your Virtualbox VM entering the “gurumeditation” state’, meroupatate, May 02, 2020. https://meroupatate.github.io/posts/gurumeditation/ (accessed May 05, 2023).
2. ‘Create and manage Vagrant machines using Libvirt/QEMU’, Vagrant Libvirt Documentation. https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html (accessed May 05, 2023).
3. ‘libvirt: Virtual Networking’. https://wiki.libvirt.org/VirtualNetworking.html (accessed May 05, 2023).
4. ‘SettingUpNFSHowTo - Community Help Wiki’. https://help.ubuntu.com/community/SettingUpNFSHowTo (accessed May 05, 2023).
5. Andrea, ‘Managing KVM virtual machines part I – Vagrant and libvirt’, LeftAsExercise, May 15, 2020. https://leftasexercise.com/2020/05/15/managing-kvm-virtual-machines-part-i-vagrant-and-libvirt/ (accessed May 05, 2023).
