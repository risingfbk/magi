#!/bin/bash

gcloud beta container \
    --project "$GKE_PROJECT_ID" clusters create "$GKE_CLUSTER_SECOND_NAME" \
    --zone "$GKE_CLUSTER_SECOND_ZONE" \
    --no-enable-basic-auth \
    --cluster-version "1.27.2-gke.1200" \
    --release-channel "stable" \
    --machine-type "e2-standard-2" \
    --image-type "UBUNTU_CONTAINERD" \
    --disk-type "pd-balanced" \
    --disk-size "100" \
    --metadata disable-legacy-endpoints=true \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --num-nodes "3" \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM \
    --enable-ip-alias \
    --network "projects/$GKE_PROJECT_ID/global/networks/default" \
    --subnetwork "projects/$GKE_PROJECT_ID/regions/$GKE_CLUSTER_SECOND_REGION/subnetworks/default" \
    --enable-intra-node-visibility \
    --cluster-dns=clouddns \
    --cluster-dns-scope=cluster \
    --default-max-pods-per-node "110" \
    --security-posture=standard \
    --workload-vulnerability-scanning=disabled \
    --enable-dataplane-v2 \
    --enable-master-authorized-networks \
    --master-authorized-networks $WHITELISTED_CIDR \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-managed-prometheus \
    --enable-shielded-nodes \
    --enable-l4-ilb-subsetting \
    --node-locations "europe-hwest1-b"

gcloud beta container \
    --project "$GKE_PROJECT_ID" clusters create "$GKE_CLUSTER_FIRST_ID" \
    --zone "$GKE_CLUSTER_FIRST_ZONE" \
    --no-enable-basic-auth \
    --cluster-version "1.27.2-gke.1200" \
    --release-channel "stable" \
    --machine-type "e2-standard-2" \
    --image-type "UBUNTU_CONTAINERD" \
    --disk-type "pd-balanced" \
    --disk-size "100" \
    --metadata disable-legacy-endpoints=true \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --num-nodes "3" \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM \
    --enable-ip-alias \
    --network "projects/$GKE_PROJECT_ID/global/networks/default" \
    --subnetwork "projects/$GKE_PROJECT_ID/regions/$GKE_CLUSTER_FIRST_REGION/subnetworks/default" \
    --enable-intra-node-visibility \
    --cluster-dns=clouddns \
    --cluster-dns-scope=cluster \
    --default-max-pods-per-node "110" \
    --security-posture=standard \
    --workload-vulnerability-scanning=disabled \
    --enable-dataplane-v2 \
    --enable-master-authorized-networks \
    --master-authorized-networks $WHITELISTED_CIDR \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-managed-prometheus \
    --enable-shielded-nodes \
    --enable-l4-ilb-subsetting \
    --node-locations "$GKE_CLUSTER_FIRST_ZONE"

gcloud iam service-accounts create ${GKE_SERVICE_ACCOUNT_ID} \
    --project="${GKE_PROJECT_ID}" \
    --description="The identity used by liqoctl during the installation process" \
    --display-name="liqoctl"

gcloud projects add-iam-policy-binding ${GKE_PROJECT_ID} \
    --member="serviceAccount:${GKE_SERVICE_ACCOUNT_ID}@${GKE_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.clusterViewer"
gcloud projects add-iam-policy-binding ${GKE_PROJECT_ID} \
    --member="serviceAccount:${GKE_SERVICE_ACCOUNT_ID}@${GKE_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/compute.networkViewer"

gcloud iam service-accounts keys create ${GKE_SERVICE_ACCOUNT_PATH} \
    --iam-account=${GKE_SERVICE_ACCOUNT_ID}@${GKE_PROJECT_ID}.iam.gserviceaccount.com

gcloud container clusters get-credentials ${GKE_CLUSTER_FIRST_ID} \
        --zone ${GKE_CLUSTER_FIRST_ZONE} --project ${GKE_PROJECT_ID}

liqoctl install gke --project-id ${GKE_PROJECT_ID} \
    --cluster-id ${GKE_CLUSTER_FIRST_ID} \
    --zone ${GKE_CLUSTER_FIRST_ZONE} \
    --credentials-path ${GKE_SERVICE_ACCOUNT_PATH} \
    --service-type LoadBalancer

gcloud container clusters get-credentials ${GKE_CLUSTER_SECOND_ID} \
        --zone ${GKE_CLUSTER_SECOND_ZONE} --project ${GKE_PROJECT_ID}

liqoctl install gke --project-id ${GKE_PROJECT_ID} \
    --cluster-id ${GKE_CLUSTER_SECOND_ID} \
    --zone ${GKE_CLUSTER_SECOND_ZONE} \
    --credentials-path ${GKE_SERVICE_ACCOUNT_PATH} \
    --service-type LoadBalancer
