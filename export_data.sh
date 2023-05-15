#!/bin/zsh

STYX=/home/ubuntu/.asdf/installs/golang/1.20.4/packages/bin/styx
QUERIES=prometheus_queries
EXPORT_FOLDER=data
TS='2023-05-15T08:16:31'
DURATION=20m

for i in "${(@f)"$(<${QUERIES})"}"; do 
    echo "Exporting $i..."
    name="$(echo $i | cut -f 1 -d =)"
    query="$(echo $i | cut -f 2- -d =)"
    ${STYX} --header --start ${TS} --duration ${DURATION} ${query} > "${EXPORT_FOLDER}/${name}"
done
