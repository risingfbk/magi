#!/bin/bash

LOG_FOLDER=/tmp/magi
[[ ! -d $LOG_FOLDER ]] && mkdir -p $LOG_FOLDER

MKDIRSNOOP_LOG=$LOG_FOLDER/mkdirsnoop.log
TCPCONNECT_LOG=$LOG_FOLDER/tcpconnect.log
CTDSNOOP_LOG=$LOG_FOLDER/containerdsnoop.log

IRUEL_LOG=$LOG_FOLDER/iruel.log

if [[ "$UID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

# shellcheck disable=SC1091
source "$HOME/.bashrc"

if pgrep "containerdsnoop" &>/dev/null; then
    echo "Killing rogue containerdsnoop instances..."
    pkill -9 "containerdsnoop"
fi

if [[ $(pgrep iruel.sh) ]]; then
    pkill -9 iruel.sh
fi

rm -rf "${CTDSNOOP_LOG}" "${IRUEL_LOG}" "${MKDIRSNOOP_LOG}" "${TCPCONNECT_LOG}"
touch "${CTDSNOOP_LOG}" "${IRUEL_LOG}" "${MKDIRSNOOP_LOG}" "${TCPCONNECT_LOG}"

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
    echo "Go is not installed, exiting..."
    install_go=1
    exit 1
fi

# Assure that containerdsnoop is installed on the system
install_containerdsnoop=0
if [[ -f "containerdsnoop/containerdsnoop" ]]; then
    echo "containerdsnoop is installed"
else
    echo "containerdsnoop is not installed..."
    # Attempt to compile it
    if [[ -d "containerdsnoop" ]]; then
        echo "Attempting to compile containerdsnoop..."
        cd containerdsnoop && go build . && cd ..
    else
        install_containerdsnoop=1
        echo "containerdsnoop folder not found, you need to install it manually."
        exit 1
    fi
fi

# echo "Setting up socat..."
# rm -rf ${CTDSNOOP_LOG}
# socat PIPE:${CTDSNOOP_LOG} TCP4-LISTEN:22333,reuseaddr,fork &

echo "Rebooting kubelet, this may take a while..."
systemctl stop kubelet
(sleep 15 && systemctl start kubelet) &

sleep 10
echo "Starting containerdsnoop..."
./containerdsnoop/containerdsnoop -complete_content >${CTDSNOOP_LOG} 2>&1 &
sleep 5
pid=$!

echo "Checking python3 requirements..."
reqs=$(pip freeze -r requirements.txt 2>&1 | grep "WARNING")
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

echo "Bringing out the snoopers..."
./imagesnoop/mkdirsnoop -P $(pgrep containerd$) -f $MKDIRSNOOP_LOG &
pid="$pid $!"
./imagesnoop/tcpconnect -P $(pgrep containerd$) -f $TCPCONNECT_LOG &
pid="$pid $!"
sleep 6

echo "Invoking Iruel..."
python3 iruel.py --mkdirat $MKDIRSNOOP_LOG --connect $TCPCONNECT_LOG --output $IRUEL_LOG &
pid="$pid $!"

echo "Starting node monitoring..."
python3 node.py --snoopfile ${CTDSNOOP_LOG} --iruelfile ${IRUEL_LOG} --listen-port 22333

echo "Cleaning up..."

pgrep containerdsnoop | xargs kill -9 2>/dev/null
pgrep shamshel | xargs kill -9 2>/dev/null
pgrep python3 | xargs kill -9 2>/dev/null
pgrep imagesnoop | xargs kill -9 2>/dev/null
pgrep mkdirsnoop | xargs kill -9 2>/dev/null

for pid in $pid; do
    kill -9 "$pid"
done
