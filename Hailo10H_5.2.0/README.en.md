<p align="center">
  <img align="center" alt="logo" src="docs/static/img/branding/frigate.png">
</p>

# Frigate NVR with Hailo-10H support (HailoRT 5.2.0)

\[English\] | [Español](README.md)

> **Unofficial fork / community project.** Not affiliated with or endorsed by
> [Frigate, Inc.](https://frigate.video), the [Frigate](https://github.com/blakeblackshear/frigate)
> project, or [Hailo](https://hailo.ai). "Frigate" and "Frigate NVR" are trademarks of
> Frigate, Inc. See [TRADEMARK.md](TRADEMARK.md) and [LICENSE](LICENSE).

This repository is a fork of **[blakeblackshear/frigate](https://github.com/blakeblackshear/frigate)**
(based on `v0.17.0`, MIT) with the changes required to run object detection on a
**Hailo-10H** (Raspberry Pi 5 + AI HAT+) using **HailoRT 5.2.0**, instead of the
HailoRT 4.21.0 shipped in the official image.

The goal is an all-in-one Frigate Docker image (`frigate-10h:5.2.0`) that can be built
on an Apple Silicon Mac (native arm64) and deployed to a Raspberry Pi 5, without
depending on a Home Assistant add-on.

---

## Origin and credits

This work **did not start from scratch**; it builds on two projects:

| Project | Role |
|---|---|
| **[blakeblackshear/frigate](https://github.com/blakeblackshear/frigate)** | **The original repository.** The entire Frigate NVR codebase (MIT, Copyright Frigate, Inc.). This fork starts at tag `v0.17.0`. |
| **[mikehailodev/frigate-hass-addons-h10](https://github.com/mikehailodev/frigate-hass-addons-h10)** | **Reference for the Hailo-10H approach.** The idea and much of the technique came from here: replacing HailoRT 4.x with 5.2.0 inside the image, forcing the `v5.2.0/hailo10h/` Model Zoo prefix, detecting `HAILO10H` in `hailortcli fw-control identify`, using a `VDevice` with `group_id = "SHARED"` for concurrent access, and deleting the HailoRT 4.21.0 *flat* files (`/usr/local/bin/hailortcli`, `/usr/local/lib/libhailort.so*`) that shadow the 5.2.0 ones. |

If you want the **Home Assistant add-on** variant, mikehailodev's repo is the direct
route; this fork is for those who prefer a standalone Docker container.

---

## What's different from official Frigate?

| | Official Frigate (v0.17.0) | This fork |
|---|---|---|
| **HailoRT** | 4.21.0 (official build) | **5.2.0** |
| **Hailo hardware** | Hailo-8, Hailo-8L | **Hailo-10H** (plus 8 / 8L) |
| **Kernel driver (host)** | `hailo_pci` | **`hailo1x_pci` + firmware 5.2.0** |
| **Default Model Zoo** | `v2.14.0/hailo8(l)/yolov6n.hef` | `v5.2.0/hailo10h/yolov6n.hef` |
| **Detector key** | `type: hailo8l` | `type: hailo8l` (unchanged, for compatibility) |

Architecture detection is automatic: the plugin queries the device at startup and
selects the right model. **Your Frigate configuration does not change.**

## Modified / added files

| File | Change |
|---|---|
| `frigate/detectors/plugins/hailo8l.py` | `HAILO10H` detection, `H10_DEFAULT_MODEL` / `H10_DEFAULT_URL` constants, model selection for Hailo-10H, `group_id = "SHARED"` on the `VDevice`, and robust output-type parsing (`split(".")[-1]`, required by HailoRT 5.x). Six changes — detailed change by change below. |
| `docker/main/Dockerfile` | At the end of the `frigate` stage: installs `h10-hailort_5.2.0_arm64.deb`, uninstalls the 4.21.0 wheel, installs `hailort-5.2.0-cp311-...whl`, and removes the 4.21.0 *flat* files + `ldconfig`. |
| `hailo_files/` | **Not versioned.** Only the manifests (`README.txt` / `README.es.txt`) are committed; the HailoRT 5.2.0 packages must be downloaded from Hailo's portal before building (see the breakdown below). |
| `build_hailo10h_image.sh` | Convenience script: `build` / `verify` / `save` / `push` (scp to the Pi). |
| `dist/` | `docker save` output (`frigate-10h:5.2.0.tar.gz`). **Not committed** (see *What is and isn't committed*). |

### The `hailo8l.py` patch, change by change

`frigate/detectors/plugins/hailo8l.py` is the only Python file touched. Six changes,
all of them needed for a Hailo-10H to work with HailoRT 5.2.0. Everything else in the
plugin (preprocessing, callback, `detect_raw`, config schema) is left as upstream.

**1. New constants for the Hailo-10H default model** (module level)

```python
H10_DEFAULT_MODEL = "yolov6n.hef"
# NOTE: Hailo-10H HEFs are published under the v5.2.0 Model Zoo prefix
# (matching HailoRT 5.2.0), not v2.x. Verified via HTTP HEAD (200 OK).
H10_DEFAULT_URL = "https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v5.2.0/hailo10h/yolov6n.hef"
```

*Why:* the existing defaults for Hailo-8/8L point at `v2.14.0/hailo8(l)/`, and those
HEF files are not valid for a Hailo-10H. Hailo publishes the Hailo-10H models under the
`v5.2.0/hailo10h/` prefix that matches the HailoRT version shipped in the image.

**2. `detect_hailo_arch()` recognises Hailo-10H**

```python
if "HAILO10H" in line or "HAILO10" in line:
    return "hailo10h"
elif "HAILO8L" in line:
    return "hailo8l"
elif "HAILO8" in line:
    return "hailo8"
```

*Why:* the architecture is read from the `Device Architecture` line printed by
`hailortcli fw-control identify`, which on a Hailo-10H says `HAILO10H`. The new branch
is evaluated **first** so the 10H never falls into the Hailo-8 branches. Note the
pre-existing ordering trap: `HAILO8L` must also be checked before `HAILO8`, because the
former is a substring of the latter.

**3. `VDevice` opened in shared mode** (`HailoAsyncInference.__init__`)

```python
params = VDevice.create_params()
params.scheduling_algorithm = HailoSchedulingAlgorithm.ROUND_ROBIN
# Shared device group: lets other Hailo applications (e.g. a VLM)
# access the same physical device concurrently. Harmless when Frigate
# is the only consumer.
try:
    params.group_id = "SHARED"
except Exception as e:
    logger.debug(f"Could not set SHARED VDevice group: {e}")
```

*Why:* by default a `VDevice` takes the accelerator exclusively, so a second process
(another Frigate detector, a GenAI/VLM pipeline on the same AI HAT+) gets "device
busy". The `SHARED` group lets several processes use the same physical device; it is
harmless when Frigate is the only consumer. The `try/except` keeps the plugin working
on HailoRT/binding versions that do not expose `group_id` — it just logs at debug level
and continues.

**4. Output dtype parsing: `split(".")[-1]` instead of `split(".")[1]`**
(`_create_bindings`)

```python
- np, str(output_info.format.type).split(".")[1].lower()
+ np, str(output_info.format.type).split(".")[-1].lower()
```

*Why:* the dtype for each output buffer is derived from the string form of the format
enum — `"FormatType.FLOAT32"` → `getattr(np, "float32")`. With HailoRT 5.x that string
carries more than one dot, so index `[1]` no longer returned the type name and
`getattr(np, ...)` blew up with `AttributeError`. Taking the **last** segment works with
both formats. Note this is the path actually used: the detector builds
`HailoAsyncInference` without `output_type`, so `_create_bindings` goes through the
`output_info` branch.

**5. A log line confirming the detected architecture** (`HailoDetector.__init__`)

```python
ARCH = detect_hailo_arch()
if ARCH == "hailo10h":
    logger.info("Hailo-10H detected: using HailoRT 5.x model selection")
```

*Why:* makes it obvious in the logs which path was taken. If the AI HAT+ is connected
and this line never appears, `hailortcli fw-control identify` did not report
`HAILO10H`, which points straight at a driver/firmware or HailoRT mismatch.

**6. Model selection for `hailo10h`** (`extract_model_name` and `check_and_prepare`)

```python
# extract_model_name()            # check_and_prepare()
if ARCH == "hailo10h":             if ARCH == "hailo10h":
    return H10_DEFAULT_MODEL           self.download_model(H10_DEFAULT_URL, cached_model_path)
elif ARCH == "hailo8":             elif ARCH == "hailo8":
    return H8_DEFAULT_MODEL            self.download_model(H8_DEFAULT_URL, cached_model_path)
else:                             else:
    return H8L_DEFAULT_MODEL           self.download_model(H8L_DEFAULT_URL, cached_model_path)
```

*Why:* these two chains decide which HEF to use when the config has no explicit
`model.path`. Without the new branch a Hailo-10H fell into the final `else` and got the
**Hailo-8L** model — a HEF compiled for different hardware, which a 10H cannot load.

> The detector key stays `hailo8l` and `ARCH` is detected once per detector instance at
> startup, so existing configurations keep working untouched; the plugin picks the right
> model on its own.

### Contents of `hailo_files/`

> **The packages are NOT versioned in this repository.** `hailo_files/` is committed
> with only the manifests, and `.gitignore` excludes the `.deb` / `.whl` files. After
> cloning, this folder will be empty — you must download the files below yourself and
> drop them into `hailo_files/` with these exact names, or the build will fail.

All of these packages are downloaded from the **[Hailo Developer Zone](https://hailo.ai/developer-zone/)**
(Hailo's developer portal, free account required), downloads section
→ **HailoRT 5.2.0** → **arm64 / aarch64**. They are not from Frigate or from this
fork: they are Hailo's property, which is exactly why they are not distributed here.

| File (download into `hailo_files/`) | Size | Used by the build? | What it's for |
|---|---|---|---|
| `h10-hailort_5.2.0_arm64.deb` | 4.9 MB | **Yes (`Dockerfile`)** | HailoRT 5.2.0 userspace for Hailo-10H: `hailortcli`, `libhailort.so.5.2.0`, headers (incl. GenAI: LLM/VLM/speech2text), GStreamer plugin. |
| `hailort-5.2.0-cp311-cp311-linux_aarch64.whl` | 7.5 MB | **Yes (`Dockerfile`)** | HailoRT 5.2.0 Python binding for CPython 3.11 (the Python version used by the Frigate image). |
| `hailort-pcie-driver_5.2.0_all.deb` | 27.8 MB | No (host) | PCIe driver + **firmware 5.2.0** to install on the Raspberry Pi. Builds the `hailo1x_pci` kernel module. |
| `hailort_5.2.0_arm64.deb` | 5.0 MB | No (host) | Standard arm64 HailoRT 5.2.0 package (same runtime as the `h10-` one), for host-side diagnostics. |
| `hailort-5.2.0-cp312-cp312-linux_aarch64.whl` | 7.5 MB | No | Same as the cp311 wheel, but for Python 3.12 environments. |
| `hailo-tappas-core_5.2.0_arm64.deb` | 6.0 MB | No | TAPPAS core 5.2.0 (Hailo's GStreamer pipelines). The detector does not need it. |
| `hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl` | 2.5 MB | No | TAPPAS Python bindings (only if you use its pipelines). |

Total ≈ 61 MB once every file is in place. **Only the first two are mandatory:** they are
what the Dockerfile copies, so if they are missing the build fails at the `COPY` step.
Per-package details are in [`hailo_files/README.txt`](hailo_files/README.txt)
(Spanish: [`hailo_files/README.es.txt`](hailo_files/README.es.txt)).

---

## Requirements

**Host (Raspberry Pi 5):**
- Raspberry Pi 5 with a **Hailo-10H AI HAT+**
- `hailo1x_pci` kernel driver and **firmware 5.2.0** loaded on the host
  (the driver must be 5.x to pair with the container's HailoRT 5.2.0; a 5.x driver
  with HailoRT 4.21.0 makes the device fail with `HAILO_DRIVER_INVALID_IOCTL(86)`)
- `/dev/hailo0` device node available
- Docker installed. The userspace that **Frigate** needs ships inside the image, so installing it on the host is optional; installing `hailort_5.2.0_arm64.deb` is recommended so you get `hailortcli` and can verify the NPU from the host (see *Installing on the Raspberry Pi 5*).

**Build machine (optional):**
- Apple Silicon Mac with Docker Desktop (native arm64 build), or build directly on the Pi.

---

## End-to-end checklist (from zero to Frigate running)

The whole flow in a single pass. Every item has the command and what you should see; if
one does not match, go to *Troubleshooting, step by step*.

### A. On the build machine

- [ ] **1. Get the Hailo packages.** HailoRT 5.2.0 for arm64/aarch64, from the
      [Hailo Developer Zone](https://hailo.ai/developer-zone/), dropped into `hailo_files/`.
      Minimum: `h10-hailort_5.2.0_arm64.deb` and
      `hailort-5.2.0-cp311-cp311-linux_aarch64.whl` → see *Contents of `hailo_files/`*.
- [ ] **2. Build the image:** `./build_hailo10h_image.sh build` → ends with `>>> Done.`
- [ ] **3. Verify the image:** `./build_hailo10h_image.sh verify` → `Version: 5.2.0` and
      **no** `libhailort.so.4.21.0`.
- [ ] **4. Export it:** `./build_hailo10h_image.sh save` → `dist/frigate-10h:5.2.0.tar.gz` (~1.3 GB).
- [ ] **5. Send it to the Pi:** edit `PI_USER` / `PI_HOST` / `PI_DIR` in the script, then run
      `./build_hailo10h_image.sh push`.

### B. On the Raspberry Pi 5 (host, outside Docker)

- [ ] **6. Install driver + firmware:** `sudo dpkg -i hailort-pcie-driver_5.2.0_all.deb`
      and `sudo apt-get install -f -y`.
- [ ] **7. Install the runtime:** `sudo dpkg -i hailort_5.2.0_arm64.deb`,
      `sudo apt-get install -f -y`, `sudo ldconfig`.
- [ ] **8. (Optional) Python binding / TAPPAS** — only if you need them on the host.
- [ ] **9. Reboot:** `sudo reboot`.
- [ ] **10. Confirm the NPU answers:** `hailortcli fw-control identify` →
      `Device Architecture: HAILO10H`, firmware 5.2.0 and a serial number; also
      `ls -l /dev/hailo0` exists.
- [ ] **11. Load the image:** `docker load < frigate-10h:5.2.0.tar.gz` →
      `Loaded image: frigate-10h:5.2.0`.
- [ ] **12. Recycled `/config`?** If that volume came from a Hailo-8/8L installation, delete
      `config/model_cache/yolov6n.hef` before starting: the plugin would reuse the old HEF.

### C. Configuration and first run

- [ ] **13. Write `config.yml`:** the `detectors.hailo8l` block (`type: hailo8l`,
      `device: PCIe`) and the `model` block with
      `labelmap_path: /labelmap/coco-80.txt` → copy from *Frigate configuration*.
- [ ] **14. Start the container** with the device passed through:
      `--device /dev/hailo0:/dev/hailo0` → see *Build and deploy*.
- [ ] **15. Check the detector logs:** `docker logs frigate 2>&1 | grep -i hailo` →
      `Hailo-10H detected: using HailoRT 5.x model selection`.
- [ ] **16. Check the model is there:** `docker exec frigate ls -lh /config/model_cache/*.hef`
      → `yolov6n.hef`, downloaded from `v5.2.0/hailo10h/`.
- [ ] **17. Open the UI:** `http://<pi>:5000` → Live view; walk in front of a camera with the
      `detect` role and confirm the bounding box and the event. The **System** page shows the
      detector and its inference speed in milliseconds.
- [ ] **18. (Optional) Machine-readable check:** `curl -s http://<pi>:5000/api/stats` → look for
      `detectors.hailo8l.inference_speed` (in ms). If you have authentication enabled, run it
      on the Pi itself.

If a step fails, that item plus *Troubleshooting, step by step* usually pin it down in a
couple of minutes.

---

## Installing on the Raspberry Pi 5 (host)

These steps run **on the Pi**, outside Docker, before deploying the container. The golden
rule: on the Pi install only **arm64** (or `all`) packages; anything tagged `x86_64` is for
your desktop and must be skipped entirely.

Copy the packages over first: the ones you downloaded from the Hailo Developer Zone, or
the ones sitting in `hailo_files/` on the build machine.

```bash
scp hailo_files/*.deb hailo_files/*.whl pi@hailopi.local:~/
```

### What to install and what not to

| File | On the Pi? | What it's for |
|---|---|---|
| `hailort-pcie-driver_5.2.0_all.deb` | **Yes — required** | PCIe kernel driver + firmware. Without it the OS cannot talk to the NPU and `/dev/hailo0` never appears. |
| `hailort_5.2.0_arm64.deb` | **Yes — recommended** | Base runtime (C/C++ libraries and `hailortcli`) to verify the NPU from the host. |
| `hailort-5.2.0-cp311-cp311-linux_aarch64.whl` | Only with Python 3.11 on the host | Python binding for the host. **Frigate does not need it here**: the container brings its own. |
| `hailort-5.2.0-cp312-cp312-linux_aarch64.whl` | Only with Python 3.12 on the host | Same for Python 3.12. |
| `hailo-tappas-core_5.2.0_arm64.deb` | Optional | TAPPAS (GStreamer plugins, pre/post-processing). |
| `hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl` | Optional | TAPPAS Python bindings. |
| `hailo_dataflow_compiler-5.2.0-py3-none-linux_x86_64.whl` | **NO** | Model compiler (ONNX/TF → `.hef`). It is `x86_64`: desktop only, it fails on the Pi with an architecture mismatch. |

### Step 1 — PCIe driver and firmware (required)

```bash
sudo dpkg -i hailort-pcie-driver_5.2.0_all.deb
sudo apt-get install -f -y     # resolves dependencies (build-essential, etc.)
```

### Step 2 — HailoRT and `hailortcli` (recommended)

```bash
sudo dpkg -i hailort_5.2.0_arm64.deb
sudo apt-get install -f -y
sudo ldconfig
```

This puts `hailortcli` in `/usr/bin/` and `libhailort.so.5.2.0` in `/usr/lib/`, so you can
check the NPU without entering the container.

### Step 3 — Python binding (conditional: pick ONE)

```bash
python3 --version
```

- **Python 3.11** (the usual case on Raspberry Pi OS Bookworm) → the `cp311` wheel.
- **Python 3.12** (Ubuntu 24.04, for example) → the `cp312` wheel.

```bash
pip install hailort-5.2.0-cp311-cp311-linux_aarch64.whl --break-system-packages
```

`--break-system-packages` is required on Debian 12 / PEP 668. Remember this is only needed
if you are going to use `hailo_platform` from Python **on the host** (demos, testing);
Frigate uses the wheel baked into the image.

### Step 4 — Optional: TAPPAS

```bash
sudo dpkg -i hailo-tappas-core_5.2.0_arm64.deb
pip install hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl --break-system-packages
```

Only if you are going to run GStreamer pipelines or local demos outside Docker. They are
not needed just to hand the device to Frigate.

### Step 5 — Reboot and verify

```bash
sudo reboot
```

Once you are back in:

```bash
hailortcli fw-control identify     # architecture, serial number and firmware of the Hailo-10H
lspci | grep -i hailo              # the PCIe device shows up
sudo dmesg | grep -iE "hailo|firmware"   # driver and firmware messages
ls -l /dev/hailo0                  # the device node exists
```

If `fw-control identify` reports `Device Architecture: HAILO10H`, the serial number and
firmware version 5.2.0, the host is ready to start the container.

### Step 6 — Configure and start Frigate

The detector block and the model are covered in *Frigate configuration* (the key is still
`type: hailo8l` and the model comes from `v5.2.0/hailo10h/`). At runtime, the only
mandatory bit is passing the device to the container:

```bash
docker run -d --name frigate --restart=unless-stopped \
  --device /dev/hailo0:/dev/hailo0 \
  -v /path/to/config:/config \
  -v /path/to/media:/media/frigate \
  -p 5000:5000 -p 8971:8971 \
  frigate-10h:5.2.0
```

> **Watch out for a recycled `/config` volume:** if that `/config` already came from a
> Hailo-8/8L install, delete `config/model_cache/yolov6n.hef` before starting. The file name
> is the same for all three architectures and the plugin reuses whatever HEF is already in
> the cache. See *Troubleshooting*, step 4.

If something does not line up, follow *Troubleshooting, step by step*.

---

## Build and deploy

From the repository root:

```bash
# 1. Build the image (native arm64)
./build_hailo10h_image.sh build

# 2. Verify that everything inside the image is 5.2.0 with no 4.21.0 leftovers
./build_hailo10h_image.sh verify

# 3. Export the compressed image to ./dist
./build_hailo10h_image.sh save

# 4. Copy it to the Raspberry Pi (edit PI_USER / PI_HOST / PI_DIR in the script)
./build_hailo10h_image.sh push
```

On the Raspberry Pi:

```bash
docker load < frigate-10h:5.2.0.tar.gz

docker run -d --name frigate --restart=unless-stopped \
  --device /dev/hailo0:/dev/hailo0 \
  -v /path/to/config:/config \
  -v /path/to/media:/media/frigate \
  -v /etc/localtime:/etc/localtime:ro \
  -p 5000:5000 -p 8971:8971 \
  -p 8554:8554 -p 8555:8555/tcp -p 8555:8555/udp \
  frigate-10h:5.2.0
```

> `--device /dev/hailo0` is mandatory. If you use a different orchestration tool,
> mount the device with the equivalent permissions.

You can also build manually:

```bash
docker build -t frigate-10h:5.2.0 -f docker/main/Dockerfile .
```

### `build_hailo10h_image.sh` reference

Convenience script (bash, `set -euo pipefail`) wrapping the full cycle:
build → verify → package → transfer to the Pi. It can be run from any directory
because internally it does `cd "$(dirname "$0")"` to the repo root.

**Requirements:** Docker (Desktop) running and a **native arm64 build**. The script
does not use `--platform`, so it must run on Apple Silicon — or directly on the
Raspberry Pi; on an Intel/x86 Mac the build would be emulated, very slow, and prone
to failure.

**Configurable variables** (top of the script):

| Variable | Default | Purpose |
|---|---|---|
| `IMAGE_NAME` | `frigate-10h` | Name of the image to build. |
| `IMAGE_TAG` | `5.2.0` | Image tag (HailoRT version). |
| `TARBALL` | `frigate-10h:5.2.0.tar.gz` | Name of the exported file inside `dist/`. |
| `PI_USER` | `rdvt` | SSH user on the Raspberry Pi. **Change it.** |
| `PI_HOST` | `hailopi.local` | Host or IP of the Pi (mDNS/Avahi). **Change it.** |
| `PI_DIR` | `~` | Destination directory for the `scp`. |

**Subcommands:**

| Command | What it does exactly |
|---|---|
| `build` (default) | `docker build -t frigate-10h:5.2.0 -f docker/main/Dockerfile .`. This is the long step: it compiles ffmpeg, the frontend, and the dependencies. |
| `verify` | Runs the image with `docker run --rm` to check the installed HailoRT: `pip3 show hailort`, `hailortcli version`, and the `libhailort` libraries via `ldconfig -p` and on disk. **It does not need the Pi or `/dev/hailo0`**, so you can verify on the build machine. It fails if `hailort` is not 5.2.0. |
| `save` | `mkdir -p dist` and `docker save frigate-10h:5.2.0 \| gzip > dist/frigate-10h:5.2.0.tar.gz`, then prints the size (~1.3 GB). |
| `push` | Requires the tarball to exist (otherwise it tells you to run `save`), `scp`s it to `${PI_USER}@${PI_HOST}:${PI_DIR}/`, and prints the `docker load` command to run on the Pi. |
| anything else | Prints the usage (`build\|verify\|save\|push`) and exits with code 1. |

**Expected `verify` output:**

```
>>> HailoRT python wheel:
Name: hailort
Version: 5.2.0
>>> hailortcli version (userspace):
HailoRT-CLI version 5.2.0
>>> libhailort as resolved by the loader (ldconfig -p):
    libhailort.so.5.2.0 (libc6,AArch64) => /usr/lib/libhailort.so.5.2.0
>>> and the actual files on disk:
-rw-r--r-- 1 root root 13067768 ... /usr/lib/libhailort.so.5.2.0
```

The 5.2.0 package installs `hailortcli` into `/usr/bin/` and the library into
`/usr/lib/` (only the versioned `.so`, no symlinks). That is why `verify` looks at
those paths and at `ldconfig -p`: if the library does not resolve, the detector will
fail to import `hailo_platform` even with the device properly connected.

If any `libhailort.so.4.21.0` appears under `/usr/local/lib`, the Dockerfile `rm`
did not take effect and the device will fail with `HAILO_DRIVER_INVALID_IOCTL(86)`.

**Practical notes**

- `push` uses `scp` and relies on `hailopi.local` (Avahi/mDNS) resolving; if it fails,
  put the IP directly in `PI_HOST`.
- The exported file has a `:` in its name (`frigate-10h:5.2.0.tar.gz`): valid on
  macOS/Linux, but problematic on Windows/NTFS. To copy it to an exFAT drive, rename
  it to `frigate-10h-5.2.0.tar.gz` (`docker load` does not care).
- `dist/` is in `.gitignore` because of its size (see *What is and isn't committed*).
- The script does not tag or sign the image: it is just a local shortcut over the
  Docker commands you can run by hand.

---

## Frigate configuration

The detector key is still `hailo8l` (for compatibility with existing configurations).
Working example, verified on Hailo-10H:

```yaml
mqtt:
  enabled: true
  host: <home assistant url>
  user: user_name
  password: pass

cameras:
  Camera_1:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://<path>
          roles:
            - detect
            - record

detectors:
  hailo8l:
    type: hailo8l
    device: PCIe

model:
  width: 640
  height: 640
  input_tensor: nhwc
  input_pixel_format: rgb
  input_dtype: int
  model_type: yolo-generic
  labelmap_path: /labelmap/coco-80.txt
  # Optional: if omitted, yolov6n.hef is downloaded from the v5.2.0/hailo10h Model Zoo
  path:
    https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v5.2.0/hailo10h/yolov8m.hef

detect:
  enabled: true
  fps: 5

objects:
  track:
    - person

record:
  enabled: true
  detections:
    pre_capture: 5
    post_capture: 5
    retain:
      days: 1
      mode: active_objects

snapshots:
  enabled: true
  timestamp: true
  bounding_box: true
  crop: false
  retain:
    default: 1
    objects:
      person: 1

logger:
  default: info
  logs:
    frigate.detectors.plugins.hailo8l: debug
```

### Models (Model Zoo)

Hailo-10H HEFs are published under the `v5.2.0/hailo10h/` prefix:

```
https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v5.2.0/hailo10h/<model>.hef
```

By default the plugin uses `yolov6n.hef`; you can point it to `yolov8m.hef` or others
(just change the URL in `model.path`).

---

## Quick verification

Inside the container:

```bash
docker run --rm --entrypoint hailortcli frigate-10h:5.2.0 fw-control identify
docker run --rm --entrypoint pip3 frigate-10h:5.2.0 show hailort
```

Expected:
- `hailort` **5.2.0** (Python wheel)
- `Device Architecture: HAILO10H`
- `libhailort.so.5.2.0` resolved from `/usr/lib/` and **no** `libhailort.so.4.21.0` under `/usr/local/lib`

(the `./build_hailo10h_image.sh verify` subcommand performs these same checks
automatically)

In the Frigate logs you should see:
`Hailo-10H detected: using HailoRT 5.x model selection`.

## Known issues

- **`HAILO_DRIVER_INVALID_IOCTL(86)`** → the host kernel driver and the container's
  HailoRT are not from the same generation. Hailo-10H needs the `hailo1x_pci` driver
  + firmware 5.2.0.
- **`hailortcli` reports version 4.21.0** → the *flat* binaries under `/usr/local/`
  are still there (the Dockerfile patches this; if you build by hand, check that step).
- **`Device not found`** → `--device /dev/hailo0` is missing or the firmware is not loaded.
- If another process (e.g. a VLM) uses the same Hailo-10H, the plugin's
  `group_id = "SHARED"` lets it share the device; throughput is split between them.

## Troubleshooting, step by step

Those error strings above, in the order in which it makes sense to check things. Each
step has a command and the expected result — stop at the first one that does not match.

| Symptom | Most likely cause | Check |
|---|---|---|
| `HAILO_DRIVER_INVALID_IOCTL(86)` | The container's HailoRT and the host driver are from different generations | Steps 1 and 3 |
| `hailortcli` reports version 4.21.0 | The 4.21.0 *flat* files are still in `/usr/local/` | Step 2 |
| `Device not found` / no device | Missing `--device /dev/hailo0`, or firmware not loaded | Steps 1 and 3 |
| The line `Hailo-10H detected…` never appears in the logs | `fw-control identify` failed → `ARCH = None` → the plugin silently falls back to the Hailo-8L model | Steps 1–3 |
| The HEF fails to load, or detections are nonsense | A HEF for another architecture is cached under the same name (`yolov6n.hef`) | Step 4 |
| `Timeout waiting for inference results` | The inference thread died: device lost or incompatible HEF | Step 5 |

### Step 1 — Does the host see the Hailo-10H?

On the Raspberry Pi, outside Docker:

```bash
lspci | grep -i hailo                 # is the PCIe device enumerated?
lsmod | grep -i hailo                 # is the hailo1x_pci module loaded?
ls -l /dev/hailo0                     # does the device node exist?
sudo dmesg | grep -iE "hailo|firmware"     # driver and firmware messages
```

- Nothing in `lspci` → the AI HAT+ is not seated correctly, or the Pi's PCIe connector
  is not enabled.
- `lsmod` empty → install the driver + firmware on the host
  (`sudo dpkg -i hailo_files/hailort-pcie-driver_5.2.0_all.deb`, `sudo apt-get install -f`,
  reboot) and check `dmesg` after booting.
- No `/dev/hailo0` → nothing can open the device, and the container will also need
  `--device /dev/hailo0`.

### Step 2 — Is the container shipping HailoRT 5.2.0?

```bash
# userspace version inside the image
docker run --rm --entrypoint hailortcli frigate-10h:5.2.0 version

# or the whole check in one go
./build_hailo10h_image.sh verify
```

Expected `5.2.0`. If it answers `4.21.0`, the *flat* files that `install_hailort.sh`
leaves in `/usr/local/` are shadowing the new ones — the `rm` step of the Dockerfile did
not take effect. Rebuild:

```bash
docker build -t frigate-10h:5.2.0 -f docker/main/Dockerfile .
```

### Step 3 — Can HailoRT 5.2.0 talk to the device?

```bash
docker run --rm --device /dev/hailo0 --entrypoint hailortcli \
  frigate-10h:5.2.0 fw-control identify
```

Expected: a `Device Architecture: HAILO10H` line, plus the board/serial and a firmware
version in the 5.x line.

- `HAILO_DRIVER_INVALID_IOCTL(86)` → the container's HailoRT and the host driver/firmware
  are not paired. Both sides must be 5.2.0: rebuild the image (step 2) *and* update the
  driver on the host (step 1). HailoRT 5.x userspace does not work against a 4.x driver,
  nor the other way around.
- `Device not found` → the container has no access to the device: add
  `--device /dev/hailo0` and re-check step 1.
- This is the very same command the plugin runs at startup to decide the architecture, so
  **if it fails, `detect_hailo_arch()` returns `None` and Frigate silently loads the
  Hailo-8L model**. That is why step 4 inspects the logs.

### Step 4 — Is Frigate using the Hailo-10H model?

```bash
# detector startup lines
docker logs frigate 2>&1 | grep -iE "hailo|hef|model"

# which HEF is actually on disk
docker exec frigate ls -lh /config/model_cache/*.hef
```

Expected:

```
Hailo-10H detected: using HailoRT 5.x model selection          # INFO, always printed
[INIT] Loading HEF model from /config/model_cache/yolov6n.hef  # DEBUG, needs debug logging
```

For the second line (and much more detail), enable the plugin's debug logs in `config.yml`
and restart:

```yaml
logger:
  default: info
  logs:
    frigate.detectors.plugins.hailo8l: debug
```

**The cached-model trap:** the default file name is `yolov6n.hef` for Hailo-8, Hailo-8L
**and** Hailo-10H, and `check_and_prepare()` reuses whatever is already inside
`/config/model_cache/` without checking which architecture it was compiled for. If you
previously ran this same `/config` with an 8/8L image, the plugin will happily load that
old HEF. Delete it and restart:

```bash
rm -f /path/to/config/model_cache/yolov6n.hef    # on the host
docker restart frigate                           # it downloads the v5.2.0/hailo10h model again
```

If instead you set `model.path` yourself, make sure the URL points at `v5.2.0/hailo10h/`:
a HEF from `v2.14.0/hailo8(l)/` will not load on a 10H.

### Step 5 — Is inference actually running?

```bash
docker logs frigate 2>&1 | grep -iE "timeout|inference thread|error"
```

- `Timeout waiting for inference results for request …` followed by `HailoRT inference
  thread has stopped, restart required.` → the worker thread died, usually because the
  device was lost or the HEF is incompatible. Restart the container; if it comes back, go
  to steps 3 and 4.
- If another process on the Pi uses the same Hailo-10H (a GenAI/VLM demo, for instance),
  make sure it does not hold the device exclusively. The plugin opens the `VDevice` in
  `SHARED` mode precisely so both can coexist, but throughput is split between them.
- Still failing? Grab the full startup log of one detector
  (`docker logs frigate 2>&1 | head -200`) and compare it line by line against this list.

## What is and isn't committed

Two kinds of large files are deliberately kept out of this repo, both via `.gitignore`:

| Path | Why it's not versioned | How to get it |
|---|---|---|
| `hailo_files/*.deb`, `hailo_files/*.whl` | Hailo's proprietary packages (~61 MB); they are not redistributed here | Download them from the [Hailo Developer Zone](https://hailo.ai/developer-zone/) and drop them into `hailo_files/` (see the manifest) |
| `dist/*.tar.gz` | The exported image is ~1.3 GB and **GitHub rejects files larger than 100 MB** | Build it locally with `./build_hailo10h_image.sh build && ./build_hailo10h_image.sh save` |

So `hailo_files/` only carries the manifests (`README.txt` / `README.es.txt`), which
document which file goes where and where to download it. If you ever do want to keep the
packages in the repo, remove those lines from `.gitignore` — but check Hailo's license
first.

---

## License and trademarks

- **Code:** [MIT License](LICENSE), same as the original project
  (Copyright © Frigate, Inc. and contributors). If you reuse this fork you must keep
  the original copyright notice.
- **Trademarks:** the names "Frigate", "Frigate NVR", and the logo are trademarks of
  Frigate, Inc. and are **not** covered by the MIT License. See [TRADEMARK.md](TRADEMARK.md).
- **HailoRT / Hailo:** the bundled binaries belong to Hailo and are subject to their
  own terms.

## Documentation

General Frigate documentation: <https://docs.frigate.video>
