# MobileEyeDoor Bridge

Turn a **CTV / XiongMai video doorbell** — the kind that only talks to the
*MobileEyeDoor+* / *uCareHome* mobile apps (e.g. **CTV-M4101AHD**) — into
ordinary RTSP / WebRTC cameras inside Home Assistant.

These doorbells have **no RTSP and no ONVIF**. Video is only served over a
proprietary XiongMai binary protocol on the "mobile port" (default **10510**).
This add-on speaks that protocol directly, extracts the H.264 stream and
re-publishes it through a bundled [go2rtc](https://github.com/AlexxIT/go2rtc),
so every camera channel shows up as a normal camera entity.

## Supported devices

Any XiongMai-based doorbell/monitor whose app is **MobileEyeDoor+** or
**uCareHome** and that exposes the mobile port (8000 = control, 8090 = web,
10510 = mobile). Confirmed on CTV-M4101AHD (4-channel AHD monitor). The
protocol is identical across the family; only the login secret differs.

## How it works

The client sends a single **88-byte login frame** and the doorbell immediately
streams H.264 for the requested channel — the login *is* the stream request.
Only one byte of the frame selects the camera:

| byte 80 | camera |
|---------|--------|
| `0x01`  | 1      |
| `0x02`  | 2      |
| `0x04`  | 3      |
| `0x08`  | 4      |

Everything else in the frame (username, password hash, protocol constants) is
device-specific and is supplied once as the `login_hex` option.

## Getting your `login_hex`

The password hash cannot be regenerated from the plaintext password (the
XiongMai hashing routine is not published), so you capture the login frame
your own app already sends, **once**:

1. Run the doorbell app while capturing its traffic to the doorbell IP:
   - **Android / emulator (BlueStacks):** built-in Windows `pktmon` works
     without Wireshark:
     ```
     pktmon filter add -i <DOORBELL_IP>
     pktmon start --capture --pkt-size 0 --file-name cap.etl
     # open all cameras in the app, then:
     pktmon stop
     pktmon etl2pcap cap.etl -o cap.pcapng
     ```
   - **Phone:** capture with PCAPdroid, or mirror the traffic on your router.
2. Extract the 88-byte login frame from the capture:
   ```
   python3 tools/extract_login.py cap.pcapng
   ```
   It prints the `login_hex` string (channel byte is normalised).
3. Paste that hex into the add-on's `login_hex` option.

> The `login_hex` contains your doorbell's password hash. Treat it as a
> secret — it stays in your Home Assistant config, never commit it anywhere.

## Configuration

```yaml
host: 192.168.1.50        # doorbell IP (give it a DHCP reservation)
port: 10510               # mobile port
login_hex: "0000005401..."  # 88-byte login frame, hex (see above)
cameras:
  - channel: 1
    name: door
  - channel: 3
    name: yard
```

Each entry becomes a go2rtc stream named after `name`.

## Using the cameras

After the add-on starts, the streams are available at:

```
rtsp://<home-assistant>:8554/<name>
```

Add them in Home Assistant via **Settings → Devices & Services → go2rtc**, or
the *Generic Camera* integration pointed at the RTSP URL, or the go2rtc web UI
on port `1984`.

## Limitations

- **Few simultaneous connections.** XiongMai doorbells accept only a handful of
  sockets. Running this add-on *and* the phone app on the same camera at the
  same time may starve one of them. Give each camera to one consumer.
- **Battery/standby panels stay dark.** The doorbell's own call panel is only
  lit on a call; its channel will be a black frame (valid stream, no light)
  until then.
- Stream is whatever the doorbell encodes — typically H.264 Baseline 640×480.

## License

MIT. See [LICENSE](../LICENSE).
