#!/bin/bash

if [[ -z $REGISTRY_IP_DOMAIN ]]; then
    echo "The domain with its port of the registry is missing. E.g. registry.example.com:8080. Please add it to the variable \$REGISTRY_IP_DOMAIN."
    exit
fi

TIME_BETWEEN_DEPLOY_DELETE=${TIME_BETWEEN_DEPLOY_DELETE:-20}
TIME_BETWEEN_DIFFERENT_DEPLOYS=${TIME_BETWEEN_DIFFERENT_DEPLOYS:-10}

# Randomize the order of the pods
for i in $(seq 1 7 | shuf); do
    echo "Applying $i"
    name="randomgb-$i-generated.yml"
cat << EOF > "$name"
apiVersion: v1
kind: Pod
metadata:
  name: randomgb-$i
  namespace: limited
spec:
  containers:
  - name: randomgb
    image: $REGISTRY_IP_DOMAIN/mfranzil/randomgb:$i
EOF
    kubectl apply -f "$name"
    sleep $TIME_BETWEEN_DEPLOY_DELETE 
    kubectl delete -f "$name" --force --grace-period=0
    sleep $TIME_BETWEEN_DIFFERENT_DEPLOYS
done

kubectl -n limited run --image nginx:latest nginx
