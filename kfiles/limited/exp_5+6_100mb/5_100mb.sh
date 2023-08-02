#!/bin/bash

if [[ -z $REGISTRY_IP_DOMAIN ]]; then
    echo "The domain with its port of the registry is missing. E.g. registry.example.com:8080. Please add it to the variable \$REGISTRY_IP_DOMAIN."
    exit
fi

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
    image: $REGISTRY_IP_DOMAIN/mfranzil/100mb:$i
EOF
    kubectl apply -f "$name"
    sleep 2
    kubectl delete -f "$name" --force --grace-period=0
done
