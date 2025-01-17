---
layout: single
title:  "Notes on Wireguard"
date:   2025-01-16 22:00:00
categories: security
tags: ["wireguard", "mikrotik", "networking", "security"]
---

Some very poorly researched notes on Wireguard


# Background

I was resetting my Wireguard setup and I set out to do so with these goals in mind:

1. Star topology. My clients would connect to the router. The clients would not be able to talk to each other directly.
2. Find a decent config generator
3. Apply what the config generator spits out on my Mikrotik router and client devices


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
  PrefixLen: 24
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

## Project dependencies

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

For example let's trim out Client1 from this:

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
AllowedIPs = 192.168.0.0/24, 192.168.50.0/24
PublicKey = PDDg4bdpQnYzi8ArXyPdoQZPY+mnObT1aBMKn7BY0lQ=
Endpoint = my.dynamic.ip.example.com:51820
PersistentKeepalive = 25
PresharedKey = c1lFItz4oDuFEoUrTwXRhFBmTnE/J1BpzuON1SlxMjo=
```

Repeat for clients 2 and 3

# Setting up the Mikrotik router

From the generated config, we can set up the Mikrotik config with the following.

This is a decent example guide on [how to set up Mikrotik for Wireguard][Mikrotik Wireguard example configuration].

Whatever Mikrotik/Wireguard setup you have, use the values from the `Router.yaml` config.

# Linux client configuration

Install `wireguard` and `wireguard-tools` packages which should be available on most, if not all, distributions.

Copy the shortened `Client1.yaml` file to our client machine to `/etc/wireguard/wg0.conf`

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


# Caveats

Ensure that the `AllowedIps` are set to something reasonable
For example, given the star configuration above, if your router private IP is not accessible, you might not be able to get routed to the internet (depending on the client's routing configuration).

If your Wireguard interfaces are on a separate subnet from, for example, your Router LAN(s) you wish to communicate to, those LAN(s) also need to be incorporated into `AllowedIPs`

This is a bit from fuzzy memory, but if I remember correctly Mikrotik would sometimes show a "session started" metric and timer even though the credentials are wrong. That can make troubleshooting a bit difficult.

[wireguard-config-gen]: https://github.com/radupotop/wireguard-config-gen
[Mikrotik Wireguard example configuration]: https://help.mikrotik.com/docs/spaces/ROS/pages/69664792/WireGuard#WireGuard-WireGuardinterfaceconfiguration
[Arch Linux page on WireGuard]: https://wiki.archlinux.org/title/WireGuard
