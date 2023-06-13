# MAGI: Monitor and Alerter for Guarded Integrity

## Introduction

The MAGI system is used to monitor the integrity of the Kubernetes cluster.


## Leftovers

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