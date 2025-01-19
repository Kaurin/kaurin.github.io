---
layout: single
title:  "Notes on Wireguard (with Mikrotik)"
date:   2025-01-16 22:00:00
categories: security
tags: ["wireguard", "mikrotik", "networking", "security"]
---

Some poorly researched notes on Wireguard


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

This config generator will create configs for a mesh configuration. This is not what I want, but the configs are easily modified to fit my need.

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
  # Client peers will get a Dynamic address beginning with StartIP
  Client1: {}
  Client2: {}
  Client3: {}
```
Note: Names `Router`, `Client1`, `Client2` and `Client3` can be replaced by any string.

## wireguard-config-gen dependencies

The project ships with `pyproject.toml`, however poetry no longer installs the deps into a venv because it wants some poetry fields in the `pyproject.toml` file.
So, I just cat the `pyproject.toml` file and install deps with pipenv.

```bash
pipenv install cryptography pydantic pyyaml
```

## Run the generator

```bash
pipenv run python run.py interfaces.yaml
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

The configs that get "spat out" are for a mesh configuration, however the unnecessary blocks can be easily trimmed from each of the clients.

For example let's trim out `Client1` from this:

```ini
## Generated: 2025-01-17 01:51:06.266187+00:00
## From Version: 0.6.1

[Interface]
## Client1
Address = 192.168.50.2/24
PrivateKey = EN2pv/CIMcogr7kN1Z5skJpulOoRNcGu09noQMVqM0U=
DNS = 192.168.0.1,192.168.0.2

[Peer]
## Router
AllowedIPs = 192.168.0.0/24, 192.168.50.0/24
PublicKey = PDDg4bdpQnYzi8ArXyPdoQZPY+mnObT1aBMKn7BY0lQ=
Endpoint = my.dynamic.ip.example.com:51820
PersistentKeepalive = 25
PresharedKey = c1lFItz4oDuFEoUrTwXRhFBmTnE/J1BpzuON1SlxMjo=

[Peer]
## Client2
AllowedIPs = 192.168.50.3/32
PublicKey = 9nqwhl9EiSYMlhIDrj1OAS2WjzXrFtdcxsPxRdOZdU0=
PresharedKey = aHOB57odhRx9Eo5MEHvmdmhY34TlJqI6dP5PAdDBNmc=

[Peer]
## Client3
AllowedIPs = 192.168.50.4/32
PublicKey = eHbIszr7cwDByVqKx9ajR4IYRzTBzfI/0u47jrMuewc=
PresharedKey = XJoRwv2/fgcRdO/B044TRGAP57LP2GnuutF0CdKKAe0=
```

To this:
```ini
## Generated: 2025-01-17 01:51:06.266187+00:00
## From Version: 0.6.1

[Interface]
## Client1
Address = 192.168.50.2/24
PrivateKey = EN2pv/CIMcogr7kN1Z5skJpulOoRNcGu09noQMVqM0U=
DNS = 192.168.0.1,192.168.0.2

[Peer]
## Router
AllowedIPs = 0.0.0.0/0 # NOTE - CHANGED FROM GENERATED
PublicKey = PDDg4bdpQnYzi8ArXyPdoQZPY+mnObT1aBMKn7BY0lQ=
Endpoint = my.dynamic.ip.example.com:51820
PersistentKeepalive = 25
PresharedKey = c1lFItz4oDuFEoUrTwXRhFBmTnE/J1BpzuON1SlxMjo=
```

Repeat for clients 2 and 3, making sure to set AllowedIPs to `0.0.0.0/0` because of the goal where clients will route all traffic through the tunnel.

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

There are [many ways][Arch Linux page on WireGuard] to use Wireguard on Linux, but I find using the simple `wg-quick` utility the easiest.

Note: The script's output will hint if you are missing utilities needed to operate it, such as iptables.

```bash
sudo wg-quick up wg0
```

You can stop the wireguard interface like so
```bash
sudo wg-quick down wg0
```

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
