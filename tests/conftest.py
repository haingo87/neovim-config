import json
import os
import socket
import subprocess
import sys
import time
import uuid

import pytest

DAEMON_SCRIPT = os.path.join(os.path.dirname(__file__), "..", "nvim-daemon")


@pytest.fixture
def daemon_socket():
    """Start a test daemon and yield its socket path."""
    tag = uuid.uuid4().hex[:8]
    state_dir = f"/tmp/nd-{tag}"
    os.makedirs(state_dir, exist_ok=True)
    sock_path = os.path.join(state_dir, "s")
    log_path = os.path.join(state_dir, "l")

    proc = subprocess.Popen(
        [sys.executable, DAEMON_SCRIPT, "--socket", sock_path, "--log-file", log_path, "--foreground", "--test"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    for _ in range(50):
        if os.path.exists(sock_path):
            break
        time.sleep(0.1)
    else:
        proc.terminate()
        raise RuntimeError(f"Daemon did not start. Log: {open(log_path).read() if os.path.exists(log_path) else 'none'}")

    yield sock_path

    proc.terminate()
    proc.wait(timeout=5)
    import shutil
    shutil.rmtree(state_dir, ignore_errors=True)


@pytest.fixture
def client(daemon_socket):
    """Connect a client to the daemon and yield the socket."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(daemon_socket)
    sock.settimeout(5)
    yield sock
    sock.close()


def send_and_recv(sock, msg):
    """Send a JSON message and receive the response."""
    sock.sendall((json.dumps(msg) + "\n").encode())
    data = b""
    while b"\n" not in data:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("Daemon closed connection")
        data += chunk
    return json.loads(data.split(b"\n")[0])
