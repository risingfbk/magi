FROM debian:latest
RUN apt-get update && apt-get install -y iperf3 && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/usr/bin/iperf3"] 
