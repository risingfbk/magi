#!/bin/bash

# Friendly parser for the audit logs
if [[ "$UID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi


python3 master.py --auditfile /var/log/kubernetes/audit/audit.log --target-port 22333