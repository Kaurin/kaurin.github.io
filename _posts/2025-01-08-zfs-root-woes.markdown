---
layout: single
title:  "ZFS Root woes"
date:   2025-01-08 18:00:00
categories: zfs
tags: ["zfs", "troubleshooting", "grub", "zfsbootmenu"]
---

Documenting an issue with my machine/Fedora installation which uses ZFS Boot to boot from a ZFS root.

# Disclaimer

**These are very destructive procedures. I bare no responsibility for any damages done to your system.**

# The issue

My relatively new system based on AMD Ryzen 7 8700G w/ Radeon 780M Graphics is experiencing random shutdowns where 2 out of 3 NVME drives don't show up in BIOS unless I fully shut down and start-up the machine.

Often times the boot partition which contains the ZFS Boot menu will get corrupted requiring me to re-download the ZFS Boot Menu bootloader.

Other times the data will get corrupted on one of the ZFS disks, but that's not at issue here because I can simply scrub the ZFS pool for errors.

# The repair process

1. Boot into the the current version of the bootable Fedora medium.
2. Consult the [ZBM Fedora Install section]. Note: We will be using a shortened and slightly different procedure. No need for chroot, etc.
3. Verify which first partition of the three NVME devices contains the EFI filesystem and structure (For example, the EFI dir on a vfat filesystem).
4. Mount the discovered EFI partition
5. Download the latest `VMLINUZ.EFI` bootloader and backup entry bootloader
6. Finally set the env vars and run the `efibootmgr` (see below)

The whole procedure looks like this:
```bash
mount /dev/nvme0n1p1 /mnt

curl -o /mnt/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
cp /mnt/EFI/ZBM/VMLINUZ.EFI /mnt/EFI/ZBM/VMLINUZ-BACKUP.EFI

export BOOT_DISK="/dev/nvme0n1"
export BOOT_PART="1"

efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
  -L "ZFSBootMenu (Backup)" \
  -l '\EFI\ZBM\VMLINUZ-BACKUP.EFI'

efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
  -L "ZFSBootMenu" \
  -l '\EFI\ZBM\VMLINUZ.EFI'
```

# Root cause

Not yet sure. I need to set up centralized logging in the hopes of catching whatever might be the issue, but right now it looks like a hardware (motherboard? PSU?) issue.

[ZBM Fedora Install section]: https://zfsbootmenu.org/en/latest/guides/fedora/uefi.html#install-zfsbootmenu

