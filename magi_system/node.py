import argparse
import json
import logging as log
import os
import threading
from time import sleep

from flask import Flask, request, abort

from common import follow

app = Flask(__name__)

queue = []
blacklist = []
ports = {}

watch_mode = False

@app.route('/alert', methods=['POST'])
def alert():
    if not request.json:
        abort(400)
    json_test = request.json
    image = json_test["image"]

    # TODO detect position of the image and see if it's actually being pulled
    if image in queue:
        log.info(f"Image {image} in queue, terminating download")
        terminate_download(image)
        return {"result": f"Requesting removal of image {image} from queue"}, 202
    else:
        log.info(f"Image {image} not in queue, adding to blacklist")
        return {"result": f"Image {image} not in queue, blacklisting"}, 404


def show_queue():
    old_queuestr = str(queue)
    while True:
        if str(queue) != old_queuestr:
            log.info(f"Queue: {queue}")
            old_queuestr = str(queue)
        sleep(5)


def port_mappings(iruellines):
    for line in iruellines:
        try:
            # "$pid,$fd,$sport,$saddr,$dport,$daddr,$layer"
            pid, _, port, _, _, _, layer = line.split(",")
            port = int(port)
            layer = layer.strip()
            if layer not in ports:
                ports[layer] = [port]
            else:
                ports[layer].append(port)
            log.debug(f"Iruel reports layer {layer} is being downloaded on port {port}")
        except ValueError:
            log.error(f"Could not parse line {line}")
            continue


def terminate_download(image):
    if watch_mode:
        return

    image_fullname, tag = image.split(":")
    splt = image_fullname.split("/")
    if len(splt) == 2:  # image is from dockerhub
        registry_domain = "index.docker.io"
        image_name = splt[0] + "/" + splt[1]
    elif len(splt) == 3:  # image is from a private registry
        registry_domain = splt[0]
        image_name = splt[1] + "/" + splt[2]
    else:
        log.warning(f"Image {image} is not from dockerhub or a private registry")
        return

    registry_ip = os.popen(f"dig +short {registry_domain} | grep '.'").read().strip()
    node_source = os.popen("hostname -I | cut -f 1 -d ' '").read().strip()

    # Obtain layer information
    layer_command = "./shamshel.sh"
    layer_hashes = []
    result = [json.loads(line) for line in os.popen(layer_command).read().strip().split("\n")]
    for avail_image in result:
        if avail_image["repo"] + "/" + avail_image["name"] in image_fullname:  # TODO tag missing
            # Append each layer hash to the list without sublists
            layer_hashes += avail_image["layers"]

    if layer_hashes == []:
        raise Exception(f"Could not find layer hashes for {image}, result: {result}")
    else:
        log.debug(f"Obtained layer hashes for {image}: {layer_hashes}")

    # layer_command = f"curl -X GET -u {passwords} https://{registry_domain}/v2/{image_name}/manifests/{tag}
    # 2>/dev/null | jq '.fsLayers[].blobSum' | uniq | tr -d '\"' | cut -f 2 -d : | sort"
    # layer_hashes = os.popen(layer_command).read().strip().split("\n")
    # passwords = "testuser:testpassword"
    #    registry_port = 443
    # log.info(f"Layer hashes: {layer_hashes}")

    log.info(f"Terminating download of image {image} from node {node_source} using registry {registry_ip}")

    # Obtain ports to terminate. Try it 4 times, waiting 3 seconds between each try
    #for _ in range(4):
    for layer in layer_hashes:
        if layer not in ports:
            log.warning(f"Layer {layer} not found in ports (ports: {ports})")
            continue
        layer_ports = ports[layer]
        for layer_port in layer_ports:
            command = f"ss -K src {node_source} sport = {layer_port}"
            result = os.popen(command).read().strip()
            # if results more than 1 line then something was killed
            if len(result.split("\n")) > 1:
                log.info(f"Terminated download of layer {layer} on port {layer_port}")  # log.info(f"Result: {result}")
        ports[layer] = []  # Empty ports for this layer
    # sleep(3)

    # command = f'netstat -apeen | grep $(pgrep containerd | xargs ps | grep "containerd$" | ' \
    #           f'cut -f 1 -d " ")/containerd | grep tcp | grep {registry_ip} | sed -E " s/ +/ /g" | ' \
    #           'cut -f 4 -d " " | cut -f 2 -d : | xargs -I {} ' \
    #           f'ss -K src {node_source} ' \
    #           'sport = {}'

    queue.remove(image)  # log.info("Queue emptied due to termination of download")


def run_flask(port):
    app.run(host="0.0.0.0", port=port)


def inspect_logs(loglines):
    # 12:19:34.176552   kubelet        1732336 1732394 85265  REQ    23     /runtime.v1.ImageService/PullImag
    # "&PullImageRequest{Image:&ImageSpec{Image:registry-1-2-3-4.nip.io/mfranzil/5gb:2,
    # Annotations:map[string]string{kubectl.kubernetes.io/last-applied-configuration:
    # {\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{
    # \"annotations\":{},\"name\":\"5gb-2\",\"namespace\":\"limited\"},
    # \"spec\":{\"containers\":[{\"image\":\"registry-1-2-3-4.nip.io/mfranzil/5gb:2\",\"name\":\"5gb\"}]}}\n,k
    # ubernetes.io/config.seen: 2023-06-05T12:19:31.988703516Z,kubernetes.io/config.source: api,},},Auth:&AuthConf
    # ig{Username:testuser,Password:testpassword,Auth:,ServerAddress:,IdentityToken:,RegistryToken:,},SandboxConf
    # ig:&PodSandboxConfig{Metadata:&PodSandboxMetadata{Name:5gb-2,Uid:e9e9a0af-9233-4c2d-807e-5ea5ecc6bfcb
    # ,Namespace:limited,Attempt:0,},Hostname:5gb-2,LogDirectory:/var/log/pods/limited_5gb-2_e9e9a0af-9
    # 233-4c2d-807e-5ea5ecc6bfcb,DnsConfig:&DNSConfig{Servers:[10.96.0.10],Searches:[limited.svc.cluster.lo
    # cal svc.cluster.local cluster.local],Options:[ndots:5],},PortMappings:[]*PortMapping{},Labels:ma
    # p[string]string{io.kubernetes.pod.name: 5gb-2,io.kubernetes.pod.namespace: limited,io.kubernete
    # s.pod.uid: e9e9a0af-9233-4c2d-807e-5ea5ecc6bfcb,},Annotations:map[string]string{kubectl.kub
    # ernetes.io/last-applied-configuration: {\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"
    # annotations\":{},\"name\":\"5gb-2\",\"namespace\":\"limited\"},
    # \"spec\":{\"containers\":[{\"image\":\"registry-1-2-3-4.nip.io/mfranzil/5gb:2\",\"name\":\"5gb\"}]}}\n
    # ,kubernetes.io/config.seen: 2023-06-05T12:19:31.988703516Z,kubernetes.io/config.source: api,},Linux:&L
    # inuxPodSandboxConfig{CgroupParent:/kubepods.slice/kubepods-besteffort.slice/kubepods-besteffort-pode9
    # e9a0af_9233_4c2d_807e_5ea5ecc6bfcb.slice,SecurityContext:&LinuxSandboxSecurityContext{NamespaceOption
    # s:&NamespaceOption{Network:POD,Pid:CONTAINER,Ipc:POD,TargetId:,UsernsOptions:nil,},SelinuxOptions:nil
    # ,RunAsUser:nil,ReadonlyRootfs:false,SupplementalGroups:[],Privileged:false,SeccompProfilePath:,
    # :nil,Seccomp:&SecurityProfile{ProfileType:RuntimeDefault,LocalhostRef:,},Apparmor:nil,},Sysctls:map[s
    # tring]string{},Overhead:&LinuxContainerResources{CpuPeriod:0,CpuQuota:0,CpuShares:0,MemoryLimitInByte
    # s:0,OomScoreAdj:0,CpusetCpus:,CpusetMems:,HugepageLimits:[]*HugepageLimit{},Unified:map[string]string
    # {},MemorySwapLimitInBytes:0,},Resources:&LinuxContainerResources{CpuPeriod:100000,CpuQuota:0,CpuShare
    # s:2,MemoryLimitInBytes:0,OomScoreAdj:0,CpusetCpus:,CpusetMems:,HugepageLimits:[]*HugepageLimit{},Unif
    # ied:map[string]string{},MemorySwapLimitInBytes:0,},},Windows:nil,},}"
    for line in loglines:
        if "PullImage" not in line:
            continue

        if "RESP" in line:
            # This is a response
            # containerd     1415023 3409742 3416218 RESP   33     /runtime.v1.ImageService/PullImage
            # "&PullImageResponse{ImageRef:sha256:cfb479bb8ac9e4d1b941d04baf842bd392ebfcab62d292f9006f2a56edb7e9d6,}"
            sha = line.lower().split("imageref:sha256:")[1].split(",")[0].strip()
            log.debug(f"Detected a response for pullImage with sha {sha}")
            # Try to obtain the image name from the sha
            try:
                image = os.popen(
                    f"sudo crictl images --no-trunc | grep {sha} | sed -E 's/ +/:/g' | cut -f 1,2 -d :").read().strip()
                log.debug(f"SHA {sha} corresponds to image {image}")
                log.info(f"Detected a response for pullImage with image {image}")
            except Exception as e:
                log.error(f"Could not obtain image name from sha {sha}: {e}")
                continue

            if image in queue:
                queue.remove(image)
                log.info(f"Removed {image} from queue")
            elif "docker.io/library/" in image:
                # This is a docker image, try to remove the prefix
                image = image.split("docker.io/library/")[1]
                if image in queue:
                    queue.remove(image)
                    log.info(f"Removed {image} from queue")
                else:
                    log.warning(f"Cound not find {image} in queue...")
            else:
                log.warning(f"Cound not find {image} in queue...")

        elif "REQ" in line:
            # Attempt to extract the json from the log line
            try:
                # Find the "{Image:" part
                image = ":".join(line.split("{Image:&ImageSpec")[1].split(",")[0].split(":")[1:])
            except IndexError:
                with open("indexerror.log", "a+") as f:
                    f.write(line)
                log.error(f"Could not extract json from the line. See indexerror.log")
                continue
            except Exception:
                log.error(f"Unhandled exception while extracting json from {line}")
                continue

            log.info(f"Detected a request for pullImage with image {image}")

            if image not in queue:
                queue.append(image)
                log.info(f"Added {image} to queue")
            else:
                log.info(f"{image} is already in queue, skipping")

            if image in blacklist:
                blacklist.remove(image)
                terminate_download(image)
                log.info("Terminated download since image was in blacklist")

        else:
            log.error("Malformed log line, skipping")


def main(args):
    # One thread reads the file and keeps a list of all the images being pulled
    # Another thread runs the flask app and listens for alerts
    # If an alert is received, check if the image is in the list
    # If it is, brutally murder the containerd
    log.basicConfig(level=log.INFO, format="%(asctime)s [%(levelname)s] {%(threadName)s} - %(message)s")

    if args.watch_mode:
        watch_mode = True

    snoopfile = args.snoopfile
    iruelfile = args.iruelfile

    if args.test or args.interactive_test:
        with open(snoopfile, "r") as f:
            loglines = f.readlines()
        with open(iruelfile, "r") as f:
            iruellines = f.readlines()
    else:
        loglines = follow(snoopfile)
        iruellines = follow(iruelfile)

    flask_thread = threading.Thread(target=run_flask, args=(args.listen_port,))
    management_thread = threading.Thread(target=inspect_logs, args=(loglines,))
    information_thread = threading.Thread(target=show_queue)
    iruel_thread = threading.Thread(target=port_mappings, args=(iruellines,))

    flask_thread.start()
    management_thread.start()
    information_thread.start()
    iruel_thread.start()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--listen-port", help="Port to listen on", default=8080)
    parser.add_argument("-f", "--snoopfile", help="File from containerdsnoop", required=True)
    parser.add_argument("-I", "--iruelfile", help="File from Iruel", required=True)
    parser.add_argument("-t", "--test", help="Test mode", action="store_true")
    parser.add_argument("-i", "--interactive-test", help="Interactive test mode", action="store_true")
    parser.add_argument("-w", "--watch-mode", help="Watch mode", action="store_true")
    arguments = parser.parse_args()
    main(arguments)
