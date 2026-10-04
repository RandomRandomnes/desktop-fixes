#!/usr/bin/env python3
"""Default apps helper for the Windows 11 style settings.

  defaultapps.py list            -> JSON: {category: {"current": id, "candidates": [{id, name, icon}]}}
  defaultapps.py set CAT ID      -> make ID (desktop file id, e.g. firefox.desktop) the default for CAT
"""
import configparser, glob, json, os, subprocess, sys

CATEGORIES = {
    "browser":  ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"],
    "files":    ["inode/directory"],
    "text":     ["text/plain"],
    "image":    ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/svg+xml"],
    "video":    ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"],
    "music":    ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"],
    "pdf":      ["application/pdf"],
    "mail":     ["x-scheme-handler/mailto"],
    "archive":  ["application/zip", "application/x-7z-compressed", "application/x-tar", "application/x-rar"],
}


def app_dirs():
    data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    dirs = [data_home] + data_dirs + ["/var/lib/flatpak/exports/share", os.path.expanduser("~/.local/share/flatpak/exports/share")]
    seen, out = set(), []
    for d in dirs:
        p = os.path.join(d, "applications")
        if p not in seen and os.path.isdir(p):
            seen.add(p)
            out.append(p)
    return out


def entries():
    found = {}
    for d in app_dirs():
        for f in glob.glob(os.path.join(d, "**", "*.desktop"), recursive=True):
            did = os.path.relpath(f, d).replace("/", "-")
            if did in found:
                continue  # earlier dirs take precedence
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            if e.get("NoDisplay", "false").lower() == "true" or e.get("Hidden", "false").lower() == "true":
                found[did] = None
                continue
            found[did] = {
                "id": did,
                "name": e.get("Name", did),
                "icon": e.get("Icon", ""),
                "mimes": [m for m in e.get("MimeType", "").split(";") if m],
            }
    return {k: v for k, v in found.items() if v}


def query_default(mime):
    try:
        return subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        return ""


def cmd_list():
    ents = entries()
    out = {}
    for cat, mimes in CATEGORIES.items():
        cands = [e for e in ents.values() if any(m in e["mimes"] for m in mimes)]
        cands.sort(key=lambda e: e["name"].lower())
        out[cat] = {
            "current": query_default(mimes[0]),
            "candidates": [{"id": e["id"], "name": e["name"], "icon": e["icon"]} for e in cands],
        }
    print(json.dumps(out))


def cmd_set(cat, did):
    if cat not in CATEGORIES:
        sys.exit(f"unknown category {cat}")
    ents = entries()
    if did not in ents:
        sys.exit(f"unknown app {did}")
    # only claim the types the app says it can open (plus the primary one)
    mimes = [m for m in CATEGORIES[cat] if m in ents[did]["mimes"]] or CATEGORIES[cat][:1]
    subprocess.run(["xdg-mime", "default", did] + mimes, check=False)
    if cat == "browser":
        subprocess.run(["xdg-settings", "set", "default-web-browser", did], check=False)
    print(json.dumps({"ok": True, "set": mimes}))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        cmd_list()
    elif len(sys.argv) == 4 and sys.argv[1] == "set":
        cmd_set(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
