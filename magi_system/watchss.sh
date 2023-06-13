#!/bin/bash

# Script that monitors the open sockets and keeps track for how long they are open

if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

REGISTRY_DOMAIN=$1
REGISTRY_PORT=$2
INTERVAL=0.1

if [[ -z "$REGISTRY_DOMAIN" || -z "$REGISTRY_PORT" ]]; then
  echo "Please provide the registry domain and port"
  exit 1
fi

NODE_SOURCE="$(hostname -I | cut -f 1 -d ' ')"
REGISTRY_IP="$(dig +short $REGISTRY_DOMAIN | tail -n 1)"
PNAME="$(pgrep containerd | xargs ps | grep "containerd$" | cut -f 1 -d " ")/containerd"
 # | xargs -I {} sudo ss src $NODE_SOURCE sport = {}
# Create a map of ports to times
declare -A port_times

i=0
while true; do
    i=$((i + 1))
    # Get currently open ports
    ports="$(sudo netstat -apeen | grep $PNAME | grep tcp | grep $REGISTRY_IP | sed -E " s/ +/ /g" | cut -f 4 -d " " | cut -f 2 -d :)"
    # For each port, check if it is in the map
    # if not, add it with time=0, else add +0.5 to the time
    for port in $ports; do
        if [[ -z "${port_times[$port]}" ]]; then
            port_times[$port]=0
        else
            port_times[$port]=$(echo "${port_times[$port]} + $INTERVAL" | bc)
        fi
    done
    # Print the map ordered by time every 2 seconds
    if [[ $i -eq 20 ]]; then
        i=0
        clear
        echo "---------------------"
        echo "Open ports:"
        output="$(
            for port in "${!port_times[@]}"; do
                # if port no longer open, remove it from the map
                if ! echo "$ports" | grep -q "$port"; then
                    unset port_times[$port]
                    continue
                else
                    # else print it
                  printf "$port\t${port_times[$port]}\n"
                fi
            done
        )"
        echo "$output" | sort -k 2 -n -r
    fi
    sleep $INTERVAL
done