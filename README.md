<p align="center">
  <img align="center" alt="logo" src="docs/static/img/branding/frigate.png">
</p>

# Frigate NVR con soporte Hailo-10H (HailoRT 5.2.0)

[English](README.md) | \[Español\]

> **Fork no oficial / proyecto comunitario.** No está afiliado ni respaldado por
> [Frigate, Inc.](https://frigate.video), el proyecto [Frigate](https://github.com/blakeblackshear/frigate)
> ni por [Hailo](https://hailo.ai). "Frigate" y "Frigate NVR" son marcas de Frigate, Inc.
> Ver [TRADEMARK.md](TRADEMARK.md) y [LICENSE](LICENSE).

Este repositorio es un fork de **[blakeblackshear/frigate](https://github.com/blakeblackshear/frigate)**
(base `v0.17.0`, MIT) con los cambios necesarios para que el detector de objetos
funcione sobre un **Hailo-10H** (Raspberry Pi 5 + AI HAT+) usando **HailoRT 5.2.0**,
en lugar de la HailoRT 4.21.0 que trae la imagen oficial.

El objetivo es tener una imagen Docker de Frigate "todo en uno" (`frigate-10h:5.2.0`)
que se pueda construir en un Mac Apple Silicon (arm64 nativo) y desplegar en la
Raspberry Pi 5, sin depender de un add-on de Home Assistant.

---

## Origen y créditos

Este trabajo **no parte de cero**, se apoyó en dos proyectos:

| Proyecto | Rol |
|---|---|
| **[blakeblackshear/frigate](https://github.com/blakeblackshear/frigate)** | **Repositorio original.** Todo el código base de Frigate NVR (MIT, Copyright Frigate, Inc.). Este fork parte de la etiqueta `v0.17.0`. |
| **[mikehailodev/frigate-hass-addons-h10](https://github.com/mikehailodev/frigate-hass-addons-h10)** | **Referencia para el enfoque Hailo-10H.** De aquí se tomó la idea y gran parte de la técnica: reemplazar HailoRT 4.x por 5.2.0 dentro de la imagen, forzar el prefijo del Model Zoo `v5.2.0/hailo10h/`, detectar `HAILO10H` en `hailortcli fw-control identify`, usar un `VDevice` con `group_id = "SHARED"` para acceso concurrente y eliminar los archivos *flat* de HailoRT 4.21.0 (`/usr/local/bin/hailortcli`, `/usr/local/lib/libhailort.so*`) que ensombrecen a los de 5.2.0. |

Si buscas la variante como **add-on de Home Assistant**, el repo de mikehailodev es
el camino directo; este fork es para quien prefiere el contenedor Docker autónomo.

---

## ¿Qué cambia respecto a Frigate oficial?

| | Frigate oficial (v0.17.0) | Este fork |
|---|---|---|
| **HailoRT** | 4.21.0 (entrega oficial) | **5.2.0** |
| **Hardware Hailo** | Hailo-8, Hailo-8L | **Hailo-10H** (además de 8 / 8L) |
| **Driver de kernel (host)** | `hailo_pci` | **`hailo1x_pci` + firmware 5.2.0** |
| **Model Zoo por defecto** | `v2.14.0/hailo8(l)/yolov6n.hef` | `v5.2.0/hailo10h/yolov6n.hef` |
| **Clave de detector** | `type: hailo8l` | `type: hailo8l` (igual, por compatibilidad) |

La detección de arquitectura es automática: el plugin consulta el dispositivo al
arrancar y selecciona el modelo correcto. **La configuración de Frigate no cambia.**

## Archivos modificados / añadidos

| Archivo | Cambio |
|---|---|
| `frigate/detectors/plugins/hailo8l.py` | Detección de `HAILO10H`, constantes `H10_DEFAULT_MODEL` / `H10_DEFAULT_URL`, selección de modelo para Hailo-10H, `group_id = "SHARED"` en el `VDevice` y parseo robusto del tipo de salida (`split(".")[-1]`, necesario con HailoRT 5.x). Son seis cambios, explicados uno por uno más abajo. |
| `docker/main/Dockerfile` | Al final de la etapa `frigate`: instala `h10-hailort_5.2.0_arm64.deb`, desinstala el wheel 4.21.0, instala `hailort-5.2.0-cp311-...whl` y borra los archivos *flat* 4.21.0 + `ldconfig`. |
| `hailo_files/` | **No se versiona.** Solo se suben los manifiestos (`README.es.txt` / `README.txt`); los paquetes de HailoRT 5.2.0 hay que bajarlos del portal de Hailo antes de construir (ver el desglose más abajo). |
| `build_hailo10h_image.sh` | Script de conveniencia: `build` / `verify` / `save` / `push` (scp a la Pi). |
| `dist/` | Salida del `docker save` (`frigate-10h:5.2.0.tar.gz`). **No se sube al repo** (ver *Qué se sube y qué no*). |

### El parche de `hailo8l.py`, cambio por cambio

`frigate/detectors/plugins/hailo8l.py` es el único archivo Python que se toca. Son seis
cambios, todos necesarios para que un Hailo-10H funcione con HailoRT 5.2.0. El resto
del plugin (preprocesado, callback, `detect_raw`, el esquema de configuración) queda
igual que en el repositorio original.

**1. Constantes nuevas para el modelo por defecto del Hailo-10H** (nivel de módulo)

```python
H10_DEFAULT_MODEL = "yolov6n.hef"
# NOTE: Hailo-10H HEFs are published under the v5.2.0 Model Zoo prefix
# (matching HailoRT 5.2.0), not v2.x. Verified via HTTP HEAD (200 OK).
H10_DEFAULT_URL = "https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v5.2.0/hailo10h/yolov6n.hef"
```

*Por qué:* los valores por defecto que ya existían para Hailo-8/8L apuntan a
`v2.14.0/hailo8(l)/`, y esos HEF no son válidos para un Hailo-10H. Hailo publica los
modelos del 10H bajo el prefijo `v5.2.0/hailo10h/`, que va en pareja con la versión de
HailoRT que lleva la imagen.

**2. `detect_hailo_arch()` reconoce el Hailo-10H**

```python
if "HAILO10H" in line or "HAILO10" in line:
    return "hailo10h"
elif "HAILO8L" in line:
    return "hailo8l"
elif "HAILO8" in line:
    return "hailo8"
```

*Por qué:* la arquitectura se lee de la línea `Device Architecture` que imprime
`hailortcli fw-control identify`, y en un Hailo-10H dice `HAILO10H`. La rama nueva se
evalúa **primero** para que el 10H nunca caiga en las ramas de Hailo-8. Ojo con una
trampa que ya venía de antes: `HAILO8L` también tiene que comprobarse antes que
`HAILO8`, porque el primero es un subtexto del segundo.

**3. `VDevice` abierto en modo compartido** (`HailoAsyncInference.__init__`)

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

*Por qué:* por defecto un `VDevice` toma el acelerador en exclusiva, así que un segundo
proceso (otro detector de Frigate, una pipeline GenAI/VLM sobre el mismo AI HAT+) recibe
"dispositivo ocupado". El grupo `SHARED` permite que varios procesos usen el mismo
dispositivo físico, y no molesta cuando Frigate es el único consumidor. El `try/except`
mantiene el plugin funcionando en versiones de HailoRT o del binding que no exponen
`group_id`: solo registra un mensaje de debug y sigue.

**4. Parseo del tipo de salida: `split(".")[-1]` en vez de `split(".")[1]`**
(`_create_bindings`)

```python
- np, str(output_info.format.type).split(".")[1].lower()
+ np, str(output_info.format.type).split(".")[-1].lower()
```

*Por qué:* el dtype de cada buffer de salida se deduce de la forma en texto del enum de
formato — `"FormatType.FLOAT32"` → `getattr(np, "float32")`. Con HailoRT 5.x ese texto
lleva más de un punto, así que el índice `[1]` ya no devolvía el nombre del tipo y
`getattr(np, ...)` reventaba con `AttributeError`. Tomando el **último** segmento
funciona en los dos formatos. Es, además, la ruta que realmente se usa: el detector crea
`HailoAsyncInference` sin `output_type`, así que `_create_bindings` entra por la rama de
`output_info`.

**5. Un log que confirma la arquitectura detectada** (`HailoDetector.__init__`)

```python
ARCH = detect_hailo_arch()
if ARCH == "hailo10h":
    logger.info("Hailo-10H detected: using HailoRT 5.x model selection")
```

*Por qué:* deja claro en los logs qué camino se tomó. Si el AI HAT+ está conectado y esa
línea nunca aparece, significa que `hailortcli fw-control identify` no reportó
`HAILO10H`, lo que apunta directo a un desajuste de driver/firmware o de HailoRT.

**6. Selección del modelo para `hailo10h`** (`extract_model_name` y `check_and_prepare`)

```python
# extract_model_name()            # check_and_prepare()
if ARCH == "hailo10h":             if ARCH == "hailo10h":
    return H10_DEFAULT_MODEL           self.download_model(H10_DEFAULT_URL, cached_model_path)
elif ARCH == "hailo8":             elif ARCH == "hailo8":
    return H8_DEFAULT_MODEL            self.download_model(H8_DEFAULT_URL, cached_model_path)
else:                             else:
    return H8L_DEFAULT_MODEL           self.download_model(H8L_DEFAULT_URL, cached_model_path)
```

*Por qué:* estas dos cadenas deciden qué HEF se usa cuando la configuración no trae un
`model.path` explícito. Sin la rama nueva, un Hailo-10H caía en el `else` final y se
llevaba el modelo de **Hailo-8L**, un HEF compilado para otro hardware que el 10H no
puede cargar.

> La clave del detector sigue siendo `hailo8l` y `ARCH` se detecta una sola vez por
> instancia, al arrancar, así que las configuraciones existentes siguen funcionando sin
> cambios: el plugin elige el modelo correcto por sí solo.

### Contenido de `hailo_files/`

> **Los paquetes NO se versionan en este repositorio.** `hailo_files/` se sube con los
> manifiestos únicamente, y el `.gitignore` excluye los `.deb` / `.whl`. Después de
> clonar, esta carpeta estará vacía: tienes que descargar los archivos de abajo y
> dejarlos en `hailo_files/` con estos nombres exactos, o el build fallará.

Todos estos paquetes se descargan del **[Hailo Developer Zone](https://hailo.ai/developer-zone/)**
(portal de desarrollo de Hailo, requiere cuenta gratuita), sección de descargas
→ **HailoRT 5.2.0** → **arm64 / aarch64**. No son de Frigate ni de este fork:
son propiedad de Hailo, y justamente por eso no se distribuyen aquí.

| Archivo (descargar en `hailo_files/`) | Tamaño | ¿Lo usa el build? | Para qué sirve |
|---|---|---|---|
| `h10-hailort_5.2.0_arm64.deb` | 4.9 MB | **Sí (`Dockerfile`)** | HailoRT 5.2.0 de usuario para Hailo-10H: `hailortcli`, `libhailort.so.5.2.0`, cabeceras (incl. GenAI: LLM/VLM/speech2text), plugin GStreamer. |
| `hailort-5.2.0-cp311-cp311-linux_aarch64.whl` | 7.5 MB | **Sí (`Dockerfile`)** | Binding Python de HailoRT 5.2.0 para CPython 3.11 (el Python que usa la imagen de Frigate). |
| `hailort-pcie-driver_5.2.0_all.deb` | 27.8 MB | No (host) | Driver PCIe + **firmware 5.2.0** para instalar en la Raspberry Pi. Compila el módulo de kernel `hailo1x_pci`. |
| `hailort_5.2.0_arm64.deb` | 5.0 MB | No (host) | Paquete HailoRT 5.2.0 estándar arm64 (mismo runtime que el `h10-`), para diagnóstico en el host. |
| `hailort-5.2.0-cp312-cp312-linux_aarch64.whl` | 7.5 MB | No | Igual que el wheel cp311, pero para entornos con Python 3.12. |
| `hailo-tappas-core_5.2.0_arm64.deb` | 6.0 MB | No | TAPPAS core 5.2.0 (pipelines GStreamer de Hailo). El detector no la necesita. |
| `hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl` | 2.5 MB | No | Bindings Python de TAPPAS (solo si usas sus pipelines). |

Total ≈ 61 MB cuando están todos los archivos. **Solo los dos primeros son obligatorios:**
son los que copia el Dockerfile, así que si faltan el build falla en el paso `COPY`.
El detalle de cada paquete está en [`hailo_files/README.es.txt`](hailo_files/README.es.txt)
(en inglés: [`hailo_files/README.txt`](hailo_files/README.txt)).

---

## Requisitos

**Host (Raspberry Pi 5):**
- Raspberry Pi 5 con **Hailo-10H AI HAT+**
- Driver de kernel `hailo1x_pci` y **firmware 5.2.0** cargados en el host
  (el driver debe ser 5.x para hacer pareja con la HailoRT 5.2.0 del contenedor;
  con un driver 5.x y HailoRT 4.21.0 el dispositivo falla con
  `HAILO_DRIVER_INVALID_IOCTL(86)`)
- Nodo de dispositivo `/dev/hailo0` disponible
- Docker instalado. El userspace que **usa Frigate** va dentro de la imagen, así que no es obligatorio instalarlo en el host; sí conviene instalar `hailort_5.2.0_arm64.deb` para tener `hailortcli` y verificar el NPU desde el host (ver *Instalación en la Raspberry Pi 5*).

**Máquina de build (opcional):**
- Mac Apple Silicon con Docker Desktop (build arm64 nativo), o build directamente en la Pi.

---

## Flujo completo de extremo a extremo (checklist)

Todo el proceso en una sola pasada. Cada punto trae el comando y lo que deberías ver; si
alguno no cuadra, ve a *Solución de problemas paso a paso*.

### A. En la máquina de build

- [ ] **1. Consigue los paquetes de Hailo.** HailoRT 5.2.0 para arm64/aarch64 desde el
      [Hailo Developer Zone](https://hailo.ai/developer-zone/), dentro de `hailo_files/`.
      Mínimo: `h10-hailort_5.2.0_arm64.deb` y `hailort-5.2.0-cp311-cp311-linux_aarch64.whl`
      → ver *Contenido de `hailo_files/`*.
- [ ] **2. Construye la imagen:** `./build_hailo10h_image.sh build` → termina con `>>> Done.`
- [ ] **3. Verifica la imagen:** `./build_hailo10h_image.sh verify` → `Version: 5.2.0` y
      **ningún** `libhailort.so.4.21.0`.
- [ ] **4. Expórtala:** `./build_hailo10h_image.sh save` → `dist/frigate-10h:5.2.0.tar.gz` (~1.3 GB).
- [ ] **5. Envíala a la Pi:** edita `PI_USER` / `PI_HOST` / `PI_DIR` en el script y luego
      `./build_hailo10h_image.sh push`.

### B. En la Raspberry Pi 5 (host, fuera de Docker)

- [ ] **6. Instala el driver y el firmware:** `sudo dpkg -i hailort-pcie-driver_5.2.0_all.deb`
      y `sudo apt-get install -f -y`.
- [ ] **7. Instala el runtime:** `sudo dpkg -i hailort_5.2.0_arm64.deb`,
      `sudo apt-get install -f -y`, `sudo ldconfig`.
- [ ] **8. (Opcional) Binding de Python / TAPPAS:** solo si los necesitas en el host.
- [ ] **9. Reinicia:** `sudo reboot`.
- [ ] **10. Confirma que el NPU responde:** `hailortcli fw-control identify` →
      `Device Architecture: HAILO10H`, firmware 5.2.0 y número de serie; además
      `ls -l /dev/hailo0`.
- [ ] **11. Carga la imagen:** `docker load < frigate-10h:5.2.0.tar.gz` →
      `Loaded image: frigate-10h:5.2.0`.
- [ ] **12. ¿`/config` reciclado?** Si ese volumen venía de una instalación con Hailo-8/8L,
      borra `config/model_cache/yolov6n.hef` antes de arrancar: el plugin reutilizaría el HEF viejo.

### C. Configuración y primer arranque

- [ ] **13. Escribe `config.yml`:** bloque `detectors.hailo8l` (`type: hailo8l`,
      `device: PCIe`) y el bloque `model` con `labelmap_path: /labelmap/coco-80.txt` →
      cópialo de *Configuración de Frigate*.
- [ ] **14. Arranca el contenedor** pasando el dispositivo:
      `--device /dev/hailo0:/dev/hailo0` → ver *Build y despliegue*.
- [ ] **15. Revisa los logs del detector:** `docker logs frigate 2>&1 | grep -i hailo` →
      `Hailo-10H detected: using HailoRT 5.x model selection`.
- [ ] **16. Revisa que el modelo esté:** `docker exec frigate ls -lh /config/model_cache/*.hef`
      → `yolov6n.hef`, descargado de `v5.2.0/hailo10h/`.
- [ ] **17. Abre la interfaz:** `http://<pi>:5000` → vista Live; pásate por delante de una
      cámara con el rol `detect` y confirma el recuadro y el evento. La página **System**
      muestra el detector y su velocidad de inferencia en milisegundos.
- [ ] **18. (Opcional) Comprobación automática:** `curl -s http://<pi>:5000/api/stats` → busca
      `detectors.hailo8l.inference_speed` (en ms). Si tienes autenticación activada, ejecútalo
      en la propia Pi.

Si algún punto falla, con ese punto y *Solución de problemas paso a paso* normalmente se
resuelve en un par de minutos.

---

## Instalación en la Raspberry Pi 5 (host)

Estos pasos se ejecutan **en la Pi**, fuera de Docker, antes de desplegar el contenedor.
La regla de oro: en la Pi solo se instalan paquetes **arm64** (o `all`); los archivos
marcados `x86_64` son para el PC y se ignoran por completo.

Copia primero los paquetes: los que bajaste del Hailo Developer Zone o los que tengas en
`hailo_files/` de la máquina de build.

```bash
scp hailo_files/*.deb hailo_files/*.whl pi@hailopi.local:~/
```

### Qué instalar y qué no

| Archivo | ¿En la Pi? | Para qué |
|---|---|---|
| `hailort-pcie-driver_5.2.0_all.deb` | **Sí — obligatorio** | Driver de kernel PCIe + firmware. Sin él el sistema no habla con el NPU y no aparece `/dev/hailo0`. |
| `hailort_5.2.0_arm64.deb` | **Sí — recomendado** | Runtime base (librerías C/C++ y `hailortcli`) para verificar el NPU desde el host. |
| `hailort-5.2.0-cp311-cp311-linux_aarch64.whl` | Solo con Python 3.11 en el host | Binding de Python para el host. **Frigate no lo necesita aquí**: el contenedor trae el suyo. |
| `hailort-5.2.0-cp312-cp312-linux_aarch64.whl` | Solo con Python 3.12 en el host | Ídem para Python 3.12. |
| `hailo-tappas-core_5.2.0_arm64.deb` | Opcional | TAPPAS (plugins GStreamer, pre/postprocesado). |
| `hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl` | Opcional | Bindings Python de TAPPAS. |
| `hailo_dataflow_compiler-5.2.0-py3-none-linux_x86_64.whl` | **NO** | Compilador de modelos (ONNX/TF → `.hef`). Es `x86_64`: solo en tu PC de escritorio, en la Pi falla por arquitectura. |

### Paso 1 — Driver PCIe y firmware (obligatorio)

```bash
sudo dpkg -i hailort-pcie-driver_5.2.0_all.deb
sudo apt-get install -f -y     # resuelve las dependencias (build-essential, etc.)
```

### Paso 2 — HailoRT y `hailortcli` (recomendado)

```bash
sudo dpkg -i hailort_5.2.0_arm64.deb
sudo apt-get install -f -y
sudo ldconfig
```

Esto deja `hailortcli` en `/usr/bin/` y `libhailort.so.5.2.0` en `/usr/lib/`, así puedes
comprobar el estado del NPU sin entrar al contenedor.

### Paso 3 — Binding de Python (condicional: elige UNO)

```bash
python3 --version
```

- **Python 3.11** (lo habitual en Raspberry Pi OS Bookworm) → wheel `cp311`.
- **Python 3.12** (por ejemplo Ubuntu 24.04) → wheel `cp312`.

```bash
pip install hailort-5.2.0-cp311-cp311-linux_aarch64.whl --break-system-packages
```

El `--break-system-packages` es necesario en Debian 12 / PEP 668. Recuerda que esto solo
hace falta si vas a usar `hailo_platform` desde Python **en el host** (demos, pruebas);
Frigate usa el wheel que viene dentro de la imagen.

### Paso 4 — Opcional: TAPPAS

```bash
sudo dpkg -i hailo-tappas-core_5.2.0_arm64.deb
pip install hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl --break-system-packages
```

Solo si vas a montar pipelines GStreamer o demos locales fuera de Docker. Para pasarle el
dispositivo a Frigate no hacen falta.

### Paso 5 — Reinicia y verifica

```bash
sudo reboot
```

Al volver a entrar:

```bash
hailortcli fw-control identify    # arquitectura, número de serie y firmware del Hailo-10H
lspci | grep -i hailo             # el dispositivo PCIe aparece
sudo dmesg | grep -iE "hailo|firmware"  # mensajes del driver y del firmware
ls -l /dev/hailo0                 # el nodo de dispositivo existe
```

Si `fw-control identify` devuelve `Device Architecture: HAILO10H`, el número de serie y la
versión de firmware 5.2.0, el host está listo para arrancar el contenedor.

### Paso 6 — Configura y arranca Frigate

El bloque del detector y el modelo están en la sección *Configuración de Frigate* (la
clave sigue siendo `type: hailo8l` y el modelo se toma de `v5.2.0/hailo10h/`). Al arrancar,
lo único imprescindible es pasar el dispositivo al contenedor:

```bash
docker run -d --name frigate --restart=unless-stopped \
  --device /dev/hailo0:/dev/hailo0 \
  -v /ruta/a/config:/config \
  -v /ruta/a/media:/media/frigate \
  -p 5000:5000 -p 8971:8971 \
  frigate-10h:5.2.0
```

> **Ojo con el volumen `/config` reciclado:** si ese `/config` ya venía de una instalación
> con Hailo-8/8L, borra `config/model_cache/yolov6n.hef` antes de arrancar. El nombre del
> archivo es el mismo para las tres arquitecturas y el plugin reutiliza el HEF que ya está
> en la caché. Ver *Solución de problemas*, paso 4.

Si algo no cuadra, sigue la sección *Solución de problemas paso a paso*.

---

## Build y despliegue

Desde la raíz del repo:

```bash
# 1. Construir la imagen (arm64 nativo)
./build_hailo10h_image.sh build

# 2. Verificar que dentro de la imagen todo es 5.2.0 y no queda rastro de 4.21.0
./build_hailo10h_image.sh verify

# 3. Exportar la imagen comprimida a ./dist
./build_hailo10h_image.sh save

# 4. Copiarla a la Raspberry Pi (edita PI_USER / PI_HOST / PI_DIR en el script)
./build_hailo10h_image.sh push
```

En la Raspberry Pi:

```bash
docker load < frigate-10h:5.2.0.tar.gz

docker run -d --name frigate --restart=unless-stopped \
  --device /dev/hailo0:/dev/hailo0 \
  -v /ruta/a/config:/config \
  -v /ruta/a/media:/media/frigate \
  -v /etc/localtime:/etc/localtime:ro \
  -p 5000:5000 -p 8971:8971 \
  -p 8554:8554 -p 8555:8555/tcp -p 8555:8555/udp \
  frigate-10h:5.2.0
```

> El `--device /dev/hailo0` es imprescindible. Si usas otro tipo de orquestación,
> monta el dispositivo con los permisos equivalentes.

También puedes construir a mano:

```bash
docker build -t frigate-10h:5.2.0 -f docker/main/Dockerfile .
```

### Referencia de `build_hailo10h_image.sh`

Script de conveniencia (bash, `set -euo pipefail`) que envuelve el ciclo completo:
construir → verificar → empaquetar → transferir a la Pi. Se puede ejecutar desde
cualquier directorio, porque internamente hace `cd "$(dirname "$0")"` hasta la raíz
del repo.

**Requisitos:** Docker (Desktop) en marcha y **build nativo arm64**. El script no usa
`--platform`, así que debe correr en Apple Silicon —o directamente en la Raspberry Pi—;
en un Mac Intel/x86 el build sería por emulación, muy lento y propenso a fallar.

**Variables configurables** (cabecera del script):

| Variable | Valor por defecto | Para qué |
|---|---|---|
| `IMAGE_NAME` | `frigate-10h` | Nombre de la imagen a construir. |
| `IMAGE_TAG` | `5.2.0` | Etiqueta de la imagen (versión de HailoRT). |
| `TARBALL` | `frigate-10h:5.2.0.tar.gz` | Nombre del archivo exportado dentro de `dist/`. |
| `PI_USER` | `rdvt` | Usuario SSH de la Raspberry Pi. **Cámbialo.** |
| `PI_HOST` | `hailopi.local` | Host o IP de la Pi (mDNS/Avahi). **Cámbialo.** |
| `PI_DIR` | `~` | Carpeta destino del `scp` en la Pi. |

**Subcomandos:**

| Comando | Qué hace exactamente |
|---|---|
| `build` (por defecto) | `docker build -t frigate-10h:5.2.0 -f docker/main/Dockerfile .`. Es el paso largo: compila ffmpeg, el frontend y las dependencias. |
| `verify` | Lanza la imagen con `docker run --rm` para comprobar la HailoRT instalada: `pip3 show hailort`, `hailortcli version` y las `libhailort` según `ldconfig -p` y en disco. **No necesita la Pi ni `/dev/hailo0`**, así que puedes verificar en la máquina de build. Falla si `hailort` no es 5.2.0. |
| `save` | `mkdir -p dist` y `docker save frigate-10h:5.2.0 \| gzip > dist/frigate-10h:5.2.0.tar.gz`; al final muestra el tamaño (~1.3 GB). |
| `push` | Exige que exista el tarball (si no, te pide correr `save`), hace `scp` a `${PI_USER}@${PI_HOST}:${PI_DIR}/` e imprime el `docker load` que hay que ejecutar en la Pi. |
| cualquier otro | Imprime el uso (`build\|verify\|save\|push`) y sale con código 1. |

**Salida esperada de `verify`:**

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

El paquete 5.2.0 instala `hailortcli` en `/usr/bin/` y la librería en `/usr/lib/`
(solo la `.so` versionada, sin symlinks). Por eso el `verify` mira esas rutas y
`ldconfig -p`: si la librería no se resuelve, el detector fallará al importar
`hailo_platform` incluso con el dispositivo bien conectado.

Si aparece cualquier `libhailort.so.4.21.0` bajo `/usr/local/lib`, el `rm` del
Dockerfile no se aplicó y el dispositivo dará `HAILO_DRIVER_INVALID_IOCTL(86)`.

**Notas prácticas**

- `push` usa `scp` y depende de que `hailopi.local` (Avahi/mDNS) resuelva; si falla,
  pon la IP directa en `PI_HOST`.
- El archivo exportado lleva `:` en el nombre (`frigate-10h:5.2.0.tar.gz`): es válido en
  macOS/Linux, pero problemático en Windows/NTFS. Para copiarlo a un disco exFAT,
  renómbralo a `frigate-10h-5.2.0.tar.gz` (el `docker load` no lo necesita).
- `dist/` está en `.gitignore` por su tamaño (ver *Qué se sube y qué no*).
- El script no versiona ni firma la imagen: es solo un atajo local sobre los comandos
  de Docker que puedes ejecutar a mano.

---

## Configuración de Frigate

La clave del detector sigue siendo `hailo8l` (por compatibilidad con la configuración
existente). Ejemplo funcional verificado con Hailo-10H:

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
  # Opcional: si lo omites, se descarga yolov6n.hef del Model Zoo v5.2.0/hailo10h
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

### Modelos (Model Zoo)

Los HEF para Hailo-10H se publican bajo el prefijo `v5.2.0/hailo10h/`:

```
https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v5.2.0/hailo10h/<modelo>.hef
```

Por defecto el plugin usa `yolov6n.hef`; puedes apuntar a `yolov8m.hef` u otros
(basta cambiar la URL en `model.path`).

---

## Verificación rápida

Dentro del contenedor:

```bash
docker run --rm --entrypoint hailortcli frigate-10h:5.2.0 fw-control identify
docker run --rm --entrypoint pip3 frigate-10h:5.2.0 show hailort
```

Esperado:
- `hailort` **5.2.0** (wheel de Python)
- `Device Architecture: HAILO10H`
- `libhailort.so.5.2.0` resuelta desde `/usr/lib/` y **ningún** `libhailort.so.4.21.0` en `/usr/local/lib`

(el subcomando `./build_hailo10h_image.sh verify` hace estas mismas comprobaciones
de forma automática)

En los logs de Frigate deberías ver:
`Hailo-10H detected: using HailoRT 5.x model selection`.

## Problemas conocidos

- **`HAILO_DRIVER_INVALID_IOCTL(86)`** → el driver de kernel del host y la HailoRT
  del contenedor no son de la misma generación. Hailo-10H necesita driver `hailo1x_pci`
  + firmware 5.2.0.
- **`hailortcli` responde con la versión 4.21.0** → quedaron los binarios *flat* de
  `/usr/local/` (los parchea el Dockerfile; si construyes a mano, revisa ese paso).
- **`Device not found`** → falta `--device /dev/hailo0` o el firmware no está cargado.
- Si otro proceso (p. ej. un VLM) usa el mismo Hailo-10H, el `group_id = "SHARED"`
  del plugin permite compartir el dispositivo; el rendimiento se reparte.

## Solución de problemas paso a paso

Los errores de arriba, en el orden en que tiene sentido ir comprobando. Cada paso trae un
comando y el resultado esperado: detente en el primero que no cuadre.

| Síntoma | Causa más probable | Revisa |
|---|---|---|
| `HAILO_DRIVER_INVALID_IOCTL(86)` | La HailoRT del contenedor y el driver del host son de generaciones distintas | Pasos 1 y 3 |
| `hailortcli` responde con la versión 4.21.0 | Quedaron los archivos *flat* de 4.21.0 en `/usr/local/` | Paso 2 |
| `Device not found` / no aparece el dispositivo | Falta `--device /dev/hailo0` o el firmware no está cargado | Pasos 1 y 3 |
| La línea `Hailo-10H detected…` nunca sale en los logs | Falló `fw-control identify` → `ARCH = None` → el plugin cae en silencio al modelo de Hailo-8L | Pasos 1–3 |
| El HEF no carga o las detecciones no tienen sentido | Hay un HEF de otra arquitectura en caché con el mismo nombre (`yolov6n.hef`) | Paso 4 |
| `Timeout waiting for inference results` | Murió el hilo de inferencia: se perdió el dispositivo o el HEF es incompatible | Paso 5 |

### Paso 1 — ¿El host ve el Hailo-10H?

En la Raspberry Pi, fuera de Docker:

```bash
lspci | grep -i hailo                 # ¿aparece el dispositivo PCIe?
lsmod | grep -i hailo                 # ¿está cargado el módulo hailo1x_pci?
ls -l /dev/hailo0                     # ¿existe el nodo de dispositivo?
sudo dmesg | grep -iE "hailo|firmware"     # mensajes del driver y del firmware
```

- Nada en `lspci` → el AI HAT+ no está bien montado, o el conector PCIe de la Pi no está
  habilitado.
- `lsmod` vacío → instala el driver + firmware en el host
  (`sudo dpkg -i hailo_files/hailort-pcie-driver_5.2.0_all.deb`, `sudo apt-get install -f`,
  reinicia) y revisa `dmesg` después de arrancar.
- No hay `/dev/hailo0` → nada puede abrir el dispositivo, y además el contenedor
  necesitará `--device /dev/hailo0`.

### Paso 2 — ¿El contenedor lleva HailoRT 5.2.0?

```bash
# versión de usuarios dentro de la imagen
docker run --rm --entrypoint hailortcli frigate-10h:5.2.0 version

# o toda la comprobación de una vez
./build_hailo10h_image.sh verify
```

Se espera `5.2.0`. Si responde `4.21.0`, los archivos *flat* que deja `install_hailort.sh`
en `/usr/local/` están tapando a los nuevos: el paso `rm` del Dockerfile no se aplicó.
Vuelve a construir:

```bash
docker build -t frigate-10h:5.2.0 -f docker/main/Dockerfile .
```

### Paso 3 — ¿HailoRT 5.2.0 puede hablar con el dispositivo?

```bash
docker run --rm --device /dev/hailo0 --entrypoint hailortcli \
  frigate-10h:5.2.0 fw-control identify
```

Se espera una línea `Device Architecture: HAILO10H`, más la placa/serie y una versión de
firmware en la línea 5.x.

- `HAILO_DRIVER_INVALID_IOCTL(86)` → la HailoRT del contenedor y el driver/firmware del
  host no hacen pareja. Los dos lados tienen que ser 5.2.0: reconstruye la imagen
  (paso 2) *y* actualiza el driver en el host (paso 1). La HailoRT 5.x de usuarios no
  funciona contra un driver 4.x, ni al revés.
- `Device not found` → el contenedor no tiene acceso al dispositivo: agrega
  `--device /dev/hailo0` y vuelve al paso 1.
- Es exactamente el mismo comando que ejecuta el plugin al arrancar para decidir la
  arquitectura, así que **si falla, `detect_hailo_arch()` devuelve `None` y Frigate carga
  en silencio el modelo de Hailo-8L**. Por eso el paso 4 mira los logs.

### Paso 4 — ¿Frigate está usando el modelo del Hailo-10H?

```bash
# líneas de arranque del detector
docker logs frigate 2>&1 | grep -iE "hailo|hef|model"

# qué HEF hay realmente en disco
docker exec frigate ls -lh /config/model_cache/*.hef
```

Se espera:

```
Hailo-10H detected: using HailoRT 5.x model selection          # INFO, siempre sale
[INIT] Loading HEF model from /config/model_cache/yolov6n.hef  # DEBUG, requiere logs de debug
```

Para la segunda línea (y mucho más detalle), activa los logs de debug del plugin en
`config.yml` y reinicia:

```yaml
logger:
  default: info
  logs:
    frigate.detectors.plugins.hailo8l: debug
```

**La trampa del modelo en caché:** el nombre por defecto es `yolov6n.hef` para Hailo-8,
Hailo-8L **y** Hailo-10H, y `check_and_prepare()` reutiliza lo que ya esté en
`/config/model_cache/` sin comprobar para qué arquitectura se compiló. Si antes usaste ese
mismo `/config` con una imagen de 8/8L, el plugin cargará tan tranquilo ese HEF viejo.
Bórralo y reinicia:

```bash
rm -f /ruta/a/config/model_cache/yolov6n.hef    # en el host
docker restart frigate                          # vuelve a bajar el modelo v5.2.0/hailo10h
```

Si en cambio pones `model.path` a mano, asegúrate de que la URL apunte a `v5.2.0/hailo10h/`:
un HEF de `v2.14.0/hailo8(l)/` no carga en un 10H.

### Paso 5 — ¿La inferencia está corriendo de verdad?

```bash
docker logs frigate 2>&1 | grep -iE "timeout|inference thread|error"
```

- `Timeout waiting for inference results for request …` seguido de `HailoRT inference
  thread has stopped, restart required.` → el hilo de trabajo murió, normalmente porque se
  perdió el dispositivo o el HEF es incompatible. Reinicia el contenedor; si vuelve a
  pasar, regresa a los pasos 3 y 4.
- Si otro proceso de la Pi usa el mismo Hailo-10H (por ejemplo una demo GenAI/VLM),
  asegúrate de que no lo tome en exclusiva. El plugin abre el `VDevice` en modo `SHARED`
  justamente para que los dos convivan, pero el rendimiento se reparte.
- ¿Sigue fallando? Saca el log de arranque completo de un detector
  (`docker logs frigate 2>&1 | head -200`) y compáralo línea por línea con esta lista.

## Qué se sube y qué no

Hay dos tipos de archivos grandes que se dejan fuera del repo a propósito, ambos vía
`.gitignore`:

| Ruta | Por qué no se versiona | Cómo obtenerlo |
|---|---|---|
| `hailo_files/*.deb`, `hailo_files/*.whl` | Paquetes propietarios de Hailo (~61 MB); aquí no se redistribuyen | Descárgalos del [Hailo Developer Zone](https://hailo.ai/developer-zone/) y déjalos en `hailo_files/` (ver el manifiesto) |
| `dist/*.tar.gz` | La imagen exportada pesa ~1.3 GB y **GitHub rechaza archivos de más de 100 MB** | Genéralo en local con `./build_hailo10h_image.sh build && ./build_hailo10h_image.sh save` |

Así, `hailo_files/` solo lleva los manifiestos (`README.es.txt` / `README.txt`), que
documentan qué archivo va en cada lugar y de dónde bajarlo. Si en algún momento quieres
versionar los paquetes, quita esas líneas del `.gitignore`; antes revisa la licencia
de Hailo.

---

## Licencia y marcas

- **Código:** [MIT License](LICENSE), igual que el proyecto original
  (Copyright © Frigate, Inc. y contribuidores). Al reutilizar este fork debes
  conservar el aviso de copyright original.
- **Marcas:** los nombres "Frigate", "Frigate NVR" y el logo son marcas de
  Frigate, Inc. y **no** están cubiertos por la licencia MIT. Ver [TRADEMARK.md](TRADEMARK.md).
- **HailoRT / Hailo:** los binarios incluidos pertenecen a Hailo y están sujetos a
  sus propios términos.

## Documentación

Documentación general de Frigate: <https://docs.frigate.video>
