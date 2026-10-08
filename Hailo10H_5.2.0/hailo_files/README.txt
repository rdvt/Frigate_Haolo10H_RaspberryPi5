========================================================================
 hailo_files/ — HailoRT 5.2.0 packages for Hailo-10H
========================================================================

IMPORTANT: THESE PACKAGES ARE NOT VERSIONED IN THIS REPOSITORY
--------------------------------------------------------------
Only the two manifests (README.txt and README.es.txt) are committed. The
.gitignore file excludes *.deb and *.whl, so right after cloning the repo this
folder will contain nothing but these text files, and the Docker build will
fail at the COPY step until you download the packages listed below from Hailo's
portal and place them here using the exact same names.

That is intentional: the packages are Hailo's property and are not
redistributed in this repository.


SOURCE
------
Every file in this folder is downloaded from the **Hailo Developer Zone**,
Hailo's developer portal:

    https://hailo.ai/developer-zone/

A free account is required. Inside the portal, in the software downloads
section, select:

    - Version:      HailoRT 5.2.0  (the same version as the container's HailoRT)
    - Architecture: arm64 / aarch64  (Raspberry Pi 5, Linux)
    - PCIe driver + firmware: included in hailort-pcie-driver

These packages are not part of this repository or of Frigate: they are Hailo's
property, which is why they are not distributed here. Review Hailo's license
before deciding to commit or redistribute them (see
/usr/share/doc/h10-hailort/copyright inside the .deb).

Whenever you need them again — for example right after cloning the repo —
download them from the portal and place them here using the same file names.


FILES YOU MUST DOWNLOAD INTO THIS FOLDER
----------------------------------------
Download each of these from the portal and keep the exact file name:

Name                                                      Size     Used by this repo's build?
--------------------------------------------------------  -------  --------------------
h10-hailort_5.2.0_arm64.deb                                4.9 MB   YES (Dockerfile)
hailort-5.2.0-cp311-cp311-linux_aarch64.whl               7.5 MB   YES (Dockerfile)
hailort-pcie-driver_5.2.0_all.deb                         27.8 MB   no  (host)
hailort_5.2.0_arm64.deb                                    5.0 MB   no  (host)
hailort-5.2.0-cp312-cp312-linux_aarch64.whl               7.5 MB   no
hailo-tappas-core_5.2.0_arm64.deb                          6.0 MB   no
hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl    2.5 MB   no
--------------------------------------------------------  -------
                                                  TOTAL    ~61 MB


NEVER INSTALL ON THE RASPBERRY PI
---------------------------------
As a rule: on the Pi install only arm64 / aarch64 / all packages, and skip
anything tagged x86_64.

hailo_dataflow_compiler-5.2.0-py3-none-linux_x86_64.whl   (NOT in this folder)
    The model compiler (ONNX / TensorFlow -> .hef) and it is built for x86_64,
    so it only runs on your Intel/AMD desktop. Installing it on the Pi fails
    with an architecture mismatch.


DETAILS FOR EACH FILE
---------------------

h10-hailort_5.2.0_arm64.deb                    [USED BY THE DOCKERFILE]
    Debian package:        h10-hailort 5.2.0 (arm64)
    Contents:              /usr/bin/hailortcli
                           /usr/lib/libhailort.so.5.2.0
                           /usr/include/hailo/** (including GenAI: llm, vlm,
                           speech2text)
                           /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgsthailo.so
                           /usr/lib/cmake/HailoRT/**
    What it's for:         HailoRT 5.2.0 (userspace) inside the image. This is the
                           package that replaces the HailoRT 4.21.0 shipped with
                           Frigate by default. Without it, the Hailo-10H fails
                           with HAILO_DRIVER_INVALID_IOCTL(86).

hailort-5.2.0-cp311-cp311-linux_aarch64.whl   [USED BY THE DOCKERFILE]
    Python wheel:          hailort 5.2.0 (aarch64, CPython 3.11)
    What it's for:         HailoRT Python binding imported by the detector
                           (`from hailo_platform import ...`). Frigate uses
                           Python 3.11, hence the cp311 variant.

hailort-pcie-driver_5.2.0_all.deb                        [HOST / RASPBERRY PI]
    Debian package:        hailort-pcie-driver 5.2.0 (all)
    Contents:              Hailo PCIe driver + firmware
    Depends on:            build-essential (builds the kernel module)
    What it's for:         install on the host to get the hailo1x_pci driver and
                           the 5.2.0 firmware, which is what the /dev/hailo0
                           device node needs. It does NOT go inside the image.

hailort_5.2.0_arm64.deb                                  [OPTIONAL / HOST]
    Debian package:        hailort 5.2.0 (arm64)
    Contents:              same as h10-hailort (runtime + libraries +
                           hailortcli), shipped as the standard package.
    What it's for:         install HailoRT 5.2.0 on the host if you want to use
                           hailortcli outside the container for diagnostics.

hailort-5.2.0-cp312-cp312-linux_aarch64.whl             [OPTIONAL]
    Python wheel:          hailort 5.2.0 (aarch64, CPython 3.12)
    What it's for:         same library as cp311 but for Python 3.12
                           environments. The Frigate image does not use it.

hailo-tappas-core_5.2.0_arm64.deb                       [OPTIONAL]
    Debian package:        hailo-tappas-core 5.2.0 (arm64)
    What it's for:         core components of TAPPAS 5.2.0 (Hailo's GStreamer
                           pipelines). It pulls in many dependencies (gstreamer,
                           libzmq, cairo, etc.). Frigate's detector does NOT
                           need it.

hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl [OPTIONAL]
    Python wheel:          hailo-tappas-core-python-binding 5.2.0
    What it's for:         TAPPAS Python bindings. Only if you are going to use
                           Hailo's GStreamer pipelines.


AFTER A FRESH CLONE (EXPECTED STATE)
------------------------------------
If this folder only has README.txt and README.es.txt, nothing is wrong: that is
how the repository is published. Before building you must add at least
`h10-hailort_5.2.0_arm64.deb` and `hailort-5.2.0-cp311-cp311-linux_aarch64.whl`,
because the Dockerfile copies those two; if they are missing, the build fails at
the COPY step. Download them from Hailo's portal (5.2.0, arm64) and try again.

The remaining files are for the host (driver/firmware) or optional material.
You may add them as a record of the exact version that was tested, or skip
them.

Reference: the repository's README.md (README.es.md for Spanish), sections
"Modified / added files" and "Requirements".

Spanish version of this manifest: README.es.txt
