"""Builds the Studio installer: studio/bundle.json (every script and place
setting, as data) and studio/install.luau (the code the Command Bar line runs).

Run from the block-horde folder after changing anything in src/ or
default.project.json:  python3 tools/build_installer.py
Then commit and push; the Command Bar line always installs the newest push.
"""
import hashlib, json, os, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = "will51mps0n/Adam-Simpson-Portfolio"
BRANCH = "claude/great-pascal-ej3sv8"
BUNDLE_PATH = "block-horde/studio/bundle.json"

# Enum-valued properties used in default.project.json, and their enum type.
ENUMS = {
    "Technology": "Technology",
    "DevComputerMovementMode": "DevComputerMovementMode",
    "DevTouchMovementMode": "DevTouchMovementMode",
}
# Settings Studio may refuse to change from a script; skip them quietly.
OPTIONAL = {"Technology"}
SERVICES = {"ReplicatedStorage", "ServerScriptService", "StarterPlayer", "Players", "Lighting", "Workspace", "StarterGui"}


def script_entry(parent, file_path):
    name = os.path.basename(file_path)
    if name.endswith(".server.luau"):
        cls, base = "Script", name[: -len(".server.luau")]
    elif name.endswith(".client.luau"):
        cls, base = "LocalScript", name[: -len(".client.luau")]
    elif name.endswith(".luau"):
        cls, base = "ModuleScript", name[: -len(".luau")]
    else:
        return None
    with open(file_path, encoding="utf-8") as f:
        source = f.read()
    return {"parent": parent, "name": base, "class": cls, "source": source}


def walk_dir(parent, name, dir_path, replaces, out):
    out.append({"parent": parent, "name": name, "class": "Folder", "replaces": replaces})
    here = parent + "/" + name
    for entry in sorted(os.listdir(dir_path)):
        full = os.path.join(dir_path, entry)
        if os.path.isdir(full):
            walk_dir(here, entry, full, False, out)
        else:
            item = script_entry(here, full)
            if item:
                out.append(item)


def walk_tree(node, path, scripts, properties):
    for key, value in node.get("$properties", {}).items():
        setting = {"path": path, "property": key}
        if key in ENUMS:
            setting.update(kind="Enum", value=[ENUMS[key], value])
        elif isinstance(value, list) and len(value) == 3:
            setting.update(kind="Color3", value=value)
        else:
            setting.update(kind="Value", value=value)
        if key in OPTIONAL:
            setting["optional"] = True
        properties.append(setting)
    for child, spec in node.items():
        if child.startswith("$"):
            continue
        child_path = path + [child]
        if "$path" in spec:
            target = os.path.join(ROOT, spec["$path"])
            parent = "/".join(path)
            if os.path.isdir(target):
                walk_dir(parent, child, target, True, scripts)
            else:
                item = script_entry(parent, target)
                item["name"] = child
                item["replaces"] = True
                scripts.append(item)
        else:
            walk_tree(spec, child_path, scripts, properties)


def main():
    with open(os.path.join(ROOT, "default.project.json")) as f:
        project = json.load(f)
    scripts, properties = [], []
    for service, spec in project["tree"].items():
        if service.startswith("$"):
            continue
        walk_tree(spec, [service], scripts, properties)

    digest = hashlib.sha1(json.dumps(scripts, sort_keys=True).encode()).hexdigest()[:8]
    bundle = {
        "build": time.strftime("%Y-%m-%d") + "-" + digest,
        "scripts": scripts,
        "properties": properties,
    }
    os.makedirs(os.path.join(ROOT, "studio"), exist_ok=True)
    with open(os.path.join(ROOT, "studio", "bundle.json"), "w", encoding="utf-8") as f:
        json.dump(bundle, f, indent=1)
        f.write("\n")
    with open(os.path.join(ROOT, "tools", "install_template.luau"), encoding="utf-8") as f:
        template = f.read()
    install = (
        template.replace("{{REPO}}", REPO)
        .replace("{{BRANCH}}", BRANCH)
        .replace("{{BUNDLE_PATH}}", BUNDLE_PATH)
    )
    with open(os.path.join(ROOT, "studio", "install.luau"), "w", encoding="utf-8") as f:
        f.write(install)
    count = sum(1 for s in scripts if "source" in s)
    print("bundle %s: %d scripts, %d settings" % (bundle["build"], count, len(properties)))


if __name__ == "__main__":
    main()
