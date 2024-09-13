#!/bin/bash

if ! command -v gcloud &> /dev/null; then
    echo "gcloud is not installed. Please install it before running this script."
    exit 1
fi

if ! command -v liqoctl &> /dev/null; then
    echo "liqoctl is not installed. Please install it before running this script."
    exit 1
fi

[[ -z "$GKE_PROJECT_ID" ]] && echo "GKE_PROJECT_ID is not set" && exit 1
[[ -z "$GKE_CLUSTER_FIRST_ID" ]] && echo "GKE_CLUSTER_FIRST_ID is not set" && exit 1
[[ -z "$GKE_CLUSTER_FIRST_ZONE" ]] && echo "GKE_CLUSTER_FIRST_ZONE is not set" && exit 1
[[ -z "$GKE_CLUSTER_FIRST_REGION" ]] && echo "GKE_CLUSTER_FIRST_REGION is not set" && exit 1
[[ -z "$GKE_CLUSTER_SECOND_ID" ]] && echo "GKE_CLUSTER_SECOND_ID is not set" && exit 1
[[ -z "$GKE_CLUSTER_SECOND_ZONE" ]] && echo "GKE_CLUSTER_SECOND_ZONE is not set" && exit 1
[[ -z "$GKE_CLUSTER_SECOND_REGION" ]] && echo "GKE_CLUSTER_SECOND_REGION is not set" && exit 1
[[ -z "$GKE_SERVICE_ACCOUNT_ID" ]] && echo "GKE_SERVICE_ACCOUNT_ID is not set" && exit 1
[[ -z "$GKE_SERVICE_ACCOUNT_PATH" ]] && echo "GKE_SERVICE_ACCOUNT_PATH is not set" && exit 1
[[ -z "$WHITELISTED_CIDR" ]] && echo "WHITELISTED_CIDR is not set" && exit 1

gcloud beta container \
    --project "$GKE_PROJECT_ID" clusters create "$GKE_CLUSTER_SECOND_ID" \
    --zone "$GKE_CLUSTER_SECOND_ZONE" \
    --no-enable-basic-auth \
    --cluster-version "1.30.3-gke.1639000" \
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
    --cluster-dns=clouddns \
    --cluster-dns-scope=cluster \
    --default-max-pods-per-node "110" \
    --security-posture=standard \
    --workload-vulnerability-scanning=disabled \
    --enable-dataplane-v2 \
    --enable-master-authorized-networks \
    --master-authorized-networks "$WHITELISTED_CIDR" \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-managed-prometheus \
    --enable-shielded-nodes \
    --enable-l4-ilb-subsetting \
    --node-locations "$GKE_CLUSTER_SECOND_ZONE" 

gcloud beta container \
    --project "$GKE_PROJECT_ID" clusters create "$GKE_CLUSTER_FIRST_ID" \
    --zone "$GKE_CLUSTER_FIRST_ZONE" \
    --no-enable-basic-auth \
    --cluster-version "1.30.3-gke.1639000" \
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
    --cluster-dns=clouddns \
    --cluster-dns-scope=cluster \
    --default-max-pods-per-node "110" \
    --security-posture=standard \
    --workload-vulnerability-scanning=disabled \
    --enable-dataplane-v2 \
    --enable-master-authorized-networks \
    --master-authorized-networks "$WHITELISTED_CIDR" \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-managed-prometheus \
    --enable-shielded-nodes \
    --enable-l4-ilb-subsetting \
    --node-locations "$GKE_CLUSTER_FIRST_ZONE"

# SA

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
    --credentials-path ${GKE_SERVICE_ACCOUNT_PATH}

gcloud container clusters get-credentials ${GKE_CLUSTER_SECOND_ID} \
        --zone ${GKE_CLUSTER_SECOND_ZONE} --project ${GKE_PROJECT_ID}

liqoctl install gke --project-id ${GKE_PROJECT_ID} \
    --cluster-id ${GKE_CLUSTER_SECOND_ID} \
    --zone ${GKE_CLUSTER_SECOND_ZONE} \
    --credentials-path ${GKE_SERVICE_ACCOUNT_PATH} 

### 

exit 1
### Further steps
liqoctl --context ${1} peer --remote-context ${2}

gcloud compute instances list --filter "name~gke" --format="value(name,zone)" | while read -r name zone; do
    # gcloud compute ssh --zone "$zone" "$name" --project "$GKE_PROJECT_ID" --command "sudo apt-get update; git clone https://github.com/risingfbk/magi; exit" </dev/null
    echo gcloud compute ssh --zone "$zone" "$name" --project "$GKE_PROJECT_ID"
done 

sudo apt install -y zip bison build-essential cmake flex git libedit-dev \
  libllvm14 llvm-14-dev libclang-14-dev python3 zlib1g-dev libelf-dev libfl-dev python3-setuptools \
  liblzma-dev libdebuginfod-dev arping netperf iperf python3-pip dnsutils file jq
git clone https://github.com/risingfbk/magi --recursive
cd /tmp
wget https://github.com/iovisor/bcc/releases/download/v0.24.0/bcc-src-with-submodule.tar.gz
tar xvf bcc-src-with-submodule.tar.gz && rm bcc-src-with-submodule.tar.gz
mkdir bcc/build; cd bcc/build
cmake -DPYTHON_CMD=python3 ..
make -j8 && make install && ldconfig