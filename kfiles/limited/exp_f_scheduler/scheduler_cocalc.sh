kubectl run -n limited --image sagemathinc/cocalc:latest cocalc1
sleep 1
# kubectl -n limited delete pod cocalc  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:fcddf25ba2aa cocalc2
sleep 1
# kubectl -n limited delete pod cocalc2  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:be98b03ccae8 cocalc3
sleep 1
# kubectl -n limited delete pod cocalc3  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:1c72407fd0f7 cocalc4
sleep 1
# kubectl -n limited delete pod cocalc4  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:3584f1c4a33e cocalc5
sleep 1
# kubectl -n limited delete pod cocalc  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:f87de25341d5 cocalc6
sleep 1
# kubectl -n limited delete pod cocalc2  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:211628f4f0a0 cocalc7
sleep 1
# kubectl -n limited delete pod cocalc3  --force --grace-period=0

kubectl run -n limited --image sagemathinc/cocalc:b5c7e0c25cca cocalc8
sleep 1
# kubectl -n limited delete pod cocalc4  --force --grace-period=0
