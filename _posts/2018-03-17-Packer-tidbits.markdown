---
layout: post
title:  "Packer tidbits"
date:   2018-03-17 16:00:00
categories: misc
tags: packer,hashicorp
---

# Controlling the keystroke delay during packer's VNC execution

This is very useful if you are on a fast machine. I use the following on my Core-i7 4770:

`PACKER_KEY_INTERVAL=10ms packer <rest-of-packer-params>`

# Vagrant + libvirt = <3

Assuming you are running on a host that has KVM installed and working, you can do:

`vagrant plugin install vagrant-libvirt`

Because most vagrant images come with VirtualBox support, do check out Chef's [Bento](https://github.com/chef/bento) project!
