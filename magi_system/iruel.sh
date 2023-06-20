#!/bin/bash

# [pid 1947889] mkdirat(AT_FDCWD, "/var/lib/containerd/io.containerd.content.v1.content
# /ingest/b253829324bf5dcf58029b126e42713139712a9a671e097dacff2b2d2db85ac0", 0755

# Extract PID and hash from strace output


if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

TMPFILE="$(mktemp)"
rm -rf /tmp/iruel.log && touch /tmp/iruel.log

sudo strace -fp $(pgrep containerd$) &> $TMPFILE &
writer=$!
trap "pkill -P $$; kill $writer; rm -rf $TMPFILE; exit" INT TERM EXIT

tail -F $TMPFILE | $(which grep) --line-buffered --color=never -E "openat.*/var/lib/containerd/io.containerd.content.v1.content/ingest/.*/ref" | sed -u --regexp-extended 's/.*\[pid ([0-9]+)\].*ingest\/(.*?)\/ref".*/\1 \2/g' | while read line; do
    if [[ -z "$line" ]]; then
        continue
    fi
    sha=""
    pid=""
    hash=""
    fd=""
    port=""
    ip=""

    (
    # echo "> $line"
    pid="$(echo $line | cut -f 1 -d " ")"
    hash="$(echo $line | cut -f 2 -d " ")"
    sha="$(cat /var/lib/containerd/io.containerd.content.v1.content/ingest/$hash/ref 2> /dev/null)"
    sleep 2
    if [[ -n "$sha" ]]; then
        sha="$(echo $sha | rev | cut -f 1 -d : | rev)"
        # 420045 connect(49, {sa_family=AF_INET, sin_port=htons(443), sin_addr=inet_addr("10.231.0.208")}, 16) = -1 EINPROGRESS (Operation now in progress)
        # 420040 getsockname(61,  <unfinished ...>
        # 420040 <... getsockname resumed>{sa_family=AF_INET, sin_port=htons(59184), sin_addr=inet_addr("192.168.121.58")}, [112->16]) = 0
        second_line=$(cat $TMPFILE | grep --color=never "$pid" | grep --color=never "$HASH" -A 10000 | grep --color=never "getsockname" | grep --color=never "htons" | grep -oE "sin_port=htons\(([0-9]+)\).*sin_addr=inet_addr\(\"([0-9\.]+)\"\)" | tail -n 1)
        if [[ -n "$second_line" ]]; then
            port="$(echo $second_line | cut -f 1 -d " " | cut -f 2 -d "(" | cut -f 1 -d ")" | cut -f 2 -d "=")"
            dst_ip="$(echo $second_line | cut -f 2 -d " " | cut -f 2 -d "(" | cut -f 1 -d ")" | cut -f 2 -d "=" | cut -f 2 -d "\"")"
            echo "$pid,$sha,,$port,$dst_ip," >> /tmp/iruel.log
        fi
        # second_line=$(cat $TMPFILE | grep --color=never "$pid" | grep --color=never "$hash" -A 10000 | grep --color=never -v "127.0.0.53" | $(which grep) --line-buffered --color=never -E "connect\(.*?, \{" | sed -u --regexp-extended 's/connect\(([0-9]+).*port=htons\(([0-9]+)\).*inet_addr\("([0-9\.]+)"\).*$/\1 \2 \3/g')
        # fd="$(echo $second_line | cut -f 3 -d " ")"
        # dst_port="$(echo $second_line | cut -f 2 -d " ")"
        # dst_ip="$(echo $second_line | cut -f 1 -d " ")"
        # if [[ -n "$fd" ]]; then
            # COMMAND      PID USER   FD   TYPE    DEVICE SIZE/OFF NODE NAME
            # container 420038 root   18u  IPv4 319703123      0t0  TCP worker2:49716->10.231.0.208:https (ESTABLISHED)
            #port=$(lsof -i -a -p $(pgrep containerd$) | grep ${fd}u | awk '{print $9}' | cut -f 2 -d ":" | cut -f 1 -d "-")
            # echo "PID $pid is downloading sha256:$sha on FD $fd. Would kill port $port"
    fi
    ) &
done


