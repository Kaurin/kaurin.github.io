---
layout: post
title:  "Cross-compile and setup ZNC for Ubuntu 14.04"
date:   2015-12-28 16:00:00
categories: misc
tags: irc,znc,bouncer
---

## Why are you writing this article?

* I have a small VPS box that didn't have the memory to compile znc with python/perl/tcp support even withouth the '-pipe' CFLAG.
* As a reminder to myself on cross compiling

## Overview

* We'll have a "Compile" and "Destination" machines (or virts, depending on your capabilities)
* Compile box best be discardable VM with a fresh install of Ubuntu 14.04, with more tha 512mb of ram. I'm not sure how much more ram, but 512mb won't cut it.
* We won't be creating a package. This is an old school compile and .tar copy-install. Just a heads up if you don't like this sort of thing
* Due to point above, compile prefix will be /opt/znc.  I like a higher-degree of separation in /opt instead of everything jumbled up.
* After compiling, we'll create a separate user for ZNC and an upstart file to have znc run as a service via non-privileged user.

## Compile box

Assuming that  this is a fresh install of Ubuntu 14.04 (server), run the following commands. 

I recommend you do them 1-by-1 for maximum control.

{% highlight bash %}
# Note on "build-dep znc" - manually installing libraries might get us newer 
# dep-library versions, but I'm lazy.
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install build-essential autoconf automake git swig3.0 libicu-dev
sudo apt-get -y build-dep znc

# Optional:
sudo reboot

# Workspace preparation:
mkdir ~/git
cd ~/git

# Let's get the project and cd into it
git clone https://github.com/znc/znc.git
cd znc

# Check out the 1.6.x brach. This branch was stable at the time of writing 
# this article. Not sure if my guide will work with the "master" branch, 
# but I don't see why not.
git checkout 1.6.x

# This is a project requirement
./autogen.sh

# Configure with tcl,perl,python
./configure \
    --enable-python=python3 \
    --enable-tcl \
    --enable-perl \
    --prefix=/opt/znc 

# Another project requirement
git submodule update --init --recursive

# DO THIS ON THE DESTINATION BOX TO GET THE ARCH!
# If gcc is not on the destination box, install build-essential, 
# and then remove it after running the command
# Note that the 3 lines below are 1 command!
gcc -march=native -E -v - </dev/null 2>&1 |
    grep cc1 |
    perl -pe 's|.*-march=(.*?) .*|\1|g'

# Back to Compile box. Remember to replace "REPLACEME" with your arch!
CFLAGS="-march=REPLACEME -O2 -pipe"
CXXFLAGS="$CFLAGS"

# -jx = number of cores +1. I had 8 cores = -j9
make -j9

# This will install to prefix /opt/znc/{bin,..}
sudo make install

# Let's create a tarball!
tar -czf ~/znc.tar.gz /opt/znc
{% endhighlight %}

## Intermezzo

Copy the tar "znc.tar.gz" from the Compile box to the Destination box

## Destination box

{% highlight bash %}
# Prepare the box for installation of znc
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y libperl5.18 libpython3.4 libtcl8.5 tcl8.5 libicu52

# Optional
sudo reboot

# Let's extract to the same dir structure as on Compile
sudo tar -xf znc.tar.gz  -C /

# Create dedicated user "zncuser"
sudo useradd -c "ZNC bouncer user" -ms /bin/false zncuser

# Initial znc configuration as "zncuser"
# At the last prompt, don't select to start now. 
# We'll do it via upstart in a second
HOME=/home/zncuser sudo -u zncuser /opt/znc/bin/znc --makeconf
{% endhighlight %}

## Set up the upstart script

### /etc/init/zncbnc.conf

{% highlight text %}
# znc

description "IRC Bouncer"

start on runlevel [2345]

stop on runlevel [016]

respawn
respawn limit 10 5
setuid zncuser

script
  exec /opt/znc/bin/znc -fn
end script
{% endhighlight %}

## Final words

You can now start your bouncer via:
{% highlight bash %}
sudo start zncbnc
{% endhighlight %}

It will also get started automatically with system reboot which you can test.

[ZNC documentation](http://wiki.znc.in/ZNC) is quite extensive, so I won't dive deep into configuring it. Have fun!