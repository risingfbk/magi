#!/bin/bash

kubectl apply -f 5gb-1.yaml
sleep 2
kubectl delete -f 5gb-1.yaml --force --grace-period=0
sleep 2
kubectl apply -f 5gb-2.yaml
sleep 2
kubectl delete -f 5gb-2.yaml --force --grace-period=0
sleep 2
kubectl apply -f 5gb-3.yaml
sleep 2
kubectl delete -f 5gb-3.yaml --force --grace-period=0
sleep 2
kubectl apply -f 5gb-4.yaml
sleep 2
kubectl delete -f 5gb-4.yaml --force --grace-period=0
sleep 2
kubectl apply -f ../httpd.yaml
