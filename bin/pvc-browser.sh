#!/bin/bash

if [[ $# eq 2 ]]; then

cat << EOF | kubectl create -n $1 -f -
kind: Pod
apiVersion: v1
metadata:
  name: pvc-browser
spec:
  volumes:
    - name: $1
      persistentVolumeClaim:
       claimName: $1
    - name: media
      persistentVolumeClaim:
        claimName: cephfs-media-claim
  containers:
    - name: pvc-browser
      args:
      - bash
      stdin: true
      tty: true
      image: ubuntu
      volumeMounts:
      - name: $1
        mountPath: "/data"
      - name: media
        mountPath: /media
        subPath: data/
EOF

else
  echo "Usage: pvc-browser.sh <namespace> <pvc>"
  exit 1
fi
