#!/bin/bash

CTDSNOOP_LOG=/tmp/containerdsnoop.log
IRUEL_TMP=/tmp/iruel.tmp
IRUEL_LOG=/tmp/iruel.log

if [[ "$UID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

# shellcheck disable=SC1091
source "$HOME/.bashrc"

if [[ $(pgrep containerdsnoop) ]]; then
    pkill -9 containerdsnoop
fi
if [[ $(pgrep iruel.sh) ]]; then
    pkill -9 iruel.sh
fi

rm -rf "${CTDSNOOP_LOG}" "${IRUEL_LOG}"

# Assure that Go 1.20 is installed on the system
install_go=0
if which go &>/dev/null; then
    # Check version
    if [[ $(go version) =~ go1.20 ]]; then
        echo "Go 1.20 is installed"
    else
        echo "Go 1.20 is not installed..."
        install_go=1
    fi
else
    # Check if go is installed but not in the path
    if [[ -f "/usr/local/go/bin/go" ]]; then
        echo "Go is installed but not in the path, adding..."
        export PATH=$PATH:/usr/local/go/bin
    else
        echo "Go is not installed..."
        install_go=1
    fi
fi

# Assure that containerdsnoop is installed on the system
install_containerdsnoop=0
if command -v containerdsnoop &>/dev/null; then
    echo "containerdsnoop is installed"
else
    echo "containerdsnoop is not installed..."
    install_containerdsnoop=1
fi

if [[ "$install_go" -eq 1 || "$install_containerdsnoop" -eq 1 ]]; then
    echo "Some dependencies are missing. Please fix them before continuing."
    exit 1
fi

# echo "Setting up socat..."
# rm -rf ${CTDSNOOP_LOG}
# socat PIPE:${CTDSNOOP_LOG} TCP4-LISTEN:22333,reuseaddr,fork &

echo "Rebooting kubelet, this may take a while..."
systemctl stop kubelet
(sleep 15 && systemctl start kubelet) &

if pgrep "containerdsnoop" &>/dev/null; then
    echo "Killing rogue containerdsnoop instances..."
    pgrep "containerdsnoop" | xargs kill
fi

echo "Starting containerdsnoop..."
containerdsnoop -complete_content >${CTDSNOOP_LOG} 2>&1 &
pid=$!

echo "Checking python3 requirements..."
reqs=$(pip freeze -r requirements.txt 2>&1 | grep "Warning")
if [[ -n "$reqs" && $(echo "$reqs" | wc -l) -gt 0 ]]; then
    echo "Some python3 requirements are missing:"
    echo "$reqs"

    echo "By proceeding, you are installing the following packages:"
    cat requirements.txt
    echo "on this python environment:"
    printf "%s @ %s\n" "$(python3 --version)" "$(which python3)"

    read -p "Do you want to proceed? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting..."
        exit 1
    fi

    echo "Installing python3 requirements..."
    pip3 install -r requirements.txt
else
    echo "All python3 requirements are satisfied."
fi
# trap "exit" INT TERM ERR

echo "Checking if bbolt is installed..."
if which bbolt &>/dev/null; then
    echo "bbolt is installed"
else
    if [[ -f "$HOME/go/bin/bbolt" ]]; then
        echo "bbolt is installed but not in the path, adding..."
        export PATH=$PATH:/home/vagrant/go/bin
    else
        echo "bbolt is not installed, installing..."
        go install go.etcd.io/bbolt/cmd/bbolt@latest
    fi
fi

echo "Invoking Iruel, this may take a while..."

docker rm -f tetragon-container
[[ -f "$IRUEL_TMP" ]] && rm $IRUEL_TMP
[[ -f "$IRUEL_LOG" ]] && rm $IRUEL_LOG

docker run -d --name tetragon-container \
    --rm --pull always --pid=host --cgroupns=host \
    --privileged -v "$PWD/tracing_policy.yaml:/tracing_policy.yaml" \
    -v /sys/kernel/btf/vmlinux:/var/lib/tetragon/btf \
    quay.io/cilium/tetragon-ci:latest \
    --tracing-policy /tracing_policy.yaml

echo "Waiting for tetragon-container to be ready..."
sleep 50

echo "Recording events..."
sleep 10

docker exec tetragon-container tetra getevents -o json > $IRUEL_TMP &

python3 iruel.py
pid="$pid $!"

echo "Starting monitoring..."
python3 node.py --snoopfile ${CTDSNOOP_LOG} --iruelfile ${IRUEL_LOG} --listen-port 22333

echo "Cleaning up..."

pgrep containerdsnoop | xargs kill -9
pgrep shamshel | xargs kill -9
pgrep python3 | xargs kill -9
docker stop tetragon-container && docker rm -f tetragon-container

for pid in $pid; do
    kill -9 "$pid"
done
