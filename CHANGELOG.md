# Changelog

Todas las novedades relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y
el versionado semántico ([SemVer](https://semver.org/lang/es/)).

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

- El proyecto se independizó de Hack The Box y pasó a ser genérico: el nombre,
  los archivos, el estado y los mensajes usan el prefijo `vpn-*` en lugar de
  `htb-*`.
  - `htb-indicator.sh` → `vpn-indicator.sh`
  - `htb-set-target-gui` → `vpn-set-target`
  - `htb-clear-target` → `vpn-clear-target`
  - `~/.config/htb-target` → `~/.config/vpn-target`
  - `~/.config/htb-panel-plugin` → `~/.config/vpn-panel-plugin`
  - `HTB-INSTALL.sh` → `vpn-target-indicator.sh`
- El instalador migra automáticamente una instalación `htb-*`: conserva el
  target (mueve `~/.config/htb-target`), borra los scripts antiguos y reasigna
  sin preguntar el *Generic Monitor* que apuntaba a `htb-indicator.sh`.
- La desinstalación también borra los restos de la versión anterior.
- La documentación habla de "clic" y no de "clic izquierdo": `<txtclick>` del
  *Generic Monitor* se ejecuta con cualquier clic sobre el texto.

### Notas

- Los targets guardados por versiones anteriores (`~/.config/htb-target`) se
  migran solos al instalar; si prefieres hacerlo a mano:
  `mv ~/.config/htb-target ~/.config/vpn-target`.

[1.0.0]: https://github.com/jarodsmdev/vpn-target-indicator/releases/tag/v1.0.0
