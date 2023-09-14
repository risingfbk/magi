#!/bin/bash

kubectl run -n limited --image sagemathinc/cocalc:d97b1277eb1c test1
sleep 10
kubectl -n limited delete --force pod/test1
kubectl run -n limited --image sagemathinc/cocalc:fcddf25ba2aa test1
sleep 10
kubectl -n limited delete --force pod/test1
kubectl run -n limited --image sagemathinc/cocalc:be98b03ccae8 test1
sleep 10
kubectl -n limited delete --force pod/test1
kubectl run -n limited --image nginx:latest test2
