#!/usr/bin/env python3
"""GPU statistics for the bar resources widgets: AMD, NVIDIA and Intel (2026-10-04, ours; not upstream).

No root needed. Used by scripts/sysstats/sysstats.py (import) and by the classic widget's get_gpuinfo.sh and
get_power.sh (command line):

  gpustats.py json      one sample as JSON (or null when no supported GPU is found)
  gpustats.py info      classic text: "  Usage : 12 %", "  VRAM : 1.2/16.0 GB", "  Temp : 45 °C"
  gpustats.py power     classic text: "  Draw : 30.5 W", "  Cap : 250.0 W"

Sources:
  AMD (amdgpu)       sysfs: gpu_busy_percent, mem_info_vram_*, hwmon (temps, power, fan, clocks, voltage)
  NVIDIA (nvidia)    nvidia-smi (comes with the driver). A GPU in runtime power-down (laptops) is not queried, since
                     a query would wake it; it reports as sleeping instead. nouveau has no usage data: unsupported.
  Intel (i915, xe)   usage = 1 - share of time in the RC6 idle state (rc6_residency_ms / idle_residency_ms), current
                     clock, and for Arc cards power/temperature from hwmon. Integrated GPUs use system RAM (no VRAM)
                     and share the CPU temperature, so those values are absent.
Several GPUs: a dedicated card is preferred over integrated graphics. GPU_CARD=card1 (or AMD_GPU_CARD) picks one.
GPUSTATS_SYS points at a fake /sys tree (testing).
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

SYS = os.environ.get("GPUSTATS_SYS", "/sys")
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "quickshell-sysstats")


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def read_int(path, default=0):
    try:
        return int(read(path, default))
    except (TypeError, ValueError):
        return default


def num(text):
    """nvidia-smi field -> float, or None for [N/A] / [Not Supported]."""
    try:
        return float(text)
    except (TypeError, ValueError):
        return None


def clean_name(raw):
    """"Intel(R) Iris(R) Xe Graphics (ADL GT2)" -> "Intel Iris Xe Graphics"; "AMD Radeon RX 7800 XT (RADV NAVI32)" ->
    "Radeon RX 7800 XT"; "NVIDIA GeForce RTX 4060" -> "GeForce RTX 4060"."""
    name = re.sub(r"\((R|TM)\)", "", raw)
    name = re.sub(r"\s*\([^()]*\)\s*$", "", name)          # only a final bracketed note (driver / codename)
    name = re.sub(r"^(AMD|NVIDIA)\s+", "", name.strip())
    return re.sub(r"\s+", " ", name).strip()


def vulkan_name(pci_id):
    """Marketing name from vulkaninfo for vendor:device (slow, so cached per PCI id)."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache = os.path.join(CACHE_DIR, "gpu-name")
    cached_id, _, cached_name = (read(cache, "") or "").partition("\t")
    if cached_id == pci_id and cached_name:
        return cached_name
    name = ""
    try:
        # only the non-NVIDIA Vulkan drivers: loading NVIDIA's can wake a powered-down laptop GPU
        icds = [f for f in glob.glob("/usr/share/vulkan/icd.d/*.json") if "nvidia" not in os.path.basename(f).lower()]
        env = dict(os.environ, VK_DRIVER_FILES=":".join(icds), VK_ICD_FILENAMES=":".join(icds)) if icds else None
        out = subprocess.run(["vulkaninfo", "--summary"], capture_output=True, text=True, timeout=8, env=env).stdout
        for block in re.split(r"\nGPU\d+:", out):
            ids = dict(re.findall(r"(vendorID|deviceID)\s*=\s*(0x[0-9a-fA-F]+)", block))
            m = re.search(r"deviceName\s*=\s*(.+)", block)
            if m and f"{ids.get('vendorID', '').lower()}:{ids.get('deviceID', '').lower()}" == pci_id.lower():
                name = clean_name(m.group(1))
                break
    except (OSError, subprocess.SubprocessError):
        pass
    if name:
        with open(cache, "w") as f:
            f.write(f"{pci_id}\t{name}")
    return name


class Gpu:
    vendor = ""
    integrated = False
    temp_warn = 95

    def __init__(self, card):
        self.card = card                                   # /sys/class/drm/cardN
        self.dev = os.path.join(card, "device")
        self.slot = os.path.basename(os.path.realpath(self.dev))
        self.pci_id = f"{(read(os.path.join(self.dev, 'vendor'), '') or '').lower()}:{(read(os.path.join(self.dev, 'device'), '') or '').lower()}"
        hw = sorted(glob.glob(os.path.join(self.dev, "hwmon", "hwmon*")))
        self.hwmon = hw[0] if hw else None
        self._name = None

    def hw(self, name, default=0):
        return read_int(os.path.join(self.hwmon, name), default) if self.hwmon else default

    @property
    def name(self):
        if self._name is None:
            self._name = vulkan_name(self.pci_id)
        return self._name

    def base(self):
        return {"vendor": self.vendor, "name": self.name, "integrated": self.integrated, "sleeping": False,
                "busy": 0.0, "vramUsed": 0, "vramTotal": 0, "sclk": 0, "mclk": 0,
                "temp": 0, "temps": [], "tempWarn": self.temp_warn,
                "power": 0.0, "powerCap": 0.0, "fan": None, "fanPercent": None, "mv": None}


class Amd(Gpu):
    vendor = "AMD"

    def __init__(self, card):
        super().__init__(card)
        self.integrated = read_int(os.path.join(self.dev, "mem_info_vram_total")) < 2 * 1024 ** 3   # APU carve-out

    def sample(self):
        s = self.base()
        temps = {}
        if self.hwmon:
            for lf in glob.glob(os.path.join(self.hwmon, "temp*_label")):
                v = read_int(lf.replace("_label", "_input"), None)
                if v is not None:
                    temps[read(lf)] = v / 1000
        power = self.hw("power1_average") or self.hw("power1_input")
        s.update({
            "busy": read_int(os.path.join(self.dev, "gpu_busy_percent")) / 100,
            "vramUsed": read_int(os.path.join(self.dev, "mem_info_vram_used")),
            "vramTotal": read_int(os.path.join(self.dev, "mem_info_vram_total")),
            "sclk": self.hw("freq1_input") / 1e6, "mclk": self.hw("freq2_input") / 1e6,
            "temps": [[k, temps[k]] for k in ("edge", "junction", "mem") if k in temps],
            "temp": temps.get("junction") or temps.get("edge") or 0,
            "power": power / 1e6, "powerCap": self.hw("power1_cap") / 1e6,
        })
        if self.hwmon and os.path.exists(os.path.join(self.hwmon, "fan1_input")):
            s["fan"] = self.hw("fan1_input")
        if self.hwmon and os.path.exists(os.path.join(self.hwmon, "in0_input")):
            s["mv"] = self.hw("in0_input")
        s["temps"] = [["hotspot" if k == "junction" else k, v] for k, v in s["temps"]]
        return s


class Nvidia(Gpu):
    vendor = "NVIDIA"
    temp_warn = 87
    FIELDS = "name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed,clocks.gr,clocks.mem"

    def __init__(self, card):
        super().__init__(card)
        self.smi = shutil.which("nvidia-smi")
        bus = self.slot.split(":", 1)
        self.bus_id = f"0000{self.slot}" if len(bus[0]) == 4 else self.slot     # nvidia-smi: 00000000:01:00.0
        self._name = read(os.path.join(CACHE_DIR, "nvidia-name-" + self.slot), "") or ""

    @property
    def name(self):            # from nvidia-smi while awake (cached); never vulkaninfo, which can wake the card
        return self._name

    def sample(self):
        s = self.base()
        if read(os.path.join(self.dev, "power", "runtime_status"), "active") == "suspended":
            s["sleeping"] = True                    # powered down by the driver (laptops); a query would wake it
            return s
        try:
            out = subprocess.run([self.smi, "-i", self.bus_id, "--query-gpu=" + self.FIELDS,
                                  "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=4).stdout
        except (OSError, subprocess.SubprocessError):
            return s
        f = [x.strip() for x in out.strip().split("\n")[0].split(",")] if out.strip() else []
        if len(f) < 10:
            return s
        name = clean_name(f[0])
        if name and name != self._name:
            self._name = name
            os.makedirs(CACHE_DIR, exist_ok=True)
            with open(os.path.join(CACHE_DIR, "nvidia-name-" + self.slot), "w") as fh:
                fh.write(name)
        mib = 1024 * 1024
        temp = num(f[4])
        s.update({
            "busy": (num(f[1]) or 0) / 100,
            "vramUsed": int((num(f[2]) or 0) * mib), "vramTotal": int((num(f[3]) or 0) * mib),
            "temp": temp or 0, "temps": [["core", temp]] if temp is not None else [],
            "power": num(f[5]) or 0.0, "powerCap": num(f[6]) or 0.0,
            "fanPercent": num(f[7]), "sclk": num(f[8]) or 0, "mclk": num(f[9]) or 0, "name": self._name or "",
        })
        return s


class Intel(Gpu):
    vendor = "Intel"

    def __init__(self, card):
        super().__init__(card)
        self.integrated = self.slot.endswith(":00:02.0")          # Intel integrated graphics sit at 00:02.0
        xe = os.path.basename(os.path.realpath(os.path.join(self.dev, "driver"))) == "xe"
        if xe:
            gt = os.path.join(self.dev, "tile0", "gt0")
            self.idle_path = os.path.join(gt, "gtidle", "idle_residency_ms")
            self.freq_path = os.path.join(gt, "freq0", "act_freq")
        else:
            self.idle_path = next((p for p in (os.path.join(card, "gt", "gt0", "rc6_residency_ms"),
                                               os.path.join(card, "power", "rc6_residency_ms")) if os.path.exists(p)), "")
            self.freq_path = next((p for p in (os.path.join(card, "gt", "gt0", "rps_act_freq_mhz"),
                                               os.path.join(card, "gt_act_freq_mhz")) if os.path.exists(p)), "")
        self.prev_idle = None
        self.prev_energy = None

    def sample(self, wait=0.0):
        s = self.base()
        now, idle = time.monotonic(), read_int(self.idle_path, None)
        if wait and self.prev_idle is None and idle is not None:    # one-shot callers: measure over a short window
            self.prev_idle, self.prev_energy = (now, idle), (now, self.hw("energy1_input", None))
            time.sleep(wait)
            now, idle = time.monotonic(), read_int(self.idle_path, None)
        if idle is not None and self.prev_idle is not None and now > self.prev_idle[0]:
            idle_share = (idle - self.prev_idle[1]) / ((now - self.prev_idle[0]) * 1000)
            s["busy"] = max(0.0, min(1.0, 1 - idle_share))
        self.prev_idle = (now, idle) if idle is not None else None
        s["sclk"] = read_int(self.freq_path)
        energy = self.hw("energy1_input", None)                      # Arc: microjoules
        if energy is not None and self.prev_energy and self.prev_energy[1] is not None and now > self.prev_energy[0]:
            s["power"] = max(0.0, (energy - self.prev_energy[1]) / 1e6 / (now - self.prev_energy[0]))
        self.prev_energy = (now, energy)
        s["powerCap"] = self.hw("power1_max") / 1e6 if self.hwmon else 0.0
        t = self.hw("temp1_input", None) if self.hwmon else None
        if t:
            s["temp"], s["temps"] = t / 1000, [["core", t / 1000]]
        return s


DRIVERS = {"amdgpu": Amd, "nvidia": Nvidia, "i915": Intel, "xe": Intel}


def detect_all():
    """Every supported GPU, the one to show first: a dedicated card before integrated graphics; GPU_CARD /
    AMD_GPU_CARD move the named card to the front."""
    found = []
    for card in sorted(glob.glob(os.path.join(SYS, "class", "drm", "card[0-9]*"))):
        if not re.fullmatch(r"card\d+", os.path.basename(card)):
            continue
        drv = os.path.basename(os.path.realpath(os.path.join(card, "device", "driver")))
        cls = DRIVERS.get(drv)
        if cls is Amd and not os.path.exists(os.path.join(card, "device", "gpu_busy_percent")):
            continue
        if cls is Nvidia and not shutil.which("nvidia-smi"):
            continue
        if cls:
            found.append(cls(card))
    found.sort(key=lambda g: g.integrated)
    want = os.environ.get("GPU_CARD") or os.environ.get("AMD_GPU_CARD")
    chosen = [g for g in found if want and os.path.basename(g.card) == want]
    return chosen or found                       # GPU_CARD: exactly that card (shown as "Off" while it sleeps)


def sample_best(gpus, **kw):
    """Sample of the first GPU that is awake: a powered-down laptop GPU gives way to the integrated one."""
    first = None
    for g in gpus:
        s = g.sample(**kw) if isinstance(g, Intel) else g.sample()
        if first is None:
            first = s
        if not s.get("sleeping"):
            return s
    return first


def detect():
    """The GPU to show: a dedicated card before integrated graphics; GPU_CARD / AMD_GPU_CARD override."""
    found = []
    for card in sorted(glob.glob(os.path.join(SYS, "class", "drm", "card[0-9]*"))):
        if not re.fullmatch(r"card\d+", os.path.basename(card)):
            continue
        drv = os.path.basename(os.path.realpath(os.path.join(card, "device", "driver")))
        cls = DRIVERS.get(drv)
        if cls is Amd and not os.path.exists(os.path.join(card, "device", "gpu_busy_percent")):
            continue
        if cls is Nvidia and not shutil.which("nvidia-smi"):
            continue
        if cls:
            found.append(cls(card))
    want = os.environ.get("GPU_CARD") or os.environ.get("AMD_GPU_CARD")
    for g in found:
        if want and os.path.basename(g.card) == want:
            return g
    found.sort(key=lambda g: g.integrated)       # stable: dedicated first, then card order
    return found[0] if found else None


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "json"
    gpus = detect_all()
    s = sample_best(gpus, wait=0.25) if gpus else None
    if cmd == "json":
        print(json.dumps(s))
    elif cmd == "info":
        if not s:
            print("No GPU available.")
            sys.exit(1)
        gb = 1024 ** 3
        print(f"[{s['vendor']} GPU]")
        print(f"  Usage : {round(s['busy'] * 100)} %")
        print(f"  VRAM : {s['vramUsed'] / gb:.1f}/{s['vramTotal'] / gb:.1f} GB")
        edge = next((v for k, v in s["temps"] if k == "edge"), None)    # the classic widget has always shown edge
        t = edge if edge is not None else s["temp"]
        if t:                                          # no temperature line when the card reports none
            print(f"  Temp : {round(t)} °C")
    elif cmd == "power":
        if not s or not s["power"]:
            print("No power data available.")
            sys.exit(1)
        print("[GPU Power]")
        print(f"  Draw : {s['power']:.1f} W")
        print(f"  Cap : {s['powerCap']:.1f} W")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
