---
layout: single
title:  "Mounting libvirt block devices with losetup"
date:   2024-05-02 17:00:00
categories: virtualization
tags: ["kvm", "libvirt", "lvm", "losetup"]
---

How to perform disk surgery on a "cold" libvirt volume.

# Disclaimer

**These are very destructive procedures. I bare no responsibility for any damages done to your system.**

# Problem

Sometimes we are very smart and provision our virtual machine using a cloud image and "nocloud" metadata to provision a passwordless system that only allows key-based SSH access.

Sometimes we are not so smart and destroy our network access to the machine which propagates on reboot. Because we have a passwordless virt, using `virsh console` won't save us.

In my case, disabling a systemd service was all that was needed for the fix. This can be done on a "cold" OS disk by symlinking the service to `/dev/null` - so, disk surgery.

This particular VM was a Fedora 39 based on the cloud image, which has 5 partitions out of the box - and the target device on the virt host was a LVM volume. This guide should work for any block storage volume aside from LVM, but I haven't tested it.

# Procedure

Before you get started, check whether you are using the `/dev/loop0` device for anything else. You should also be able to use any of the available `/dev/loopX` devices in your system (not tested).

```bash
# Status
losetup -a

# Setup loop dev
losetup -P /dev/loop0 /dev/mapper/libvirt_lvm-samba

# Check status again (we should now see output)
losetup -a

# See partitions
lsblk | grep loop0

# Mount desired partition
mount /dev/loop0p5 /mnt

# Do some work on your mountpoint

# Umount 
umount /mnt

# undefine loop dev
losetup -d /dev/loop0

# Check if no output shown
losetup -a
```