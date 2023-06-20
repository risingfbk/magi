#!/bin/bash

SHAFOLDER="/var/lib/containerd/io.containerd.content.v1.content/blobs/sha256"
DBFILE="/var/lib/containerd/io.containerd.metadata.v1.bolt/meta.db"
BBOLT="/home/vagrant/go/bin/bbolt"

if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

#while [[ 1 = 1 ]]; do
    files=$(find "$SHAFOLDER" -type f -exec file -i {} \; | grep application/json | cut -f 1 -d : | xargs -I {} ls -l --time-style="+%s" {} | rev | cut -f 1,2 -d " " | rev | sort | sed "s/ /,/g")
    for i in $files; do
        time=$(echo $i | cut -f 1 -d ,)
        file=$(echo $i | cut -f 2 -d ,)
        if [[ $(jq .mediaType $file) =~ "application/vnd.docker.distribution.manifest.v2+json" ]]; then
            layers=$(jq -r ".layers[].digest" $file | tr '\n' ',' | sed 's/,$//' | sed 's/sha256://g')
            manifest=$(echo $file | rev | cut -f 1 -d / | rev)

            tmp=$(mktemp)
            cp $DBFILE $tmp
            target_key=$($BBOLT keys $tmp v1 k8s.io content blob sha256:$manifest labels | grep distribution.source)
            if [[ -z "$target_key" ]]; then
                continue
            fi
            repo=$(echo $target_key | sed 's|containerd.io/distribution.source.||g')
            name=$($BBOLT get $tmp v1 k8s.io content blob sha256:$manifest labels $target_key)
            # printf "%s (%s) => %s/%s\n" "$manifest" "$time" "$repo" "$name"
            # echo "Layers: $layers"
            # echo "----"
            # Convert to json
            jq -cMn --arg layers "$layers" --arg manifest "$manifest" --arg repo "$repo" --arg name "$name" --arg time "$time" '{layers: $layers | split(","), manifest: $manifest, repo: $repo, name: $name, time: $time}'

        fi
    done
