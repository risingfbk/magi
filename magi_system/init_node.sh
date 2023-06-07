#!/bin/bash

LOG_FILE=/tmp/containerdsnoop.log

if [[ "$UID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

# Assure that Go 1.20 is installed on the system
install_go=0
if command -v go &>/dev/null; then
    # Check version
    if [[ $(go version) =~ "go1.20" ]]; then
        echo "Go 1.20 is installed"
    else
        echo "Go 1.20 is not installed..."
        install_go=1
    fi
else
    # Check if go is installed but not in the path
    if [[ -f "/usr/local/go/bin/go" ]]; then
        echo "Go is installed but not in the path, adding..."
        echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
        source ~/.bashrc
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
# rm -rf ${LOG_FILE}
# socat PIPE:${LOG_FILE} TCP4-LISTEN:22333,reuseaddr,fork &

echo "Rebooting kubelet, this may take a while..."
systemctl stop kubelet
(sleep 15 && systemctl start kubelet) &

echo "Starting containerdsnoop..."
containerdsnoop -complete_content >${LOG_FILE} 2>&1 &

echo "Checking python3 requirements..."
echo "By proceeding, you are installing the following packages:"
cat requirements.txt
echo "on this python environment:"
echo $(which python3)
python3 --version
read -p "Do you want to proceed? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting..."
    exit 1
fi

echo "Installing python3 requirements..."
pip3 install -r requirements.txt

# trap "exit" INT TERM ERR

echo "Starting monitoring..."
python3 node.py --snoopfile ${LOG_FILE} --listen-port 22333

# &> ${LOG_FILE} # &
# echo "Waiting for containerdsnoop to start..."
# sleep 15
# rip="$(pgrep "main|socat" | tr '\n' ' ')"
# echo "To terminate everything: kill $rip"