#!/bin/bash

# Cleanup all old resources
kubectl delete all -n exp-b-magi --all

# Create a new namespace
kubectl create namespace exp-b-magi

# Launch a few legit services from Dockerhub, with our attack intertwined
kubectl run --image sagemathinc/cocalc:d97b1277eb1c cocalc -n exp-b-magi &

if [[ "$1" == "--attack" ]]; then
    ../exp_3_randomgb/3_random_upto7.sh &
fi
sleep 2

# Create a fake secret containing BS credentials, because why not
kubectl create secret docker-registry regcred --docker-server=http://fake.server.com:5000 --docker-username=test --docker-password=test -n exp-b-magi &
sleep 2

kubectl run --image jupyter/scipy-notebook adder -n exp-b-magi &
sleep 20

kubectl run --image $REGISTRY_IP_DOMAIN/mfranzil/obese-httpd:50 obese -n exp-b-magi &
sleep 20

kubectl delete pod/adder -n exp-b-magi &

kubectl apply -n exp-b-magi -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml &
sleep 14

# kubectl delete all -n exp-b-magi --all