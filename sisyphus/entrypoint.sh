#!/bin/bash

trap 'rm -rf tmp*; kill $pid; exit 0' SIGINT SIGTERM 

if [[ -z "$1" && "$1" != "cpu" && "$1" != "io" ]]; then
    echo "Usage: $0 [cpu|io]"
    exit 1
fi

if [[ "$1" == "cpu" ]]; then
    ./cpu.sh &
    pid=$!
elif [[ "$1" == "io" ]]; then
    ./io.sh &
    pid=$!
else
    echo "Usage: $0 [cpu|io]"
    exit 1
fi

# Start monitoring the CPU usage (user, system, real)
# and the IO usage (read, write)
while true; do
    uptime=$(cat /proc/uptime | awk '{print $1}')
    stat=$(cat /proc/$pid/stat | awk '{print $14,$15,$16,$17}')
    echo "uptime=$uptime, utime,stime,cutime,cstime=$stat"
    sleep 2
done

