---
layout: single
title:  "Folding At Home UI From Docker"
date:   2020-06-06 22:00:00
categories: linux
tags: ["docker","folding", "linux"]
---

How to set up a docker container for Folding-At-Home

Run:
```shell
xhost +local:root
sudo docker run --rm -ti --net=host --env="DISPLAY=$DISPLAY" ubuntu:16.04
```

Then, in the container:

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install net-tools wget python python-gtk2 python-gnome2 -y
wget https://download.foldingathome.org/releases/public/release/fahcontrol/debian-stable-64bit/v7.6/fahcontrol_7.6.13-1_all.deb
dpkg -i fahcontrol_7.6.13-1_all.deb

# Start it up:
FAHControl
```

FAHControl will like to connect to localhost:36330 by default. If you have it running on a remote host, you can port forward:

```shell
ssh <RemoteFoldingHost> -L 36330:localhost:36330
```

