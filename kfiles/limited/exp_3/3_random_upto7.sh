#!/bin/bash

# Randomize the order of the pods
for i in $(shuf <(ls randomgb-*)); do
    echo "Applying $i"
    kubectl apply -f $i
    sleep 2
    kubectl delete -f $i --force --grace-period=0
done
kubectl apply -f ../httpd.yaml
