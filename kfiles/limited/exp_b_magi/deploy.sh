#!/bin/bash

# Cleanup all old resources
kubectl delete all -n exp-b-magi --all

# Create a new namespace
kubectl create namespace exp-b-magi

echo "Start time:"
date --iso-8601=seconds

# Launch a few legit services from Dockerhub, with our attack intertwined
kubectl run --image sagemathinc/cocalc:d97b1277eb1c cocalc -n exp-b-magi &
sleep 20

if [[ "$1" == "--attack" ]]; then
    cd ../exp_3_randomgb
    ./3_random_upto7.sh &
    cd -
fi
sleep 30

# Create a fake secret containing BS credentials, because why not
# kubectl create secret docker-registry regcred --docker-server=http://fake.server.com:5000 --docker-username=test --docker-password=test -n exp-b-magi &
# sleep 2

kubectl run --image jupyter/scipy-notebook adder -n exp-b-magi &
sleep 20

kubectl run --image nginx:mainline-alpine3.18-perl nginx -n exp-b-magi &
sleep 20

kubectl apply -n exp-b-magi -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/release/kubernetes-manifests.yaml &
sleep 20

echo "Times for adder"
kubectl get pod/adder -n exp-b-magi -o yaml | yq '.status.conditions'
kubectl delete pod/adder -n exp-b-magi
date --iso-8601=seconds

echo "When it's finished, run the following commands"
echo "k get pod -n exp-b-magi cocalc -o yaml | yq '.status.conditions'"
echo "k get pod -n exp-b-magi nginx -o yaml | yq '.status.conditions'"
echo "k get pod -n exp-b-magi frontend -o yaml | yq '.status.conditions'"
echo "k get pod -n exp-b-magi adservice -o yaml | yq '.status.conditions'"
echo "k delete all -n exp-b-magi --all"
