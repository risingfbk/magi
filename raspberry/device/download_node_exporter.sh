wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-armv7.tar.gz
tar xvf node_exporter*.tar.gz
rm node_exporter*.tar.gz
cd node_exporter*
sudo ./node_exporter &
disown %1
