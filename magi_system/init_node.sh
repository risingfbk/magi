#!/bin/bash

LOG_FILE=/tmp/containerdsnoop.log

if [[ "$UID" -ne 0 ]]; then
    echo "Please run eva01.sh as root."
    exit 1
fi

cd ~

# Assure that Go 1.20 is installed on the system
install_go=0
if command -v go &>/dev/null; then
    # Check version
    if [[ $(go version) =~ "go1.20" ]]; then
        echo "Go 1.20 is installed"
    else
        echo "Go 1.20 is not installed, installing..."
        install_go=1
    fi
else
    # Check if go is installed but not in the path
    if [[ -f "/usr/local/go/bin/go" ]]; then
        echo "Go is installed but not in the path, adding..."
        echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
        source ~/.bashrc
    else
        echo "Go is not installed, installing..."
        install_go=1
    fi
fi

if [[ "$install_go" -eq 1 ]]; then
    rm -rf /usr/local/go
    curl -sLO https://dl.google.com/go/go1.20.4.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
    source ~/.bashrc
fi

# Assure that containerdsnoop is installed on the system
install_containerdsnoop=0
if [[ -d ~/containerdsnoop && -f ~/containerdsnoop/main.go ]]; then
    echo "containerdsnoop is installed"
else
    echo "containerdsnoop is not installed, installing..."
    install_containerdsnoop=1
fi

if [[ "$install_containerdsnoop" -eq 1 ]]; then
    git clone https://github.com/mfranzil/containerdsnoop
fi

# sudo rm -rf ${LOG_FILE}
# echo "Setting up socat..."
# sudo socat PIPE:${LOG_FILE} TCP4-LISTEN:22333,reuseaddr,fork &

# Start listening for containerd events
echo "Starting containerdsnoop..."
cd ~/containerdsnoop
# Download dependencies
go get .
sudo systemctl stop containerd
(sleep 6 && sudo systemctl start containerd) &
sudo $(which go) run main.go -complete_content 2>&1 # &> ${LOG_FILE} # &

# echo "Waiting for containerdsnoop to start..."
# sleep 15

# rip="$(pgrep "main|socat" | tr '\n' ' ')"
# echo "To terminate everything: kill $rip"