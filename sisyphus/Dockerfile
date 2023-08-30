FROM ubuntu:latest
# RUN apt-get update && apt-get install -y sysstat && rm -rf /var/cache/apt/*
RUN mkdir /app
WORKDIR /app
COPY . /app
RUN chmod +x io.sh cpu.sh entrypoint.sh
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]

