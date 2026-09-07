#!/usr/bin/env python3
"""Launches a built Ruflet macOS app and proves the embedded Ruby app really ran.

Finds the port the app's embedded server bound (via lsof on its own pid), opens
the Ruflet WebSocket and sends register_client. The server answers that only
after running the whole application block and building its page, so a reply is
evidence the packaged Ruby app started and rendered -- not merely that a socket
was listening.

Usage: verify_app.py <App.app> [label]
"""

import base64
import os
import plistlib
import socket
import struct
import subprocess
import sys
import time

def bundle_binary(app):
    with open(os.path.join(app, "Contents", "Info.plist"), "rb") as handle:
        info = plistlib.load(handle)
    return os.path.join(app, "Contents", "MacOS", info["CFBundleExecutable"])

def listening_port(pid, deadline):
    """The embedded server's port, once it starts listening."""
    while time.time() < deadline:
        # -a matters: without it lsof ORs the selection criteria and reports
        # every listening socket on the machine, not just this process's.
        out = subprocess.run(
            ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP", "-sTCP:LISTEN"],
            capture_output=True, text=True).stdout
        for line in out.splitlines()[1:]:
            for field in line.split():
                if field.startswith("127.0.0.1:") or field.startswith("*:"):
                    return int(field.rsplit(":", 1)[1])
        time.sleep(0.02)
    return None

def encode_register():
    """MessagePack [1, {session_id, page_name, page:{route,width,height,platform}}]."""
    out = bytearray()
    def s(text):
        raw = text.encode()
        out.append(0xA0 | len(raw))
        out.extend(raw)
    def u16(value):
        out.append(0xCD)
        out.extend(struct.pack(">H", value))
    out.append(0x92); out.append(0x01)
    out.append(0x80 | 3)
    s("session_id"); s("")
    s("page_name"); s("")
    s("page")
    out.append(0x80 | 4)
    s("route"); s("/")
    s("width"); u16(1024)
    s("height"); u16(768)
    s("platform"); s("macos")
    return bytes(out)

def ws_frame(payload):
    """Client -> server binary frame, masked as the protocol requires."""
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    header = bytearray([0x82])
    length = len(payload)
    if length < 126:
        header.append(0x80 | length)
    elif length < 1 << 16:
        header.append(0x80 | 126); header.extend(struct.pack(">H", length))
    else:
        header.append(0x80 | 127); header.extend(struct.pack(">Q", length))
    return bytes(header) + mask + masked

def read_frame(sock):
    def need(n):
        buf = b""
        while len(buf) < n:
            chunk = sock.recv(n - len(buf))
            if not chunk:
                raise EOFError("socket closed")
            buf += chunk
        return buf
    first, second = need(2)
    length = second & 0x7F
    if length == 126:
        length = struct.unpack(">H", need(2))[0]
    elif length == 127:
        length = struct.unpack(">Q", need(8))[0]
    return first & 0x0F, need(length)

def main():
    app = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(app)

    started = time.time()
    process = subprocess.Popen(
        [bundle_binary(app)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = started + 60
        port = listening_port(process.pid, deadline)
        if port is None:
            print(f"{label}: FAILED - no listening port within 60s")
            return 1
        bound = time.time()

        sock = socket.create_connection(("127.0.0.1", port), timeout=30)
        key = base64.b64encode(os.urandom(16)).decode()
        sock.sendall(
            f"GET /ws HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n".encode())
        handshake = b""
        while b"\r\n\r\n" not in handshake:
            handshake += sock.recv(4096)
        if b"101" not in handshake.split(b"\r\n")[0]:
            print(f"{label}: FAILED - upgrade rejected: {handshake.splitlines()[0]!r}")
            return 1

        sock.sendall(ws_frame(encode_register()))
        opcode, payload = read_frame(sock)
        rendered = time.time()
        sock.close()

        if opcode != 2 or len(payload) < 2 or payload[0] != 0x92 or payload[1] != 0x01:
            print(f"{label}: FAILED - unexpected reply {payload[:8].hex()}")
            return 1

        print(f"{label}: OK  port={port}  "
              f"server_bound={(bound - started) * 1000:.0f}ms  "
              f"page_rendered={(rendered - started) * 1000:.0f}ms  "
              f"page_patch={len(payload)}B")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()

if __name__ == "__main__":
    sys.exit(main())
