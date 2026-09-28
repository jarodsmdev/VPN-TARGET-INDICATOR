<div align="center">

# VPN Target Indicator

<img src="https://img.shields.io/badge/XFCE4-2980b9?style=for-the-badge&logo=xfce&logoColor=white" alt="XFCE4">
<img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash">
<img src="https://img.shields.io/badge/Licen%20se-MIT-blue?style=for-the-badge" alt="Licencia MIT">
<img src="https://img.shields.io/badge/Plataforma-Linux-FFD700?style=for-the-badge&logo=linux&logoColor=black" alt="Linux">
<img src="https://img.shields.io/badge/versi%C3%B3n-1.1.0-8A2BE2?style=for-the-badge" alt="Version 1.1.0">

**Indicador de escritorio para XFCE que muestra en el panel el estado de tu VPN y la IP del target en el que estás trabajando.**

Un solo script instalable, sin dependencias de compilación, que se integra con el
*Generic Monitor* del panel y se gestiona con un menú interactivo.

[Instalación](#instalación) · [Uso](#uso) · [Comandos](#opciones-de-línea-de-comandos) · [Actualizar](#actualizar-o-reinstalar) · [Problemas frecuentes](#problemas-frecuentes) · [Licencia](#licencia)

> El target es **opcional**. El indicador funciona y muestra el estado de la VPN
> aunque nunca escribas una IP.

</div>

---

## ¿Qué muestra?

```
🔒 VPN: 10.10.14.5  │  🎯 TARGET: dc01.lab
```

Un clic sobre el indicador abre una ventana para escribir la IP o el hostname
del target. **Es opcional**: si no escribís nada, el panel muestra únicamente el
estado de la VPN (`🔒 VPN: OFF` cuando no hay túnel) y `Cancelar` siempre es una
respuesta válida.

## Características

- **Estado de la VPN en vivo** — detecta la IP de `tun0` y valida que el proceso
  `openvpn` esté corriendo y con ruta activa.
- **Target opcional y persistente** — la IP (o el hostname) queda en
  `~/.config/vpn-target`; sin archivo, el indicador funciona igual.
- **Un clic para escribirlo** — diálogo `zenity` con botones `Guardar` /
  `Cancelar` y el valor actual precargado. Acepta IPv4, IPv4 con CIDR
  (`10.10.14.0/24`) y hostnames (`dc01.lab`).
- **Sin diálogos apilados** — un lock evita que se abran varias ventanas a la
  vez aunque el panel lance el script varias veces.
- **Sin recompilar nada** — el indicador es un script de Bash que el
  *Generic Monitor* ejecuta cada 2 segundos.
- **Menú interactivo** — instalador con barra de progreso, validaciones de
  compatibilidad, autodiagnóstico (`estado`) y desinstalación completa en un
  único archivo.
- **Auditoría del panel** — detecta un *Generic Monitor* mal configurado (por
  ejemplo, apuntando al diálogo en vez del indicador) y lo corrige solo.
- **Reinstalación limpia** — volvés a ejecutar `instalar` las veces que quieras:
  reutiliza el mismo plugin del panel y conserva tu target.
- **No invasivo** — todo vive dentro de `$HOME`; no modifica el sistema ni
  requiere `sudo` (salvo al instalar `zenity` si falta).
- **Color aware** — desactiva los códigos ANSI cuando la salida no es una TTY
  o cuando se define `NO_COLOR=1`.

## Requisitos

| Componente | Necesario | Notas |
| --- | --- | --- |
| Linux + XFCE 4 | Sí | Sin XFCE instala los scripts, pero no configura el panel |
| Bash 4+ | Sí | |
| `xfce4-genmon-plugin` | Sí | *Generic Monitor* del panel |
| `xfconf` (incluye `xfconf-query`) | Sí | Para leer y escribir la configuración del panel |
| `zenity` | Se instala si falta | Diálogo de entrada del target |
| `libnotify-bin` | Opcional | Avisos al cambiar el target |
| Herramientas base | Sí | `iproute2` (`ip`), `procps` (`pgrep`), `gawk`, `sed`, `grep`, `coreutils` |

En Debian/Ubuntu/Kali:

```bash
sudo apt install xfce4-genmon-plugin xfconf zenity libnotify-bin iproute2 procps gawk
```

## Instalación

### Opción 1 — clonar y ejecutar (recomendado)

```bash
git clone https://github.com/jarodsmdev/vpn-target-indicator.git
cd vpn-target-indicator
chmod +x vpn-target-indicator.sh
./vpn-target-indicator.sh
```

### Opción 2 — línea única

```bash
curl -fsSL https://raw.githubusercontent.com/jarodsmdev/vpn-target-indicator/main/vpn-target-indicator.sh | bash
```

> Ejecuta el script **como tu usuario de escritorio**, nunca como `root`: los
> archivos se instalan en tu `$HOME` y el panel sólo los ve en tu sesión.

## Uso

Al ejecutarlo sin argumentos se abre el menú:

```
==============================================
     VPN TARGET INDICATOR  v1.1.0
==============================================

  Estado: 3/3 scripts en /home/tu/.local/bin │ target 10.10.14.42

  1)  Instalar / reinstalar
  2)  Estado / diagnóstico
  3)  Desinstalar
  4)  Salir

  Repo: https://github.com/jarodsmdev/VPN-TARGET-INDICATOR

  Elige una opción [1-4]:
```

1. **Instalar / reinstalar** — valida el entorno, migra una instalación
   anterior si existe, audita y corrige el panel, instala `zenity` si hace
   falta, escribe los tres scripts, engancha el *Generic Monitor* y prueba el
   indicador.
2. **Estado / diagnóstico** — muestra qué scripts están instalados, el target
   guardado, qué *Generic Monitor* apunta a qué y cuál es la salida real del
   indicador. Es la herramienta para diagnosticar problemas de panel.
3. **Desinstalar** — vacía el comando del plugin, borra los scripts y el
   target guardado, y opcionalmente recarga el panel.

Después de instalar, el flujo habitual es:

- **Clic** en el indicador → escribir la IP o el hostname del target.
- **Guardar con el campo vacío** → borrar el target.
- **Cancelar** → no cambia nada (el target es opcional).
- **Sin target** → el panel muestra sólo `🔒 VPN: OFF` o `🔒 VPN: 10.10.14.5`.

## Opciones de línea de comandos

El menú es opcional: el script acepta una acción directa, útil para
automatizar o para instaladores de sistemas.

```bash
./vpn-target-indicator.sh instalar      # instala (alias: install, i)
./vpn-target-indicator.sh estado        # diagnóstico (alias: status, diag)
./vpn-target-indicator.sh desinstalar   # desinstala (alias: uninstall, remove, d)
./vpn-target-indicator.sh salir         # sale (alias: exit, s, q)
./vpn-target-indicator.sh --help        # ayuda (alias: -h, help)
```

```bash
# Ejemplo: instalación silenciosa, sin preguntas interactivas
curl -fsSL https://raw.githubusercontent.com/jarodsmdev/vpn-target-indicator/main/vpn-target-indicator.sh \
  | bash -s -- instalar
```

## Archivos generados

| Ruta | Descripción |
| --- | --- |
| `~/.local/bin/vpn-indicator.sh` | Indicador del panel: emite el `<txt>` de Genmon y el `<txtclick>` |
| `~/.local/bin/vpn-set-target` | Diálogo `zenity` para escribir o borrar el target |
| `~/.local/bin/vpn-clear-target` | Borra el target y avisa por `notify-send` |
| `~/.config/vpn-target` | Target actual (una línea con la IP) |
| `~/.config/vpn-panel-plugin` | ID del plugin del panel que quedó configurado |
| `xfce4-panel` → `/plugins/<id>/command` | Ruta al indicador, con `period = 2` (segundos) |

### ⚠ Importante: el comando del Generic Monitor

En *Configuración del panel ▸ Elementos ▸ Generic Monitor ▸ Editar*, el campo
**Comando** debe contener **únicamente** la ruta del indicador:

```
/home/tu/.local/bin/vpn-indicator.sh
```

**Nunca** pongas `vpn-set-target` ni `vpn-clear-target` ahí. Son los diálogos: si
el panel los ejecuta cada 2 segundos, se abriría una ventana tras otra y
parecería que el target se pide solo. El instalador detecta esa configuración y
la corrige, pero si lo hacés a mano, `estado` te lo dice:

```bash
./vpn-target-indicator.sh estado
```

Los diálogos se abren **con un clic** sobre el indicador, no solos.

## Actualizar o reinstalar

```bash
git pull
./vpn-target-indicator.sh instalar
```

La instalación es idempotente: vuelve a escribir los tres scripts, reutiliza el
mismo *Generic Monitor* si ya está configurado y **conserva tu target**. También
audita el panel y corrige cualquier comando mal puesto (ver
[Comando del Generic Monitor](#importante-el-comando-del-generic-monitor)).

Para empezar de cero sin perder el target:

```bash
rm -f ~/.config/vpn-target    # opcional: borra el target guardado
./vpn-target-indicator.sh instalar
```

## Cómo funciona

```
tun0 + proceso openvpn  ──►  vpn-indicator.sh  ──►  Generic Monitor (panel)
        │                                                    │
        └── IP de la VPN                                     │ clic
                                                             ▼
                              ~/.config/vpn-target  ◄──  vpn-set-target (zenity)
```

1. `vpn-indicator.sh` corre cada 2 segundos. Consulta la IPv4 de `tun0`, la
   presencia del proceso `openvpn` y la ruta activa de la interfaz.
2. Si las tres condiciones se cumplen imprime `VPN: <ip>`; en caso contrario
   `VPN: OFF`.
3. Si existe `~/.config/vpn-target`, añade `🎯 TARGET: <ip>` a la misma línea.
4. El último `<txtclick>` apunta a `vpn-set-target`, que valida la IP con una
   expresión regular y escribe (o borra) el archivo de target.

El detalle completo, incluidos los criterios de detección y la selección del
plugin, está en **[docs/COMO-FUNCIONA.md](docs/COMO-FUNCIONA.md)**.

## Personalización

| Qué | Dónde | Por defecto |
| --- | --- | --- |
| Interfaz de la VPN | `vpn-indicator.sh` → `tun0` | `tun0` |
| Periodo de refresco | `xfconf-query -c xfce4-panel -p /plugins/<id>/period` | `2` segundos |
| ID del plugin usado | `~/.config/vpn-panel-plugin` | elegido por el instalador |
| Emojis del panel | `vpn-indicator.sh` → `echo "<txt>🔒 …"` | `🔒` y `🎯` |

Después de editar `~/.local/bin/vpn-indicator.sh`, el panel lo refleja en el
siguiente ciclo de refresco (o al reiniciar el panel con `xfce4-panel -r`).

## Desinstalación

```bash
./vpn-target-indicator.sh desinstalar
```

La desinstalación vacía el comando del *Generic Monitor* (dejando el resto de
sus ajustes intactos), borra los tres scripts, el target y el archivo de
estado y, si hace falta, los restos de una instalación previa.
Si queda un proceso antiguo del indicador en el panel, recarga el panel o
cierra la sesión.

Para una limpieza total, desde XFCE:
**Configuración del panel ▸ Elementos ▸ Generic Monitor ▸ Editar ▸ Eliminar**.

## Problemas frecuentes

Resumen rápido; la guía completa está en
**[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| **El diálogo del target se abre solo, cada 2 s** | El *Generic Monitor* apunta a `vpn-set-target` en vez del indicador | `./vpn-target-indicator.sh instalar` lo corrige, o poné `vpn-indicator.sh` en *Editar ▸ Comando* |
| El panel no muestra nada | No hay ningún *Generic Monitor* en el panel | Añádelo en *Configuración del panel ▸ Elementos ▸ Añadir* |
| `xfconf-query no está instalado` | Falta `xfconf` | `sudo apt install xfconf` |
| Aparece `VPN: OFF` con la VPN conectada | La interfaz no es `tun0` o falta el proceso `openvpn` | Edita `tun0` en `vpn-indicator.sh` |
| No aparecen los avisos | Falta `libnotify-bin` | `sudo apt install libnotify-bin` |
| `Todos los Generic Monitor ya están en uso` | Ningún plugin tiene el comando libre | Responde `S` para reasignar el primero, o deja otro *Generic Monitor* sin usar |

Para diagnosticar sin adivinar, `./vpn-target-indicator.sh estado` imprime los
scripts instalados, el target, el comando de cada *Generic Monitor* y la salida
real del indicador.

## Estructura del repositorio

```
.
├── vpn-target-indicator.sh   # instalador / desinstalador (único archivo ejecutable)
├── docs/
│   ├── COMO-FUNCIONA.md      # arquitectura, detección de VPN, panel, migración
│   └── TROUBLESHOOTING.md    # diagnóstico y soluciones
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Contribuciones

Las contribuciones son bienvenidas. Lee
**[CONTRIBUTING.md](CONTRIBUTING.md)** y abrí un issue antes de enviar cambios
grandes.

```bash
git clone https://github.com/jarodsmdev/vpn-target-indicator.git
cd vpn-target-indicator
bash -n vpn-target-indicator.sh    # chequeo de sintaxis
./vpn-target-indicator.sh --help
```

## Licencia

Distribuido bajo la licencia MIT. Ver [LICENSE](LICENSE).

Funciona con cualquier VPN y cualquier objetivo de trabajo: no está atado a
ninguna plataforma en particular.
