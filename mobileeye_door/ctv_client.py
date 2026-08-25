#!/usr/bin/env python3
"""
CTV / XiongMai video-doorbell local-protocol client (mobile port, default 10510).

Reverse-engineered from MobileEyeDoor+ / uCareHome traffic on a CTV-M4101AHD
(XiongMai platform). The client opens a TCP connection, sends a single 88-byte
login frame and the doorbell immediately starts streaming H.264 for the
selected channel. There is no separate "start stream" command — the login *is*
the request.

The client strips the XiongMai media framing and writes a clean H.264
Annex-B elementary stream to stdout, ready to be piped into ffmpeg / go2rtc.

Login frame layout (88 bytes)::

    [0:4]   00 00 00 54   payload length (0x54 = 84)
    [4:8]   01 00 00 00   command = login
    [8:21]  header        fixed protocol bytes
    [21:53] username      ASCII, NUL-padded (default "Admin")
    [53:80] password hash  device-specific secret
    [80]    channel mask   0x01 cam1 / 0x02 cam2 / 0x04 cam3 / 0x08 cam4
    [81:88] tail           fixed protocol bytes

Because the password hash is device-specific and could not be regenerated from
the plaintext password without the (still unknown) XiongMai hashing routine,
the whole 88-byte login template is provided as a hex string (``--login-hex``
or the ``LOGIN_HEX`` env var). Capture yours once with the doorbell's own app,
then reuse it — see README for the capture recipe. Only byte 80 (the channel)
is overwritten by this client.
"""
import argparse
import os
import socket
import sys
import time

H264_START = b"\x00\x00\x00\x01"
# H.264 NAL unit types that make up a decodable stream.
KEEP_NAL_TYPES = {1, 5, 6, 7, 8}  # P, IDR, SEI, SPS, PPS
CHANNEL_MASK = {1: 0x01, 2: 0x02, 3: 0x04, 4: 0x08}
LOGIN_CHANNEL_OFFSET = 80


def build_login(login_hex: str, channel: int) -> bytes:
    frame = bytearray(bytes.fromhex(login_hex.replace(" ", "")))
    if len(frame) < LOGIN_CHANNEL_OFFSET + 1:
        raise ValueError(
            f"login template too short: {len(frame)} bytes, "
            f"need at least {LOGIN_CHANNEL_OFFSET + 1}"
        )
    if channel not in CHANNEL_MASK:
        raise ValueError(f"channel must be 1..4, got {channel}")
    frame[LOGIN_CHANNEL_OFFSET] = CHANNEL_MASK[channel]
    return bytes(frame)


def extract_h264(chunk: bytes) -> bytes:
    """Pull decodable H.264 NAL units out of the XiongMai media framing."""
    out = bytearray()
    for part in chunk.split(H264_START)[1:]:
        if part and (part[0] & 0x1F) in KEEP_NAL_TYPES:
            out += H264_START + part
    return bytes(out)


def stream(host, port, login, reconnect, log):
    while True:
        try:
            with socket.create_connection((host, port), timeout=10) as sock:
                sock.sendall(login)
                log(f"connected to {host}:{port}, login sent")
                sock.settimeout(15)
                while True:
                    data = sock.recv(65536)
                    if not data:
                        log("connection closed by doorbell")
                        break
                    nal = extract_h264(data)
                    if nal:
                        sys.stdout.buffer.write(nal)
                        sys.stdout.buffer.flush()
        except (OSError, ValueError) as exc:
            log(f"stream error: {exc}")
        if not reconnect:
            return
        time.sleep(reconnect)
        log("reconnecting...")


def main():
    ap = argparse.ArgumentParser(description="CTV/XiongMai doorbell H.264 client")
    ap.add_argument("--host", default=os.environ.get("DOORBELL_HOST"))
    ap.add_argument("--port", type=int,
                    default=int(os.environ.get("DOORBELL_PORT", "10510")))
    ap.add_argument("--channel", type=int, required=True, help="camera 1..4")
    ap.add_argument("--login-hex", default=os.environ.get("LOGIN_HEX"),
                    help="88-byte login frame as hex (or LOGIN_HEX env)")
    ap.add_argument("--reconnect", type=float, default=3.0,
                    help="seconds between reconnects, 0 to disable")
    args = ap.parse_args()

    if not args.host:
        ap.error("--host or DOORBELL_HOST is required")
    if not args.login_hex:
        ap.error("--login-hex or LOGIN_HEX is required")

    def log(msg):
        print(f"[ctv_client ch{args.channel}] {msg}", file=sys.stderr, flush=True)

    login = build_login(args.login_hex, args.channel)
    stream(args.host, args.port, login, args.reconnect, log)


if __name__ == "__main__":
    main()
