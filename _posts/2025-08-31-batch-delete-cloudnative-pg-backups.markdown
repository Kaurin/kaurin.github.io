---
layout: single
title:  "Batch delete CloudNativePG backups"
date:   2025-08-31 00:50:00
last_modified_at: 2026-05-02T23:52:00+01:00
categories: kubernetes
tags: ["bash", "cloudnative-pg"]
---

This script is very destructive. Do not run unless you fully accept the risk.


# Problem statement

I completely forgot that my snapshot-based CloudNativePG backups were piling up. To get rid of them I needed a script which I can run periodically to clean things up.

Public apology: The initially published script was copy/pasta from the initial AI output instead of the manually completed script. Apologies to those who wasted their time using a defunct piece of code.

# The (new) script

Generated with AI but tested and hosted here:

<https://github.com/Kaurin/cnpg-backups-cleanup>

# Notes: 

At the time of writing this, retention policy for CloudNativePG backups are [not implemented][CloudNativePG backups] for Volume-Snapshot-based backups.

[CloudNativePG backups]: https://cloudnative-pg.io/documentation/current/backup/
