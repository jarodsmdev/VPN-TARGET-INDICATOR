# Troubleshooting

Diagnóstico y soluciones para los problemas más habituales.

## Diagnóstico rápido

Lo primero: `./vpn-target-indicator.sh estado` (o `2` en el menú). Imprime los
scripts instalados, el target, el comando de cada *Generic Monitor* y la salida
real del indicador. Es la forma más rápida de ver qué está mal.

Luego, probá el indicador a mano. Si imprime una línea `<txt>…</txt>`, el
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

Deberías ver `command` apuntando a `~/.local/bin/vpn-indicator.sh` y el periodo
en `update-period = 2000` (milisegundos). Los *Generic Monitor* antiguos usan
`period = 2` (segundos): los dos significan 2 s, pero escribí la que corresponda
a tu versión o el panel la ignora en silencio.


---

## El diálogo del target se abre solo (en cada refresco)

**Causa:** el *Generic Monitor* del panel tiene como comando el diálogo
(`vpn-set-target`) en lugar del indicador. El panel lo ejecuta cada pocos
segundos, así que se abre una ventana tras otra; al aceptar una, se abre la
siguiente. Da igual lo que escribas: la IP se guarda y el diálogo vuelve a
aparecer.

Desde la 1.2.0 el diálogo se niega a abrirse en ese caso (el indicador le pasa
un token `--click`) y el panel muestra en su lugar
`⚠ target: el panel no debe ejecutar este script`: si ves ese aviso, ya sabés
que el comando mal configurado es `vpn-set-target`.

**Comprobación:**

```bash
./vpn-target-indicator.sh estado
# o
xfconf-query -c xfce4-panel -lv | grep genmon
```

Si ves `command  /home/tu/.local/bin/vpn-set-target`, esa es la causa.

**Solución:** el instalador lo corrige solo:

```bash
./vpn-target-indicator.sh instalar
```

O a mano, en *Configuración del panel ▸ Elementos ▸ Generic Monitor ▸ Editar*,
poné como **Comando**:

```
/home/tu/.local/bin/vpn-indicator.sh
```

El diálogo se abre con un **clic** sobre el indicador, no solo.

> Kali trae su propio indicador de VPN en
> `/usr/share/kali-themes/xfce4-panel-genmon-vpnip.sh`. Si ya lo usás, podés
> dejar el nuestro apuntando sólo al target o borrar uno de los dos. El
> instalador sólo pisa un *Generic Monitor* propio: si encuentra otro que ya
> apunta a nuestros scripts, lo reconvierte, y si no, pregunta antes de
> tocar uno ajeno.

---

## El panel muestra `not found` o `Error in command`

**Causa:** el campo *Comando* del *Generic Monitor* apunta a un archivo que no
existe —típico si desinstalaste, si borraste `~/.local/bin` o si instalaste con
`sudo`—. *Generic Monitor* ≥ 4.1 muestra en el panel la salida de error del
comando y además avisa con un diálogo `Error in command "…"`.

**Comprobación:**

```bash
ls -l ~/.local/bin/vpn-*
./vpn-target-indicator.sh estado
```

`estado` marca con `✘ no existe:` el plugin cuyo comando no está en disco.

**Solución:** reinstalar como tu usuario de escritorio (sin `sudo`):

```bash
./vpn-target-indicator.sh instalar
```

---

## El panel no se actualiza cada 2 segundos

**Causa:** el *Generic Monitor* instalado es de los que guardan el periodo en
`period` (segundos) y no en `update-period` (milisegundos), o al revés. La
propiedad equivocada no da ningún error: el panel la ignora y se queda con el
periodo que ya tuviera (a veces 30 s o 1 minuto), y por eso el diálogo mal
configurado "volvía a aparecer" cada tanto en vez de cada 2 segundos.

**Comprobación:** `./vpn-target-indicator.sh estado` muestra el periodo real de
cada plugin entre paréntesis.

**Solución:** `instalar` lo detecta y escribe la clave correcta; a mano:

```bash
# genmon actual
xfconf-query -c xfce4-panel -p /plugins/<id>/update-period -n -t int -s 2000
# genmon antiguo
xfconf-query -c xfce4-panel -p /plugins/<id>/period -n -t int -s 2
```

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
2. Probá el script directamente: `~/.local/bin/vpn-set-target`. Desde una
   terminal se abre siempre; si lo redirigís a un archivo o a otro programa
   (y por eso no hay terminal), imprime el aviso de "el panel no debe ejecutar
   este script" en vez de la ventana: es la protección contra el bucle de
   diálogos.
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
