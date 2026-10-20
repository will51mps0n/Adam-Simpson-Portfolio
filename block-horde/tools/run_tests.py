"""Runs tests/spec.luau and tests/sim.luau with the Luau command-line runtime.

Roblox modules load each other with require(script.Parent.X), which plain
Luau doesn't understand, so this copies src/shared (and the server modules the
enemy simulation needs) into tests/.build with those requires rewritten to file
paths, plus small stand-ins for the few Roblox globals they touch.

Run from the block-horde folder:  python3 tools/run_tests.py [path-to-luau]
"""
import os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src", "shared")
BUILD = os.path.join(ROOT, "tests", ".build")
SHIM = "local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end, new = function(r, g, b) return { r, g, b } end }\n"

def transform(text):
    text = re.sub(r"require\(script\.Parent\.Parent\.(\w+)\)", r'require("../\1")', text)
    text = re.sub(r"require\(script\.Parent\.(\w+)\.(\w+)\)", r'require("./\1/\2")', text)
    text = re.sub(r"require\(script\.Parent\.(\w+)\)", r'require("./\1")', text)
    if "Color3." in text:
        # Keep "--!strict" as the first line.
        lines = text.split("\n", 1)
        text = lines[0] + "\n" + SHIM + (lines[1] if len(lines) > 1 else "")
    return text

SERVER_MODULES = ["EnemyService", "KillContext", "RoomBuilder"]
PRELUDE = "local __rbx = require(\"../rbx\")\nlocal game, workspace, Random, Color3 = __rbx.game, __rbx.workspace, __rbx.Random, __rbx.Color3\n"


def transform_server(text):
    text = re.sub(r"require\(ReplicatedStorage\.Shared\.Net\)", 'require("../rbx_net")', text)
    text = re.sub(r"require\(ReplicatedStorage\.Shared\.Models\.(\w+)\)", r'require("../shared/Models/\1")', text)
    text = re.sub(r"require\(ReplicatedStorage\.Shared\.(\w+)\)", r'require("../shared/\1")', text)
    text = re.sub(r"require\(script\.Parent\.(\w+)\)", r'require("./\1")', text)
    lines = text.split("\n", 1)
    return lines[0] + "\n" + PRELUDE + (lines[1] if len(lines) > 1 else "")


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else shutil.which("luau") or "luau"
    shutil.rmtree(BUILD, ignore_errors=True)
    for folder, _, files in os.walk(SRC):
        for name in files:
            if not name.endswith(".luau"):
                continue
            rel = os.path.relpath(os.path.join(folder, name), SRC)
            out = os.path.join(BUILD, "shared", rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with open(os.path.join(folder, name)) as f:
                text = f.read()
            with open(out, "w") as f:
                f.write(transform(text))
    os.makedirs(os.path.join(BUILD, "server"), exist_ok=True)
    for name in SERVER_MODULES:
        with open(os.path.join(ROOT, "src", "server", name + ".luau")) as f:
            text = f.read()
        with open(os.path.join(BUILD, "server", name + ".luau"), "w") as f:
            f.write(transform_server(text))
    for name in ("spec.luau", "sim.luau", "rbx.luau", "rbx_net.luau"):
        shutil.copy(os.path.join(ROOT, "tests", name), os.path.join(BUILD, name))
    code = 0
    for test in ("spec.luau", "sim.luau"):
        print("== " + test)
        code = code or subprocess.call([luau, os.path.join(BUILD, test)])
    sys.exit(code)

if __name__ == "__main__":
    main()
