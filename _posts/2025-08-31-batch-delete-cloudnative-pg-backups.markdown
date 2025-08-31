---
layout: single
title:  "Batch delete CloudNativePG backups"
date:   2025-08-31 01:50:00
categories: kubernetes
tags: ["bash", "cloudnative-pg"]
---

This script is very destructive. Do not run unless you fully accept the risk.


# Problem statement

I completely forgot that my snapshot-based CloudNativePG backups were piling up. To get rid of them I needed a script which I can run periodically to clean things up.

# The script

```bash
#!/usr/bin/env bash
for namespace in $(kubectl get namespaces); do
  timespec="$(date -d '60 days ago' -Ins --utc | sed 's/+0000/Z/')"
  kubectl  get backup -n "$namespace" -o go-template \
    --template '{{range .items}}{{.metadata.name}} {{.metadata.creationTimestamp}}{{"\n"}}{{end}}' \
    | awk '$2 <= "'$timespec'" { print $1 }' \
    | xargs -I{} kubectl delete -n "$namespace" backup/{}
done
```

# Notes: 

At the time of writing this, retention policy for CloudNativePG backups are [not implemented][CloudNativePG backups] for Volume-Snapshot-based backups.

[CloudNativePG backups]: https://cloudnative-pg.io/documentation/current/backup/
