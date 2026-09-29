========================================================================
 hailo_files/ — paquetes HailoRT 5.2.0 para Hailo-10H
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

    - Versión:      HailoRT 5.2.0  (la misma que la HailoRT del contenedor)
    - Arquitectura: arm64 / aarch64  (Raspberry Pi 5, Linux)
    - Driver PCIe + firmware: incluidos en hailort-pcie-driver

Estos paquetes NO son de este repositorio ni de Frigate: son propiedad de Hailo,
y por eso no se distribuyen aquí. Revisa la licencia de Hailo antes de decidir
versionarlos o redistribuirlos (ver /usr/share/doc/h10-hailort/copyright dentro
del .deb).

Cuando los necesites otra vez —por ejemplo justo después de clonar el repo—
vuelve a bajarlos del portal y colócalos aquí con los mismos nombres.


ARCHIVOS QUE DEBES DESCARGAR EN ESTA CARPETA
--------------------------------------------
Descarga cada uno del portal y conserva el nombre exacto del archivo:

Nombre                                                    Tamaño   ¿Build de este repo?
--------------------------------------------------------  -------  --------------------
h10-hailort_5.2.0_arm64.deb                                4.9 MB   SÍ  (Dockerfile)
hailort-5.2.0-cp311-cp311-linux_aarch64.whl               7.5 MB   SÍ  (Dockerfile)
hailort-pcie-driver_5.2.0_all.deb                         27.8 MB   no  (host)
hailort_5.2.0_arm64.deb                                    5.0 MB   no  (host)
hailort-5.2.0-cp312-cp312-linux_aarch64.whl               7.5 MB   no
hailo-tappas-core_5.2.0_arm64.deb                          6.0 MB   no
hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl    2.5 MB   no
--------------------------------------------------------  -------
                                                  TOTAL    ~61 MB


NUNCA INSTALAR EN LA RASPBERRY PI
---------------------------------
Como regla general: en la Pi solo se instalan paquetes arm64 / aarch64 / all, y se
descarta todo lo que esté marcado como x86_64.

hailo_dataflow_compiler-5.2.0-py3-none-linux_x86_64.whl   (NO está en esta carpeta)
    Es el compilador de modelos (ONNX / TensorFlow -> .hef) y está compilado para
    x86_64, así que solo funciona en tu PC de escritorio Intel/AMD. Instalarlo en
    la Pi falla por incompatibilidad de arquitectura.


DETALLE DE CADA ARCHIVO
-----------------------

h10-hailort_5.2.0_arm64.deb                    [USADO POR EL DOCKERFILE]
    Paquete Debian:        h10-hailort 5.2.0 (arm64)
    Contenido:             /usr/bin/hailortcli
                           /usr/lib/libhailort.so.5.2.0
                           /usr/include/hailo/** (incluye GenAI: llm, vlm,
                           speech2text)
                           /usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgsthailo.so
                           /usr/lib/cmake/HailoRT/**
    Para qué:              HailoRT 5.2.0 (usuarios) dentro de la imagen. Es el
                           paquete que reemplaza a la HailoRT 4.21.0 que trae
                           Frigate de fábrica. Sin él, el Hailo-10H falla con
                           HAILO_DRIVER_INVALID_IOCTL(86).

hailort-5.2.0-cp311-cp311-linux_aarch64.whl   [USADO POR EL DOCKERFILE]
    Wheel de Python:       hailort 5.2.0 (aarch64, CPython 3.11)
    Para qué:              binding Python de HailoRT que importa el detector
                           (`from hailo_platform import ...`). Frigate usa
                           Python 3.11, por eso es la variante cp311.

hailort-pcie-driver_5.2.0_all.deb                        [HOST / RASPBERRY PI]
    Paquete Debian:        hailort-pcie-driver 5.2.0 (all)
    Contenido:             driver PCIe + firmware de Hailo
    Depende de:            build-essential (compila el módulo de kernel)
    Para qué:              instalar en el host para tener el driver hailo1x_pci
                           y el firmware 5.2.0, que es lo que necesita el nodo
                           /dev/hailo0. NO va dentro de la imagen.

hailort_5.2.0_arm64.deb                                  [OPCIONAL / HOST]
    Paquete Debian:        hailort 5.2.0 (arm64)
    Contenido:             igual al h10-hailort (runtime + bibliotecas +
                           hailortcli), distribuido como paquete estándar.
    Para qué:              instalar HailoRT 5.2.0 en el host si quieres usar
                           hailortcli fuera del contenedor para diagnóstico.

hailort-5.2.0-cp312-cp312-linux_aarch64.whl             [OPCIONAL]
    Wheel de Python:       hailort 5.2.0 (aarch64, CPython 3.12)
    Para qué:              misma biblioteca que la cp311 pero para entornos con
                           Python 3.12. La imagen de Frigate no la usa.

hailo-tappas-core_5.2.0_arm64.deb                       [OPCIONAL]
    Paquete Debian:        hailo-tappas-core 5.2.0 (arm64)
    Para qué:              componentes core de TAPPAS 5.2.0 (pipelines
                           GStreamer de Hailo). Trae muchas dependencias
                           (gstreamer, libzmq, cairo, etc.). El detector de
                           Frigate NO la necesita.

hailo_tappas_core_python_binding-5.2.0-py3-none-any.whl [OPCIONAL]
    Wheel de Python:       hailo-tappas-core-python-binding 5.2.0
    Para qué:              bindings Python de TAPPAS. Solo si vas a usar las
                           pipelines GStreamer de Hailo.


DESPUÉS DE CLONAR EL REPO (ESTADO ESPERADO)
-------------------------------------------
Si esta carpeta solo tiene README.es.txt y README.txt, no falta nada: así se
publica el repositorio. Antes de construir tienes que agregar al menos
`h10-hailort_5.2.0_arm64.deb` y `hailort-5.2.0-cp311-cp311-linux_aarch64.whl`,
porque el Dockerfile copia esos dos; si faltan, el build falla en el paso COPY.
Descárgalos del portal de Hailo (5.2.0, arm64) y vuelve a intentar.

El resto de archivos son para el host (driver/firmware) o material opcional.
Puedes agregarlos como respaldo de la versión exacta que se probó, u omitirlos.

Referencia: el README del repositorio (`README.es.md` para español,
`README.md` para inglés), secciones "Archivos modificados / añadidos" y
"Requisitos".
