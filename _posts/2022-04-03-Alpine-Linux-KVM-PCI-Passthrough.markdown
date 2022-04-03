---
layout: post
title:  "Alpine Linux KVM PCI Passthrough"
date:   2022-04-03 18:00:00
categories: virtualization
tags: kvm,linux,libvirt,alpine-linux
---

# Disclaimer

I'm by no means an expert on the topics of VFIO/IOMMU/PCI passthrough in Linux. I found the [fenguoerbian's blog post][fenguoerbian's article] half way through documenting my steps, and I'd encourage you to go read it because it covers more use cases and is just more comprehensive.

Other good reads:
* [Alpine Linux KVM Wiki][Alpine Linux KVM Wiki]
* [Arch Linux PCI Passthrough Wiki][Arch Linux PCI Passthrough Wiki]
* [Fedora PCI Passthrough Article][Fedora PCI Passthrough Article] (old, but good)

# Intended audience

Me, really. Writing this mostly as a document on what I did to get where I am. Having this written down in Ansible or similar IaC won't retell the whole story of tools and articles used to figure out what needs to be done.


# Goal

Have Alpine Linux be the libvirt host on a bare metal x86_64 . Have some PCI (USB) devices availble to be passed through to guests by using early VFIO binding.


# Assumptions

Guide assumes that your (my) target system has vt-d or AMD's equivalent supported and enabled in BIOS. Intel-based system is used here, so your kernel parameters and module options might differ for AMD.

# Alpine Linux installation

Options during setup:

* Crypto/sys
* br0 for network. It's great that setup lets you set up a bridge without configuration because i'll need it for libvirt. 

# Network

I run a DHCP server where I manage any static entries, so aside from choosing `br0` at install time, only router config needs to be modified.

# Packages 

The only thing that needs explanation is the `libvirt-guests` package which makes the host gracefully shut down guests before shutting itself off.

```bash
apk add libvirt-daemon qemu-img qemu-system-x86_64 qemu-modules openrc vim pciutils usbutils wget
rc-update add libvirtd
rc-update add libvirt-guests
```

# KVM

Comfort of running the `virt-manager` remotely costs us having to install `dbus`, `polkit` and some other dependancies, so I opted to have a leaner system that I'll manage with `virsh` when I SSH in.

So. Ensure the tun driver loads on boot:

```bash
cat /etc/modules | grep tun || echo tun >> /etc/modules
```



# VFIO / PCI Passthrough

## Initial steps

For this section, it's best to first read up on the [Arch Linux Wiki][Arch Linux PCI Passthrough Wiki] on how PCI devices relate to IOMMU groups.

First, lets ensure IOMMU is enabled at boot. In `/etc/update-extlinux.conf`, add `intel_iommu=on` and `iommu=pt` to `default_kernel_opts`. For example:

```bash
cat /etc/update-extlinux.conf
default_kernel_opts="quiet rootfstype=ext4 intel_iommu=on iommu=pt"
```

Run

```bash
update-extlinux
```

REBOOT! After the reboot, let's figure out what PCI devices we want to passthrough. In my case, I needed to pass through a few USB devices from the host.

## PCI devices detective work

This one is fairly easy. Just use `lspci` and make a note of the device(s) you are interested in.

It is often the case that we have to isolate more than just the device we want because they share an IOMMU group. More on that later.

## USB devices detective work

This is where it gets tricky. USB devices (to my knowledge) are always a "child" of a PCI device. We need to figure out the PCI->USB relation before we proceed.

First step:
```shell
dmesg | grep 'usb \d-\d' | grep Product:
```

Find entries of devices you want to isolate from the host. In my case:

```
[    2.399790] usb 3-1: Product: C-Media USB Headphone Set 
[    3.435788] usb 3-2: Product: Sonoff Zigbee 3.0 USB Dongle Plus
[    4.353124] usb 4-2: Product: USB Audio CODEC
```

Now use fenguoerbian's fantastic script:

```bash
 for usb_ctrl in $(find /sys/bus/usb/devices/usb* -maxdepth 0 -type l); do pci_path="$(dirname "$(realpath "${usb_ctrl}")")"; echo "Bus $(cat "${usb_ctrl}/busnum") --> $(basename $pci_path) (IOMMU group $(basename $(realpath $pci_path/iommu_group)))"; lsusb -s "$(cat "${usb_ctrl}/busnum"):"; echo; done
 ```

...Which will print out this convenient list of IOMMU groups in relation to USB devices. Conveniently, all three of my USB devices are in the same IOMMU group. To be more precise, USB bus 3 and USB bus 4 are in the same IOMMU group:

```
Bus 3 --> 0000:00:1a.0 (IOMMU group 4)
...
Bus 003 Device 001: ID 1d6b:0001
...
Bus 004 Device 001: ID 1d6b:0001
...
Bus 003 Device 002: ID 0d8c:000c
...

Bus 4 --> 0000:00:1a.1 (IOMMU group 4)
...
Bus 003 Device 001: ID 1d6b:0001
...
Bus 004 Device 001: ID 1d6b:0001
...
Bus 003 Device 002: ID 0d8c:000c
...
```

But, if we want to pass through the relevant controllers, we have to isolate all the devices in IOMMU group 4. Let's check out what we have in that whole group:

```bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

Output:
```
...
IOMMU Group 4:
	00:1a.0 USB controller [0c03]: Intel Corporation 82801JD/DO (ICH10 Family) USB UHCI Controller #4 [8086:3a67] (rev 02)
	00:1a.1 USB controller [0c03]: Intel Corporation 82801JD/DO (ICH10 Family) USB UHCI Controller #5 [8086:3a68] (rev 02)
	00:1a.2 USB controller [0c03]: Intel Corporation 82801JD/DO (ICH10 Family) USB UHCI Controller #6 [8086:3a69] (rev 02)
	00:1a.7 USB controller [0c03]: Intel Corporation 82801JD/DO (ICH10 Family) USB2 EHCI Controller #2 [8086:3a6c] (rev 02)
...
```

I do have a whole other set of USB devices I can use on the host, so no problem there.

This concludes USB detective work. Next up we'll be isolating the IOMMU group 4 from the OS, so we can pass down those devices to the guest

# PCI device isolation

## Initramfs

Ensure VFIO kernel drivers are loaded into the initramfs:
```bash
cat <<EOT > /etc/mkinitfs/features.d/vfio.modules
kernel/drivers/vfio/vfio.ko.*
kernel/drivers/vfio/vfio_virqfd.ko.*
kernel/drivers/vfio/vfio_iommu_type1.ko.*
kernel/drivers/vfio/pci/vfio-pci.ko.*
EOT
```

Make sure to run:

```bash
mkinitfs
mkinitfs -l | grep vfio
```

And add all devices from your IOMMU group to the `ids=` param of `vfio-pci`:

```bash
cat <<EOT > /etc/modprobe.d/vfio.conf 
options vfio-pci ids=8086:3a67,8086:3a68,8086:3a69,8086:3a6c
options vfio_iommu_type1 allow_unsafe_interrupts=1
softdep igb pre: vfio-pci
EOT
```

Don't forget to

```bash
mkinitfs
```

And verify that the drivers are in the initfs by running:

```bash
mkinitfs -l | grep vfio
```


## Kernel boot parameters

Having the modules ready is one thing, but we also need to invoke them early. In `/etc/update-extlinux.conf` update `default_kernel_opts` and `modules` sections to something like this:

```bash
grep '^default_kernel_opts\|^modules' /etc/update-extlinux.conf
```

Output:

(you don't necessarily have the crypto stuff, just focus on iommu and vfio-pci here)
```
default_kernel_opts="cryptroot=UUID=eec5190e-eebd-4985-9abc-36a61341e038 cryptdm=root quiet rootfstype=ext4 intel_iommu=on iommu=pt"
modules=sd-mod,usb-storage,ext4,vfio,vfio-pci,vfio_iommu_type1,vfio_virqfd
```

Don't forget to run:

```bash
update-extlinux
```

## Reboot and verify

Reboot. Let's check if we're in business:

```bash
dmesg | grep vfio
```

And you should see something like:

```
[    1.163469] vfio_pci: add [8086:3a67[ffffffff:ffffffff]] class 0x000000/00000000
[    1.163515] vfio_pci: add [8086:3a68[ffffffff:ffffffff]] class 0x000000/00000000
[    1.163543] vfio_pci: add [8086:3a69[ffffffff:ffffffff]] class 0x000000/00000000
[    1.179966] vfio_pci: add [8086:3a6c[ffffffff:ffffffff]] class 0x000000/00000000
```

# Time to spin up a virtual machine with passed through devices!

## Download image

In my case:

```bash
wget https://github.com/home-assistant/operating-system/releases/download/7.5/haos_ova-7.5.qcow2.xz -O - | xzcat > home-assistant.qcow2
```

## Create storage pool

Maybe don't use the name "default" as it might already exist, but:

```bash
virsh pool-define-as default dir - - - - "/var/lib/libvirt/images"
```

## Copy your image into the above dir

```bash
mv home-assistant.qcow2 /var/lib/libvirt/images/
```

## Start the virt

```bash
virt-install \
    --name "homeassistant" \
    --vcpus 2 \
    --cpu host \
    --memory 4096 \
    --sysinfo host \
    --import \
    --boot uefi \
    --os-variant=alpinelinux3.14 \
    --disk vol=default/home-assistant.qcow2,bus=virtio \
    --network bridge=br0,mac=52:54:00:C4:2D:4A \
    --graphics none \
    --video none \
    --sound none \
    --input none \
    --memballoon none \
    --hostdev pci_0000_00_1a_0 \
    --hostdev pci_0000_00_1a_1
```


Et voilà!


[fenguoerbian's article]: https://fenguoerbian.github.io/post/device-passthrough-in-kvm/
[Alpine Linux KVM Wiki]: https://wiki.alpinelinux.org/wiki/KVM
[Arch Linux PCI Passthrough Wiki]: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
[Fedora PCI Passthrough Article]: https://docs.fedoraproject.org/en-US/Fedora/13/html/Virtualization_Guide/chap-Virtualization-PCI_passthrough.html