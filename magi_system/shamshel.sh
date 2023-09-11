#!/bin/bash

SHAFOLDER="/var/lib/containerd/io.containerd.content.v1.content/blobs/sha256"
DBFILE="/var/lib/containerd/io.containerd.metadata.v1.bolt/meta.db"
BBOLT="/root/bin/bbolt"

if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# List all files in the sha folder, filter out only the json files, get the time and the file name
files=$(find "$SHAFOLDER" -type f -exec file -i {} \; \
    | grep application/json | cut -f 1 -d : \
    | xargs -I {} ls -l --time-style="+%s" {} \
    | rev | cut -f 1,2 -d " " | rev \
    | sort | sed "s/ /,/g")

for i in $files; do
    time=$(echo $i | cut -f 1 -d ,)
    file=$(echo $i | cut -f 2 -d ,)
    if [[ $(jq .mediaType $file) =~ "application/vnd.docker.distribution.manifest.v2+json" ]]; then
        layers=$(jq -r ".layers[].digest" $file | tr '\n' ',' | sed 's/,$//' | sed 's/sha256://g')
        manifest=$(echo $file | rev | cut -f 1 -d / | rev)
        # Temporarily copy the file to avoid "database is locked" error
        tmp=$(mktemp)
        cp $DBFILE $tmp
        target_key=$($BBOLT keys $tmp v1 k8s.io content blob sha256:$manifest labels | grep distribution.source)
        # Some images may not have a source label (yet)
        if [[ -n "$target_key" ]]; then
            repo=$(echo $target_key | sed 's|containerd.io/distribution.source.||g')
            name=$($BBOLT get $tmp v1 k8s.io content blob sha256:$manifest labels $target_key)
            jq -cMn --arg layers "$layers" --arg manifest "$manifest" --arg repo "$repo" \
                    --arg name "$name" --arg time "$time" \
                    '{layers: $layers | split(","), manifest: $manifest, repo: $repo, name: $name, time: $time}'
        fi
    fi
done
