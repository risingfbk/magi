#!/bin/bash

# [pid 1947889] mkdirat(AT_FDCWD, "/var/lib/containerd/io.containerd.content.v1.content
# /ingest/b253829324bf5dcf58029b126e42713139712a9a671e097dacff2b2d2db85ac0", 0755

# 420045 connect(49, {sa_family=AF_INET, sin_port=htons(443),
# sin_addr=inet_addr("1.2.3.4")}, 16) = -1 EINPROGRESS (Operation now in progress)

# 420040 getsockname(61,  <unfinished ...>

# 420040 <... getsockname resumed>{sa_family=AF_INET,
# sin_port=htons(59184), sin_addr=inet_addr("192.168.121.58")}, [112->16]) = 0

# Extract PID and hash from strace output

if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

rm -rf /tmp/iruel.log && touch /tmp/iruel.log

TMPFILE="$(mktemp)"
sudo strace -fp $(pgrep containerd$) -o $TMPFILE &> /dev/null &
writer=$!
trap "kill $writer; rm -rf $TMPFILE" SIGTERM

function parse() {
    mapping=$1
    pid=$(echo $mapping | cut -f 1 -d ",")
    layers="$(cat $TMPFILE | grep --color=never --line-buffered $pid \
        | grep --color=never --line-buffered -oE ".content/ingest/.*?/.*" | cut -f 3 -d / | uniq \
        | sed -E 's|^(.*)$|/var/lib/containerd/io.containerd.content.v1.content/ingest/\1/ref|g' \
        | xargs -I {} awk '{print $0}' {} 2>/dev/null | cut -f 2 -d :)"

    fd_req=$(echo $mapping | cut -f 2 -d ",")
    dport=$(echo $mapping | cut -f 3 -d ",")
    daddr=$(echo $mapping | cut -f 4 -d ",")

    localmaps=$(cat $TMPFILE | grep --color=never --line-buffered -E "getsockname" \
        | grep --color=never --line-buffered AF_INET -B 1 | tr '\n' '~' | sed "s/>~\[/>[/g" | sed -E "s/>~([0-9]+) </>\1 </g" | tr "~" "\n" \
        | grep --color=never --line-buffered -oE "(^\[pid +|^)([0-9]+)(\])?.*getsockname\($fd_req,.*?sin_port=htons\(([0-9]+)\),.*?sin_addr=inet_addr\(\"([0-9\.]+)\"\)" \
        | sed -u --regexp-extended 's/(^\[pid +|^)([0-9]+)(\])?.*getsockname\(([0-9]+).*port=htons\(([0-9]+)\).*inet_addr\("([0-9\.]+)"\).*$/\4 \5 \6/g' \
        | tr ' ' ',')
    for layer in $layers; do
        for map in $localmaps; do
            fd=$(echo $map | cut -f 1 -d ",")
            sport=$(echo $map | cut -f 2 -d ",")
            saddr=$(echo $map | cut -f 3 -d ",")
            echo "$pid,$fd,$sport,$saddr,$dport,$daddr,$layer" >> /tmp/iruel.log
        done
    done
}

tail --follow=name $TMPFILE \
        | grep --color=never --line-buffered -E "connect\(" | grep --color=never --line-buffered AF_INET | grep --color=never --line-buffered -v "htons(53)" \
        | grep --color=never --line-buffered -oE "(^\[pid +|^)([0-9]+)(\])?.*connect\(([0-9]+),.*?sin_port=htons\(([0-9]+)\),.*?sin_addr=inet_addr\(\"([0-9\.]+)\"\)" \
        | sed -u --regexp-extended 's/(^\[pid +|^)([0-9]+)(\])?.*connect\(([0-9]+).*port=htons\(([0-9]+)\).*inet_addr\("([0-9\.]+)"\).*$/\2 \4 \5 \6/g' \
        | grep --color=never --line-buffered -vE "^(.*?) (.*?) 53 (.*?)" | while read line; do
    if [[ -z "$line" || "$line" == "" ]]; then
        continue
    fi
    line=$(echo $line | tr ' ' ',')
    parse "$line" &
done
