# Troubleshooting

Diagnóstico y soluciones para los problemas más habituales.

## Diagnóstico rápido

Primero, probá el indicador a mano. Si imprime una línea `<txt>…</txt>`, el
script funciona y el problema está en el panel:

```bash
~/.local/bin/vpn-indicator.sh
```

Verificá que los tres scripts existen y son ejecutables:

```bash
ls -l ~/.local/bin/vpn-*
```

Comprobá el estado del plugin en el panel:

```bash
xfconf-query -c xfce4-panel -lv | grep genmon
```

Deberías ver `command` apuntando a `~/.local/bin/vpn-indicator.sh` y
`period = 2`.

---

## El panel no muestra nada

**Causa:** no hay ningún *Generic Monitor* en el panel, o su comando está
vacío.

**Solución:** en XFCE, *Configuración del panel ▸ Elementos ▸ Añadir ▸
Generic Monitor*. Luego apuntá el comando a:

```
/home/tu/.local/bin/vpn-indicator.sh
```

y poné el periodo en `2` segundos. Después reiniciá el panel:

```bash
xfce4-panel -r
```

El instalador también puede hacerlo: `./vpn-target-indicator.sh instalar`
detecta un slot libre y lo configura solo.

---

## `xfconf-query no está instalado`

**Causa:** falta el paquete `xfconf`, así que el instalador no puede leer ni
escribir la configuración del panel.

```bash
sudo apt install xfconf
```

Los scripts se instalan igual; sólo se omite (o se hace a mano) el paso del
panel.

---

## `No se encontró libgenmon.so (Generic Monitor)`

**Causa:** el plugin del panel no está instalado.

```bash
sudo apt install xfce4-genmon-plugin
```

Después reiniciá la sesión de XFCE (o `xfce4-panel -r`).

---

## El panel muestra `VPN: OFF` pero la VPN está conectada

**Causas posibles:**

1. La interfaz no es `tun0` (típico con `tun1`, `tap0`, `wg0`).
2. El cliente VPN no es `openvpn` (WireGuard no crea un proceso `openvpn`).
3. La ruta por defecto no pasa por `tun0` (split tunnel).

**Diagnóstico:**

```bash
ip -4 addr show tun0
pgrep -x openvpn
ip route show dev tun0
```

**Solución:** ajustá el indicador a tu caso. Por ejemplo, para un cliente que
no usa `openvpn`, quitá la comprobación del proceso y dejá sólo la IP y la ruta:

```bash
# ~/.local/bin/vpn-indicator.sh
if [ -n "$VPN_IP" ] && [ -n "$VPN_ROUTE" ]; then
    VPN="VPN: $VPN_IP"
else
    VPN="VPN: OFF"
fi
```

Para WireGuard, cambiá `tun0` por `wg0` y `pgrep -x openvpn` por
`pgrep -x wg-quick`. Recargá el panel con `xfce4-panel -r` al terminar.

---

## La ventana de escribir el target no aparece

1. Verificá que `zenity` está instalado: `command -v zenity`.
2. Probá el script directamente: `~/.local/bin/vpn-set-target`.
3. Si cancelás el diálogo, el script termina con `exit 0` sin cambios: es el
   comportamiento esperado, no un error.

Para ejecutarlo desde una terminal de apoyo y ver errores:

```bash
bash -x ~/.local/bin/vpn-set-target
```

---

## No llegan los avisos al cambiar el target

`notify-send` viene en `libnotify-bin` y requiere un gestor de notificaciones
activo.

```bash
sudo apt install libnotify-bin
```

Sin él, el indicador **sigue funcionando**: sólo desaparecen los avisos.

---

## El indicador quedó congelado o vacío en el panel

El *Generic Monitor* guarda en caché la salida del comando. Para forzar el
refresco:

```bash
xfce4-panel -r
```

Si sigue igual, eliminá el plugin del panel y volvé a instalarlo con
`./vpn-target-indicator.sh instalar`.

---

## El script se ejecutó con `sudo` y el panel no ve nada

Con `sudo`, `$HOME` apunta a `/root`: los scripts se instalan en
`/root/.local/bin` y el panel corre en tu usuario, así que no los encuentra.
Además, el plugin se configuró con una ruta que tu usuario no puede leer.

**Solución:** desinstalá como root (`sudo ./vpn-target-indicator.sh
desinstalar`) y reinstalá **sin** `sudo`.

---

## Errores de permisos en `~/.local/bin` o `~/.config`

El instalador aborta con un bloqueo si no puede escribir. Suele pasar cuando
`$HOME` apunta a un directorio montado con `noexec` o sin permisos para tu
usuario. Verificá:

```bash
ls -ld "$HOME" "$HOME/.local" "$HOME/.config"
```

Si `~/.config` no existe, el instalador lo crea; si falla por permisos, corrige
el propietario o ejecutá el script con el usuario correcto.

---

## La instalación falla a mitad de camino

El script se detiene en el primer paso fallido y muestra las últimas líneas del
log de ese paso. Los pasos completados **no se deshacen**. Vuelve a ejecutar
`./vpn-target-indicator.sh instalar`: la instalación es idempotente y
sobrescribe los archivos.

Si el problema es `apt`, configurá un mirror que funcione y reintentá; el
instalador sólo llama a `sudo apt` cuando falta `zenity`.

---

## Desinstalé pero el panel sigue ejecutando el indicador

La desinstalación vacía el comando del plugin, pero el proceso antiguo queda
vivo hasta que el panel se recarga:

```bash
xfce4-panel -r
```

Si lo hacés por remoto (SSH) o sin sesión gráfica, cerrá y abrí la sesión de
escritorio. Para eliminar el plugin por completo: *Configuración del panel ▸
Elementos ▸ Generic Monitor ▸ Editar ▸ Eliminar*.

---

## Comprobación de sintaxis del script

Antes de reportar un bug, verificá que el script no tenga errores de sintaxis:

```bash
bash -n vpn-target-indicator.sh
```

Y, si tenés `shellcheck` instalado:

```bash
shellcheck vpn-target-indicator.sh
```

---

## Reportar un problema

Abrí un issue en
<https://github.com/jarodsmdev/vpn-target-indicator/issues> con:

- Distribución y versión de XFCE.
- Salida de `./vpn-target-indicator.sh instalar`.
- Salida de `~/.local/bin/vpn-indicator.sh`.
- Resultado de `xfconf-query -c xfce4-panel -lv | grep genmon`.
