========================================================================
 hailo_files/ — paquetes HailoRT 5.3.0 para Hailo-10H
========================================================================

IMPORTANTE: ESTOS PAQUETES NO SE VERSIONAN EN ESTE REPOSITORIO
--------------------------------------------------------------
Solo se suben los dos manifiestos (README.es.txt y README.txt). El archivo
.gitignore excluye los *.deb y *.whl, así que justo después de clonar el repo
esta carpeta solo tendrá estos textos y el build de Docker fallará en el paso
COPY hasta que descargues del portal de Hailo los paquetes de la lista de abajo
y los dejes aquí con los nombres exactos.

Es intencional: los paquetes son propiedad de Hailo y no se redistribuyen en
este repositorio.


ORIGEN
------
Todos los archivos de esta carpeta se descargan del **Hailo Developer Zone**,
el portal de desarrollo de Hailo:

    https://hailo.ai/developer-zone/

Se requiere una cuenta gratuita. Dentro del portal, en la sección de descargas
de software, selecciona:

    - Versión:      HailoRT 5.3.0  (la misma que la HailoRT del contenedor)
    - Arquitectura: arm64 / aarch64  (Raspberry Pi 5, Linux)
    - Driver PCIe + firmware: incluidos en hailort-pcie-driver

Estos paquetes NO son de este repositorio ni de Frigate: son propiedad de Hailo,
y por eso no se distribuyen aquí. Revisa la licencia de Hailo antes de decidir
versionarlos o redistribuirlos (ver /usr/share/doc/<paquete>/copyright dentro
del .deb).

CAMBIO DE NOMBRE RESPECTO A 5.2.0
---------------------------------
En HailoRT 5.2.0 el runtime venía como `h10-hailort_5.2.0_arm64.deb`. En 5.3.0
el paquete se llama simplemente `hailort_5.3.0_arm64.deb`: **no existe la
variante `h10-`**. El Dockerfile copia ese nombre; si tu descarga del portal se
llama distinto, ajusta las dos líneas COPY de docker/main/Dockerfile.


ARCHIVOS QUE DEBES DESCARGAR EN ESTA CARPETA
--------------------------------------------
Descarga cada uno del portal y conserva el nombre exacto del archivo:

Nombre                                                          ¿Build de este repo?
--------------------------------------------------------------  --------------------
hailort_5.3.0_arm64.deb                                         SÍ  (Dockerfile)
hailort-5.3.0-cp311-cp311-linux_aarch64.whl                     SÍ  (Dockerfile)
hailort-pcie-driver_5.3.0_all.deb                               no  (host)
hailort-5.3.0-cp310-cp310-linux_aarch64.whl                     no  (host, Py3.10)
hailort-5.3.0-cp312-cp312-linux_aarch64.whl                     no  (host, Py3.12)
hailo-tappas-core_5.3.0_arm64.deb                               no
hailo_gen_ai_model_zoo_5.3.0_arm64.deb                          no
hailo-accelerator-integration-tool_5.3.0_arm64.deb              no
hailo_dataflow_compiler-5.3.0-py3-none-linux_x86_64.whl         NO  (x86_64: solo PC)
--------------------------------------------------------------  --------------------

Los tamaños dependen del portal; el único grande es el compilador de dataflow
(~120 MB) y ese no se instala ni en la Pi ni dentro de la imagen.


NUNCA INSTALAR EN LA RASPBERRY PI
---------------------------------
Como regla general: en la Pi solo se instalan paquetes arm64 / aarch64 / all, y se
descarta todo lo que esté marcado como x86_64.

hailo_dataflow_compiler-5.3.0-py3-none-linux_x86_64.whl
    Es el compilador de modelos (ONNX / TensorFlow -> .hef) y está compilado para
    x86_64, así que solo funciona en tu PC de escritorio Intel/AMD. Instalarlo en
    la Pi falla por incompatibilidad de arquitectura. Pesa ~120 MB.


DETALLE DE CADA ARCHIVO
-----------------------

hailort_5.3.0_arm64.deb                    [DOCKERFILE + HOST]
    Paquete Debian:        hailort 5.3.0 (arm64)
    Contenido:             /usr/bin/hailortcli
                           /usr/lib/libhailort.so.5.3.0
                           /usr/include/hailo/** (incluye GenAI: llm, vlm,
                           speech2text)
                           /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgsthailo.so
                           /usr/lib/cmake/HailoRT/**
    Para qué:              HailoRT 5.3.0 (usuarios). El Dockerfile lo copia dentro
                           de la imagen, donde reemplaza a la HailoRT 4.21.0 que
                           trae Frigate de fábrica (sin él, el Hailo-10H falla con
                           HAILO_DRIVER_INVALID_IOCTL(86)). Además es el que se
                           instala en el host para tener hailortcli y comprobar el
                           NPU fuera del contenedor.

hailort-5.3.0-cp311-cp311-linux_aarch64.whl   [DOCKERFILE]
    Wheel de Python:       hailort 5.3.0 (aarch64, CPython 3.11)
    Para qué:              binding Python de HailoRT que importa el detector
                           (`from hailo_platform import ...`). Frigate usa
                           Python 3.11, por eso es la variante cp311. El
                           Dockerfile lo copia dentro de la imagen.

hailort-pcie-driver_5.3.0_all.deb                        [HOST / RASPBERRY PI]
    Paquete Debian:        hailort-pcie-driver 5.3.0 (all)
    Contenido:             driver PCIe + firmware de Hailo
    Depende de:            build-essential (compila el módulo de kernel)
    Para qué:              instalar en el host para tener el driver hailo1x_pci
                           y el firmware 5.3.0, que es lo que necesita el nodo
                           /dev/hailo0. NO va dentro de la imagen.

hailort-5.3.0-cp310-cp310-linux_aarch64.whl             [OPCIONAL / HOST]
    Wheel de Python:       hailort 5.3.0 (aarch64, CPython 3.10)
    Para qué:              binding para entornos con Python 3.10. La imagen de
                           Frigate no lo usa (usa cp311).

hailort-5.3.0-cp312-cp312-linux_aarch64.whl             [OPCIONAL / HOST]
    Wheel de Python:       hailort 5.3.0 (aarch64, CPython 3.12)
    Para qué:              misma biblioteca que la cp311 pero para entornos con
                           Python 3.12. La imagen de Frigate no la usa.

hailo-tappas-core_5.3.0_arm64.deb                       [OPCIONAL]
    Paquete Debian:        hailo-tappas-core 5.3.0 (arm64)
    Para qué:              componentes core de TAPPAS 5.3.0 (pipelines
                           GStreamer de Hailo). Trae muchas dependencias
                           (gstreamer, libzmq, cairo, etc.). El detector de
                           Frigate NO la necesita.

hailo_gen_ai_model_zoo_5.3.0_arm64.deb                  [OPCIONAL]
    Paquete Debian:        hailo_gen_ai_model_zoo 5.3.0 (arm64)
    Para qué:              model zoo GenAI (LLM, VLM, speech-to-text) que aparece
                           a partir de 5.3.0. Frigate no lo usa: su detección de
                           objetos va por HEF de YOLO, no por el model zoo GenAI.

hailo-accelerator-integration-tool_5.3.0_arm64.deb      [OPCIONAL]
    Paquete Debian:        hailo-accelerator-integration-tool 5.3.0 (arm64)
    Para qué:              herramienta de integración del acelerador, nueva en
                           5.3.0. No hace falta para Frigate.


DESPUÉS DE CLONAR EL REPO (ESTADO ESPERADO)
-------------------------------------------
Si esta carpeta solo tiene README.es.txt y README.txt, no falta nada: así se
publica el repositorio. Antes de construir tienes que agregar al menos
`hailort_5.3.0_arm64.deb` y `hailort-5.3.0-cp311-cp311-linux_aarch64.whl`,
porque el Dockerfile copia esos dos; si faltan (o están vacíos, como los
marcadores de 0 bytes que se usan para preparar la carpeta), el build falla con
un mensaje explícito gracias a la comprobación que hace el propio Dockerfile.

El resto de archivos son para el host (driver/firmware) o material opcional.
Puedes agregarlos como respaldo de la versión exacta que se probó, u omitirlos.

Referencia: el README del repositorio (`README.md` para español, `README.en.md`
para inglés), secciones "Archivos modificados / añadidos" y "Requisitos".
