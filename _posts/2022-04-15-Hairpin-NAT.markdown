---
layout: single
title:  "Hairpin NAT"
date:   2022-04-15 00:45:00
categories: networking
tags: ["mikrotik","networking","nat"]
---

My attempt at explaining the Hairpin NAT concept

# Disclaimer

Not a networking expert.
A better explanation of this can be found in [Mikrotik's NAT Documentation][Mikrotik's NAT Documentation]

# Use Case

Assumption: Typical home LAN with a router that provides access to the internet.

I would like to access my home server by using the Public IP that's assigned to the router's "WAN" port.

# First attempt at a solution

I thought - simple - Just use a port forwarding rule (DST-NAT):
```
Chain:              dstnat
Input interfaces:   LAN (Mikrotik specific, interface lists)
DST port:           443
Protocol:           TCP
DST address:        <router-pub-ip>
Action:             dst-nat
To-Address:         <home-server-private-ip>
```

Unfortunately, when used from within the home network I get a timeout while trying to connect to the home server via the public IP.

What goes on "under the hood" is the following:

1. Packet originates from our LAN client computer and heads towards the router, because the destination is a public IP and not a local one
2. Router matches the packet to our port forwarding rule and sends the packet through, but it also changes the Destination IP to the private IP of the server
3. The server happily accepts the incoming packet, but replies to the private IP directly, completely ignoring the router. In this very simple scenario, home server and client are on the same /24 network which makes them neighbors.
4. The client drops/rejects the returning invalid packet (in the networking stack) because the source IP of the returning packet is server's PRIVATE IP, which is not the IP we sent the original packet to.



# The missing piece

To make this type of connectivity work, we also need to set up a SNAT (source NAT, masquerade... use your preferred term). This Source NAT is not the one we already have for LAN->WAN connectivity. This one is specific to LAN->Public-IP->Home-Server traversal, so, depending on our use case, we need to have something like this:

```
Chain:              srcnat
Source Address:     192.168.0.0/16
Dst Address:        <home-server-private-ip>
DST port:           443
Protocol:           TCP
Action:             masquerade
```

Of course, if you have a wide range of ports you'd like to loop back from LAN to your home server (via the public IP), then this rule should be changed accordingly. It is even simpler if you want your home server to be a "catch all" for any LAN->Public-IP communication.

# Situations when you don't need a hairpin NAT

If your setup is slightly more robust, say, the home server(s) are on a separate subnet, then you don't need the source NAT rule.

I'm not actually sure EXACTLY why passing back through the router is "magical", but this is what happens:

1. Packet originates from our LAN client computer and heads towards the router, because the destination is a public IP and not a local one
2. Router matches the packet to our port forwarding rule and sends the packet through, but it also changes the Destination IP to the private IP of the server (note: different subnet to the client's)
3. The server happily accepts the incoming packet, and sends the reply packet back through the router
4. The router sees the related packet, and returns it to the client. This packet's source IP gets re-written to the public-ip (I don't know why)
5. The client sees the related packet and accepts it because the source IP is the public IP


# Sources

* [Mikrotik's NAT Documentation][Mikrotik's NAT Documentation]



[Mikrotik's NAT Documentation]: https://help.mikrotik.com/docs/display/ROS/NAT
