#!/usr/bin/env python3
"""System stats sampler for the bar resources widget (2026-10-03, ours; not upstream).

Runs as one long-lived process (services/SystemStats.qml) and prints one JSON object per line every INTERVAL seconds
(argv[1], default 1). Reads sysfs/procfs only, no root needed: CPU usage, per-thread clocks, temps (k10temp), package
power (RAPL energy counter), GPU (AMD, NVIDIA or Intel via scripts/gpu/gpustats.py), memory, zram, disks,
NVMe temps, uptime, processes, network throughput, and an estimated total system power.
"""
import glob
import json
import os
import re
import sys
import time

try:   # at least 0.2 s (0 would loop without pause); not a number: the default (F20)
    INTERVAL = max(0.2, float(sys.argv[1])) if len(sys.argv) > 1 else 1.0
except ValueError:
    INTERVAL = 1.0
# rest of the system (board, RAM, drives, fans, USB) is not metered; a fixed estimate is added to CPU + GPU
OTHER_SYSTEM_W = 20.0
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


def hwmon_by_name(name):
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(os.path.join(h, "name")) == name:
            yield h


def labelled_temps(h):
    temps = {}
    for label_file in glob.glob(os.path.join(h, "temp*_label")):
        value = read_int(label_file.replace("_label", "_input"), None)
        if value is not None:
            temps[read(label_file)] = value / 1000
    return temps


# ---- static info (once) -------------------------------------------------------------------------------------
cpu_model = ""
for line in open("/proc/cpuinfo"):
    if line.startswith("model name"):
        cpu_model = re.sub(r"\s+\d+-Core Processor$", "", line.split(":", 1)[1].strip()).replace("AMD ", "")
        # Intel: "Intel(R) Core(TM) i7-12700K CPU @ 3.60GHz" -> "Core i7-12700K"
        cpu_model = re.sub(r"\s+CPU\s+@.*$|\s*@\s*[\d.]+\s*GHz$", "", cpu_model)
        cpu_model = re.sub(r"\((R|TM|tm)\)", "", cpu_model).replace("Intel ", "").replace(" CPU ", " ").replace("  ", " ").strip()
        break
threads = os.cpu_count() or 1
# physical cores: core ids repeat on each CPU package (multi-socket), so count (package, core) pairs
cores = len({(read(os.path.join(d, "physical_package_id")), read(os.path.join(d, "core_id")))
             for d in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/topology")}) or threads
freq_paths = sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"),
                    key=lambda p: int(re.search(r"cpu(\d+)", p).group(1)))
# highest clock any core reports (0 where cpufreq isn't available, e.g. many VMs: the UI then leaves it out)
cpu_max_mhz = max([read_int(p) for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq")] or [0]) / 1000
governor = read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", "")
driver = read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver", "")
# CPU temperature sensor: AMD (k10temp, or the zenpower driver), Intel (coretemp); otherwise a thermal zone
# (x86_pkg_temp, or acpitz on many laptops/VMs). None found: the temperature is reported as unknown, not 0.
k10 = next((h for n in ("k10temp", "zenpower", "coretemp") for h in hwmon_by_name(n)), None)
cpu_zone = None
if not k10:
    for want in ("x86_pkg_temp", "acpitz"):
        cpu_zone = next((z for z in sorted(glob.glob("/sys/class/thermal/thermal_zone*"))
                         if read(os.path.join(z, "type")) == want), None)
        if cpu_zone:
            break
rapl = "/sys/class/powercap/intel-rapl:0"
rapl_max = read_int(os.path.join(rapl, "max_energy_range_uj"), 0)

# GPU: AMD, NVIDIA or Intel (scripts/gpu/gpustats.py, shared with the classic widget)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "gpu"))
try:
    import gpustats
    gpu_devs = gpustats.detect_all()
    gpu_dev = gpu_devs[0] if gpu_devs else None
except Exception:        # never let GPU detection stop the CPU/RAM/disk stats
    gpu_dev = None

nvmes = []
for h in hwmon_by_name("nvme"):
    model = read(os.path.join(h, "device/model"), "") or "NVMe"
    nvmes.append((h, model.strip()))
mem_total_kb = 0


# ---- sampling ------------------------------------------------------------------------------------------------
def cpu_times():
    with open("/proc/stat") as f:
        parts = [int(x) for x in f.readline().split()[1:]]
    idle = parts[3] + parts[4]
    return sum(parts[:8]), idle


def net_bytes():
    rx = tx = 0
    with open("/proc/net/dev") as f:
        for line in list(f)[2:]:
            name, data = line.split(":", 1)
            name = name.strip()
            if name == "lo" or name.startswith(("veth", "docker", "br-", "virbr")):
                continue
            fields = data.split()
            rx += int(fields[0])
            tx += int(fields[8])
    return rx, tx


def meminfo():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, value = line.split(":", 1)
            info[key] = int(value.split()[0])
    return info


def disk(path):
    try:
        st = os.statvfs(path)
        dev = os.stat(path).st_dev
    except OSError:
        return None
    total = st.f_blocks * st.f_frsize
    used = (st.f_blocks - st.f_bfree) * st.f_frsize
    return {"path": path, "used": used, "total": total, "dev": dev}


def disks():
    """/home and /, once each: when /home is on the system partition only "/" is listed (F20)."""
    out = []
    for d in (disk("/home"), disk("/")):
        if d and not any(o["dev"] == d["dev"] for o in out):
            out.append(d)
    if len(out) == 1:
        out[0]["path"] = "/"
    return [{k: v for k, v in d.items() if k != "dev"} for d in out]


METER = "/run/phoenix-power/cpu.json"


def meter_watts():
    """CPU package watts from phoenix-power-meter.service (the counter itself stays root-only; F21). None if the
    meter isn't installed, isn't running (reading older than 5 s) or the CPU has no counter."""
    try:
        with open(METER) as f:
            m = json.load(f)
        return float(m["cpuWatts"]) if m.get("cpuWatts") is not None and time.time() - m.get("time", 0) < 5 else None
    except (OSError, ValueError, KeyError, TypeError):
        return None


prev_cpu = cpu_times()
prev_energy = read_int(os.path.join(rapl, "energy_uj"), None)
prev_net = net_bytes()
prev_time = time.monotonic()

while True:
    time.sleep(INTERVAL)
    now = time.monotonic()
    dt = max(now - prev_time, 1e-3)
    prev_time = now

    total, idle = cpu_times()
    dtotal, didle = total - prev_cpu[0], idle - prev_cpu[1]
    prev_cpu = (total, idle)
    cpu_usage = max(0.0, min(1.0, 1 - didle / dtotal)) if dtotal > 0 else 0.0

    freqs = [read_int(p) / 1000 for p in freq_paths]
    temps = labelled_temps(k10) if k10 else {}
    cpu_temp = temps.get("Tctl") or temps.get("Tdie") or temps.get("Package id 0") or (max(temps.values()) if temps else None)
    if cpu_temp is None and cpu_zone:
        z = read_int(os.path.join(cpu_zone, "temp"), None)
        cpu_temp = z / 1000 if z else None
    ccd_temps = [v for k, v in sorted(temps.items()) if k.startswith("Tccd")]

    energy = read_int(os.path.join(rapl, "energy_uj"), None)
    cpu_power = meter_watts()   # the root power meter's coarse reading, when it runs (phoenix power-meter)
    if cpu_power is None and energy is not None and prev_energy is not None:
        delta = energy - prev_energy
        if delta < 0 and rapl_max:
            delta += rapl_max
        cpu_power = delta / 1e6 / dt
    prev_energy = energy

    gpu = None
    if gpu_dev:
        try:
            gpu = gpustats.sample_best(gpu_devs)
        except Exception:
            gpu = None

    mi = meminfo()
    zram = None
    mm = read("/sys/block/zram0/mm_stat")
    if mm:
        fields = mm.split()
        zram = {"orig": int(fields[0]), "compr": int(fields[1]), "used": int(fields[2]),
                "algo": re.search(r"\[(\w+)\]", read("/sys/block/zram0/comp_algorithm", "") or "")}
        zram["algo"] = zram["algo"].group(1) if zram["algo"] else ""

    rx, tx = net_bytes()
    net = {"rx": max(0, rx - prev_net[0]) / dt, "tx": max(0, tx - prev_net[1]) / dt}
    prev_net = (rx, tx)

    with open("/proc/loadavg") as f:
        load = [float(x) for x in f.read().split()[:3]]
    uptime = float((read("/proc/uptime", "0") or "0").split()[0])
    procs = sum(1 for d in os.listdir("/proc") if d.isdigit())

    measured = (cpu_power or 0) + (gpu["power"] if gpu else 0)
    sample = {
        "cpu": {
            "model": cpu_model, "cores": cores, "threads": threads,
            "usage": cpu_usage, "freqs": freqs,
            "freqAvg": sum(freqs) / len(freqs) if freqs else 0, "freqMax": cpu_max_mhz,
            "temp": cpu_temp, "ccd": ccd_temps, "power": cpu_power,
            # why power is missing: the counter is root-only on most kernels, or the CPU has none (F21)
            "powerNote": "" if cpu_power is not None else ("power meter not installed"
                                                            if os.path.exists(os.path.join(rapl, "energy_uj")) else "not available"),
            "load": load, "governor": governor, "driver": driver,
        },
        "gpu": gpu,
        "mem": {
            "total": mi.get("MemTotal", 0) * 1024, "available": mi.get("MemAvailable", 0) * 1024,
            "cached": (mi.get("Cached", 0) + mi.get("SReclaimable", 0)) * 1024,
            "used": (mi.get("MemTotal", 0) - mi.get("MemAvailable", 0)) * 1024,
            "swapTotal": mi.get("SwapTotal", 0) * 1024, "swapUsed": (mi.get("SwapTotal", 0) - mi.get("SwapFree", 0)) * 1024,
            "zram": zram,
        },
        "disks": disks(),
        "nvme": [{"model": model, "temp": labelled_temps(h).get("Composite", read_int(os.path.join(h, "temp1_input")) / 1000)}
                 for h, model in nvmes],
        "net": net,
        "sys": {
            "uptime": uptime, "procs": procs,
            "powerMeasured": measured, "powerOther": OTHER_SYSTEM_W, "powerEstimate": measured + OTHER_SYSTEM_W,
        },
    }
    print(json.dumps(sample, separators=(",", ":")), flush=True)
