---
layout: single
title:  "Installing Arch on a 2015 MacBookPro"
date:   2024-05-05 15:00:00
categories: linux
tags: ["linux", "arch-linux", "apple", "macbook", "macbookpro"]
---

These are my notes on what I did to get Arch running on a MacBookPro 11,5 (Mid-2015)

My setup has no swap, EFI boot, encrypted root (single partition)

# Disclaimer

**These are very destructive procedures. I bare no responsibility for any damages done to your system.**

# Boot into the arch install USB

## Live System Wifi

It is worth mentioning that I first connected to my wifi network using the `iwctl` utility. 
I actually didn't make note of the commands there, but from memory I think they were:

```
station wlan0 connect MY_WIFI_SSID
station wlan0 show
```

## Prep root password and SSH

My next step is to set a root password, enable root login in the sshd config, and start the sshd service.

Note: This unsafe SSH setup is for the live system only and does not propagate to the installed system.

## Log in remotely and start setting up the system

I like to do this because all my notes are on a working, stable system. When I inevitably have to iterate, using remote access proves to be super useful.

First, let's wipe our disk (you've been warned by the disclaimer!)

```bash
wipefs -a /dev/sda
```

Set up partitions

```bash
parted /dev/sda mklabel gpt
parted /dev/sda mkpart boot fat32 0% 1GB
parted /dev/sda set 1 esp on
parted /dev/sda mkpart luks 1GB 100%
```

Set up encryption

```bash
cryptsetup -y -v luksFormat /dev/sda2
cryptsetup open /dev/sda2 root
```

Optional: Fill up the disk space (takes a long time)

```bash
dd if=/dev/urandom of=/dev/mapper/root bs=1M
```

Create rootFS and mount

```bash
mkfs.xfs /dev/mapper/root
mount /dev/mapper/root /mnt
```


Set up the EFI partition

```bash
mkfs.fat -F32 /dev/sda1
mount --mkdir /dev/sda1 /mnt/boot
```

Basic bootstrap & fstab & chroot

```bash
pacstrap -K /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

Can't live without vim

```bash
pacman -Syu --noconfirm vim
```

Timezone, timesync

```bash
ln -sf /usr/share/zoneinfo/Europe/Dublin /etc/localtime
hwclock --systohc
```

Locale

```bash
localectl set-locale LANG=en_US.UTF-8
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

# These two commands are just for the current session. May not be needed
unset LANG
source /etc/profile.d/locale.sh
```

Hostname

```bash
echo myhostname > /etc/hostname
```

initramfs modifications in `/etc/mkinitcpio.conf`
We want the amdgpu driver to have precedence over radeon

```
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
MODULES=(amdgpu radeon)
```

Ensure we are using the amdgpu with the appropriate family support

```bash
echo "options amdgpu si_support=1" > /etc/modprobe.d/amdgpu.conf
echo "options radeon si_support=0" > /etc/modprobe.d/radeon.conf
```

Install xfsprogs before we re-bake initramfs

```bash
pacman -Syu --noconfirm xfsprogs
mkinitcpio -P
```

Gnome & friends

```bash
pacman -Syu --noconfirm mesa libva-mesa-driver mesa-vdpau vulkan-radeon vulkan-intel
pacman -Syu --noconfirm gnome gnome-extra
```

Enable gdm

```bash
systemctl enable gdm
```

More software...

```bash
pacman -Syu --noconfirm less rsync firefox htop i2c-tools lm_sensors aspell hunspell hunspell-en_us hunspell-en_gb wget
```

Devel and AUR software

```bash
pacman -S --needed base-devel git
```

Audio software

```bash
pacman -Syu --noconfirm sudo networkmanager
pacman -Syu --noconfirm pipewire wireplumber alsa-utils 
```

Enable networkmanager and sshd

```bash
systemctl enable NetworkManager
systemctl enable sshd
```

Enable gnome power control panel options

```bash
pacman -Syu power-profiles-daemon
systemctl enable power-profiles-daemon
```

Add my user

```bash
useradd -m myusername
passwd myusername
usermod -aG wheel myusername
```

Root password

```bash
passwd
```

Install and setup refind (needed for osx spoofing)

```bash
pacman -Syu --noconfirm refind
refind-install
```

Edit `/boot/efi/EFI/refind/refind.conf`

```
spoof_osx_version 10.11
```

List our encrypted root block device ID

```bash
ls -l /dev/disk/by-uuid/ | grep sda2
# lrwxrwxrwx 1 root root 10 May  5 15:01 EXAMPLE_UUID -> ../../sda2
```

Edit `/boot/refind_linux.conf`. Find "Boot with Standard options" (first entry). Add the following kernel options

Make sure to use the correct UUID as per what we got above. The `brcmfmac.feature_disable=0x82000` stanza hais from [this solution](https://bbs.archlinux.org/viewtopic.php?pid=2195130#p2195130). WiFi is currently broken without this stanza.

```
"Boot with standard options"  "amdgpu.aspm=0 acpi_osi=Darwin acpi_backlight=native radeon.si_support=0 amdgpu.si_support=1 cryptdevice=UUID=EXAMPLE_UUID:root root=/dev/mapper/root rw add_efi_memmap intel_iommu=on iommu=pt brcmfmac.feature_disable=0x82000"
```

Disable suspend. We do this because currently there is a, what looks like, a kernel bug that crashes amdgpu on S3 suspend.

```bash
mkdir /etc/systemd/sleep.conf.d
vim /etc/systemd/sleep.conf.d/disable-suspend.conf
```

```ini
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
```


# Finally...

```bash
exit
umount -R /mnt
reboot
```


# References

## General Arch installation references

* https://wiki.archlinux.org/title/Installation_guide
* https://wiki.archlinux.org/title/Arch_boot_process#Boot_loader
* https://wiki.archlinux.org/title/REFInd
* https://www.rodsbooks.com/refind/linux.html#easiest
* https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition
* https://wiki.archlinux.org/title/MacBookPro11,x


## Arch sound references

* https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture
* https://wiki.archlinux.org/title/PipeWire
* https://wiki.archlinux.org/title/WirePlumber


## Power management references

* https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate


## Graphics references

* https://wiki.archlinux.org/title/AMDGPU
* https://wiki.archlinux.org/title/Intel_graphics
* [Radeon M370X quirk](https://bbs.archlinux.org/viewtopic.php?id=288355)
* [MBP 11,5 suspend hang on arch forums](https://bbs.archlinux.org/viewtopic.php?id=199388)
* [MBP 11,5 suspend hang on gentoo forums](https://forums.gentoo.org/viewtopic-p-7772846.html?sid=7ab6dd35c3dfc7a38a2c1b02edb15044)
* [Possible related MBP suspend hang bug on freedesktop gitlab](https://gitlab.freedesktop.org/drm/amd/-/issues/2711)
