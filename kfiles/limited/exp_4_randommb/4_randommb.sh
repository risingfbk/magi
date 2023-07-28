#!/bin/bash

# Randomize the order of the pods
for i in $(seq 1 40 | shuf); do
    echo "Applying $i"
    name="randommb-$i-generated.yml"
cat << EOF > "$name"
apiVersion: v1
kind: Pod
metadata:
  name: randommb-$i
  namespace: limited
spec:
  containers:
  - name: randommb
    image: registry-10-231-0-208.nip.io/mfranzil/randommb:$i
EOF
    kubectl apply -f "$name"
    sleep 2
    kubectl delete -f "$name" --force --grace-period=0
done
