import json
from common import follow
import argparse
import threading
import time

directories = {}
connections = {}

def mkdir_callback(mkdir_lines):
    for m_line in mkdir_lines:
        if "/var/lib/containerd/io.containerd.content.v1.content/ingest" not in m_line:
            continue
        m_obj = json.loads(m_line)
        tid = m_obj["tid"]
        __hash = m_obj["argv"]
        try:
            with open(__hash + "/ref", "r") as ref:
                layer = ref.read().strip()
                layer = layer.split(":")[1]
                if tid not in directories:
                    directories[tid] = [layer]
                else:
                    directories[tid].append(layer)
                # print(f"hash={__hash}, layer={layer} from tid={tid}")
        except FileNotFoundError as err:
            print(f"Too late for hash={__hash} from tid={tid}")
            continue

def connect_callback(conn_lines):
    for c_line in conn_lines:
        c_obj = json.loads(c_line)

        tid = c_obj["tid"]

        if tid not in connections:
            connections[tid] = []

        connections[tid].append(
            {
                "sport": c_obj["lport"],
                "saddr": c_obj["saddr"],
                "dport": c_obj["dport"],
                "daddr": c_obj["daddr"]
            }
        )

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mkdirat", required=True, help="file path to mkdirat log")
    parser.add_argument("--connect", required=True, help="file path to tcp_connect log")
    parser.add_argument("--output", required=True, default="file path to output")
    args = parser.parse_args()

    if not args.mkdirat or not args.connect or not args.output:
        parser.usage()
        exit(1)
    mkdirat_path = args.mkdirat
    conn_path = args.connect

    mkdir_lines = follow(mkdirat_path)
    conn_lines = follow(conn_path)

    # Spawn two reading threads and read from files
    t = threading.Thread(target=mkdir_callback, args=[mkdir_lines])
    t.start()

    t = threading.Thread(target=connect_callback, args=[conn_lines])
    t.start()

    while True:
        time.sleep(0.1)
        mkdir_keys = set(directories.keys())
        conn_keys = set(connections.keys())

        found = mkdir_keys & conn_keys
        if found == set():
            continue

        #  "$pid,$fd,$sport,$saddr,$dport,$daddr,$layer"
        mappings = []
        for key in found:
            for directory in directories[key]:
                for connection in connections[key]:
                    mappings.append([key, connection["sport"], connection["saddr"],
                           connection["dport"], connection["daddr"],
                           directory])

        with open(args.output, "a") as fp:
            for mapping in mappings:
                fp.write(",".join([str(e) for e in mapping]) + "\n")
            
        for key in found:
            del directories[key]
            del connections[key]

    # print("Connections", json.dumps(connections, indent=4))
    # print("Directories", json.dumps(directories, indent=4))

if __name__ == "__main__":
    main()
