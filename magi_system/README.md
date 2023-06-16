# MAGI: Mitigation Against Gigantic Images 

## Introduction

The MAGI system is used to monitor the integrity of the Kubernetes cluster.


## Leftovers

### Evil one-liner

This evil one-liner uses netstat to obtain the offending connections' information (usually four ports are opened, one for each concurrent layer download). These port numbers are then parsed and piped to ss, which brutally closes each port with the provided filter. This works best when parallelImagePulls is set to 1, but works anyway (although re-triggering a download for the other images) even if the parameter is set to any value > 1.

```bash
sudo netstat -apeen | grep $(pgrep containerd | xargs ps \
  | grep "containerd$" | cut -f 1 -d " ")/containerd | grep tcp \
  | grep 10.231.0.208 | sed -E " s/ +/ /g" | cut -f 4 -d " " \
  | cut -f 2 -d : | xargs -I {} sudo ss -K src 192.168.121.58 sport = {}
```

### `/etc/hosts` file

```bash
192.168.221.10 master
192.168.221.11 worker1
192.168.221.12 worker2
```

### Original jq string for master

```bash
tail -F /var/log/kubernetes/audit/audit.log | grep "/pods" | \
 jq 'select(.verb == "delete" or .verb == "create")| {requestURI: .requestURI, verb: .verb, 
 stage: .stage, imageRequest: .responseObject.spec.containers[0].image, targetNode: 
 .requestObject.target.name, respondingNode: .responseObject.spec.nodeName}'
```

### Get offending blobs

```bash
curl -X GET -u testuser:testpassword https://registry-10-231-0-208.nip.io/v2/mfranzil/5gb/manifests/1 2>/dev/null \
    | jq ".fsLayers[].blobSum" | uniq | tr -d '"' | cut -f 2 -d : \
    | xargs -I {} rm -rf /var/lib/containerd/io.containerd.content.v1.content/blobs/sha256/{} \
    && rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/*
```

### Limit the bandwidth of the network interface

```bash
sudo tc qdisc add dev enp0s3 root tbf rate 500kbit burst 16kbit latency 50ms
# Deletion:
sudo tc qdisc del dev enp0s3 root
```
