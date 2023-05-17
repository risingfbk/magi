# README

## Preliminaries

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

## Cluster

Before starting, make sure you either change the IPs in the `Vagrantfile` or apply the provided `virsh` network configuration. The latter is the preferred option, as it will create a bridge interface on which the cluster will operate.

```shell
virsh net-define ./network.xml
virsh net-start k8s
```

The provided Vagrantfile should be enough to create a 3-node cluster. The nodes are named `master`, `worker1` and `worker2`. The cluster is created using the `kubeadm` tool.
For your convenience, a copy of the `node_exporter` binary is provided in the `./bin` directory. The `node_exporter` is a Prometheus exporter that exposes metrics about the host machine.
Each machine has an NFS share mounted in `/vagrant` that can be used to share files between the host and the VMs. Indeed, it is used to share a `join.sh` script that can be used to join the worker nodes to the cluster. Once finished, you may want to remove it.
Once finished, Vagrant will spit out a `config` file that can be used to interact with the cluster using `kubectl`. Please move it to `$HOME/.kube/config` and use it to interact with the cluster.


## Registry

Handling the registry is trickier as it requires some manual steps. Indeed, k8s and Docker strongly dislike self-signed certificates.
First of all, run the `Vagrantfile` and make sure the registry VM is up and running. You may do so before or after the cluster creation, but remember to perform all the following steps before trying to push something to the registry.
Once the VM is up, connect to it and start the registry container:

```shell
vagrant ssh
```

Within the VM:

```shell
cd /vagrant
docker compose up -d
```

You will now have a fresh registry up and running. It may only be accessed with the credentials found in the `auth` folder. The default user is `testuser` and the default password is `testpassword`. You may change them by editing the `htpasswd` file.
Now, we need to make sure the registry is accessible from both the host machine and the k8s nodes. To do so, we need to generate a certificate for the registry.
We will use the excellent `nip.io` service to resolve the registry domain name to the VM IP. Unfortunately, in our setup our host machine was airgapped, and we were unable to use Let's Encrypt to generate a certificate. Therefore, we will use a self-signed certificate.

```shell
openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -addext "subjectAltName = DNS:registry-192-168-221-100.nip.io" \
  -x509 -days 365 -out certs/domain.crt
```

With Let's Encrypt:

```shell
certbot certonly --standalone --preferred-challenges http --non-interactive --staple-ocsp --agree-tos -m mfranzil@fbk.eu -d registry-192-168-221-100.nip.io
```

The certificate will be valid for the `registry-192-168-221-100.nip.io` domain. You may change it to whatever you want, but remember to change it everywhere.

Now, copy the certificate in each k8s node:

```shell
vagrant scp ./certs/domain.crt master:domain.crt
vagrant scp ./certs/domain.crt worker1:domain.crt
vagrant scp ./certs/domain.crt worker2:domain.crt
```

Some final steps:

- Perform `sudo cp $HOME/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates` on each node
  - (optional) do the same on the host machine: `(cp ./certs/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`
- Copy the certificate in the host machine:

```shell
sudo mkdir -p /etc/docker/certs.d/registry-192-168-221-100.nip.io/
sudo cp /home/vbox/kubetests/certs/domain.crt /etc/docker/certs.d/registry-192-168-221-100.nip.io/ca.crt
```

- *Important!* Perform a `sudo systemctl restart containerd` on each node to let containerd know of the new certificates
- Perform a `docker login` and check that everything is ok (testuser:testpassword)

```shell
docker login registry-192-168-221-100.nip.io
```

Finally, we can create the k8s secret from the CA cert:

```shell
kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

After having pushed something, verify the contents of the registry:

```shell
curl -X GET -u testuser:testpassword https://registry-192-168-221-100.nip.io/v2/_catalog
```

## References

1. ‘A possible reason for your Virtualbox VM entering the “gurumeditation” state’, meroupatate, May 02, 2020. https://meroupatate.github.io/posts/gurumeditation/ (accessed May 05, 2023).
2. ‘Create and manage Vagrant machines using Libvirt/QEMU’, Vagrant Libvirt Documentation. https://vagrant-libvirt.github.io/vagrant-libvirt/installation.html (accessed May 05, 2023).
3. ‘libvirt: Virtual Networking’. https://wiki.libvirt.org/VirtualNetworking.html (accessed May 05, 2023).
4. ‘SettingUpNFSHowTo - Community Help Wiki’. https://help.ubuntu.com/community/SettingUpNFSHowTo (accessed May 05, 2023).
5. Andrea, ‘Managing KVM virtual machines part I – Vagrant and libvirt’, LeftAsExercise, May 15, 2020. https://leftasexercise.com/2020/05/15/managing-kvm-virtual-machines-part-i-vagrant-and-libvirt/ (accessed May 05, 2023).
