#!/bin/sh
set -eu
if [ ! -f /data/flows.json ]; then
  if [ -n "$(find /data -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo 'Volumen con datos pero sin flows.json; revisar manualmente'; exit 1
  fi
  cp /examples/flows.json /data/flows.json
fi
chown -R 1000:1000 /data
chmod 700 /data
