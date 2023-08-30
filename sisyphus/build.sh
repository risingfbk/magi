#!/bin/bash

if [[ "$2" == "--regen" ]]; then
    echo "Regenerating data.pdf..."
    od /dev/urandom | tr -d " " | head -c 100M > data.txt
    # pandoc data.txt -o data.pdf
    # rm data.txt
fi

docker build . -t ${REGISTRY_IP_DOMAIN}/mfranzil/sisyphus:$1 --no-cache
docker push ${REGISTRY_IP_DOMAIN}/mfranzil/sisyphus:$1
