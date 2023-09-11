#  | tee $LOG_FILE \
#     | jq -rc "select(.process_kprobe!=null) | .process_kprobe" \
#     | grep --color=never --line-buffered ingest \
#     | jq -rc '[ .process.tid, .args[1].string_arg ] | @csv' > $TMP_FILE &
# tail --follow=name $TMP_FILE \
#     | while read -r line; do
#     echo "Log line received: $line"
#     tid=$(echo "$line" | cut -f 1 -d ,)
#     hash=$(echo "$line" | cut -f 2 -d , | tr -d '"' | rev | cut -f 1 -d / | rev)
#     cat $LOG_FILE \
#         | jq -rc "select(.process_kprobe!=null and
# .process_kprobe.process.tid==$tid and .process_kprobe.function_name==\"tcp_connect\")
# | .process_kprobe.args[0].sock_arg | [ $tid, \"\", .sport, .saddr, .dport, .daddr, \"$hash\" ] | @csv"
# done

import json
from common import follow

file = "/tmp/iruel.tmp"
lines = follow(file)
innerfile = open(file, "r")
seek_pos = 0
open("/tmp/iruel.log", "w").close()

# print("tid", "hash")
for line in lines:
    if "ingest" not in line:
        continue
    obj = json.loads(line)
    if "process_kprobe" not in obj:
        continue
    if "mkdirat" not in obj['process_kprobe']['function_name']:
        continue
    try:
        __tid = obj['process_kprobe']['process']['tid']
        __hash = obj['process_kprobe']['args'][1]['string_arg']
    except Exception as err:
        continue
    # open contents of file "$__hash/ref"
    try:
        with open(__hash + "/ref", "r") as ref:
            layer = ref.read().strip()
            layer = layer.split(":")[1]
            # print(f"hash={__hash}, layer={layer}")
    except FileNotFoundError as err:
        continue

    # print("__hash: ", __hash, " from __tid: ", __tid)
    # Keep reading innerfile until last position before eof
    innerfile.seek(seek_pos)
    for innerline in innerfile:
        seek_pos += 1
        if str(__tid) not in innerline:
            continue
        try:
            innerobj = json.loads(innerline)
            if (
                "process_kprobe" in innerobj
                and innerobj["process_kprobe"]["process"]["tid"] == __tid
                and innerobj["process_kprobe"]["function_name"] == "tcp_connect"
            ):
                arg = innerobj["process_kprobe"]["args"][0]["sock_arg"]
                stuff = [
                    __tid, "", arg["sport"], arg["saddr"],
                    arg["dport"], arg["daddr"], layer
                ]
                print(",".join([str(i) for i in stuff]), flush=True, file=open("/tmp/iruel.log", "a+"))
                # print(stuff)
        except Exception as err:
            continue
