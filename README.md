# MobileEyeDoor — Home Assistant add-on

Bring **CTV / XiongMai video doorbells** (the *MobileEyeDoor+* / *uCareHome*
kind, e.g. **CTV-M4101AHD**) into Home Assistant as regular cameras.

These doorbells ship **no RTSP and no ONVIF** — video is locked inside a
proprietary XiongMai protocol on the mobile port (10510) that only the vendor
apps speak. This repository contains a reverse-engineered bridge that talks
that protocol, extracts the H.264 stream and republishes it via
[go2rtc](https://github.com/AlexxIT/go2rtc).

## Install

1. In Home Assistant: **Settings → Add-ons → Add-on Store**.
2. Kebab menu (⋮) → **Repositories** → add:
   ```
   https://github.com/steel0rat/mobileEyeDoor
   ```
3. Install **MobileEyeDoor Bridge**, then configure it — see the
   [add-on README](mobileeye_door/README.md), especially *Getting your
   `login_hex`*.

## Repository layout

```
mobileeye_door/     the Home Assistant add-on (bridge + go2rtc)
  ctv_client.py     XiongMai mobile-protocol client → H.264 on stdout
  run.sh            generates go2rtc config from add-on options
  config.yaml       add-on manifest & options
  Dockerfile        add-on image (python + ffmpeg + go2rtc)
  README.md         setup & capture recipe
tools/
  extract_login.py  pull the 88-byte login frame out of a packet capture
```

## The protocol, briefly

Reverse-engineered from captured app traffic (see the add-on README for the
capture recipe). The client opens TCP to `:10510`, sends one 88-byte login
frame, and the doorbell immediately streams H.264 for the channel selected by
**byte 80** (`0x01/0x02/0x04/0x08` for cameras 1–4). The XiongMai media framing
is stripped down to a clean H.264 Annex-B elementary stream.

The device-specific login secret (username + password hash) is never stored in
this repo — you supply your own captured `login_hex` in the add-on options.

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

Independent interoperability work for talking to hardware you own. Not
affiliated with CTV or XiongMai. No vendor firmware or code is included.
