---
layout: single
title:  "Windows EFI Boot Surgery"
date:   2024-03-17 17:00:00
categories: windows
tags: ["windows","uefi","boot","efi","multiboot"]
---

How to create an EFI partition on a fully utilized Windows Drive

# Disclaimer

**These are very destructive procedures. I bare no responsibility for any damages done to your system.**

Windows and Linux knowledge is required. This guide is tailored for my system. Your mileage may vary.

# Problem

After wiping my Fedora disk and re-installing Fedora from scratch I no longer had my UEFI Windows boot entry available in the BIOS.

This means that I previously only had one EFI partition on that Linux storage device and that Windows piggy backed onto it.

Now that the Fedora is reinstalled on the freshly wiped disk, I lost the Windows boot entry.


# Disk layout


My system looked like this (lsblk output with comments).

Notice the lack of EFI partition anywhere else except for the Linux storage device.

```
                NAME                                          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS

                sda                                           8:0      1 447.1G  0 disk  
                └─sda1                                        8:1      1 447.1G  0 part 

Linux ssd       sdb                                           8:16     1 223.6G  0 disk  
                ├─sdb1                                        8:17     1   600M  0 part  /boot/efi
                ├─sdb2                                        8:18     1     1G  0 part  /boot
                └─sdb3                                        8:19     1   222G  0 part  
                └─luks-REDACTED                               253:0    0   222G  0 crypt /home
                                                                                         /

                zram0                                         252:0    0     8G  0 disk  [SWAP]
                nvme0n1                                       259:0    0 931.5G  0 disk  
                ├─nvme0n1p1                                   259:1    0    16M  0 part  
                └─nvme0n1p2                                   259:2    0 931.5G  0 part  

Windows nvme    nvme2n1                                       259:3    0 465.8G  0 disk  
                ├─nvme2n1p1                                   259:4    0    16M  0 part  
                └─nvme2n1p2                                   259:5    0 465.8G  0 part  

                nvme1n1                                       259:7    0   3.6T  0 disk  
                ├─nvme1n1p1                                   259:8    0    16M  0 part  
                └─nvme1n1p2                                   259:9    0   3.6T  0 part 
```

# Options

I guess I can go back and learn how to put the Windows EFI boot option onto the existing linux-ssd EFI partition, but seeing that the Windows installer did this before, and it caused grief, I opted for the following:

**Resize the Windows partition and create an EFI partition on the Windows disk for redundancy**


# Execute the fix

1. Download the Windows ISO
1. Write the ISO to the usb Flash `dd if=/home/username/Downloads/Win11_23H2_English_x64v2.iso of=/dev/sdc bs=4M`
1. Boot into the Windows-install USB flash using UEFI
1. When greeted with the Windows Installer language select window, press `Shift+F10` to get the command prompt
1. Use `diskpart` and do the following in the `diskpart` command prompt:
  1. Unassign the current `C:` drive: `remove letter=C`
  1. command `list disk` to identify the Windows disk and partition. In my case it was `Disk 2` and `Partition 2`.
  1. `select disk 2`
  1. `select part 2`
  1. `assign letter=C`
  1. Temporarily drop out of `diskpart` by running `exit` and check whether the `C` drive contains the correct partition.
  1. Back into `diskpart` : `select disk 2`, `select part 2`
  1. `shrink desired=500 minimum=500`
  1. `create partition efi`
  1. Probably redundant after partition creation, but does not hurt: `select part 3`
  1. `format fs=fat32 quick`
  1. `assign letter=y`
  1. `exit`
1. Run `bcdboot C:\windows /s Y:`
1. Reboot and optionally set your UEFI entry boot priority in your UEFI BIOS.


# References

* [How to Create UEFI Partition in Windows 10][1]
* [Microsoft Learn - diskpart][2]



[1]: https://www.diskpart.com/windows-10/create-uefi-partition-windows-10-0725.html
[2]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskpart
