
import argparse
import json
import logging as log
import os
import sys
import time

import requests

from common import follow


def main(args: argparse.Namespace):
    log.basicConfig(level=log.INFO, format="%(asctime)s [%(levelname)s] - %(message)s")

    file = args.auditfile

    if args.test or args.interactive_test:
        with open(file, "r") as f:
            loglines = f.readlines()
    else:
        loglines = follow(file)

    handled = {}

    log.info("Starting to inspect logs...")
    log.info(f"Following log file {file}")

    for line in loglines:
        if "/pods" not in line:
            continue
        try:
            js = json.loads(line)
        except json.decoder.JSONDecodeError:
            log.error(f"Could not decode json from {line}")
            continue

        uri = js["requestURI"]
        verb = js["verb"]
        stage = js["stage"]

        if verb not in ("create", "delete"):
            continue

        if verb == "create" and stage == "RequestReceived":
            continue

        if args.interactive_test:
            p = input("Print the json? (y/n) ")
            if p == "y":
                print(json.dumps(js, indent=4))

        if "name" in js["objectRef"]:
            name = js["objectRef"]["name"]
        else:
            name = js["auditID"]

        key = "-".join([name, js["objectRef"]["namespace"], js["objectRef"]["resource"]])

        # Steps:
        # create/RequestReceived to *kubectl-client-side-apply* (do nothing)
        # create/ResponseComplete to *kubectl-client-side-apply*
        # create/RequestReceived to /binding (do nothing)
        # create/ResponseComplete to /binding
        # delete/RequestReceived
        # delete/ResponseComplete

        if verb == "create" and stage == "ResponseComplete" and "kubectl-client-side-apply" in uri:
            if key in handled:
                log.warning(f"Alert: {key} was already scheduled! (previous status: {handled[key]['status']})")
            handled[key] = {}
            handled[key]["status"] = 0b001
            handled[key]["image"] = js["responseObject"]["spec"]["containers"][0]["image"]
            handled[key]["targetNode"] = None
            log.info(f"New pod detected! {key} with image {handled[key]['image']}")
        else: # Non-initialization
            if key not in handled:
                log.info(f"Ignoring: {key} was not scheduled! (previous status: None), status: verb={verb}, stage={stage}, uri={uri}") #, json={js}")
                continue
            if verb == "create" and stage == "ResponseComplete":
                if handled[key]["status"] != 0b001:
                    log.warning(f"Alert: {key} out of order (previous status: {handled[key]['status']})")
                handled[key]["status"] = 0b011
                handled[key]["targetNode"] = js['requestObject']['target']['name']
                log.info(f"Binding pod {key} response complete, target node: {handled[key]['targetNode']}")
            elif verb == "delete" and stage == "RequestReceived":
                if handled[key]["status"] != 0b011:
                    log.warning(f"Alert: {key} out of order (previous status: {handled[key]['status']})")
                # *siren noises*
                log.info(f"Sending alert to {handled[key]['targetNode']} with image {handled[key]['image']}")
                try:
                    time.sleep(2)
                    requests.post(f"http://{handled[key]['targetNode']}:{args.target_port}/alert", json={
                        "image": handled[key]["image"]
                    })
                except requests.exceptions.ConnectionError:
                    log.error(f"Could not connect to {handled[key]['targetNode']}, is the node down?")
                handled[key]["status"] = 0b111
            elif verb == "delete" and stage == "ResponseComplete":
                if handled[key]["status"] != 0b111:
                    log.warning(f"Alert: {key} out of order (previous status: {handled[key]['status']})")
                log.info(f"Node {handled[key]['targetNode']} acknowledged alert, detected pod {key} deletion")
                del handled[key]
            else:
                continue
                # log.warning(f"Alert: {key} out of order (previous status: {handled[key]['status']})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--auditfile", help="File to follow", required=True)
    parser.add_argument("-t", "--test", help="Test mode", action="store_true")
    parser.add_argument("-i", "--interactive-test", help="Interactive test mode", action="store_true")
    parser.add_argument("-p", "--target-port", help="Target port of nodes", default=8080)
    args = parser.parse_args()

    if not os.path.exists(args.auditfile):
        print("File does not exist, exiting")
        sys.exit(1)

    main(args)