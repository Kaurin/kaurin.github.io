---
layout: single
title:  "faster-whisper with Wyoming and GPU acceleration on Windows via Docker"
date:   2025-10-24 20:50:00
categories: ai
tags: ["virtualization", "homeassistant", "windows", "gpu", "ai"]
---

Works on Windows, too!

# Problem statement

I am setting up HomeAssistant's VoiceAssistant feature. For it to function while being hosted locally, I need two components:
* Text-to-speech (TTS): piper
* Automatic Speech Recognition (ASR): Wyoming + faster-whisper

TTS is not much of a problem as it is not very demanding. It can be comfortably hosted even on Raspberry Pi 4 deployments.

For a quick and easy ASR, HomeAssistant has a native Whisper integration. Unfortunately:
1. My VM which hosts HomeAssistant does not have the CPU horsepower
2. I don't see mention of it supporting GPU acceleration

There is another option: Add the Wyoming integration, and provide an address/port for a remotely hosted faster-whisper + wyoming server.

# Obvious, but less optimal solution

The more popular one I found is rhasspy's `wyoming-faster-whisper` ([github repo][rhasspy's wyoming-faster-whisper]). Unfortunately, it [does not have GPU support][lack of gpu support on rhasspy/wyoming-faster-whisper] as of writing this.

# A linuxservers hidden gem

Thankfully, linuxservers folks [made their own][linuxserver faster-whisper] faster-whisper set of Docker images, one of which has GPU support!

I opted to use my Windows Gaming PC with an Nvidia graphics card to try it out. This involved:
1. Enabling virtualization for my AMD motherboard (AMD-V)
2. Installing Docker on Windows - which will also install and update WSL2.
3. Setting the Docker service to Automatic so it spins up the container back up after reboot
4. Running the following:

```bash
docker run -d --name=faster-whisper-gpu --gpus=all -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC -e WHISPER_MODEL=turbo -e WHISPER_LANG=en -p 10300:10300 -v //d/whisper-data-dir:/config --restart unless-stopped lscr.io/linuxserver/faster-whisper:gpu
```

I have set my `D:\whisper-data-dir\` as the directory on the Windows host which contains the models, etc.

This setup works perfectly. I am not happy with hosting *anything* on Windows, but this will do for now.

# Wishlist
I wish ROCM image becomes available so I can try running linuxserver's faster-whisper on my Kubernetes node which has a 8700G CPU+iGPU

[rhasspy's wyoming-faster-whisper]: https://github.com/rhasspy/wyoming-faster-whisper
[lack of gpu support on rhasspy/wyoming-faster-whisper]: https://github.com/rhasspy/wyoming-faster-whisper/issues/35
[linuxserver faster-whisper]: https://docs.linuxserver.io/images/docker-faster-whisper/
