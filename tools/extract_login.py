#!/usr/bin/env python3
"""
Extract the 88-byte XiongMai/CTV login frame from a packet capture.

Usage:
    python3 extract_login.py <capture.pcapng> [--host DOORBELL_IP] [--port 10510]

Prints the login frame as a hex string suitable for the add-on's ``login_hex``
option. Works with pktmon pcapng (deduplicates the physical/virtual copies) and
ordinary pcap. Requires scapy (``pip install scapy``).
"""
import argparse
import sys

try:
    from scapy.all import rdpcap, IP, TCP, Raw
except ImportError:
    sys.exit("scapy is required: pip install scapy")

LOGIN_LEN = 88
DEFAULT_PORT = 10510


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture")
    ap.add_argument("--host", help="doorbell IP (auto-detected if omitted)")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = ap.parse_args()

    pkts = rdpcap(args.capture)
    seen = set()
    for p in pkts:
        if not (p.haslayer(TCP) and p.haslayer(IP) and p.haslayer(Raw)):
            continue
        ip, tcp = p[IP], p[TCP]
        if tcp.dport != args.port:
            continue
        if args.host and ip.dst != args.host:
            continue
        payload = bytes(p[Raw].load)
        if len(payload) != LOGIN_LEN:
            continue
        # dedup pktmon's duplicated frames by TCP sequence
        if tcp.seq in seen:
            continue
        seen.add(tcp.seq)
        print(f"# doorbell {ip.dst}:{tcp.dport}, channel byte at index 80")
        print(payload.hex())
        return

    sys.exit(
        "No 88-byte login frame found. Make sure the capture includes the app "
        f"connecting to the doorbell on port {args.port} (reconnect the camera "
        "while capturing)."
    )


if __name__ == "__main__":
    main()
