---
layout: single
title:  "A short Proxmox journey"
date:   2024-05-11 02:30:00
categories: virtualization
tags: ["proxmox", "proxmox ve", "proxmox virtual environment", "kvm", "libvirt", "letsencrypt", "virtualization"]
---

My short journey into Proxmox land. These are just notes for my self reference should I ever need them.


# Disclaimer

**These are very destructive procedures. I bare no responsibility for any damages done to your system.**

# Goal

* Install proxmox. 
* Have it use letsencrypt for the webui HTTPS.
* Familiarize with the product to better understand the current virtualization landscape

# KVM/libvirt Preparation

I will be using libvirt's `virt-manager` to spin up Proxmox.

## Volumes

This [time around][Virtualized TrueNAS with Truechart and Letsencrypt] I will be going with the default storage pool - meaning qcow2 backing image files.

```bash
sudo virsh vol-create-as --pool default --name proxmox-os --capacity 20G
sudo virsh vol-create-as --pool default --name proxmox-data-1 --capacity 200G
sudo virsh vol-create-as --pool default --name proxmox-data-2 --capacity 200G
sudo virsh vol-create-as --pool default --name proxmox-data-3 --capacity 200G
```

## Network

Bridge networking is fine here.

My home DNS will forward anything headed for the `*.pm.dood.ie` towards `192.168.0.60`

## First boot

* Graphical Install
* Accept license
* Select the 20GB disk for OS
* Country/Timezone/Keyboard Layout
* Password/Email
* Network
  * Management interface: default
  * Hostname: `proxmox.pm.dood.ie`
  * IP CIDR: 192.168.0.60/24
  * Gateway: 192.168.0.1
  * DNS: 127.0.0.1
* Install

# Admin user

Proxmox has a concept of "Realms", which roughly correspond to authentication mechanisms. The preferred realm is "pve" which is the proxmox propriatery auth system.

There is also the "pam" Realm which corresponds to the system-local auth, but is not provisioned top-down. You can also add more auth mechanisms (realms), but that's outside of the scope of this document.

What do I mean by "not provisioned top-down"? When we create a user, say

```bash
pveum user add testuser@pam --email youremail@something.invalid 
```

... and try to change it's password

```bash
pveum passwd testuser@pam
```

We will get an error saying:

```
change password failed: user 'testuser' does not exist
```

This is because proxmox requires you to handle PAM authenticated users yourself. 

This would work:

```bash
pveum user add testuser@pam --email youremail@something.invalid 
useradd -m testuser
pveum passwd testuser@pam
```

I did not want to proceed researching this and will be using the builtin `root` user in this guide.


# letsencrypt powered HTTPS for the Promoxmox Webui

You will need your CloudFlare Account ID and API token to proceed. Here is a [video guide][Youtube tutorial on the Proxmox ACME Cloudflare plugin] on how to get them.

Permissions for the API token need to be:
 * Zone / Zone / Read
 * Zone / DNS / Edit
 * Include / Specific Zone / yourdomain.com

```bash
cat > acme.txt <<EOF
CF_Account_ID=YOUR_ACC_ID
CF_Token=YOUR_TOKEN
EOF


pvenode acme account register account-name youremail@something.invalid
```

After the last command you will be asked for a few choices regarding letsencrypt - whether you want to use the poduction or staging server as well as to accept the terms of service. I would recommend staging certs at this point, just be aware that they will produce invalid certs. You can inspect your browser "padlock" icon to check whether it's actually letsencrypt.

But first, we need to finish the process:

```bash
pvenode acme plugin add dns cloudflare --api cf --data acme.txt
pvenode config set -acmedomain0 proxmox.pm.dood.ie,plugin=cloudflare
pvenode acme cert order
```

When we refresh the proxmox UI, the certificate should be updated.


# Conclusion

I don't really have one of much value. Speaking completely subjectively, it didn't sit right with me, and I will probably be moving on to a DIY virtualization host powered by gitops.

Regardless of my subjective feel, Proxmox seems like a great tool, especially if you need advanced features like clustering.

# Cleanup

```bash
sudo virsh vol-delete --pool default proxmox-os    
sudo virsh vol-delete --pool default proxmox-data-1
sudo virsh vol-delete --pool default proxmox-data-2
sudo virsh vol-delete --pool default proxmox-data-3
```

[Libvirt Networking]: https://wiki.libvirt.org/VirtualNetworking.html
[virt-manager Routed Network]: https://wiki.libvirt.org/TaskRoutedNetworkSetupVirtManager.html
[Proxmox Certificate Manager]: https://pve.proxmox.com/wiki/Certificate_Management
[Youtube tutorial on the Proxmox ACME Cloudflare plugin]: https://forum.proxmox.com/threads/secure-proxmox-with-letsencrypt-https-certificates-validated-with-cloudflare-dns.106347/
[Virtualized TrueNAS with Truechart and Letsencrypt]: https://blog.dood.ie/virtualization/virtualized-truenas-with-truechart-and-letsencrypt/
