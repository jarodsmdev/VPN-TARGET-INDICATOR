# Cómo funciona

Documento técnico de `vpn-target-indicator.sh`: qué se instala, cómo se detecta
la VPN y cómo se conecta todo con el panel de XFCE.

## 1. Componentes

El repositorio tiene un único archivo ejecutable, el instalador. Al ejecutarse
genera tres scripts en `~/.local/bin` y los engancha al panel:

| Componente | Ruta | Responsabilidad |
| --- | --- | --- |
| Instalador | `vpn-target-indicator.sh` | Menú, validaciones, escritura de los scripts, configuración del panel, desinstalación |
| Indicador | `~/.local/bin/vpn-indicator.sh` | Emite el texto y la acción del panel; lo ejecuta el *Generic Monitor* |
| GUI | `~/.local/bin/vpn-set-target` | Diálogo `zenity` para escribir o borrar el target |
| Limpiador | `~/.local/bin/vpn-clear-target` | Borra el target y notifica |

## 2. Flujo de datos

```
                 ┌──────────────────────────┐
  panel XFCE ───►│ vpn-indicator.sh         │  cada 2 s
  (Generic Mon.) │  tun0 + openvpn + target │──► <txt> 🔒 VPN: …  🎯 TARGET: …
                 └───────────┬──────────────┘
                             │ <txtclick> … --click
                             ▼
                 ┌──────────────────────────┐
                 │ vpn-set-target (zenity)  │
                 └───────────┬──────────────┘
                             │ escribe / borra
                             ▼
                 ~/.config/vpn-target
```

## 3. Detección de la VPN

`vpn-indicator.sh` exige **tres** condiciones simultáneas para declarar la VPN
activa. Si falta cualquiera de ellas, muestra `VPN: OFF`:

1. **Proceso `openvpn` en ejecución** — `pgrep -x openvpn`.
2. **Dirección IPv4 en `tun0`** — `ip -4 addr show tun0 | awk '/inet / {print $2}'`,
   recortando el prefijo con `cut -d/ -f1`.
3. **Ruta activa sobre `tun0`** — `ip route show dev tun0 | grep -E 'via|proto kernel'`.

La primera condición evita falsos positivos (por ejemplo, una interfaz `tun0`
residual de otro cliente VPN); la tercera evita mostrar una VPN "conectada" sin
tráfico real.

> Si tu cliente VPN no usa `tun0` (`tun1`, `wg0`, `tap0`…), editá la variable
> `tun0` dentro de `~/.local/bin/vpn-indicator.sh` y recargá el panel con
> `xfce4-panel -r`.

## 4. Salida del indicador

`vpn-indicator.sh` imprime una línea por cada etiqueta que Genmon entiende:

| Etiqueta | Efecto en el panel |
| --- | --- |
| `<txt>…</txt>` | Texto que se muestra en el panel |
| `<tool>…</tool>` | Tooltip al pasar el cursor |
| `<txtclick>…</txtclick>` | Comando ejecutado al hacer clic sobre el texto |

Con target:

```
<txt>🔒 VPN: 10.10.14.5  │  🎯 TARGET: 10.10.14.42</txt>
<tool>Clic para cambiar el target (opcional)</tool>
<txtclick>/home/tu/.local/bin/vpn-set-target --click</txtclick>
```

El token `--click` es lo que separa "el usuario hizo clic" de "el panel me
ejecutó como comando". El diálogo sólo abre la ventana si recibe ese token o si
se lo ejecuta desde una terminal (`[ -t 1 ]`); si lo lanza el *Generic Monitor*
en cada refresco, no abre nada y devuelve en su lugar un aviso para el panel:

```
<txt>⚠ target: el panel no debe ejecutar este script</txt>
<tool>El comando del Generic Monitor debe ser vpn-indicator.sh …</tool>
```

Sin target, sólo se muestra la VPN y el tooltip invita a escribirlo.

## 5. Gestión del target

- Se guarda en `~/.config/vpn-target`, un archivo de texto con una sola línea.
- La GUI precarga el valor actual y normaliza lo que se escribe: recorta
  espacios y, si viene con CIDR (`10.10.14.0/24`), guarda sólo la IP.
- Validación (`valid_ipv4` / `valid_hostname`): cuatro octetos de 0 a 255 sin
  ceros a la izquierda, prefijo `/0`-`/32`, o etiquetas de 1 a 63 caracteres
  alfanuméricos con guiones internos. Lo que no encaje se rechaza con un error
  explicativo.
- Campo vacío + `Guardar` ⇒ `rm` del archivo (queda sin target).
- `Cancelar` ⇒ `exit 0` sin tocar nada: **el target es opcional** y el
  indicador funciona igual sin él.
- Un lock en `${XDG_RUNTIME_DIR:-/tmp}/vpn-set-target.lock` (creación atómica
  con `mkdir`) evita que se apilen ventanas si el panel lanza el script varias
  veces seguidas. Si el proceso que tiene el lock ya no existe, se libera.
- Cada cambio emite un aviso con `notify-send` (silencioso si no está
  instalado).

`vpn-clear-target` existe para uso manual o desde un atajo de teclado:

```bash
~/.local/bin/vpn-clear-target
```

## 6. Integración con el panel de XFCE

`panel_detect` elige el plugin del panel con este orden de prioridad:

1. Un *Generic Monitor* cuyo `command` ya apunte al indicador (reinstalación).
2. Un *Generic Monitor* que apunte a nuestros diálogos: se reconvierte en
   indicador, en vez de dejar el error y ofrecer pisar otro monitor del panel.
3. Un *Generic Monitor* sin comando asignado (reutiliza un slot libre).
4. El primero existente, **preguntando** antes de sobrescribir su comando.

Después escribe en `xfce4-panel`:

```
/plugins/<id>/command = ~/.local/bin/vpn-indicator.sh
```

y el periodo con `set_genmon_period <id> 2`. Ojo con la clave: las versiones
actuales de *Generic Monitor* (≥ 4.1) leen **`update-period` en milisegundos**
(`2000` = 2 s) y las antiguas leían **`period` en segundos**. Escribir la clave
equivocada no falla: el panel ignora la propiedad y conserva el periodo que ya
tuviera. `genmon_period_key` decide cuál usar mirando la biblioteca
`libgenmon.so` instalada y, si no la encuentra, la que ya usa el plugin.

El ID elegido se guarda en `~/.config/vpn-panel-plugin` para que la
desinstalación sepa qué plugin desatacar.

### 6.1 Por qué la instalación reinicia el panel

El *Generic Monitor* lee su comando **una sola vez**, al construirse el plugin.
Con el panel vivo, `xfconf-query -s` no cambia lo que se está ejecutando. Peor
aún: cuando el panel se guarda (al cerrarse, al recargarse o al tocar el
layout), vuelve a escribir en `xfconf` el comando que tenía **en memoria**, así
que el valor recién escrito se pierde.

Por eso la instalación termina con `step_panel_restart`, que hace:

1. `panel_stop` — para el panel y espera a que muera (con `xfce4-panel -q`, y
   `pkill` si hace falta).
2. Reaplica la configuración de los plugins que maneja el instalador
   (`PANEL_OWNED`), ya con nadie que la pueda pisar.
3. `panel_start` — lo vuelve a levantar y espera a que esté en pie.

La desinstalación usa la misma rutina (`step_reload_panel`) para dejar el
comando vacío de verdad.

**Consecuencia para el usuario:** si editás el *Comando* a mano desde
*Configuración del panel* y guardás, el panel se reinicia y el cambio sí queda.
Pero si dejás el diálogo de *Editar* abierto mientras instalás, al pulsar
`Guardar` vuelve a escribir el valor viejo que tenía en el campo.

Si no hay ningún *Generic Monitor* en el panel, el instalador no falla: deja los
scripts instalados y explica cómo añadir el plugin a mano
(*Configuración del panel ▸ Elementos ▸ Añadir ▸ Generic Monitor*).

### 6.2 Auditoría del panel

Un error común es poner en el campo **Comando** del *Generic Monitor* el script
del diálogo (`vpn-set-target`) en vez del indicador. El panel lo ejecutaría en
cada refresco y se abriría una ventana tras otra.

`panel_wrong_plugins` lista los plugins cuyo comando coincide con
`vpn-set-target` o `vpn-clear-target`, y devuelve 0 si encuentra alguno. `panel_needs_fix` es el wrapper usable en una condición.
Durante la instalación, si hay coincidencias:

1. Se avisa antes de instalar, con el comando correcto a mano y el periodo real
   que tiene ese plugin.
2. `step_fix_panel` reescribe esos `command` a `vpn-indicator.sh` y les fija el
   periodo de 2 s.

`estado` usa `panel_plugin_line` para resumir cada plugin: qué comando tiene,
cada cuánto corre y si ese archivo existe siquiera en el disco. Esta última
comprobación importa porque *Generic Monitor* ≥ 4.1 pinta en el panel la salida
de error del comando (`sh: 1: …: not found`) cuando el archivo no existe.

La opción `estado` muestra la misma auditoría como diagnóstico, marcando los
plugins mal configurados con `✘`.

## 7. Validaciones previas

`check_compat` clasifica cada chequeo en `ok` / `info` / `warn` / `fail`:

| Chequeo | Bloqueante |
| --- | --- |
| Sesión gráfica (`DISPLAY` / `WAYLAND_DISPLAY`) | Sí |
| Escritorio XFCE | No (aviso: se omite el paso del panel) |
| `xfce4-panel` en ejecución | No |
| `libgenmon.so` presente | No |
| *Generic Monitor* en el panel | No |
| Herramientas base (`ip`, `pgrep`, `awk`…) | Sí |
| `zenity` | No (se instala después) |
| `notify-send` | No |
| Escritura en `~/.local/bin` y `~/.config` | Sí |
| Ejecución como `root` | No (aviso: instalaría en `/root`) |

Si hay bloqueos, el instalador pide confirmación explícita antes de continuar.

## 8. Barra de progreso y TTY

`run_step` envuelve cada paso con una barra de progreso y un spinner:

- Con TTY: la salida del paso se captura a un log temporal mientras se dibuja
  la barra; al fallar se muestran las últimas 12 líneas del log.
- Sin TTY (por ejemplo `curl | bash` o CI): se imprimen pasos en texto plano y
  las preguntas interactivas se auto-responden (los `confirm` devuelven "sí",
  los `confirm_no` devuelven "no").
- `NO_COLOR=1` desactiva todos los códigos ANSI.
- `VPN_TI_SKIP_PANEL=1` (sólo para pruebas) omite **todo** lo que toca el
  panel: no lo lee, no lo escribe y no lo reinicia. Instalá y desinstalá con un
  `HOME` temporal siempre con esta variable, o reconfigurás el panel de tu
  sesión real.

## 9. Desinstalación

En orden inverso y sólo para lo que exista:

1. Vaciar `/plugins/<id>/command` y poner el periodo en `0` (con la clave que
   corresponda) en cada plugin que apunte al indicador.
2. Borrar `vpn-indicator.sh`, `vpn-set-target` y `vpn-clear-target`.
3. Borrar `~/.config/vpn-target` y `~/.config/vpn-panel-plugin`.
4. Opcionalmente `xfce4-panel -r` para liberar el proceso antiguo.

El plugin en sí **no se elimina** del panel: se deja con el comando vacío para
no destruir otros ajustes del usuario.
