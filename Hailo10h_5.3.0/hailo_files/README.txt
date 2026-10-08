========================================================================
 hailo_files/ — HailoRT 5.3.0 packages for Hailo-10H
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

    - Version:      HailoRT 5.3.0  (the same version as the container's HailoRT)
    - Architecture: arm64 / aarch64  (Raspberry Pi 5, Linux)
    - PCIe driver + firmware: included in hailort-pcie-driver

These packages are not part of this repository or of Frigate: they are Hailo's
property, which is why they are not distributed here. Review Hailo's license
before deciding to commit or redistribute them (see /usr/share/doc/<package>/
copyright inside the .deb).

NAME CHANGE SINCE 5.2.0
-----------------------
In HailoRT 5.2.0 the runtime came as `h10-hailort_5.2.0_arm64.deb`. In 5.3.0 the
package is simply `hailort_5.3.0_arm64.deb`: **there is no `h10-` variant**. The
Dockerfile copies that exact name; if your portal download is named differently,
adjust the two COPY lines in docker/main/Dockerfile.


FILES YOU MUST DOWNLOAD INTO THIS FOLDER
----------------------------------------
Download each of these from the portal and keep the exact file name:

Name                                                            Used by this repo's build?
--------------------------------------------------------------  --------------------
hailort_5.3.0_arm64.deb                                         YES (Dockerfile)
hailort-5.3.0-cp311-cp311-linux_aarch64.whl                     YES (Dockerfile)
hailort-pcie-driver_5.3.0_all.deb                               no  (host)
hailort-5.3.0-cp310-cp310-linux_aarch64.whl                     no  (host, Py3.10)
hailort-5.3.0-cp312-cp312-linux_aarch64.whl                     no  (host, Py3.12)
hailo-tappas-core_5.3.0_arm64.deb                               no
hailo_gen_ai_model_zoo_5.3.0_arm64.deb                          no
hailo-accelerator-integration-tool_5.3.0_arm64.deb              no
hailo_dataflow_compiler-5.3.0-py3-none-linux_x86_64.whl         NO  (x86_64: desktop only)
--------------------------------------------------------------  --------------------

Sizes vary per release; the only big one is the dataflow compiler (~120 MB), and
it is installed neither on the Pi nor inside the image.


NEVER INSTALL ON THE RASPBERRY PI
---------------------------------
As a rule: on the Pi install only arm64 / aarch64 / all packages, and skip
anything tagged x86_64.

hailo_dataflow_compiler-5.3.0-py3-none-linux_x86_64.whl
    The model compiler (ONNX / TensorFlow -> .hef) and it is built for x86_64,
    so it only runs on your Intel/AMD desktop. Installing it on the Pi fails
    with an architecture mismatch. About 120 MB.


DETAILS FOR EACH FILE
---------------------

hailort_5.3.0_arm64.deb                    [DOCKERFILE + HOST]
    Debian package:        hailort 5.3.0 (arm64)
    Contents:              /usr/bin/hailortcli
                           /usr/lib/libhailort.so.5.3.0
                           /usr/include/hailo/** (including GenAI: llm, vlm,
                           speech2text)
                           /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgsthailo.so
                           /usr/lib/cmake/HailoRT/**
    What it's for:         HailoRT 5.3.0 (userspace). The Dockerfile copies it
                           into the image, where it replaces the HailoRT 4.21.0
                           shipped with Frigate by default (without it, the
                           Hailo-10H fails with HAILO_DRIVER_INVALID_IOCTL(86)).
                           It is also the package you install on the host to get
                           hailortcli and check the NPU from outside the
                           container.

hailort-5.3.0-cp311-cp311-linux_aarch64.whl   [DOCKERFILE]
    Python wheel:          hailort 5.3.0 (aarch64, CPython 3.11)
    What it's for:         HailoRT Python binding imported by the detector
                           (`from hailo_platform import ...`). Frigate uses
                           Python 3.11, hence the cp311 variant. The Dockerfile
                           copies it into the image.

hailort-pcie-driver_5.3.0_all.deb                        [HOST / RASPBERRY PI]
    Debian package:        hailort-pcie-driver 5.3.0 (all)
    Contents:              Hailo PCIe driver + firmware
    Depends on:            build-essential (builds the kernel module)
    What it's for:         install on the host to get the hailo1x_pci driver and
                           the 5.3.0 firmware, which is what the /dev/hailo0
                           device node needs. It does NOT go inside the image.

hailort-5.3.0-cp310-cp310-linux_aarch64.whl             [OPTIONAL / HOST]
    Python wheel:          hailort 5.3.0 (aarch64, CPython 3.10)
    What it's for:         binding for Python 3.10 environments. The Frigate
                           image does not use it (it uses cp311).

hailort-5.3.0-cp312-cp312-linux_aarch64.whl             [OPTIONAL / HOST]
    Python wheel:          hailort 5.3.0 (aarch64, CPython 3.12)
    What it's for:         same library as cp311 but for Python 3.12
                           environments. The Frigate image does not use it.

hailo-tappas-core_5.3.0_arm64.deb                       [OPTIONAL]
    Debian package:        hailo-tappas-core 5.3.0 (arm64)
    What it's for:         core components of TAPPAS 5.3.0 (Hailo's GStreamer
                           pipelines). It pulls in many dependencies (gstreamer,
                           libzmq, cairo, etc.). Frigate's detector does NOT
                           need it.

hailo_gen_ai_model_zoo_5.3.0_arm64.deb                  [OPTIONAL]
    Debian package:        hailo_gen_ai_model_zoo 5.3.0 (arm64)
    What it's for:         the GenAI model zoo (LLM, VLM, speech-to-text) that
                           appears from 5.3.0 onwards. Frigate does not use it:
                           object detection runs on YOLO HEFs, not on the GenAI
                           zoo.

hailo-accelerator-integration-tool_5.3.0_arm64.deb      [OPTIONAL]
    Debian package:        hailo-accelerator-integration-tool 5.3.0 (arm64)
    What it's for:         accelerator integration tool, new in 5.3.0. Not
                           needed for Frigate.


AFTER A FRESH CLONE (EXPECTED STATE)
------------------------------------
If this folder only has README.txt and README.es.txt, nothing is wrong: that is
how the repository is published. Before building you must add at least
`hailort_5.3.0_arm64.deb` and `hailort-5.3.0-cp311-cp311-linux_aarch64.whl`,
because the Dockerfile copies those two; if they are missing (or empty, like the
0-byte placeholders used to prepare this folder), the build fails with an
explicit message thanks to the check the Dockerfile performs.

The remaining files are for the host (driver/firmware) or optional material.
You may add them as a record of the exact version that was tested, or skip
them.

Reference: the repository's README (`README.en.md` for English, `README.md` for
Spanish), sections "Modified / added files" and "Requirements".
