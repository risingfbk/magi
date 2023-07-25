#!/bin/bash

# The name of the service account used by liqoctl to interact with GCP
export GKE_SERVICE_ACCOUNT_ID=liqoctl
# The path where the GCP service account is stored
export GKE_SERVICE_ACCOUNT_PATH=$HOME/.liqo/gcp_service_account

# The ID of the GCP project where your cluster was created
[[ -z $GKE_PROJECT_ID ]] && echo "export GKE_PROJECT_ID='your_project_name_here'" && exit 1
# The GCP zone where your GKE cluster is executed (if you are using zonal GKE clusters)
export GKE_CLUSTER_FIRST_ZONE=europe-southwest1-b
export GKE_CLUSTER_SECOND_ZONE=europe-west1-b

export GKE_CLUSTER_FIRST_REGION=europe-southwest1
export GKE_CLUSTER_SECOND_REGION=europe-west1
# The name of the GKE resource on GCP
export GKE_CLUSTER_FIRST_ID=rising
export GKE_CLUSTER_SECOND_ID=createnet2

[[ -z $WHITELISTED_CIDR ]] && echo "export WHITELISTED_CIDR='subnets_that_can_use_kubectl'" && exit 1