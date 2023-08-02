#!/bin/zsh

STYX=styx
QUERIES=prometheus_queries

if [[ -z "$3" ]]; then
    EXPORT_FOLDER=temp_data
else
    EXPORT_FOLDER=$3
    mkdir -p $3
fi

mkdir -p $EXPORT_FOLDER
TS=${1:-'2023-05-19T07:08:20'}
DURATION=${2-:16m}

for i in "${(@f)"$(<${QUERIES})"}"; do 
    echo "Exporting $i..."
    name="$(echo $i | cut -f 1 -d =)"
    query="$(echo $i | cut -f 2- -d =)"
    ${STYX} --header --start ${TS} --duration ${DURATION} ${query} > "${EXPORT_FOLDER}/${name}"
done
