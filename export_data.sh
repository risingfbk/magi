#!/bin/zsh

STYX=/home/ubuntu/go/bin/styx
QUERIES=prometheus_queries
EXPORT_FOLDER=data
DURATION=13h

for i in "${(@f)"$(<${QUERIES})"}"; do 
    echo "Exporting $i..."
    name="$(echo $i | cut -f 1 -d =)"
    query="$(echo $i | cut -f 2- -d =)"
    ${STYX} --duration ${DURATION} ${query} > "${EXPORT_FOLDER}/${name}"
done
