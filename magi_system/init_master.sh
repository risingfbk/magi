#!/bin/bash

# Friendly parser for the audit logs
if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

sudo tail -F /var/log/kubernetes/audit/audit.log | grep "/pods" | jq 'select(.verb == "delete" or .verb == "create") | {requestURI: .requestURI, verb: .verb, stage: .stage, imageRequest: .responseObject.spec.containers[0].image, targetNode: .requestObject.target.name, respondingNode: .responseObject.spec.nodeName}'