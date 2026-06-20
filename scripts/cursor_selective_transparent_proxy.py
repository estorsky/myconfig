#!/usr/bin/env python3

import argparse
import datetime as dt
import ipaddress
import socket
import struct
import threading


SO_ORIGINAL_DST = 80


def log(message: str) -> None:
    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    print(f"[{timestamp}] {message}", flush=True)


def tune_socket(sock: socket.socket) -> None:
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

    tcp_keepidle = getattr(socket, "TCP_KEEPIDLE", None)
    tcp_keepintvl = getattr(socket, "TCP_KEEPINTVL", None)
    tcp_keepcnt = getattr(socket, "TCP_KEEPCNT", None)
    tcp_user_timeout = getattr(socket, "TCP_USER_TIMEOUT", None)

    if tcp_keepidle is not None:
        sock.setsockopt(socket.IPPROTO_TCP, tcp_keepidle, 30)
    if tcp_keepintvl is not None:
        sock.setsockopt(socket.IPPROTO_TCP, tcp_keepintvl, 10)
    if tcp_keepcnt is not None:
        sock.setsockopt(socket.IPPROTO_TCP, tcp_keepcnt, 3)
    if tcp_user_timeout is not None:
        sock.setsockopt(socket.IPPROTO_TCP, tcp_user_timeout, 45000)


def get_original_destination(conn: socket.socket) -> tuple[str, int]:
    raw = conn.getsockopt(socket.SOL_IP, SO_ORIGINAL_DST, 16)
    port = struct.unpack("!H", raw[2:4])[0]
    host = socket.inet_ntoa(raw[4:8])
    return host, port


def is_ipv4_address(value: str) -> bool:
    try:
        return isinstance(ipaddress.ip_address(value), ipaddress.IPv4Address)
    except ValueError:
        return False


def parse_tls_sni(data: bytes) -> str | None:
    if len(data) < 5 or data[0] != 0x16:
        return None

    record_len = int.from_bytes(data[3:5], "big")
    if len(data) < 5 + record_len:
        return None

    body = memoryview(data)[5 : 5 + record_len]
    if len(body) < 4 or body[0] != 0x01:
        return None

    hello_len = int.from_bytes(body[1:4], "big")
    if len(body) < 4 + hello_len:
        return None

    idx = 4
    idx += 2  # legacy_version
    idx += 32  # random
    if idx >= len(body):
        return None

    session_id_len = body[idx]
    idx += 1 + session_id_len
    if idx + 2 > len(body):
        return None

    cipher_suites_len = int.from_bytes(body[idx : idx + 2], "big")
    idx += 2 + cipher_suites_len
    if idx >= len(body):
        return None

    compression_methods_len = body[idx]
    idx += 1 + compression_methods_len
    if idx + 2 > len(body):
        return None

    extensions_len = int.from_bytes(body[idx : idx + 2], "big")
    idx += 2
    end = idx + extensions_len

    while idx + 4 <= end and idx + 4 <= len(body):
        ext_type = int.from_bytes(body[idx : idx + 2], "big")
        ext_len = int.from_bytes(body[idx + 2 : idx + 4], "big")
        idx += 4
        ext_end = idx + ext_len
        if ext_end > len(body):
            return None

        if ext_type == 0x0000:
            if idx + 2 > ext_end:
                return None
            server_name_list_len = int.from_bytes(body[idx : idx + 2], "big")
            pos = idx + 2
            limit = min(ext_end, pos + server_name_list_len)
            while pos + 3 <= limit:
                name_type = body[pos]
                name_len = int.from_bytes(body[pos + 1 : pos + 3], "big")
                pos += 3
                if pos + name_len > limit:
                    return None
                if name_type == 0:
                    try:
                        return bytes(body[pos : pos + name_len]).decode("utf-8")
                    except UnicodeDecodeError:
                        return None
                pos += name_len

        idx = ext_end

    return None


SETUP_TIMEOUT_SECONDS = 12


def socks5_connect(socks_host: str, socks_port: int, dst_host: str, dst_port: int) -> socket.socket:
    upstream = socket.create_connection((socks_host, socks_port), timeout=SETUP_TIMEOUT_SECONDS)
    tune_socket(upstream)
    upstream.settimeout(SETUP_TIMEOUT_SECONDS)
    upstream.sendall(b"\x05\x01\x00")

    reply = upstream.recv(2)
    if len(reply) != 2 or reply[0] != 0x05 or reply[1] != 0x00:
        raise RuntimeError("SOCKS5 authentication negotiation failed")

    if is_ipv4_address(dst_host):
        request = b"\x05\x01\x00\x01" + socket.inet_aton(dst_host) + struct.pack("!H", dst_port)
    else:
        host_bytes = dst_host.encode("idna")
        if len(host_bytes) > 255:
            raise RuntimeError("SOCKS5 destination hostname is too long")
        request = b"\x05\x01\x00\x03" + bytes([len(host_bytes)]) + host_bytes + struct.pack("!H", dst_port)

    upstream.sendall(request)

    header = upstream.recv(4)
    if len(header) != 4 or header[0] != 0x05 or header[1] != 0x00:
        raise RuntimeError("SOCKS5 connect failed")

    atyp = header[3]
    if atyp == 0x01:
        to_read = 4 + 2
    elif atyp == 0x03:
        length = upstream.recv(1)
        if len(length) != 1:
            raise RuntimeError("SOCKS5 connect failed while reading domain length")
        to_read = length[0] + 2
    elif atyp == 0x04:
        to_read = 16 + 2
    else:
        raise RuntimeError(f"Unsupported SOCKS5 address type: {atyp}")

    data = b""
    while len(data) < to_read:
        chunk = upstream.recv(to_read - len(data))
        if not chunk:
            raise RuntimeError("SOCKS5 connect failed while reading bind address")
        data += chunk

    upstream.settimeout(None)
    return upstream


def pump(src: socket.socket, dst: socket.socket) -> None:
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass
        try:
            src.close()
        except OSError:
            pass
        try:
            dst.close()
        except OSError:
            pass


def handle_client(conn: socket.socket, socks_host: str, socks_port: int) -> None:
    initial_data = b""
    try:
        tune_socket(conn)
        dst_host, dst_port = get_original_destination(conn)
        connect_host = dst_host

        if dst_port == 443:
            conn.settimeout(1.0)
            try:
                initial_data = conn.recv(8192)
            except TimeoutError:
                initial_data = b""
            finally:
                conn.settimeout(None)

            sni_host = parse_tls_sni(initial_data) if initial_data else None
            if sni_host:
                connect_host = sni_host

        log(f"accepted redirected connection to {dst_host}:{dst_port} (proxy target {connect_host})")
        upstream = socks5_connect(socks_host, socks_port, connect_host, dst_port)
        log(f"socks5 connect established to {connect_host}:{dst_port} via {socks_host}:{socks_port}")
        if initial_data:
            upstream.sendall(initial_data)
    except Exception as exc:
        log(f"connection setup failed: {exc!r}")
        try:
            conn.close()
        except OSError:
            pass
        return

    threading.Thread(target=pump, args=(conn, upstream), daemon=True).start()
    threading.Thread(target=pump, args=(upstream, conn), daemon=True).start()


def main() -> None:
    parser = argparse.ArgumentParser(description="Transparent TCP to SOCKS5 bridge for Cursor selective routing")
    parser.add_argument("--listen-host", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, default=12335)
    parser.add_argument("--socks-host", default="127.0.0.1")
    parser.add_argument("--socks-port", type=int, default=12334)
    args = parser.parse_args()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.listen_host, args.listen_port))
    server.listen()
    log(
        f"transparent proxy listening on {args.listen_host}:{args.listen_port}, "
        f"upstream socks={args.socks_host}:{args.socks_port}"
    )

    while True:
        conn, _ = server.accept()
        threading.Thread(
            target=handle_client,
            args=(conn, args.socks_host, args.socks_port),
            daemon=True,
        ).start()


if __name__ == "__main__":
    main()
