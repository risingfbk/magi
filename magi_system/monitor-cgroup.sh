#!/bin/bash

[[ -z "$1" ]] && echo "Usage: $0 <cgroupname>" && exit

[[ "$(id -u)" -ne 0 ]] && echo "This script must be run as root" && exit

[[ ! -e /sys/fs/cgroup/$1 ]] && echo "Cgroup $1 not found" && exit

cgroup=$1

printf "time,cpu,mem,pids\n"

while true; do
    tstart=$(date +%s%N)
    cstart=$(cat /sys/fs/cgroup/$cgroup/cpu.stat | grep usage_usec | awk '{ print $2 }')

    sleep 2

    tstop=$(date +%s%N)
    cstop=$(cat /sys/fs/cgroup/$cgroup/cpu.stat | grep usage_usec | awk '{ print $2 }')


    cpu=$(bc -l <<EOF
($cstop - $cstart) / ($tstop - $tstart) * 100
EOF
)
    mem=$(cat /sys/fs/cgroup/$cgroup/memory.current)
    memory=$(bc -l <<EOF
$mem / 1024 / 1024
EOF
)

    printf "%s,%f,%f,%d\n" "$(date  --rfc-3339=seconds)" "$cpu" "$memory" "$(cat /sys/fs/cgroup/$cgroup/pids.current)"
done
    