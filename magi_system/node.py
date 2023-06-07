import argparse
import json
import logging as log
import os
import threading

from flask import Flask, request, abort

from common import follow

app = Flask(__name__)

queue = []

@app.route('/alert', methods=['POST'])
def alert():
    if not request.json:
        abort(400)
    json = request.json
    image = json["image"]

    if image in queue:
        terminate_download(image)
        return {"result": "Requesting removal of image {} from queue".format(image)}, 202
    else:
        return {"result": "Image {} not in queue".format(image)}, 404


def terminate_download(image):
    splt = image.split("/")
    if len(splt) == 2: # image is from dockerhub
        registry_ip = "index.docker.io"
    elif len(splt) == 3: # image is from a private registry
        registry_ip = splt[0]
    else:
        print(splt)
        log.warning("Image {} is not from dockerhub or a private registry".format(image))
        return

    registry_ip = os.popen(f"dig +short {registry_ip} | grep '.'").read().strip()
    node_source = os.popen("hostname -I | cut -f 1 -d ' '").read().strip()

    log.info(f"Terminating download of image {image} from node {node_source} using registry {registry_ip}")

    command = f'netstat -apeen | grep $(pgrep containerd | xargs ps | grep "containerd$" | ' \
              f'cut -f 1 -d " ")/containerd | grep tcp | grep {registry_ip} | sed -E " s/ +/ /g" | ' \
              'cut -f 4 -d " " | cut -f 2 -d : | xargs -I {} ' \
              f'ss -K src {node_source} ' \
              'sport = {}'
    result = os.popen(command).read().strip()
    log.info(f"Result: {result}")

def run_flask():
    app.run(host="0.0.0.0", port=args.listen_port)


def inspect_logs(loglines):
    # 12:19:34.176552   kubelet        1732336 1732394 85265  REQ    23     /runtime.v1.ImageService/PullImag
    # "&PullImageRequest{Image:&ImageSpec{Image:registry-10-231-0-208.nip.io/mfranzil/5gb:2,
    # Annotations:map[string]string{kubectl.kubernetes.io/last-applied-configuration:
    # {\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{
    # \"annotations\":{},\"name\":\"5gb-2\",\"namespace\":\"limited\"},
    # \"spec\":{\"containers\":[{\"image\":\"registry-10-231-0-208.nip.io/mfranzil/5gb:2\",\"name\":\"5gb\"}]}}\n,k
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
    # \"spec\":{\"containers\":[{\"image\":\"registry-10-231-0-208.nip.io/mfranzil/5gb:2\",\"name\":\"5gb\"}]}}\n
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
        if "REQ" not in line:
            continue
        tmp = line.split("last-applied-configuration:")
        tmp = tmp[1].split("}\n")[0].strip().replace("\\n", "").replace("\\", "").replace(" ", "")
        # Try to count curly braces and terminate when the count is 0
        ctcrl = 0
        i = 0
        while i < len(tmp):
            # print(f"current char: {tmp[i]}, i: {i}, ctcrl: {ctcrl}")
            if tmp[i] == "{":
                ctcrl += 1
            elif tmp[i] == "}":
                ctcrl -= 1
            if ctcrl == 0:
                break
            i += 1
        tmp = tmp[:i + 1]
        js = json.loads(tmp)
        image = js["spec"]["containers"][0]["image"]
        queue.append(image)
        log.info(f"Added {image} to queue")

        # TODO implement removal of image from queue

def main(args):
    # One thread reads the file and keeps a list of all the images being pulled
    # Another thread runs the flask app and listens for alerts
    # If an alert is received, check if the image is in the list
    # If it is, brutally murder the containerd
    log.basicConfig(level=log.INFO, format="%(asctime)s [%(levelname)s] - %(message)s")

    file = args.snoopfile

    if args.test or args.interactive_test:
        with open(file, "r") as f:
            loglines = f.readlines()
    else:
        loglines = follow(file)

    flask_thread = threading.Thread(target=run_flask)
    management_thread = threading.Thread(target=inspect_logs, args=(loglines,))

    flask_thread.start()
    management_thread.start()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--listen-port", help="Port to listen on", default=8080)
    parser.add_argument("-f", "--snoopfile", help="File from containerdsnoop", required=True)
    parser.add_argument("-t", "--test", help="Test mode", action="store_true")
    parser.add_argument("-i", "--interactive-test", help="Interactive test mode", action="store_true")
    args = parser.parse_args()
    main(args)