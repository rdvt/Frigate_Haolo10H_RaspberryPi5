<p align="center">
  <img align="center" alt="logo" src="Hailo10H_5.2.0/docs/static/img/branding/frigate.png">
</p>

# Frigate NVR with Hailo-10H support

\[English\] | [Español](README.md)

> **Unofficial fork / community project.** Not affiliated with or endorsed by
> [Frigate, Inc.](https://frigate.video), the [Frigate](https://github.com/blakeblackshear/frigate)
> project, or [Hailo](https://hailo.ai). "Frigate" and "Frigate NVR" are trademarks of
> Frigate, Inc. See [TRADEMARK.md](Hailo10H_5.2.0/TRADEMARK.md) and [LICENSE](Hailo10H_5.2.0/LICENSE).

This repository contains the code and documentation to run Frigate NVR on a
**Raspberry Pi 5 with a Hailo-10H AI HAT+**, organised by HailoRT version.

---

## Choose your HailoRT version

Each directory corresponds to a specific HailoRT driver and runtime version.
The host driver, the Docker image, and the Model Zoo HEF must all be from the **same generation**.

| Directory | HailoRT | Kernel driver (host) | Notes |
|---|---|---|---|
| [**Hailo10H\_5.2.0/**](Hailo10H_5.2.0/README.en.md) | 5.2.0 | `hailo1x_pci` + firmware 5.2.0 | First release with Hailo-10H support |
| [**Hailo10h\_5.3.0/**](Hailo10h_5.3.0/README.en.md) | 5.3.0 | `hailo1x_pci` + firmware 5.3.0 | Adds host preflight, cp310 wheel, TAPPAS 5.3.0 |
| [**Hailo10H\_5.4.0/**](Hailo10H_5.4.0/README.en.md) | 5.4.0 | `hailo1x_pci` + firmware 5.4.0 | Driver renamed to `h10-hailort-pcie-driver` |

> **Which one should I pick?** Use the version that matches the driver you have (or plan to
> install) on the Raspberry Pi. If starting from scratch, use **5.4.0** (the latest).

---

## Repository layout

```
repo/
├── Hailo10H_5.2.0/   ← Full Frigate fork for HailoRT 5.2.0
├── Hailo10h_5.3.0/   ← Full Frigate fork for HailoRT 5.3.0
└── Hailo10H_5.4.0/   ← Full Frigate fork for HailoRT 5.4.0
```

Each directory is self-contained: it ships its own `Dockerfile`, the `hailo8l.py` patch,
the `build_hailo10h_image.sh` convenience script, a `hailo_files/` folder with package
manifests, and full documentation in both Spanish and English.

---

## What changed between versions

| Change | 5.2.0 | 5.3.0 | 5.4.0 |
|---|---|---|---|
| Runtime `.deb` package | `h10-hailort_5.2.0_arm64.deb` | `hailort_5.3.0_arm64.deb` | `hailort_5.4.0_arm64.deb` |
| Driver package name | `hailort-pcie-driver` | `hailort-pcie-driver` | **`h10-hailort-pcie-driver`** (renamed) |
| Mandatory Python wheel | `cp311` | `cp311` (+ `cp310`) | `cp311` (+ `cp310`, `cp312`) |
| Host preflight in build script | ✗ | ✔ | ✔ |
| Rollback guide between versions | ✗ | ✔ | ✔ |

---

## General Frigate documentation

<https://docs.frigate.video>
