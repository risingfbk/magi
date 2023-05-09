# 

## Insecure Docker Registry

- Generate the certs (using different CN if needed)

```shell
openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -addext "subjectAltName = DNS:registry-192-168-221-100.nip.io" \
  -x509 -days 365 -out certs/domain.crt
```

Alternatively, use
  
```shell
certbot certonly --standalone --preferred-challenges http --non-interactive --staple-ocsp --agree-tos -m mfranzil@fbk.eu -d registry-192-168-221-100.nip.io
```

- Deploy the registry container:

```shell
---
version: "3.9"
services:
  registry:
    restart: always
    image: registry:2
    ports:
      - 443:443
    environment:
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
      REGISTRY_HTTP_ADDR: 0.0.0.0:443
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
    volumes:
      - /vagrant/data:/var/lib/registry
      - /vagrant/certs:/certs
      - /vagrant/auth:/auth
```

- Copy the certificate in each k8s node:

```shell
vagrant scp ./certs/domain.crt master:domain.crt
vagrant scp ./certs/domain.crt worker1:domain.crt
vagrant scp ./certs/domain.crt worker2:domain.crt
```

- Perform `sudo cp $HOME/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates` on each node

- Optional: do the same on the host machine: `(cp ./certs/domain.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`

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

- Create the k8s secrets from the CA cert:

```shell
kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

After having pushed something, verify the contents of the registry:

```shell
curl -X GET -u testuser:testpassword https://registry-192-168-221-100.nip.io/v2/_catalog
```
## Enable crictl for containerd

```shell
vi /etc/crictl.yaml
```
  
```shell
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: true
```

## Prometheus queries

```shell
100 - 100 * (node_memory_MemTotal_bytes - (rate(node_memory_MemFree_bytes[10m]) + rate(node_memory_Cached_bytes[10m]))) / node_memory_MemTotal_bytes
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[30s])) * 100)
rate(node_network_receive_bytes_total[30s])
rate(node_disk_written_bytes_total[30s])

no!!!! rate(node_cpu_seconds_total{mode="system",instance="192.168.57.12:9100"}[30s]) * 100
```

