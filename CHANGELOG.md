# Changelog

Todas las novedades relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
el versionado semántico ([SemVer](https://semver.org/lang/es/)).

## [1.1.0] - 2026-09-27

### Corregido

- **El diálogo del target se abría solo cada 2 segundos.** Si un *Generic
  Monitor* del panel tenía como comando `vpn-set-target` (o `vpn-clear-target`)
  en lugar del indicador, el panel ejecutaba el diálogo en cada refresh: se
  acumulaban ventanas y el target parecía "pedirse" endlessly, incluso después
  de aceptarlo. El instalador ahora lo detecta, lo avisa y lo corrige; el
  diálogo además tiene un lock, así que nunca se apilan ventanas.
- El diálogo mostraba los `\n` literales en vez de saltos de línea.
- La validación del target aceptaba cualquier cuádruplo con puntos
  (`999.999.999.999`) y rechazaba hostnames. Ahora acepta IPv4, IPv4 con CIDR y
  hostnames, y recorta espacios.

### Añadido

- Menú con una opción nueva: **Estado / diagnóstico** (`estado`, `status`,
  `diag`), que informa los scripts instalados, el target, el comando de cada
  *Generic Monitor* y la salida real del indicador.
- Auditoría del panel: detecta *Generic Monitor* que apuntan a los diálogos y los
  reasigna al indicador durante la instalación.
- El instalador muestra la URL del repositorio en el menú, en la ayuda y en el
  diagnóstico.

### Cambiado

- El target es explícitamente **opcional** en toda la interfaz: título
  `Target (opcional)`, botones `Guardar` / `Cancelar`, y un texto que aclara que
  `Cancelar` no cambia nada.
- Tooltips del indicador: "Clic para escribir un target (opcional)".
- Numeración del menú: 1) instalar, 2) estado, 3) desinstalar, 4) salir.

## [1.0.0] - 2026-09-27

### Añadido

- Menú interactivo de instalación, desinstalación y salida, con los mismos
  accesos por línea de comandos (`instalar`, `desinstalar`, `salir`, `--help`).
- Barra de progreso con spinner y log por paso; las últimas 12 líneas del log
  se muestran cuando un paso falla.
- Validación de compatibilidad previa (sesión gráfica, escritorio XFCE,
  `xfce4-panel`, plugin *Generic Monitor*, `libgenmon.so`, herramientas base,
  `zenity`, `notify-send`, permisos de escritura y ejecución como `root`).
- Instalación automática de `zenity` cuando falta.
- Detección automática del *Generic Monitor* del panel con tres prioridades:
  reutilizar el que ya apunta al indicador, usar uno sin comando, o preguntar
  antes de sobrescribir uno en uso.
- Indicador del panel con estado de la VPN (`tun0` + proceso `openvpn` + ruta
  activa) e IP del target en la misma línea.
- Diálogo `zenity` para escribir el target, con validación de IPv4 y borrado
  al dejar el campo vacío.
- `vpn-clear-target` para borrar el target desde la terminal o un atajo.
- Avisos con `notify-send` al cambiar o borrar el target.
- Desinstalación completa: vacía el plugin, borra los scripts, el target y el
  archivo de estado, con recarga opcional del panel.
- Soporte de `NO_COLOR` y de salida sin TTY (instalación desatendida).
- Documentación: [README](README.md),
  [cómo funciona](docs/COMO-FUNCIONA.md) y
  [troubleshooting](docs/TROUBLESHOOTING.md).

### Cambiado

- La documentación habla de "clic" y no de "clic izquierdo": `<txtclick>` del
  *Generic Monitor* se ejecuta con cualquier clic sobre el texto.

[1.1.0]: https://github.com/jarodsmdev/VPN-TARGET-INDICATOR/releases/tag/v1.1.0
[1.0.0]: https://github.com/jarodsmdev/VPN-TARGET-INDICATOR/releases/tag/v1.0.0
