#!/bin/bash

# Cleanup all old resources
kubectl delete all -n exp-b-magi --all &
sleep 10
# Create a new namespace
kubectl create namespace exp-b-magi &
sleep 2
# Create a fake secret containing BS credentials
kubectl create secret docker-registry regcred --docker-server=http://fake.server.com:5000 --docker-username=test --docker-password=test -n exp-b-magi &
sleep 2
# Launch a few legit services from Dockerhub, with our attack intertwined
kubectl run --image sagemathinc/cocalc:d97b1277eb1c cocalc -n exp-b-magi &
if [[ "$1" == "--attack" ]]; then
    ../exp_1+2_5gb/1_upto4.sh &
fi
sleep 10
kubectl run --image jupyter/scipy-notebook adder -n exp-b-magi &
sleep 3
kubectl run --image $REGISTRY_IP_DOMAIN/mfranzil/obese-httpd:50 obese -n exp-b-magi &
sleep 3
kubectl delete adder -n exp-b-magi &
kubectl apply -n exp-b-magi -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml &
sleep 14
