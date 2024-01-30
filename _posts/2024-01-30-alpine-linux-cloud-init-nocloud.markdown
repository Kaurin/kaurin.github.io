---
layout: post
title:  "Alpine Linux cloud-init (nocloud)"
date:   2024-01-30 17:45:00
categories: virtualization
tags: linux,alpine-linux,cloud-init
---

I was playing around with [Alpine Linux cloud images][Alpine Linux cloud images]. Apparently, cloud-init in alpine-linux creates locked user accounts by default.

To get around this, I am using the `*` password hash (not sure if needed) which should not match any password. 

In addition to this, I also have to unlock the account with `runcmd` which happens *after* the user is created. This is different to `bootcmd` which happens earlier.

It is worth noting that neither of these two hacks are needed in Fedora cloud images.


```yaml
#cloud-config

packages:
  - sudo

users:
  - name: myuser
    passwd: "*"
    primary_group: myuser
    ssh_authorized_keys:
      - ssh-rsa YOPUR_SSH_PUBLIC_KEY keycomment
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: wheel
    shell: /bin/ash

runcmd:
  - passwd -u myuser
```


[Alpine Linux cloud images]: https://www.alpinelinux.org/cloud/
