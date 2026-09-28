# Cómo contribuir

Gracias por querer mejorar **VPN Target Indicator**. Todo el proyecto vive en
un único script de Bash, así que las contribuciones son bienvenidas y fáciles de
revisar.

## Reportar un problema

Abrí un issue en
<https://github.com/jarodsmdev/vpn-target-indicator/issues> incluyendo:

- Distribución y versión de XFCE.
- Pasos para reproducirlo.
- Salida de `./vpn-target-indicator.sh instalar`.
- Salida de `~/.local/bin/vpn-indicator.sh`.
- Resultado de `xfconf-query -c xfce4-panel -lv | grep genmon`.

Si es un bug, probá primero la sección
[Troubleshooting](docs/TROUBLESHOOTING.md): casi todo se diagnostica en dos
comandos.

## Entorno de desarrollo

```bash
git clone https://github.com/jarodsmdev/vpn-target-indicator.git
cd vpn-target-indicator
```

No hay Makefile ni gestor de paquetes: el "build" es el propio script.

### Antes de enviar un cambio

```bash
bash -n vpn-target-indicator.sh          # sintaxis
shellcheck vpn-target-indicator.sh       # análisis estático (opcional)
```

Probá en un entorno aislado, sin tocar tu instalación real. `VPN_TI_SKIP_PANEL=1`
es **obligatorio** en ese caso: sin él, la instalación lee y reescribe la
configuración del panel de tu sesión de verdad y lo reinicia (aunque los
scripts se يريد en el `HOME` temporal).

```bash
HOME=$(mktemp -d) VPN_TI_SKIP_PANEL=1 ./vpn-target-indicator.sh instalar
HOME=$(mktemp -d) VPN_TI_SKIP_PANEL=1 ./vpn-target-indicator.sh desinstalar
```

Con el panel real, probá siempre sobre una máquina de pruebas o con un panel
respaldo listo (`xfce4-panel &` a mano): instalar **reinicia el panel**.

```bash
VPN_TI_SKIP_PANEL=1 ./vpn-target-indicator.sh instalar | grep SKIP_PANEL
# VPN_TI_SKIP_PANEL=1: no se tocó el panel.
```

### Probar los cambios de panel

Los pasos que tocan el panel (`step_panel`, `step_fix_panel`, `step_panel_restart`,
`step_unpanel`, `step_reload_panel`) se pueden exertar por separado sin instalar
nada, sourcing el script con `main` neutralizado:

```bash
sed 's/^main "/function main "/' vpn-target-indicator.sh > /tmp/vti-noexec.sh
. /tmp/vti-noexec.sh
genmon_period_key            # update-period o period, según la versión instalada
panel_detect; echo "$PLUGIN_ID:$PANEL_MSG"
panel_plugin_line plugin-23
```

Recordá que el panel vivo pisa lo que escribas en `xfconf` al guardarse: para
probar un valor real, usá `panel_stop` → escribí → `panel_start`.

Verificá también el modo desatendido, que es el que usan los instaladores de
distribución:

```bash
NO_COLOR=1 ./vpn-target-indicator.sh --help
curl -fsSL https://raw.githubusercontent.com/jarodsmdev/vpn-target-indicator/main/vpn-target-indicator.sh | bash -s -- --help
```

## Estilo

- Bash con comillas en todas las expansiones y `set -e` en el instalador.
- Mensajes al usuario en español; comentarios del código en español e inglés
  sólo cuando el término no tiene traducción clara.
- Las variables de ruta se definen arriba del todo: `BASE`, `CONFIG`,
  `TARGET_FILE`, `IND`, `GUI`, `CLR`, `STATE_FILE`.
- Todo lo que se escribe dentro de `$HOME` debe ser reversible por
  `do_uninstall`.
- Nada de dependencias nuevas fuera de `zenity`, `notify-send` y las
  herramientas base de GNU/Linux.

## Pull requests

1. Creá una rama: `git checkout -b mi-cambio`.
2. Commiteos pequeños y descriptivos.
3. Actualizá `CHANGELOG.md` bajo la sección *No publicado*.
4. Si cambiás comportamiento, actualizá `README.md` y `docs/`.
5. Abrí el PR describiendo el problema que resuelve y cómo lo verificaste.

## Alcance

Se aceptan cambios que:

- Mejoren la detección de VPN, la validación del target o el trabajo con el
  panel de XFCE.
- Agreguen soporte para otros clientes VPN (WireGuard, `tun1`…) de forma
  configurable.
- Mejoren la experiencia de línea de comandos y la documentación.

No se aceptan cambios que:

- Requieran privilegios de `root` más allá de instalar `zenity`.
- Modifiquen archivos fuera de `$HOME` (salvo los paquetes de sistema que el
  propio usuario instale).
- Dependan de un gestor de ventanas distinto de XFCE sin mantener el fallback
  actual.

## Código de conducta

Sé respetuoso. En los issues, PRs y discusiones se espera un trato amable; los
comportamientos abusivos no serán tolerados.
