FROM ubuntu:20.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt install -yqq \
    zip bison build-essential cmake flex git libedit-dev curl \
    libllvm12 llvm-12-dev libclang-12-dev python \
    zlib1g-dev libelf-dev libfl-dev python3-setuptools \
    liblzma-dev arping netperf iperf gcc && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -sLO https://dl.google.com/go/go1.20.4.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz && \
    echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/golang.sh && \
    echo 'export CGO_ENABLED=1' >> /etc/profile.d/golang.sh && \
    echo 'export GOHOSTARCH=amd64' >> /etc/profile.d/golang.sh && \
    echo 'export GOARCH=amd64' >> /etc/profile.d/golang.sh && \
    rm -f go1.20.4.linux-amd64.tar.gz

RUN git clone https://github.com/iovisor/bcc.git && \
    mkdir bcc/build; cd bcc/build && \
    cmake .. && make && make install && \
    cmake -DPYTHON_CMD=python3 .. && \
    pushd src/python/ && make && make install && popd

RUN

COPY . /app
WORKDIR /app
RUN mkdir -p bin && go build -o bin/containerdsnoop main.go && chmod +x bin/containerdsnoop
CMD ["/app/preinit.sh"]
