# Web wallpapers on Hyprland (2026-10-03). Started by the stand-in ./linux-wallpaperengine as process
# "linux-wallpaperengine-web" with the Wallpaper Engine app's renderer arguments, so the app's
# pkill -f "linux-wallpaperengine.*--screen-root.*<screen>" stops it; the host child gets SIGTERM when this dies.
# Runs ~/.local/bin/wallpaper-engine-hyprland (built from the KDE plugin repo, hyprland/ folder, with the local
# patch ~/.local/share/wallpaper-engine-hyprland-local.patch: background layer, so the shell's widgets stay above,
# and an "audio" IPC command + window.wallpaperRegisterAudioListener for audio-reactive pages).
# The real renderer (linux-wallpaperengine-git) crashes on every web wallpaper ("close symbol missing").
# Pauses the page while the monitor shows a fullscreen window.
import ctypes, json, os, signal, subprocess, sys, time

HOST = os.path.expanduser("~/.local/bin/wallpaper-engine-hyprland")
WORKSHOP = os.path.expanduser("~/.local/share/Steam/steamapps/workshop/content/431960")

args = sys.argv[1:]
screens, bg, fps, silent, volume, props = [], None, None, False, 100, {}
i = 0
while i < len(args):
    a = args[i]
    v = args[i + 1] if i + 1 < len(args) else None
    if a == "--screen-root": screens.append(v); i += 1
    elif a == "--bg": bg = v; i += 1
    elif a == "--fps": fps = v; i += 1
    elif a == "--volume": volume = int(float(v)); i += 1
    elif a == "--silent": silent = True
    elif a == "--set-property" and v and "=" in v:
        k, _, val = v.partition("="); props[k] = val; i += 1
    i += 1
if not bg or not screens:
    sys.exit(1)
if not os.path.isdir(bg):
    bg = os.path.join(WORKSHOP, bg)

instance = "we-" + "-".join(screens)
cmd = [HOST, "run", bg, "--instance", instance]
for s in screens:
    cmd += ["--output", s]
if fps:
    cmd += ["--fps", str(fps)]
if not silent and volume > 0:
    cmd.append("--audio")

# The app's per-wallpaper settings (--set-property name=value, strings), typed using project.json
# general.properties; the host validates them and passes them to applyUserProperties on top of the defaults.
def typed(raw, d):
    t = d.get("type")
    if t == "bool": return raw in ("true", "1")
    if t == "slider":
        try: f = float(raw); return int(f) if f.is_integer() and not d.get("fraction", True) else f
        except ValueError: return None
    if t == "combo":
        for o in d.get("options", []):
            if str(o.get("value")) == raw: return o.get("value")
        return raw
    return raw  # color ("r g b"), textinput, file, ...
if props:
    try:
        defs = json.load(open(os.path.join(bg, "project.json"))).get("general", {}).get("properties", {})
    except Exception:
        defs = {}
    values = {k: typed(v, defs[k]) for k, v in props.items() if k in defs}
    values = {k: v for k, v in values.items() if v is not None}
    if values:
        cmd += ["--properties", json.dumps(values)]

libc = ctypes.CDLL("libc.so.6", use_errno=True)
def die_with_parent():
    libc.prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG

env = dict(os.environ, QT_FORCE_STDERR_LOGGING="1")
child = subprocess.Popen(cmd, preexec_fn=die_with_parent, env=env,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
signal.signal(signal.SIGTERM, lambda *_: (child.terminate(), sys.exit(0)))

def hyprctl(what):
    try:
        return json.loads(subprocess.run(["hyprctl", what, "-j"], capture_output=True, text=True, timeout=3).stdout)
    except Exception:
        return None

def fullscreen_on_screens():
    mons, wss = hyprctl("monitors"), hyprctl("workspaces")
    if mons is None or wss is None:
        return False
    active = {m["activeWorkspace"]["id"] for m in mons if m["name"] in screens}
    return any(w.get("hasfullscreen") and w["id"] in active for w in wss)

# Audio spectrum for pages that call wallpaperRegisterAudioListener: capture what the speakers play (default sink
# monitor), 64 log-spaced bands per channel (left then right, values 0..1, like Wallpaper Engine), ~30 frames/s,
# sent to the host's "audio" IPC command. Silence sends one zero frame, then nothing until sound returns.
def uses_audio(root):
    for dirpath, _, files in os.walk(root):
        for f in files:
            if f.endswith((".js", ".html", ".htm")):
                try:
                    if "wallpaperRegisterAudioListener" in open(os.path.join(dirpath, f), errors="ignore").read():
                        return True
                except OSError:
                    pass
    return False

def audio_loop():
    import socket, threading
    import numpy as np
    sock_path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
                             "wallpaper-engine-hyprland", instance + ".sock")
    rate, n = 48000, 2048
    rec = subprocess.Popen(["parec", "-d", "@DEFAULT_MONITOR@", "--format=float32le", "--channels=2",
                            f"--rate={rate}", "--raw", "--latency-msec=20"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)
    window = np.hanning(n).astype(np.float32)
    freqs = np.fft.rfftfreq(n, 1 / rate)
    edges = np.geomspace(30, 16000, 65)
    band_idx = [np.where((freqs >= edges[i]) & (freqs < edges[i + 1]))[0] for i in range(64)]
    band_idx = [ix if ix.size else np.array([np.argmin(abs(freqs - edges[i]))]) for i, ix in enumerate(band_idx)]
    buf = np.zeros((n, 2), dtype=np.float32)
    smooth = np.zeros(128, dtype=np.float32)
    chunk = rate // 30
    sent_silence = False
    while child.poll() is None:
        raw = rec.stdout.read(chunk * 8)
        if not raw:
            break
        frames = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)
        buf = np.concatenate([buf, frames])[-n:]
        if paused:
            continue
        out = []
        for ch in (0, 1):
            mag = np.abs(np.fft.rfft(buf[:, ch] * window)) / (n / 4)
            bands = np.array([mag[ix].max() for ix in band_idx])
            db = 20 * np.log10(bands + 1e-9)
            out.append(np.clip((db + 70) / 60, 0, 1))
        cur = np.concatenate(out).astype(np.float32)
        smooth = np.where(cur > smooth, cur, smooth * 0.85 + cur * 0.15)  # fast attack, slow decay
        silent = float(smooth.max()) < 0.01
        if silent and sent_silence:
            continue
        sent_silence = silent
        msg = json.dumps({"protocol": 1, "command": "audio",
                          "values": [round(float(v), 4) for v in (np.zeros(128) if silent else smooth)]})
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.5)
            s.connect(sock_path)
            s.sendall(msg.encode() + b"\n")
            s.recv(4096)
            s.close()
        except OSError:
            pass  # host not listening yet / restarting
    rec.terminate()

paused = False  # read by audio_loop; updated by the loop below
if uses_audio(bg):
    import threading
    threading.Thread(target=audio_loop, daemon=True).start()

paused = False
while child.poll() is None:
    time.sleep(1)
    fs = fullscreen_on_screens()
    if fs != paused:
        subprocess.run([HOST, "pause" if fs else "resume", "--instance", instance],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        paused = fs
sys.exit(child.returncode or 0)
