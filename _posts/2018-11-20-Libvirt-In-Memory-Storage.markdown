---
layout: post
title:  "Libvirt In-Memory Storage"
date:   2018-11-20 05:00:00
categories: virtualization
tags: kvm,libvirt,in-memory,brd,tmpfs,ramdisk
---

# Use case

I wanted to test out my Ansible setup that provisions some of the hosts I own, including my workstation. I'm currently switching from Fedora 28 to 29. Even though upgrades have been going without a hitch for me since Fedora 25, I want to do a hard reset and test my Ansible setup against a fresh Fedora 29.

I have an UEFI system, gpt partition table on my SSD, and am using an encrypted XFS root partition which is the bulk of the drive. All of this is easily emulated with KVM/libvirt.

# Options

Because my linux workstation has 32GB of ram, I wanted to see what my options are when dealing with in-memory storage. To my knowledge, I have two options when it comes to libvirt and in-memory storage:

1. tmpfs via [Directory Pool][libvirt Directory Pool]
2. brd kernel module AKA ramdisk via [Disk Pool][libvirt Disk Pool]

`tmpfs` is a more modern approach to in-memory storage on Linux, but it does't use a ram-kept block device that can be used outside of tmpfs (to my knowledge)

`brd` kernel module allows for providing parameters to control how many `/dev/ram*` devices we have, and what their sizes are.

# brd

## Setup

* Set up about ~17.5GB ramdisk to `/dev/ram0`:

    ```
    sudo modprobe brd rd_size=18432000 max_part=1 rd_nr=1
    ```

* Define a "ramblock" storage pool for libvirt:

    ```
    sudo virsh pool-define-as --name ramblock --type disk --source-dev /dev/ram0 --target /dev
    ```

* Build the ramblock storage pool:

    ```
    sudo virsh pool-build ramblock
    ```

* Start the storage pool:

  ```
  sudo virsh pool-start  ramblock
  ```

* Create the volume. The volume name must be `ram0p1`:

    ```
    sudo virsh vol-create-as ramblock ram0p1 18350316k
    ```

* Create your VM and specify that you wish to use `ram0p1` for your storage device (under `ramblock` pool). I used the virt-manager GUI for this.

## Teardown
* Spin down your VM. Remove the storage volume from the VM definition. This won't get rid of the actual volume
* (Optional) To delete the volume with virsh, you need to do:

  ```
  sudo virsh vol-delete ram0p1 --pool ramblock
  ```

  ...unfortunately, this is buggy. If that fails, do:

  ```
  sudo parted /dev/ram0 rm 1
  ```

  If you needed to use parted, give it a few minutes until the volume disappears from the list:

  ```
  sudo virsh vol-list --pool ramblock
  ```

* Destroy (stop) the volume-pool:

  ```
  sudo virsh pool-destroy ramblock
  ```

* Unload the `brd` kernel module (or suffer memory exhaustion!):

  ```
  sudo rmmod brd
  ```

* (Optional) Undefine the volume pool. It's fine to leave it as it won't auto-start unless you made it so:

  ```
  sudo virsh pool-undefine ramblock
  ```

# tmpfs

## Setup
* Create the directory for our qcow2 files, and mount tmpfs:
  ```
  sudo mkdir -p /var/lib/libvirt/ramdisk-storage-pool
  sudo mount -t tmpfs -o size=18000M tmpfs /var/lib/libvirt/ramdisk-storage-pool
  ```

* Define the volume pool:

  ```
  sudo virsh pool-define-as --name ramdisk --type dir --target /var/lib/libvirt/ramdisk-storage-pool
  ```

* Start the storage pool:

  ```
  sudo virsh pool-start ramdisk
  ```

* Create the volume (naming is up to you):

  ```
  sudo virsh vol-create-as ramdisk fedora29 18350316k
  ```

* Create your VM and specify that you wish to use `fedora29` for your storage device (under `ramdisk` pool). I used the virt-manager GUI for this.


## Teardown
* Spin down your VM. Remove the storage volume from the VM definition. This won't get rid of the actual volume
* (Optional) To delete the volume with virsh, you need to do:

  ```
  sudo virsh vol-delete fedora29 --pool ramdisk
  ```

* Destroy (stop) the volume-pool:

  ```
  sudo virsh pool-destroy ramblock
  ```

* Unmount tmpfs  (or suffer memory exhaustion!):

  ```
  sudo umount /var/lib/libvirt/ramdisk-storage-pool
  ```

* (Optional) Undefine the volume pool. It's fine to leave it as it won't auto-start unless you made it so:

  ```
  sudo virsh pool-undefine ramdisk
  ```

# Benchmarking with gnome-disks

I have performed three tests:
* brd with "none" set as device cache in libvirt
* brd with "Hypervisor default" as device cache in libvirt
* tmpfs - Hypervisor default as it doesn't have caching options for qcow2 files

## Test setup:

### Transfer rate
* Benchmarked the encrypted root volume
* Number of samples: 1000
* Sample size: 100MB
* Write benchmark: OFF

### Access Time
* Number of Samples: 10000

## Results

|                   | brd-nocache | brd  | tmpfs | my SSD |
| ----------------- |------------:| ----:| -----:| ------:|
| Latency (msec)    | 0.05        | 0.04 | 0.06  | 0.23   |
| Throughput (GB/s) | 2.9         | 3.1  | 3.5   | 0.416  |


# Unscientific Conclusion

To my surprise, tmpfs perfomed best in terms of throughput, while brd with "hypervisor default" for cache had best latency results.

All in-memory based tests had more consistent read speeds compared to my SSD that would have a much higher variation.

The latency benefit is obvious compared to the SSD.

Cached brd might be the best solution latency-wise for this particular use-case, but I consider tmpfs to be easier to set up.


# Todo
Check whether `ramdisk` FS performs any better than `tmpfs`. I doubt it because it uses `brd` as a backing store, but it's worth checking

[libvirt Directory Pool]: https://libvirt.org/storage.html#StorageBackendDir
[libvirt Disk Pool]: https://libvirt.org/storage.html#StorageBackendDisk
