#!/bin/bash

versions=(
    mainline-alpine3.18-perl
    mainline-alpine3.18
    mainline-alpine3.18-slim
    mainline-alpine-slim
    mainline-alpine
    mainline-alpine-perl
    alpine3.18-slim
    1.25.2-alpine-slim
    1.25.2-alpine-perl
    1.25.2-alpine
    1.25-alpine3.18-slim
    1.25-alpine3.18-perl
    1.25-alpine3.18
    1-alpine3.18-slim
)

cat << EOF > initial.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: limited
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginxattack
        image: nginx:${versions[0]}
        ports:
        - containerPort: 80
EOF

kubectl apply -f initial.yaml
len=$((${#versions[@]}-1))
echo $len

for i in $(seq 1 $len); do
    tmp=$(mktemp)

    current=${versions[$i]}
    next=${versions[$((i+1))]}
    
    kubectl -n limited get deployment.apps nginx-deployment -o yaml | sed "s/image: nginx:$current/image: nginx:$next/g" > $tmp
    kubectl -n limited patch deployment.apps nginx-deployment --patch-file $tmp
    sleep 2
done
