---
layout: single
title:  "Letsencrypt is awesome!"
date:   2015-12-27 16:00:00
categories: security
tags: ["ssl","openssl","certificates", "security"]
---

I just found out about letsencrypt

I was about to shop for an SSL cert for a domain I own, and decided to do another "free SSL" Google search.

To my pleasant surprise, I stumbled upon this project "[letsencrypt](https://letsencrypt.org/)" which is sponsored by quite a lot of enterprise companies (Mozilla, Facebook to name a few).

In a nutshell, this is an CLI tool which makes life easier when you wish to configure your webserver for SSL, and also provide you with a free CA SSL cert for a domain you own. Pretty neat!

I didn't test this "quick-and-easy" setup with webservers, though. From what I see, it works via a webserver plugin.

Instead, I opted for the ```letsencrypt certonly --manual``` command. This command will require you to spin up a temporary Python webserver on a host that is verifiable by resolving the domain name. I'd say this is a small price to pay for a free SSL cert! Once that is done, you end up with your certs (and some of them bundled separately for convenience) in ```/etc/letsencrypt/live/$domain/``` .

This piece of software has my strong recommendation. You should check out their [documentation](https://letsencrypt.readthedocs.org/en/latest/using.html) which is compact and comprehensive. Have fun securing your stuff!

P.S. 

While you are at it, you might want to check out [Raymii's blog post](https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html) on tightening your SSL settings on Nginx.