---
layout: single
title:  "Notes on Wireguard (with Mikrotik)"
date:   2025-01-16 22:00:00
categories: security
tags: ["wireguard", "mikrotik", "networking", "security"]
---

Some poorly researched notes on Wireguard. Updated on August 12th, 2025.


# Background

I was resetting my Wireguard setup and I set out to do so with these goals in mind:

1. Star topology. My clients would connect to the router. The clients would not be able to talk to each other directly.
2. Find a decent config generator
3. Apply what the config generator spits out on my Mikrotik router and client devices
4. The clients should route all traffic through the wireguard connection, not just specific subnets


```
             ┌─────────┐
      ┌──────┤ Router  ├──────┐
      │      └────┬────┘      │
      │           │           │ lan
 ─────┼───────────┼───────────┼─────
      │           │           │ internet
      │           │           │
 ┌────┴────┐ ┌────┴────┐ ┌────┴────┐
 │ Client1 │ │ Client2 │ │ Client3 │
 └─────────┘ └─────────┘ └─────────┘
```


# Config generator

I landed on this fairly obscure Python-based config generator called [wireguard-config-gen]. There are many of them out there, especially web based. I just wanted a nice CLI one.

I started off by defining the `interface.yaml`. It looked something like this:

```yaml
Dynamic:
  StartIP: 192.168.50.2 # Start IP for the clients
  PrefixLen: 32
  DNS:
    - 192.168.0.1
    - 192.168.0.2
# Defined machines
Machines:
  # Server peers need a publicly accessible Endpoint
  Router:
    Interface:
      Address: 192.168.50.1
      ListenPort: 51820
    Peer:
      Endpoint: my.dynamic.ip.example.com:51820
      PersistentKeepalive: 25
      AllowedIPs:
        - 192.168.0.0/24
        - 192.168.50.0/24
      Topolgy: star
  # Client peers will get a Dynamic address beginning with StartIP
  Client1: {}
  Client2: {}
  Client3: {}
```
Note: Names `Router`, `Client1`, `Client2` and `Client3` can be replaced by any string.

## wireguard-config-gen dependencies

```bash
uv venv --seed
uv sync
uv run python run.py ...
```

## Run the generator

```bash
uv run python run.py interfaces.yaml
```

## Check out our generated configs

Even though the program outputs to stdout, you can find the individual configs in the `output` directory:

```bash
$ ls -1 output/
Client1.conf
Client2.conf
Client3.conf
result.yaml
Router.conf
```

Taking a peek at Client1.conf:

```yaml
## Generated: 2025-08-12 20:12:54.907587+00:00
## From Version: 0.6.6

[Interface]
## Client1
Address = 192.168.50.2/32
PrivateKey = cBqgY/Bu6D9/mRHCaSZ7w5O6wYKjZhJ9t+HUhZ0gE08=
DNS = 192.168.0.1,192.168.0.2

[Peer]
## Router
AllowedIPs = 192.168.0.0/24, 192.168.50.0/24
PublicKey = /8QlHt5+nwo1ElCxxParSqNW8ISOn6hJYQVsLNX3lDQ=
Endpoint = my.dynamic.ip.example.com:51820
PersistentKeepalive = 25
PresharedKey = keKlv8WcEwi0h7ddCW0zv1MIPVsAOVkQS+Hca1R/KVE=
```

Make sure to manually edit AllowedIPs to `0.0.0.0/0` because of the goal where clients will route all traffic through the tunnel.


```yaml
## Generated: 2025-08-12 20:12:54.907587+00:00
## From Version: 0.6.6

[Interface]
## Client1
Address = 192.168.50.2/32
PrivateKey = cBqgY/Bu6D9/mRHCaSZ7w5O6wYKjZhJ9t+HUhZ0gE08=
DNS = 192.168.0.1,192.168.0.2

[Peer]
## Router
AllowedIPs = 0.0.0.0/0
PublicKey = /8QlHt5+nwo1ElCxxParSqNW8ISOn6hJYQVsLNX3lDQ=
Endpoint = my.dynamic.ip.example.com:51820
PersistentKeepalive = 25
PresharedKey = keKlv8WcEwi0h7ddCW0zv1MIPVsAOVkQS+Hca1R/KVE=
```

This can also be edited later at any time on the clients.

Reference: [What does WireGuard AllowedIPs actually do?]

# Setting up the Mikrotik router

This is a decent example guide on [how to set up Mikrotik for Wireguard][Mikrotik Wireguard example configuration].

Whatever Mikrotik/Wireguard setup you have, use the values from the `Router.yaml` config.

If Mikrotik currently does not have a Wireguard configuration, you can import the `Router.yaml`:
1. Upload `Router.yaml` to your Mikrotik router
2. Run `/interface/wireguard/wg-import <filename>`

It would be a good idea to check/add/modify:
1. `/ip/address/print`
2. `/ip/firewall/address-list/print` if used for rules
3. `/interface/list/print` if used for rules
4. `/ip/firewall/filter/print`

# Linux client configuration

Install `wireguard` and `wireguard-tools` packages which should be available on most, if not all, distributions.

Copy the shortened `Client1.yaml` file to our client machine to `/etc/wireguard/wg0.conf`. Remember to set the permissions:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
```

# Using Wireguard on linux

## CLI only

There are [many ways][Arch Linux page on WireGuard] to use Wireguard on Linux, but I find using the simple `wg-quick` utility the easiest.

Note: The script's output will hint if you are missing utilities needed to operate it, such as iptables.

```bash
sudo wg-quick up wg0
```

You can stop the wireguard interface like so
```bash
sudo wg-quick down wg0
```

## Gnome Desktop Environment

Gnome can import Wireguard configs through the built-in Network Manager integration in the UI.

# Using Wireguard on Mobile

Mikrotik has a way to generate a QR code which can be scanned on the phones with middling results, but I prefer to transfer the `Client2.yaml` file to my phone and import it using the official Wireguard app.


# Troubleshooting on the Mikrotik device

Packet sniffer (tool category) is your friend. I used it thorough the UI to monitor all traffic on the wg interface. Select just the interface and headers only to save on CPU time.

Initially, I had `AllowedIPs` on my clients config set to the subnet of the LAN and Wireguard's network. Only DNS traffic would go through through the tunnel.

When I changed `AllowedIPs` to `0.0.0.0/0` that's when I saw all the client traffic flow through the router.

[wireguard-config-gen]: https://github.com/radupotop/wireguard-config-gen
[Mikrotik Wireguard example configuration]: https://help.mikrotik.com/docs/spaces/ROS/pages/69664792/WireGuard#WireGuard-WireGuardinterfaceconfiguration
[Arch Linux page on WireGuard]: https://wiki.archlinux.org/title/WireGuard
[What does WireGuard AllowedIPs actually do?]: https://techoverflow.net/2021/07/09/what-does-wireguard-allowedips-actually-do/
