#!/usr/bin/env python3
"""M9.5 acceptance: drive one full OpenMaps flow entirely through the MCP server.

Prerequisites (bridge mode):
    adb shell am start -n app.camelus.maps/.MainActivity \
        --es openmaps.control.port 7981
    adb forward tcp:7981 tcp:7981

Run:  python3 tool/openmaps_cli/acceptance/mcp_flow.py
"""
import json
import subprocess
import sys

CLI = [
    "dart", "run", "tool/openmaps_cli/bin/openmaps_cli.dart",
    "mcp", "--connect", "127.0.0.1:7981",
]

proc = subprocess.Popen(CLI, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        text=True, bufsize=1)
_next_id = 0


def rpc(method, params=None):
    global _next_id
    _next_id += 1
    message = {"jsonrpc": "2.0", "id": _next_id, "method": method}
    if params is not None:
        message["params"] = params
    proc.stdin.write(json.dumps(message) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        raise SystemExit("MCP server closed the connection")
    return json.loads(line)


def tool(name, arguments=None):
    params = {"name": name}
    if arguments is not None:
        params["arguments"] = arguments
    return rpc("tools/call", params)["result"]


def exec_command(method, params=None):
    result = tool("openmaps_execute",
                  {"method": method, **({"params": params} if params else {})})
    assert result.get("isError") is False, f"{method} failed: {result}"
    return json.loads(result["content"][0]["text"])


def check(label, condition):
    print(("PASS " if condition else "FAIL ") + label)
    if not condition:
        sys.exit(1)


def main():
    info = rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}})
    check("initialize", info["result"]["serverInfo"]["name"] == "openmaps-cli")

    state = json.loads(tool("openmaps_state")["content"][0]["text"])
    check("state is debug/profile with a Mapbox token",
          state["buildMode"] in ("debug", "profile") and state["config"]["hasMapboxToken"])

    commands = json.loads(tool("openmaps_list_commands")["content"][0]["text"])
    ids = {c["id"] for c in commands}
    check("registry exposes route/nav/ui commands",
          {"search.query", "place.select", "route.plan", "nav.start", "ui.tap"} <= ids)

    exec_command("nav.stop")
    exec_command("place.clear")

    results = exec_command("search.query", {"text": "Alexanderplatz, Berlin"})
    check("search returns results", len(results) > 0)
    place_id = results[0]["id"]
    check("search hit has an id", bool(place_id))

    place = exec_command("place.select", {"id": place_id})
    check("place.select focuses the place", place["id"] == place_id)

    route = exec_command("route.plan", {"id": place_id})
    check("route.plan returns geometry", route["distanceMeters"] > 0 and route["geometryPoints"] > 0)

    nav = exec_command("nav.start", {"live": True})
    check("nav.start begins guidance", nav["status"] == "navigating")

    screenshot = tool("openmaps_screenshot")
    block = screenshot["content"][0]
    check("screenshot is an image", block["type"] == "image" and block["mimeType"] == "image/png")

    exec_command("nav.stop")
    check("nav.stop ends guidance", exec_command("nav.state")["status"] != "navigating")

    proc.stdin.close()
    print("MCP acceptance flow: PASS")


if __name__ == "__main__":
    main()
