#!/bin/bash

if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

docker rm -f tetragon-container
LOG_FILE=/tmp/iruel.tmp
ACTUAL_LOG=/tmp/iruel.log
[[ -f "$LOG_FILE" ]] && rm $LOG_FILE
[[ -f "$ACTUAL_LOG" ]] && rm $ACTUAL_LOG

docker run -d --name tetragon-container --rm --pull always --pid=host --cgroupns=host --privileged -v "$PWD/tracing_policy.yaml:/tracing_policy.yaml" -v /sys/kernel/btf/vmlinux:/var/lib/tetragon/btf quay.io/cilium/tetragon-ci:latest       --tracing-policy /tracing_policy.yaml
echo "Waiting for tetragon-container to be ready..."
sleep 50

echo "Recording events..."
sleep 4

# cat bruh \
# tail --follow=name $LOG_FILE \
docker exec tetragon-container tetra getevents -o json > $LOG_FILE &

python3 iruel.py