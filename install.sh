#!/usr/bin/env bash
# Phoenix installer: a Windows-style desktop for Arch Linux on top of illogical-impulse (Hyprland).
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/RandomRandomnes/phoenix/main/install.sh)
#   or: git clone https://github.com/RandomRandomnes/phoenix && cd phoenix && ./install.sh
#
# Needs Arch Linux with Hyprland. Installs illogical-impulse first if it is missing (its official installer, after
# asking). Every step is shown and asks before changing anything; files Phoenix replaces are backed up, and
# `phoenix uninstall` puts them back. Phoenix files come from the newest signed release, checked against the key below.
set -euo pipefail

REPO="RandomRandomnes/phoenix"
END4_REPO="https://github.com/pctrade/end4-pC.git"
END4_COMMIT="166221ac0ea467d995a440ce097a7d09df578d79"   # fallback; normally the newest release names its own commit
SIGNER='custom-fixes namespaces="custom-fixes" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKnbnJ3PHwZ6xygmFRpLEsfTAmsPc1fuy0UtHNKRKTCl custom-fixes'
PACKAGES=(git python openssh patch curl jq efibootmgr pciutils vulkan-tools kitty kdialog libnotify flatpak)
AUR_PACKAGES=(hyprland-plugin-hyprbars)             # title bars for Windows-style windows
STATE="$HOME/.local/state/phoenix"
SWAP=(".config/hypr/custom" ".config/illogical-impulse/config.json")   # shared with illogical-impulse: swapped, never deleted

B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    %s%s%s\n' "$Y" "$*" "$N"; }
die() { printf '%sPhoenix installer: %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
ask() {   # ask "question" default(y/n)
    local a d="$2"; [ -n "${PHOENIX_YES:-}" ] && { [ "$d" = y ]; return; }
    read -r -p "    $1 [$([ "$d" = y ] && echo Y/n || echo y/N)] " a </dev/tty || a=""
    a="${a:-$d}"; [[ "$a" =~ ^[yY] ]]
}

printf '%sPhoenix%s: a Windows-style desktop for Arch Linux, built on illogical-impulse (Hyprland).\n' "$B" "$N"
echo "Nothing is changed until you confirm each step."

# ── 1. checks ──────────────────────────────────────────────────────────────────────────────────────────────────────
step "Checking this system"
[ "$(id -u)" != 0 ] || die "run it as your normal user (it asks for the password when needed), not as root"
[ -f /etc/arch-release ] || die "Phoenix needs Arch Linux"
pacman -Q hyprland >/dev/null 2>&1 || die "Hyprland is not installed (sudo pacman -S hyprland)"
info "Arch Linux, $(pacman -Q hyprland)"
if [ -f "$STATE/installed.json" ]; then
    echo "    Phoenix is already installed. Use: phoenix status | activate | deactivate | uninstall"
    echo "    Updates come through the update button (or: custom-update apply)."
    exit 0
fi
curl -fsS -o /dev/null https://api.github.com || die "no internet connection"

# ── 2. illogical-impulse ───────────────────────────────────────────────────────────────────────────────────────────
step "illogical-impulse"
has_ii() { [ -d "$HOME/.config/quickshell/ii" ] && [ -f "$HOME/.config/hypr/hyprland.lua" ] && command -v qs >/dev/null; }
if has_ii; then
    info "found"
else
    warn "illogical-impulse is not installed. Phoenix is built on it."
    info "Its official installer can set it up now: bash <(curl -s https://ii.clsty.link/get)"
    info "It shows every command before running it and asks questions of its own."
    ask "Run the illogical-impulse installer now?" y || die "install illogical-impulse first, then run this installer again"
    bash <(curl -s https://ii.clsty.link/get) </dev/tty || die "the illogical-impulse installer did not finish"
    has_ii || die "illogical-impulse still isn't complete; finish its installation, then run this installer again"
fi
[ -f "$HOME/.config/hypr/hyprland.lua" ] || die "this illogical-impulse uses the old Hyprland config format; Phoenix needs the Lua version (Hyprland 0.55 or newer). Update illogical-impulse first"

# ── 3. packages ────────────────────────────────────────────────────────────────────────────────────────────────────
step "Packages Phoenix uses"
missing=(); for p in "${PACKAGES[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
    info "To install: ${missing[*]}"
    ask "Install them now (asks for your password)?" y || die "these packages are needed"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
else
    info "all present"
fi
helper=$(command -v yay || command -v paru || true)
aur_missing=(); for p in "${AUR_PACKAGES[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || aur_missing+=("$p"); done
if [ ${#aur_missing[@]} -gt 0 ]; then
    if [ -n "$helper" ]; then
        info "From the AUR: ${aur_missing[*]} (title bars for Windows-style windows)"
        if ask "Install with $(basename "$helper")?" y; then "$helper" -S --needed --noconfirm "${aur_missing[@]}" || warn "not installed; title bars stay off"; fi
    else
        warn "No AUR helper (yay/paru): ${aur_missing[*]} is not installed, so windows have no title bars."
    fi
fi

# ── 4. the end4-pC shell ───────────────────────────────────────────────────────────────────────────────────────────
step "Shell (end4-pC, the illogical-impulse fork Phoenix extends)"
mkdir -p "$STATE"
# the exact commit the newest Phoenix release was made on (from the signed release index; fallback: END4_COMMIT)
T=$(mktemp -d)
curl -fsSL -o "$T/i.json" "https://github.com/$REPO/releases/download/index/index.json" \
    && curl -fsSL -o "$T/i.sig" "https://github.com/$REPO/releases/download/index/index.json.sig" \
    || die "can't download the Phoenix release index"
printf '%s\n' "$SIGNER" > "$T/signers"
ssh-keygen -Y verify -f "$T/signers" -I custom-fixes -n custom-fixes -s "$T/i.sig" < "$T/i.json" >/dev/null 2>&1 \
    || die "the Phoenix release index has no valid signature"
want=$(python3 - "$T/i.json" <<'PY'
import json, sys
rel = [r for r in json.load(open(sys.argv[1]))["releases"] if r.get("line") == "custom" and not r.get("test")]
def key(r):
    w, _, f = r["label"].partition(".")
    return (int(w), int(f) * 10 if len(f) == 1 else int(f or 0))
print(max(rel, key=key).get("shell", "") if rel else "")
PY
)
rm -rf "$T"
want="${want:-$END4_COMMIT}"
E="$HOME/.config/quickshell/end4-pC"
if [ -d "$E/.git" ]; then
    echo no > "$STATE/cloned-end4pC"
    if git -C "$E" merge-base --is-ancestor "$want" HEAD 2>/dev/null; then
        info "already present ($(git -C "$E" rev-parse --short HEAD)); kept as it is"
    else
        warn "present but older than the version Phoenix needs (${want:0:8})"
        ask "Update it to that version?" y || die "Phoenix needs end4-pC ${want:0:8} or newer"
        git -C "$E" fetch -q origin && git -C "$E" merge -q --ff-only "$want" \
            || die "end4-pC has local changes, so it can't be updated automatically; update it, then run this installer again"
    fi
else
    info "Cloning $END4_REPO at the version Phoenix was made on (${want:0:8})"
    git clone -q "$END4_REPO" "$E" && git -C "$E" reset -q --hard "$want"
    echo yes > "$STATE/cloned-end4pC"
fi

# ── 5. Phoenix files from the newest signed release ────────────────────────────────────────────────────────────────
step "Phoenix files (newest signed release from github.com/$REPO)"
ask "Download and install them? Files they replace are backed up." y || die "stopped; nothing of Phoenix was installed"
for item in "${SWAP[@]}"; do                 # your own copies of the shared items, for switching back
    if [ -e "$HOME/$item" ]; then mkdir -p "$(dirname "$STATE/user-side/$item")"; cp -a "$HOME/$item" "$STATE/user-side/$item"; fi
done
STATE="$STATE" REPO="$REPO" SIGNER="$SIGNER" python3 - <<'PY'
import hashlib, io, json, os, subprocess, sys, tarfile, tempfile, urllib.request, datetime
HOME, STATE, REPO = os.path.expanduser("~"), os.environ["STATE"], os.environ["REPO"]
SWAP = (".config/hypr/custom/", ".config/illogical-impulse/config.json")
def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "phoenix-install"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()
signers = tempfile.NamedTemporaryFile("w", delete=False); signers.write(os.environ["SIGNER"] + "\n"); signers.close()
def verified(data, sig):
    with tempfile.NamedTemporaryFile("wb", delete=False) as f:
        f.write(sig)
    r = subprocess.run(["ssh-keygen", "-Y", "verify", "-f", signers.name, "-I", "custom-fixes", "-n", "custom-fixes", "-s", f.name],
                       input=data, capture_output=True)
    os.unlink(f.name)
    if r.returncode:
        sys.exit("    The download's signature is not valid; nothing was installed.")
    return json.loads(data)
dl = f"https://github.com/{REPO}/releases/download"
idx = verified(fetch(f"{dl}/index/index.json"), fetch(f"{dl}/index/index.json.sig"))
custom = [r for r in idx["releases"] if r.get("line") == "custom" and not r.get("test")]
def key(r):
    whole, _, frac = r["label"].partition(".")
    return (int(whole), int(frac) * 10 if len(frac) == 1 else int(frac or 0))
newest = max(custom, key=key)
m = verified(fetch(f"{dl}/custom-{newest['label']}/manifest.json"), fetch(f"{dl}/custom-{newest['label']}/manifest.json.sig"))
payload = fetch(f"{dl}/custom-{newest['label']}/{m['payload']}")
if hashlib.sha256(payload).hexdigest() != m["payloadSha256"]:
    sys.exit("    The download is corrupted; nothing was installed.")
contents = {}
with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
    for rel, digest in m["files"].items():
        if rel.startswith("/") or ".." in rel.split("/"):
            continue
        member = tar.getmember(rel); data = tar.extractfile(member).read()
        if hashlib.sha256(data).hexdigest() != digest:
            sys.exit(f"    {rel}: checksum mismatch; nothing was installed.")
        contents[rel] = (data, member.mode & 0o777)
added, backed = [], 0
for rel, (data, mode) in contents.items():
    dst = os.path.join(HOME, rel)
    shared = rel.startswith(SWAP)            # kept by the user-side copy instead
    if os.path.exists(dst):
        if not shared and open(dst, "rb").read() != data:
            bk = os.path.join(STATE, "backup", rel); os.makedirs(os.path.dirname(bk), exist_ok=True)
            with open(dst, "rb") as s, open(bk, "wb") as d:
                d.write(s.read())
            backed += 1
    elif not shared:
        added.append(rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst + ".phoenix-tmp", "wb") as f:
        f.write(data)
    os.chmod(dst + ".phoenix-tmp", mode); os.replace(dst + ".phoenix-tmp", dst)
with open(os.path.join(STATE, "added-files.txt"), "w") as f:
    f.write("\n".join(added) + "\n")
share = os.path.join(HOME, ".local/share/custom-fixes"); st = os.path.join(HOME, ".local/state/custom-fixes")
os.makedirs(share, exist_ok=True); os.makedirs(st, exist_ok=True)
json.dump({"scheme": 2, "label": newest["label"], "version": newest.get("version", 1.0), "system": []},
          open(os.path.join(share, "base.json"), "w"), indent=2)
json.dump({"scheme": 2, "label": newest["label"], "version": newest.get("version", 1.0),
           "files": {r: hashlib.sha256(d).hexdigest() for r, (d, _) in contents.items()}},
          open(os.path.join(st, "installed.json"), "w"), indent=2)
json.dump({"date": datetime.date.today().isoformat(), "custom": newest["label"]}, open(os.path.join(STATE, "installed.json"), "w"))
print(f"    Installed custom fixes {newest['label']}: {len(contents)} files ({len(added)} new, {backed} replaced and backed up)")
PY
echo yes > "$STATE/active"

step "System fixes for this system's versions"
"$HOME/.local/bin/custom-update" system-apply | sed 's/^/    /' || warn "system fixes could not be checked; the update button retries"

step "Phoenix defaults"
mkdir -p "$HOME/.local/state/quickshell/user" "$HOME/.local/state/setup-wizard"
echo "This file is just here to confirm you've been greeted :>" > "$HOME/.local/state/quickshell/user/first_run.txt"
touch "$HOME/.local/state/setup-wizard/pending"        # the Phoenix setup assistant opens at the next login
# without the running session's address: only settings for the next login are written, the current desktop stays as it is
env -u HYPRLAND_INSTANCE_SIGNATURE "$HOME/.local/bin/setup-profile" apply default --yes | sed 's/^/    /'

# ── 6. activate now or later ───────────────────────────────────────────────────────────────────────────────────────
step "Done installing"
if ask "Switch to Phoenix now? (No = keep your current setup; switch later with: phoenix activate)" y; then
    info "Phoenix is active. Log out and back in to start it; the setup assistant opens then."
    info "Back to your previous setup at any time: phoenix deactivate"
else
    for item in "${SWAP[@]}"; do               # Phoenix's copies aside, yours back in place
        mkdir -p "$(dirname "$STATE/phoenix-side/$item")"; rm -rf "$STATE/phoenix-side/$item"
        [ -e "$HOME/$item" ] && mv "$HOME/$item" "$STATE/phoenix-side/$item"
        [ -e "$STATE/user-side/$item" ] && mv "$STATE/user-side/$item" "$HOME/$item"
    done
    echo no > "$STATE/active"
    info "Phoenix is installed but not active; your setup is unchanged. Switch with: phoenix activate"
fi
info "Remove it completely: phoenix uninstall"
