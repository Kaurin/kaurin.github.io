---
layout: post
title:  "Fedora Cloud DHCP Client hostname on-boot"
date:   2024-01-31 21:09:00
categories: virtualization
tags: linux,fedora-cloud,cloud-init
---

# Use-case

Testing Fedora cloud image on KVM while using NoCloud cloud-init. I like to have my "trusted" home devices (and virts) publish their hostname via their DHCP client request towards my router.

My router has a [script][Mikrotik Static DNS via each DHCP lease] that generates static DNS entries based on the hostname value of a client's DHCP request.

# Problem

I've noticed that a few "cloud" images that I've been trying out don't usually propagate the "hostname" value from the meta-data of NoCloud to the DHCP settings.

So far, Alpine which uses dhclient via openRC and Fedora-cloud which uses systemd + NetworkManager for its DHCP client.

I guess this is the standard. More stealthy this way, but I don't need this stealth.

# Solution (Fedora-Cloud)

Notice the runcmd. This is the current naming scheme for Fedora-cloud in 2024/01

```yaml
#cloud-config

packages:
  - sudo

users:
  - name: myuser
    primary_group: myuser
    ssh_authorized_keys:
      - ssh-rsa YOUR_PUBKEY comment
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: wheel
    shell: /bin/bash

runcmd:
  - 'nmcli con modify "cloud-init eth0" ipv4.dhcp-hostname myhostname'

```


[Mikrotik Static DNS via each DHCP lease]: https://wiki.mikrotik.com/wiki/Setting_static_DNS_record_for_each_DHCP_lease
