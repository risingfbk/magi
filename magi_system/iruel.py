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

# print("tid", "hash")
for line in lines:
    if "ingest" not in line:
        continue
    obj = json.loads(line)
    if "process_kprobe" not in obj:
        continue
    if "mkdirat" not in obj['process_kprobe']['function_name']:
        continue
    __tid = obj['process_kprobe']['process']['tid']
    __hash = obj['process_kprobe']['args'][1]['string_arg']
    __hash = __hash.split("/")[-1]
    # print("__hash: ", __hash, " from __tid: ", __tid)
    with open(file, "r") as innerfile:
        for innerline in innerfile:
            innerobj = json.loads(innerline)
            if (
                "process_kprobe" in innerobj
                and innerobj["process_kprobe"]["process"]["tid"] == __tid
                and innerobj["process_kprobe"]["function_name"] == "tcp_connect"
            ):
                arg = innerobj["process_kprobe"]["args"][0]["sock_arg"]
                stuff = [
                    __tid,
                    "",
                    arg["sport"],
                    arg["saddr"],
                    arg["dport"],
                    arg["daddr"],
                    __hash
                ]
                # print(stuff)
                print(",".join([str(i) for i in stuff]))
