#!/bin/zsh

dirs=(cluster registry)

for dir in ${dirs}; do
  sudo rm -rf vagrant_${dir}
  mkdir -p vagrant_${dir}
  sudo cp -r ${dir}/* vagrant_${dir}/
  sudo chown -R ubuntu vagrant_${dir}
done
