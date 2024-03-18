---
layout: single
title:  "Fedora ZFS raidz1 Encrypted Root and ZFSBootMenu"
date:   2024-02-25 17:42:00
categories: linux
tags: ["linux","fedora","zfs","zfsbootmenu"]
---

ZFS raidz across multiple storage devices which are also the boot device in Fedora using ZFSBootMenu

# Use-case

I want my linux home server to have an encrypted ZFS rootFS with raidz1. In my quest to realize my use-case, I found ZFSBootManager which has guides for major linux operating systems, including Fedora Workstation.

I decided to go with the  [ZFSBootMenu Fedora Workstation guide][1] rather than try to hack something on my own.

# Problem

The [ZFSBootMenu Fedora Workstation guide][1] covers the use-case with one block storage device without zraid1.

# Solution

Luckily, most of it is still valid. These are the changes I had to make for my system.

**NOTE: The [guide][1] still needs to be followed, just substitute the relevant sections**

```shell
export BOOT_DISK="/dev/nvme0n1"
export BOOT_PART="1"
export BOOT_DEVICE="${BOOT_DISK}p${BOOT_PART}"
export POOL_PART="2"


zpool labelclear -f /dev/nvme0n1p2
zpool labelclear -f /dev/nvme1n1p2
zpool labelclear -f /dev/nvme2n1p2

wipefs -a "$BOOT_DISK"
wipefs -a /dev/nvme0n1
wipefs -a /dev/nvme1n1
wipefs -a /dev/nvme2n1

sgdisk --zap-all /dev/nvme0n1
sgdisk --zap-all /dev/nvme1n1
sgdisk --zap-all /dev/nvme2n1
sgdisk --zap-all "$BOOT_DISK"

sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "/dev/nvme0n1"
sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "/dev/nvme1n1"
sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "/dev/nvme2n1"

sgdisk -n "${POOL_PART}:0:-10m" -t "2:bf00" "/dev/nvme0n1"
sgdisk -n "${POOL_PART}:0:-10m" -t "2:bf00" "/dev/nvme1n1"
sgdisk -n "${POOL_PART}:0:-10m" -t "2:bf00" "/dev/nvme2n1"

zpool create -f -o ashift=9 \
 -O compression=lz4 \
 -O acltype=posixacl \
 -O xattr=sa \
 -O relatime=on \
 -O encryption=aes-256-gcm \
 -O keylocation=file:///etc/zfs/zroot.key \
 -O keyformat=passphrase \
 -o autotrim=on \
 -m none \
 zroot raidz1 /dev/nvme1n1p2 /dev/nvme0n1p2 /dev/nvme2n1p2
```


[1]: https://docs.zfsbootmenu.org/en/latest/guides/fedora/uefi.html "ZFSBootMenu Fedora Workstation Guide"
