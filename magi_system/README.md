# MAGI: Mitigation Against Gigantic Images

The __MAGI System__ is a collection of scripts and tools that observe, monitor and mitigate the effects of the _gigantic image download_ problem in Kubernetes clusters.

## Components

The MAGI system is composed of two main components:
- the __master__, which is responsible for monitoring Kubernetes API calls and for triggering the mitigation process;
- the __node__, which inspects containerd API calls and activity to detect the offending downloads and to mitigate them.

The master component must be deployed on the Kubernetes master node, while the node component must be deployed on each Kubernetes worker node, including the master node itself.

## Installation

The MAGI System can be installed on any Kubernetest cluster with version v1.26 or higher. The following steps are required to install the system (as a root user):

```bash
apt-get -yqq update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
    zip bison build-essential cmake flex git libedit-dev curl \
    libllvm12 llvm-12-dev libclang-12-dev python python3-pip \
    zlib1g-dev libelf-dev libfl-dev python3-setuptools \
    liblzma-dev arping netperf iperf gcc kmod memcached \
    libbpf-dev linux-headers-$(uname -r) linux-libc-dev \
    socat systemctl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
cd /tmp && \
    git clone https://github.com/iovisor/bcc.git && \
    mkdir bcc/build; cd bcc/build && \
    cmake .. && make && make install && \
    cmake -DPYTHON_CMD=python3 .. && \
    cd src/python/ && make && make install
cd /tmp && \
    curl -sLO https://dl.google.com/go/go1.20.4.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz && \
    rm -f go1.20.4.linux-amd64.tar.gz
export PATH="$PATH:/usr/local/go/bin"
export CGO_ENABLED=1
export GOHOSTARCH=amd64
export GOARCH=amd64
cd /tmp && \
    git clone https://github.com/mfranzil/containerdsnoop && \
    cd containerdsnoop && \
    go build -o /usr/local/bin/containerdsnoop && \
    cd /
depmod
```

These steps will install [BCC](https://github.com/iovisor/bcc) and dependencies, Go version 1.20, and the [containerdsnoop](https://github.com/mfranzil/containerdsnoop) tool on the system.

Next, make sure each node is able to talk with each other using domain names. This can be done by adding the following lines to the `/etc/hosts` file of each node:

```bash
192.168.221.10 master
192.168.221.11 worker1
192.168.221.12 worker2
```

Finally, copy the files in a location of your choice (e.g., `/opt/magi`), and run the following commands:

```bash
sudo ./init_master.sh # on the master node
sudo ./init_node.sh # on each node
```

Once the MAGI System is installed and is up and running, you can proceed with the tests, monitoring the logs of the master and node components on the terminal. 

## Issues

- [ ] The system currently works only once before requiring a restart. This is due to how the Iruel sub-tool is implemented. Iruel reads the system call logs to detect when new sockets are opened and tries to match them with the layer being downloaded. However, once the system has been triggered and the connection terminated, Iruel reads more `connect` system calls (which are attempts to re-establish the connection) and tries to match them with the previous layer, which is not being downloaded anymore. This causes the system to fail. A possible solution is to implement a timeout mechanism in Iruel, which would allow it to forget about the previous connection after a certain amount of time. 
- [ ] The system requires the binaries to be placed in the exact position as specified in the scripts. This is due to the fact that the binaries are not installed in the system, but are copied in the specified location. This is not a problem per se, but it is not a good practice.
- [ ] Similarly, the tool uses the first Python interpreter found in the system, polluting it with the required dependencies. This can be solved by using a virtual environment, but it is not implemented yet.

## Leftovers

### Evil one-liner

This evil one-liner uses netstat to obtain the offending connections' information (usually four ports are opened, one for each concurrent layer download). These port numbers are then parsed and piped to ss, which brutally closes each port with the provided filter. This works best when parallelImagePulls is set to 1, but works anyway (although re-triggering a download for the other images) even if the parameter is set to any value > 1.

This one-liner is not used in the system and has been superseded by other methods, but is useful as a panic button for instantly terminating any download. Just make sure to replace the IP addresses of both the originating node and the registry with the correct ones.

```bash
sudo netstat -apeen | grep $(pgrep containerd | xargs ps \
  | grep "containerd$" | cut -f 1 -d " ")/containerd | grep tcp \
  | grep 10.231.0.208 | sed -E " s/ +/ /g" | cut -f 4 -d " " \
  | cut -f 2 -d : | xargs -I {} sudo ss -K src 192.168.121.58 sport = {}
```

### Original jq string for master

This string is used to parse the audit logs of the master node. It is implemented in the master component directly in Python, but it can be used to parse the logs manually.

```bash
tail -F /var/log/kubernetes/audit/audit.log | grep "/pods" | \
 jq 'select(.verb == "delete" or .verb == "create")| {requestURI: .requestURI, verb: .verb, 
 stage: .stage, imageRequest: .responseObject.spec.containers[0].image, targetNode: 
 .requestObject.target.name, respondingNode: .responseObject.spec.nodeName}'
```

### Get offending blobs

This string can be used to download the manifest of a specific image and get the list of the blobs that compose it. These blobs can then be deleted from the local disk, which will make the download fail the moment a new layer is requested.

```bash
curl -X GET -u testuser:testpassword https://registry-10-231-0-208.nip.io/v2/mfranzil/5gb/manifests/1 2>/dev/null \
    | jq ".fsLayers[].blobSum" | uniq | tr -d '"' | cut -f 2 -d : \
    | xargs -I {} rm -rf /var/lib/containerd/io.containerd.content.v1.content/blobs/sha256/{} \
    && rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/*
```

### Limit the bandwidth of the network interface

This command can be used to limit the bandwidth of the network interface. It is useful to test the system in a controlled environment, where the network is not the bottleneck.

```bash
sudo tc qdisc add dev enp0s3 root tbf rate 500kbit burst 16kbit latency 50ms
# Deletion:
sudo tc qdisc del dev enp0s3 root
```
