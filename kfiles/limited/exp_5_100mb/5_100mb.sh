#!/bin/bash

# Randomize the order of the pods
for i in $(seq 1 80 | shuf); do
    echo "Applying $i"
    name="100mb-$i-generated.yml"
cat << EOF > "$name"
apiVersion: v1
kind: Pod
metadata:
  name: 100mb-$i
  namespace: limited
spec:
  containers:
  - name: 100mb
    image: registry-10-231-0-208.nip.io/mfranzil/100mb:$i
EOF
    kubectl apply -f "$name"
    sleep 2
    kubectl delete -f "$name" --force --grace-period=0
done
