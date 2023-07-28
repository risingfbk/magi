#!/bin/bash

alias kz="kubectl --context gke_${GKE_PROJECT_ID}_${GKE_CLUSTER_FIRST_ZONE}_${GKE_CLUSTER_FIRST_ID}"
alias lqz="liqoctl --context gke_${GKE_PROJECT_ID}_${GKE_CLUSTER_FIRST_ZONE}_${GKE_CLUSTER_FIRST_ID}"

liqoctl generate peer-command
liqoctl peer oob [...] --context "gke_${GKE_PROJECT_ID}_${GKE_CLUSTER_FIRST_ZONE}_${GKE_CLUSTER_FIRST_ID}"

kubectl get foreignclusters

kz create namespace liqo-demo
lqz offload namespace liqo-demo
kz run --image sagemathinc/cocalc:d97b1277eb1c test1 -n liqo-demo