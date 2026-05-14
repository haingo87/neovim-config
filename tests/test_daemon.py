import json
import os
import socket
import time

from conftest import send_and_recv


def _real(p):
    return os.path.realpath(p)


def test_ping(client):
    resp = send_and_recv(client, {"cmd": "ping"})
    assert resp["status"] == "ok"


def test_register_and_list(daemon_socket, client):
    resp = send_and_recv(client, {
        "cmd": "register",
        "pid": 99990,
        "project_root": "/tmp/test-project",
        "socket": "/tmp/test-project.sock",
    })
    assert resp["status"] == "ok"

    resp = send_and_recv(client, {"cmd": "list"})
    assert resp["status"] == "ok"
    assert len(resp["instances"]) == 1
    assert resp["instances"][0]["project_root"] == _real("/tmp/test-project")


def test_register_duplicate(daemon_socket, client):
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99991,
        "project_root": "/tmp/test-dup",
        "socket": "/tmp/test-dup.sock",
    })

    sock2 = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock2.connect(daemon_socket)
    sock2.settimeout(5)

    resp = send_and_recv(sock2, {
        "cmd": "register",
        "pid": 99992,
        "project_root": "/tmp/test-dup",
        "socket": "/tmp/test-dup-2.sock",
    })
    assert resp["status"] == "dup"
    assert resp["socket"] == "/tmp/test-dup.sock"
    sock2.close()


def test_unregister(daemon_socket, client):
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99993,
        "project_root": "/tmp/test-unreg",
        "socket": "/tmp/test-unreg.sock",
    })

    resp = send_and_recv(client, {
        "cmd": "unregister",
        "socket": "/tmp/test-unreg.sock",
    })
    assert resp["status"] == "ok"

    resp = send_and_recv(client, {"cmd": "list"})
    assert len(resp["instances"]) == 0


def test_open_routed_to_project(daemon_socket, client):
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99994,
        "project_root": "/tmp/test-project",
        "socket": "/tmp/test-project.sock",
    })

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/test-project/src/main.lua",
    })
    assert resp["status"] == "routed"
    assert resp["socket"] == "/tmp/test-project.sock"


def test_open_no_match_returns_no_instance(daemon_socket, client):
    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/unrelated/file.txt",
    })
    assert resp["status"] == "no_instance"


def test_open_routed_to_orphan(daemon_socket, client):
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99995,
        "project_root": "/tmp/orphan-home",
        "socket": "/tmp/orphan.sock",
        "orphan": True,
    })

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/unrelated/file.txt",
    })
    assert resp["status"] == "routed"
    assert resp["socket"] == "/tmp/orphan.sock"


def test_open_directory(daemon_socket, client):
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99996,
        "project_root": "/tmp/test-dir",
        "socket": "/tmp/test-dir.sock",
    })

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/test-dir",
    })
    assert resp["status"] == "routed"
    assert resp["socket"] == "/tmp/test-dir.sock"


def test_open_with_line_col(daemon_socket, client):
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99997,
        "project_root": "/tmp/test-line",
        "socket": "/tmp/test-line.sock",
    })

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/test-line/main.lua",
        "line": 42,
        "col": 10,
    })
    assert resp["status"] == "routed"
    assert resp["line"] == 42
    assert resp["col"] == 10


def test_register_then_open(daemon_socket):
    """Register a project, then open a file in it."""
    import socket as sock_mod
    client = sock_mod.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(daemon_socket)
    client.settimeout(5)

    resp = send_and_recv(client, {
        "cmd": "register",
        "pid": 90001,
        "project_root": "/tmp/integration-project",
        "socket": "/tmp/integration-project.sock",
    })
    assert resp["status"] == "ok"

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/integration-project/src/main.py",
    })
    assert resp["status"] == "routed"
    assert resp["socket"] == "/tmp/integration-project.sock"
    client.close()


def test_orphan_fallback(daemon_socket):
    """Files outside any project root route to the orphan."""
    import socket as sock_mod
    client = sock_mod.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(daemon_socket)
    client.settimeout(5)

    resp = send_and_recv(client, {
        "cmd": "register",
        "pid": 90002,
        "project_root": "/tmp/orphan-home",
        "socket": "/tmp/orphan.sock",
        "orphan": True,
    })
    assert resp["status"] == "ok"

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/unrelated/scratch.txt",
    })
    assert resp["status"] == "routed"
    assert resp["socket"] == "/tmp/orphan.sock"
    client.close()


def test_register_unregister_cycle(daemon_socket):
    """Register, verify in list, unregister, verify gone."""
    import socket as sock_mod
    client = sock_mod.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(daemon_socket)
    client.settimeout(5)

    send_and_recv(client, {
        "cmd": "register",
        "pid": 90003,
        "project_root": "/tmp/cycle-project",
        "socket": "/tmp/cycle-project.sock",
    })

    resp = send_and_recv(client, {"cmd": "list"})
    assert any(i["project_root"].endswith("cycle-project") for i in resp["instances"])

    send_and_recv(client, {"cmd": "unregister", "socket": "/tmp/cycle-project.sock"})

    resp = send_and_recv(client, {"cmd": "list"})
    assert not any(i["project_root"].endswith("cycle-project") for i in resp["instances"])
    client.close()


def test_no_instance_for_unknown_path(daemon_socket):
    """Path not matching any project and no orphan returns no_instance."""
    import socket as sock_mod
    client = sock_mod.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(daemon_socket)
    client.settimeout(5)

    resp = send_and_recv(client, {
        "cmd": "open",
        "path": "/tmp/unknown/file.txt",
    })
    assert resp["status"] == "no_instance"
    client.close()
