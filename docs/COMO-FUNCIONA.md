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
                             │ <txtclick>
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
<tool>Clic para cambiar target</tool>
<txtclick>/home/tu/.local/bin/vpn-set-target</txtclick>
```

Sin target, sólo se muestra la VPN y el tooltip invita a escribirlo.

## 5. Gestión del target

- Se guarda en `~/.config/vpn-target`, un archivo de texto con una sola línea.
- La GUI precarga el valor actual y valida la entrada contra
  `^([0-9]{1,3}\.){3}[0-9]{1,3}$`.
- Campo vacío + Aceptar ⇒ `rm` del archivo (borrar el target).
- Cada cambio emite un aviso con `notify-send` (silencioso si no está
  instalado).

`vpn-clear-target` existe para uso manual o desde un atajo de teclado:

```bash
~/.local/bin/vpn-clear-target
```

## 6. Integración con el panel de XFCE

`panel_detect` elige el plugin del panel con este orden de prioridad:

1. Un *Generic Monitor* cuyo `command` ya apunte al indicador (reinstalación).
2. Un *Generic Monitor* sin comando asignado (reutiliza un slot libre).
3. El primero existente, **preguntando** antes de sobrescribir su comando.

Después escribe en `xfce4-panel`:

```
/plugins/<id>/command = ~/.local/bin/vpn-indicator.sh
/plugins/<id>/period  = 2
```

El ID elegido se guarda en `~/.config/vpn-panel-plugin` para que la
desinstalación sepa qué plugin desatacar.

Si no hay ningún *Generic Monitor* en el panel, el instalador no falla: deja los
scripts instalados y explica cómo añadir el plugin a mano
(*Configuración del panel ▸ Elementos ▸ Añadir ▸ Generic Monitor*).

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

## 9. Desinstalación

En orden inverso y sólo para lo que exista:

1. Vaciar `/plugins/<id>/command` y poner `period = 0` en cada plugin que
   apunte al indicador.
2. Borrar `vpn-indicator.sh`, `vpn-set-target` y `vpn-clear-target`.
3. Borrar `~/.config/vpn-target` y `~/.config/vpn-panel-plugin`.
4. Opcionalmente `xfce4-panel -r` para liberar el proceso antiguo.

El plugin en sí **no se elimina** del panel: se deja con el comando vacío para
no destruir otros ajustes del usuario.
