#!/bin/zsh

cutoff=(650 556 510 1165 965 853 947 715 702)

j=0
for i in $(find ${1:-.} -type f -name "worker2cpu" | sort); do
    j=$((j+1))
    total_time=$((cutoff[j]+1))
    idle=$(cat $i | head -n $total_time | cut -f 2 -d ";" | grep -v "mode" | paste -sd+ | bc)
    iowait=$(cat $i| head -n $total_time | cut -f 3 -d ";" | grep -v "mode" | paste -sd+ | bc)
    system=$(cat $i| head -n $total_time| cut -f 8 -d ";" | grep -v "mode" | paste -sd+ | bc)
    user=$(cat $i | head -n $total_time| cut -f 9 -d ";" | grep -v "mode" | paste -sd+ | bc)
    total=$(cat $i | head -n $total_time| cut -f 2- -d ";" | tr ";" "\n" | grep -v "mode" | paste -sd+ | bc)
    non_idle=$(echo "$total - $idle" | bc)
    load=$(python3 -c "print($non_idle / $total * 100)")
    echo "$i;$idle;$total;$non_idle;$load"

done
