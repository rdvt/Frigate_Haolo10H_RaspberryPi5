<p align="center">
  <img align="center" alt="logo" src="Hailo10H_5.2.0/docs/static/img/branding/frigate.png">
</p>

# Frigate NVR con soporte Hailo-10H

[English](README.en.md) | \[Español\]

> **Fork no oficial / proyecto comunitario.** No está afiliado ni respaldado por
> [Frigate, Inc.](https://frigate.video), el proyecto [Frigate](https://github.com/blakeblackshear/frigate)
> ni por [Hailo](https://hailo.ai). "Frigate" y "Frigate NVR" son marcas de Frigate, Inc.
> Ver [TRADEMARK.md](Hailo10H_5.2.0/TRADEMARK.md) y [LICENSE](Hailo10H_5.2.0/LICENSE).

Este repositorio contiene el código y la documentación para ejecutar Frigate NVR en una
**Raspberry Pi 5 con Hailo-10H AI HAT+**, organizado por versión de HailoRT.

---

## Elige tu versión de HailoRT

Cada directorio corresponde a una versión específica del driver y del runtime de Hailo.
El driver del host, la imagen Docker y el HEF del Model Zoo deben ser **de la misma generación**.

| Directorio | HailoRT | Driver de kernel (host) | Estado |
|---|---|---|---|
| [**Hailo10H\_5.2.0/**](Hailo10H_5.2.0/README.md) | 5.2.0 | `hailo1x_pci` + firmware 5.2.0 | Primera versión con soporte Hailo-10H |
| [**Hailo10h\_5.3.0/**](Hailo10h_5.3.0/README.md) | 5.3.0 | `hailo1x_pci` + firmware 5.3.0 | Añade preflight del host, wheel cp310, TAPPAS 5.3.0 |
| [**Hailo10H\_5.4.0/**](Hailo10H_5.4.0/README.md) | 5.4.0 | `hailo1x_pci` + firmware 5.4.0 | Driver renombrado a `h10-hailort-pcie-driver` |

> **¿Cuál elegir?** Usa la versión que coincida con el driver que tienes (o vas a instalar)
> en la Raspberry Pi. Si partes de cero, elige la **5.4.0** (la más reciente).

---

## Estructura del repositorio

```
repo/
├── Hailo10H_5.2.0/   ← Fork completo de Frigate para HailoRT 5.2.0
├── Hailo10h_5.3.0/   ← Fork completo de Frigate para HailoRT 5.3.0
└── Hailo10H_5.4.0/   ← Fork completo de Frigate para HailoRT 5.4.0
```

Cada directorio es independiente: contiene su propio `Dockerfile`, el parche de
`hailo8l.py`, el script `build_hailo10h_image.sh`, la carpeta `hailo_files/` con los
manifiestos de paquetes y su documentación completa en español e inglés.

---

## Resumen de cambios por versión

| Cambio | 5.2.0 | 5.3.0 | 5.4.0 |
|---|---|---|---|
| Paquete `.deb` del runtime | `h10-hailort_5.2.0_arm64.deb` | `hailort_5.3.0_arm64.deb` | `hailort_5.4.0_arm64.deb` |
| Paquete del driver | `hailort-pcie-driver` | `hailort-pcie-driver` | **`h10-hailort-pcie-driver`** (renombrado) |
| Wheel Python obligatorio | `cp311` | `cp311` (+ `cp310`) | `cp311` (+ `cp310`, `cp312`) |
| Preflight del host en el script | ✗ | ✔ | ✔ |
| Rollback documentado entre versiones | ✗ | ✔ | ✔ |

---

## Documentación general de Frigate

<https://docs.frigate.video>
