---
layout: single
title:  "Virtualized TrueNAS with Truechart and Letsencrypt"
date:   2024-05-10 03:00:00
categories: virtualization
tags: ["truenas scale", "truenas", "zfs", "zvol", "nas", "kvm", "libvirt", "letsencrypt", "virtualization", "traefik"]
---

Notes on what i've done to provision a virtualized TrueNAS setup with Truechart and Letsencrypt for testing purposes.


# Disclaimer

**These are very destructive procedures. I bare no responsibility for any damages done to your system.**

# Goal

[TrueCharts powered][TrueCharts on TrueNAS] setup with letsencrypt. Letsencrypt should get certs via DNS checks.

# Setting up the libvirt host

Looks like [ZFS][KVM IO Benchmarking] is pretty good as a backing store for QEMU.

First, we need a libvirt pool. Because i'm using ZFS, I can do the following

```bash
sudo virsh pool-define-as --name zfs-pool --type zfs --source-name zroot
sudo virsh pool-start zfs-pool
```

Then, let's create the required volumes inside that pool

```bash
sudo virsh vol-create-as --pool zfs-pool --name truenas-os-1 --capacity 20G
sudo virsh vol-create-as --pool zfs-pool --name truenas-os-2 --capacity 20G
sudo virsh vol-create-as --pool zfs-pool --name truenas-data-1 --capacity 200G
sudo virsh vol-create-as --pool zfs-pool --name truenas-data-2 --capacity 200G
sudo virsh vol-create-as --pool zfs-pool --name truenas-data-3 --capacity 200G
```

Then, use `virt-manager` to set up a "Debian 12" machine while using the TrueNAS boot ISO.

* Remove the sound card
* Do not use default storage from the wizard
* In the virt customization menu add all the devices we created earlier from the `zfs-pool`.

# Why no XML for the virt?

Because the libvirt / virt-manager team will make future runs through the UI more future-proof than my XML.

# First time boot

Install the OS.

* Select the *two* small OS drives for the OS
* provide a password
* EFI Boot

After the reboot, you might have to re-enable the two OS disks as boot devices.

# Home network

I set up my DHCP server to lease `192.168.0.60` to the MAC address of the virt. 

My home router is the primary (and secondary) DNS server. On my router I can set a regex rule to route all `*.tn.dood.ie` to a specific IP.

If you don't have this capability available to you, you can probably set-up the hosts file on your computer, but this is beyond the scope of this guide.

# Initial TrueNAS config

This will mostly be my retelling of the [TrueCharts][TrueCharts on TrueNAS] guide, just more compact. Definitely use the Truechart guide for reference.

* Storage -> Create Pool
  * General Info
    * Name: `tank`
    * Allow non-unique serialed disks: Allow
  * Data:
    * Layout: zraid1
    * with/number:  should be autopopulated (3/1)
    * Save and Go To Review
  * Create Pool
* System Settings -> General ->
  * GUI
    * Ports `81` and `444` respectively
    * Turn off Usage collection
    * HTTPS TLSv1.3 only
    * Once confirmed, make sure to reconnect via https://192.168.0.60:444
  * Localization
    * Timezone
  * Apps ->
    * Settings -> Choose pool
      * Select `tank`
    * Discover Apps -> Manage Catalogs
      * Add Catalog
        * name: truecharts
        * repository: `https://github.com/truecharts/catalog`
        * Preferred Trains: `premium`, `stable` and `system`
        * Branch: main
  * Services ->
    * SSH - Enable and start
* Credentials -> Users ->
  * Admin / Edit
    * Paste Authorized Key


Adding the catalog can take several minutes++

# Bootstrap Truechart with proper HTTPS

We will be using the "cluster wide certificates" as documented [here][Cluster-Wide Certificates].

Big tip when adding apps is that the navigation menu is on the right-hand side.
Huge help as the UI is trying to show yaml in UI form, and it can be a bit hard to read.

* Apps -> Discover Apps ->
  * Available Apps -> Refresh
  * Prometheus-Operator (truecharts, system)
    * Retention: as desired (default 31d)
  * CertManager - [source doc][clusterissuer Setup]
    * Set preferred DNS. Needs to be reliable. In my case `192.168.0.1:53,192.168.0.1:53`.
  * kubernetes-reflector
    * Default settings
  * clusterissuer - [source doc][clusterissuer Setup]
    * namespace: `ix-cert-manager` or `ix-<cert-mannager-chart-name>`
    * ACME Issuer
      * name: `cert-staging`
      * Type: `Cloudflare`
      * Server:` Staging`
      * email: `your email`
      * CloudFlare API Token: `your CF token`
      * **Repeat for name: `cert` and Type: `Production`**
    * Cluster Wide Certificates
      * Add
      * Enabled ✔
      * name: `cluster-staging`
      * CertManager Cluster Issuer: `cert-staging`
      * Certificate Hosts / Add
      * `*.tn.dood.ie`
      * **Repeat for name: `cluster` and CertManager Cluster Issuer: `cert`**
  * Traefik (truecharts, premium)
    * Name: traefik
    * Metrics: enabled
      * Prometheus: enabled
  
# Eat our own dogfood

Now that we've primed traefik, we can go ahead and edit it, and have it integrate with itself.

* Apps -> 
  * Traefik (edit this time)
    * Services
      * Main Service / Service Type: ClusterIP (No need for a dedicated exposed port!)
      * Don't touch those services with port 443 and 80. Those are very much needed as LoadBalancer.
    * Ingress
      * Main - Enable
      * Hosts / Add / `traefik.tn.dood.ie`
        * Path: `/`
        * Path Type: `Prefix`
    * Integrations / Traefik
      * Enabled ✔
      * Entrypoints / Entrypoint: `websecure` 
      * **DO NOT check** "CertManager"
      * Show Advanced Settings ✔
        * TLS Settings / Add
          * Certificate Hosts / Add
            * Host: `traefik.tn.dood.ie`
          * TLS Settings / Add
            * Certificate Hosts / Add / `traefik.tn.dood.ie`
            * Cert Manager Cluster issuer: leave empty!
            * Cluster Certificate (advanced): `cluster-staging` OR `cluster` 

# Standalone example - Cyberchef

Cyberchef is a cool web-based utility that's completely standalone, does not require databases etc.

Let's see how it looks like when we can deploy an app with proper HTTPS in one go.

* Apps -> Discover Apps ->
  * Cyberchef
    * Services
      * Service Type: ClusterIP (No need for a dedicated exposed port!)
    * Ingress
      * Main - Enable
      * Hosts / Add / `cyberchef.tn.dood.ie`
        * Path: `/`
        * Path Type: `Prefix`
    * Integrations / Traefik
      * Enabled ✔
      * Entrypoints / Entrypoint: `websecure` 
      * DO NOT check "CertManager"
      * Show Advanced Settings ✔
        * TLS Settings / Add
          * Certificate Hosts / Add
            * Host: `cyberchef.tn.dood.ie`
          * TLS Settings / Add
            * Certificate Hosts / Add / `cyberchef.tn.dood.ie`
            * Use Cert Manager Cluster issuer: leave empty!
            * Cluster Certificate (advanced): `cluster-staging` OR `cluster` 

# Libvirt cleanup

Delete the machine we created. If doing it through `virt-manager` it will ask you to delete the volumes. This can sometimes fail (for some volumes).

In any case:

```bash
sudo virsh pool-destroy zfs-pool
sudo virsh pool-undefine zfs-pool

sudo zfs destroy zroot/truenas-os-1
sudo zfs destroy zroot/truenas-os-2
sudo zfs destroy zroot/truenas-data-1
sudo zfs destroy zroot/truenas-data-2
sudo zfs destroy zroot/truenas-data-3
```

Sometimes this can happen:

```plain
cannot destroy 'zroot/truenas-data-3': dataset is busy
```

Looks like it [happens][OpenZFS zvol delete bug] to folks. 

Unfortunately, the workaround for me required a reboot:
* Disable libvirtd: `sudo systemctl disable libvirtd`
* Reboot
* Try to delete again
* Enable libvirtd: `sudo systemctl enable libvirtd`


# Complete derail while trying to clean up

On my third run of this very guide, the `dataset is busy`  error happened again. This time the reboot trick didn't work. Probably because I had to mask `libvirtd.socket`, `libvirt-ro.socket` and `libvirt-admin.socket` as they will start libvirtd even when it is disabled. This is pure speculation, though, because I didn't investigate what else aside from libvirt could be using this zvol.

I opted for booting into the Fedora live USB so I can have a clean slate while trying to fix the issue.

Context: Some months ago I followed this ZFSBootMenu [guide][ZFSBoootMenu Fedora] guide so I can get the live system prepared for [installing Fedora with root ZFS][Fedora ZFS root with encryption].


# Fedora Live USB

Unfortunately, I recently updated my system to Fedora 40. Website referenced in the guide, zfsonlinux.org, did not have the Fedora 40 RPMs yet.

So... naturally I had to build the packages myself in the live Fedora system. I opted for the [DKMS package build][Build Custom ZFS Packages] and that worked fine. I installed the resulting packages and I could `modprobe zfs`.

Now, because I'm fairly fresh to the ZFS game, I had no idea that ZFS is aware of the [host it is being mounted on][ZFS on Arch Wiki - Exporting a storage pool].

What this meant was that when I was trying to do `zfs import`, I was getting [`pool may be in use from other system`][ZFS pool may be in use from another system].

Being careless I just read the error message and forced the import with `zfs import -f zroot`.

I was able to get rid of the last remaining zvol with `zfs destroy zroot/truenas-data-3` and rebooted.

## Heart attack

After typing in my disk encryption password, I was greeted by a, now familiar, error during systemd startup: `pool may be in use from other system` with an option to drop to the emergency shell.

This system has this very guide as well as days of other work that has not been backed up...

Luckily, still having access to the `zfs` utility in the emergency shell I could see that the host ID is that of the live system, so I figured that another forced import would fix the issue.

It would appear that I was right: `zfs import -f zroot`. Reboot

The issue went away after that forced import back on the normal system.

# Conclusion

This endeavor has taught me a few things:
* That Truenas looks like a pretty cool project
* That Truechart also looks like a pretty cool project, but is too underdocumented for my taste at the moment. Will definitely be using their charts, though.
* That I still have a lot to learn about ZFS
* That I might skip ZFS-libvirt integration for now

[Traefik How-to]: https://truecharts.org/charts/premium/traefik/how-to/
[TrueCharts on TrueNAS]: https://truecharts.org/scale/
[KVM IO Benchmarking]: https://jrs-s.net/2013/05/17/kvm-io-benchmarking/
[clusterissuer Setup]: https://truecharts.org/charts/premium/clusterissuer/how-to/
[Cluster-Wide Certificates]: https://truecharts.org/charts/premium/clusterissuer/cluster-certificates/
[OpenZFS zvol delete bug]: https://github.com/openzfs/zfs/discussions/13594
[ZFSBoootMenu Fedora]: https://docs.zfsbootmenu.org/en/v2.3.x/guides/fedora/uefi.html
[Fedora ZFS root with encryption]:https://blog.dood.ie/linux/fedora-zfs-encrypted-root-and-zfsbootmenu/
[Build Custom ZFS Packages]: https://openzfs.github.io/openzfs-docs/Developer%20Resources/Custom%20Packages.html
[ZFS on Arch Wiki - Exporting a storage pool]: https://wiki.archlinux.org/title/ZFS#Exporting_a_storage_pool
[ZFS pool may be in use from another system]: https://wiki.archlinux.org/title/ZFS#On_boot_the_zfs_pool_does_not_mount_stating:_%22pool_may_be_in_use_from_other_system%22
