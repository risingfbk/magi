#!/bin/bash

VAGBASE="/home/vbox/kubetests/cluster"
DATABASE="/home/vbox/kubetests/"

function wipe_cache() {
    cd $VAGBASE
    vagrant ssh worker2 -c "sudo crictl rmi --prune"
    sleep 60
    cd -
}

function reload_nodes() {
    cd $VAGBASE
    vagrant ssh master -c "sudo kubeadm upgrade node phase kubelet-config; sudo systemctl restart kubelet"; \
    vagrant ssh worker1 -c "sudo kubeadm upgrade node phase kubelet-config; sudo systemctl restart kubelet"; \
    vagrant ssh worker2 -c "sudo kubeadm upgrade node phase kubelet-config; sudo systemctl restart kubelet"
    sleep 60
    cd -
}

function switch_parallel() {
    if [[ "$1" == "1_2" ]]; then
        before=1
        after=2
    elif [[ "$1" == "2_4" ]]; then
        before=2
        after=4
    elif [[ "$1" == "4_1" ]]; then
        before=4
        after=1
    else
        echo "Wrong argument provided to function switch_parallel() - exiting!"
        exit 1
    fi
    tmp=$(mktemp); kubectl get cm -n kube-system kubelet-config -o yaml | sed "s/maxParallelImagePulls: $before/maxParallelImagePulls: $after/g">$tmp; kubectl patch cm -n kube-system kubelet-config --patch-file $tmp
    sleep 10
}

EXP_DURATION=10

wipe_cache

for i in $(seq 1 30); do
    echo "Experiment 4, iteration $i (mp=1)"
    ./4_randommb.sh &
    current_date=$(date +"%FT%T" -u)
    sleep $((60 * EXP_DURATION))
    wipe_cache
    cd $DATABASE
    mkdir -p data/4_randommb_40i_r/maxpull1/$current_date/data
    ./export_data.sh $current_date ${EXP_DURATION}m data/4_randommb_40i_r/maxpull1/$current_date/data
    cd -
done

switch_parallel "1_2"
reload_nodes

for i in $(seq 1 30); do
    echo "Experiment 4, iteration $i (mp=2)"
    ./4_randommb.sh &
    current_date=$(date +"%FT%T" -u)
    sleep $((60 * EXP_DURATION))
    wipe_cache
    cd $DATABASE
    mkdir -p data/4_randommb_40i_r/maxpull2/$current_date/data
    ./export_data.sh $current_date ${EXP_DURATION}m data/4_randommb_40i_r/maxpull2/$current_date/data
    cd -
done

switch_parallel "2_4"
reload_nodes

for i in $(seq 1 30); do
    echo "Experiment 4, iteration $i (mp=4)"
    ./4_randommb.sh &
    current_date=$(date +"%FT%T" -u)
    sleep $((60 * EXP_DURATION))
    wipe_cache
    cd $DATABASE
    mkdir -p data/4_randommb_40i_r/maxpull4/$current_date/data
    ./export_data.sh $current_date ${EXP_DURATION}m data/4_randommb_40i_r/maxpull4/$current_date/data
    cd -
done

switch_parallel "4_1"
reload_nodes
