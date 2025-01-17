---
layout: single
title:  "Batch Deletion of YubiKey Credentials"
date:   2025-01-14 22:00:00
categories: security
tags: ["yubikey", "yubico", "fido2", "security"]
---

My lab Yubikey was slowing down due to the amount of credentials for a single domain

# Disclaimer

**These are very destructive procedures. I bare no responsibility for any loss of data or damage to your Yuibkey**

# Procedure

Yubikey lists the fido2 credentials in the following format:

```bash
ykman fido credentials list --csv
```

```
<long-uuid-1>,<domain>,<username>,,<long-number-1>
<long-uuid-2>,<domain>.<username>,,<long-number-2>
```

We can grep for the domain and username and get a CSV output (no Json or Yaml, sadly):

```bash
ykman fido credentials list --csv | \
  grep ',some.example.com,myusername,'  | \
  awk -F ',' '{print $1}'
```

```
<long-uuid-1>
<long-uuid-2>
```

Finally, we can run this through xargs to mass delete the domain-user combination.
* NOTE: You have an option to input the pin for every deletion, or run with `--pin` which is unsafe.
* NOTE: Nothing is stopping you from running this for a whole domain, being more specific is safer.

```bash
ykman fido credentials list --csv --pin 1234 | \
  grep ',some.example.com,myusername,' | \
  awk -F ',' '{print $1}' | \
  xargs -n1 ykman fido credentials delete --force --pin 1234
```
