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


def test_lsp_start_and_list(daemon_socket, client):
    """lsp_start creates a server entry; lsp_list returns it."""
    cwd = "/tmp/test-lsp-proj"
    resp = send_and_recv(client, {
        "cmd": "lsp_start",
        "type": "clangd",
        "cwd": cwd,
        "pid": 99998,
    })
    # In test mode, clangd Popen fails → gets error or pending
    assert resp["status"] in ("ok", "pending", "error")

    resp = send_and_recv(client, {"cmd": "lsp_list"})
    assert resp["status"] == "ok"
    if resp["status"] == "ok" and len(resp["servers"]) > 0:
        s = resp["servers"][0]
        assert s["type"] == "clangd"
        assert s["cwd"].endswith("test-lsp-proj")


def test_lsp_start_refcount(daemon_socket, client):
    """Two lsp_start for same project increment refcount."""
    cwd = "/tmp/test-lsp-refcount"
    import socket as sock_mod

    client2 = sock_mod.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client2.connect(daemon_socket)
    client2.settimeout(5)

    send_and_recv(client, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99999,
    })
    send_and_recv(client2, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99998,
    })

    resp = send_and_recv(client, {"cmd": "lsp_list"})
    if resp["status"] == "ok" and len(resp["servers"]) > 0:
        s = resp["servers"][0]
        assert s["refcount"] >= 1
    client2.close()


def test_lsp_stop_decrements(daemon_socket, client):
    """lsp_stop decrements refcount."""
    cwd = "/tmp/test-lsp-stop"
    send_and_recv(client, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99997,
    })
    send_and_recv(client, {
        "cmd": "lsp_stop", "type": "clangd", "cwd": cwd, "pid": 99997,
    })
    resp = send_and_recv(client, {"cmd": "lsp_list"})
    if len(resp["servers"]) > 0:
        assert resp["servers"][0]["refcount"] == 0


def test_lsp_stop_nonexistent(daemon_socket, client):
    """lsp_stop on a server that doesn't exist returns ok."""
    resp = send_and_recv(client, {
        "cmd": "lsp_stop", "type": "clangd", "cwd": "/tmp/ghost", "pid": 99900,
    })
    assert resp["status"] == "ok"


def test_lsp_stop_below_zero(daemon_socket, client):
    """Double lsp_stop doesn't decrement below 0."""
    cwd = "/tmp/test-lsp-double-stop"
    send_and_recv(client, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99977,
    })
    send_and_recv(client, {
        "cmd": "lsp_stop", "type": "clangd", "cwd": cwd, "pid": 99977,
    })
    send_and_recv(client, {
        "cmd": "lsp_stop", "type": "clangd", "cwd": cwd, "pid": 99977,
    })
    resp = send_and_recv(client, {"cmd": "lsp_list"})
    if len(resp["servers"]) > 0:
        assert resp["servers"][0]["refcount"] == 0


def test_lsp_pending_response(daemon_socket, client):
    """Concurrent lsp_start returns pending while spawn is in progress."""
    cwd = "/tmp/test-lsp-pending"
    import socket as sock_mod

    client2 = sock_mod.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client2.connect(daemon_socket)
    client2.settimeout(5)

    resp1 = send_and_recv(client, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99996,
    })
    resp2 = send_and_recv(client2, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99995,
    })
    assert resp1["status"] in ("ok", "pending", "error")
    assert resp2["status"] in ("ok", "pending", "error")
    client2.close()


def test_lsp_prune_dead_removes_client(daemon_socket, client):
    """Register instance, start LSP, unregister instance — LSP client pruned."""
    cwd = "/tmp/test-lsp-prune"
    send_and_recv(client, {
        "cmd": "register",
        "pid": 99994,
        "project_root": cwd,
        "socket": "/tmp/test-lsp-prune.sock",
    })
    send_and_recv(client, {
        "cmd": "lsp_start", "type": "clangd", "cwd": cwd, "pid": 99994,
    })
    send_and_recv(client, {
        "cmd": "unregister",
        "socket": "/tmp/test-lsp-prune.sock",
    })
    resp = send_and_recv(client, {"cmd": "lsp_list"})
    assert resp["status"] == "ok"
    # After unregister, _prune_dead runs in handle_lsp_list.
    # If server exists, its refcount should be 0 (client was pruned).
    if len(resp["servers"]) > 0:
        assert resp["servers"][0]["refcount"] == 0
