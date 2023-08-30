#!/bin/bash

echo "Press [CTRL+C] to stop.."
while true; do
        mkdir tmp
        for i in $(seq 1 20); do
            cp data.txt tmp/data$i.txt &>/dev/null
        done
        tar -cvf tmp.tar tmp &>/dev/null
        rm -rf tmp tmp.tar
        sleep 5
done
