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
import subprocess
import sys
import time

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
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
        break
threads = os.cpu_count() or 1
cores = len({read(p) for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/topology/core_id")}) or threads
freq_paths = sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"),
                    key=lambda p: int(re.search(r"cpu(\d+)", p).group(1)))
cpu_max_mhz = read_int("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq") / 1000
governor = read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", "")
driver = read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver", "")
k10 = next(hwmon_by_name("k10temp"), None) or next(hwmon_by_name("coretemp"), None)
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
    except OSError:
        return None
    total = st.f_blocks * st.f_frsize
    used = (st.f_blocks - st.f_bfree) * st.f_frsize
    return {"path": path, "used": used, "total": total}


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
    cpu_temp = temps.get("Tctl") or temps.get("Tdie") or temps.get("Package id 0") or 0
    ccd_temps = [v for k, v in sorted(temps.items()) if k.startswith("Tccd")]

    energy = read_int(os.path.join(rapl, "energy_uj"), None)
    cpu_power = None
    if energy is not None and prev_energy is not None:
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
        "disks": [d for d in (disk("/home"), disk("/")) if d],
        "nvme": [{"model": model, "temp": labelled_temps(h).get("Composite", read_int(os.path.join(h, "temp1_input")) / 1000)}
                 for h, model in nvmes],
        "net": net,
        "sys": {
            "uptime": uptime, "procs": procs,
            "powerMeasured": measured, "powerOther": OTHER_SYSTEM_W, "powerEstimate": measured + OTHER_SYSTEM_W,
        },
    }
    print(json.dumps(sample, separators=(",", ":")), flush=True)
