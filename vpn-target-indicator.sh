#!/bin/bash

# ============================================================
#  VPN TARGET INDICATOR - INSTALADOR / DESINSTALADOR
# ============================================================
#
#  Indicador de escritorio para XFCE que muestra en el panel:
#    · el estado de la VPN (IP de tun0 o "VPN: OFF")
#    · la IP del target guardado
#
#  Instala tres scripts en ~/.local/bin, los engancha a un
#  Generic Monitor del panel y ofrece menú interactivo,
#  barras de progreso y desinstalación completa.
#
#  Repositorio: https://github.com/jarodsmdev/vpn-target-indicator
#  Licencia:    MIT
# ============================================================

set -e

VERSION="1.1.0"
REPO_URL="https://github.com/jarodsmdev/VPN-TARGET-INDICATOR"

BASE="$HOME/.local/bin"
CONFIG="$HOME/.config"
TARGET_FILE="$CONFIG/vpn-target"
IND="$BASE/vpn-indicator.sh"
GUI="$BASE/vpn-set-target"
CLR="$BASE/vpn-clear-target"
STATE_FILE="$CONFIG/vpn-panel-plugin"

PLUGIN_ID=""
PANEL_MSG=""

# ------------------------------------------------
# Presentación
# ------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    TTY=1
    B=$'\033[1m'
    DIM=$'\033[2m'
    R=$'\033[0m'
    RED=$'\033[31m'
    GRN=$'\033[32m'
    YEL=$'\033[33m'
    CYN=$'\033[36m'
else
    TTY=0
    B=""
    DIM=""
    R=""
    RED=""
    GRN=""
    YEL=""
    CYN=""
fi

BAR_W=24
TOTAL=0
STEP=0
LABEL=""
LOG="$(mktemp -t vpn-ti-install.XXXXXX)"
TICK_PID=""
SPIN=('-' '\' '|' '/')
STREAM=0
DETAIL=()

cleanup() {
    if [ -n "$TICK_PID" ]; then
        kill "$TICK_PID" 2>/dev/null || true
    fi
    rm -f "$LOG"
}
trap cleanup EXIT

# ------------------------------------------------
# Barra de progreso
# ------------------------------------------------

clear_line() {
    if [ "$TTY" = 1 ]; then
        printf '\r\033[K'
    fi
    return 0
}

# render <pasos hechos> <total> <etiqueta> <celda en curso> <color>
render() {
    local done="$1" total="$2" label="$3" cell="$4" col="$5"
    local filled=$((BAR_W * done / total))
    local pct=$((100 * done / total))
    local i bar=""

    for ((i = 0; i < BAR_W; i++)); do
        if ((i < filled)); then
            bar+="#"
        elif ((i == filled)) && [ -n "$cell" ]; then
            bar+="$cell"
        else
            bar+="."
        fi
    done

    if [ "$TTY" = 1 ]; then
        printf '\r\033[K  %s[%s%s%s]%s %3d%%  %s%d/%d%s  %s%s%s' \
            "$DIM" "$col" "$bar" "$DIM" "$R" "$pct" \
            "$B" "$done" "$total" "$R" "$DIM" "$label" "$R"
    else
        printf '  [%s] %3d%%  %d/%d  %s\n' "$bar" "$pct" "$done" "$total" "$label"
    fi
}

tick() {
    local i=0
    while :; do
        render "$STEP" "$TOTAL" "$LABEL" "${SPIN[$((i % 4))]}" "$YEL"
        i=$((i + 1))
        sleep 0.1
    done
}

# run_step <etiqueta> <función>
run_step() {
    local label="$1"
    shift

    STEP=$((STEP + 1))
    LABEL="$label"
    DETAIL+=("$label")

    if [ "$STREAM" = 1 ]; then
        clear_line
        printf '  %s▸ %s%s\n' "$YEL" "$label" "$R"
        local rcs=0
        "$@" || rcs=$?
        STREAM=0
        if [ "$rcs" -ne 0 ]; then
            fail_step "$label" ""
        fi
        if [ "$TTY" = 1 ]; then
            printf '  %s✔ %s%s\n' "$GRN" "$label" "$R"
        fi
        return 0
    fi

    if [ "$TTY" = 1 ]; then
        render "$((STEP - 1))" "$TOTAL" "$label" "" "$YEL"
        tick &
        TICK_PID=$!
    fi

    local rc=0
    "$@" >"$LOG" 2>&1 || rc=$?

    if [ -n "$TICK_PID" ]; then
        kill "$TICK_PID" 2>/dev/null || true
        { wait "$TICK_PID"; } 2>/dev/null || true
        TICK_PID=""
    fi

    if [ "$rc" -ne 0 ]; then
        render "$STEP" "$TOTAL" "$label" "x" "$RED"
        printf '\n'
        fail_step "$label" "$LOG"
    fi

    render "$STEP" "$TOTAL" "$label" "" "$GRN"
}

fail_step() {
    printf '\n%s✘ No se pudo completar: %s%s\n' "$RED" "$1" "$R"
    if [ -n "$2" ] && [ -s "$2" ]; then
        printf '%sÚltimas líneas:%s\n' "$DIM" "$R"
        tail -n 12 "$2" | sed 's/^/    /'
    fi
    printf '\nSe abortó la operación. Los pasos que ya terminaron%s\n' "$R"
    printf 'quedaron aplicados.\n\n'
    exit 1
}

confirm() {
    local ans=""
    if [ "$TTY" = 0 ]; then
        return 0
    fi
    printf '  %s%s [S/n] %s' "$CYN" "$1" "$R" >/dev/tty
    read -r ans </dev/tty || true
    case "$ans" in
        ""|s|S|si|SI|Si|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

# Igual que confirm, pero por defecto NO.
confirm_no() {
    local ans=""
    if [ "$TTY" = 0 ]; then
        return 1
    fi
    printf '  %s%s [s/N] %s' "$CYN" "$1" "$R" >/dev/tty
    read -r ans </dev/tty || true
    case "$ans" in
        s|S|si|SI|Si|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

# ------------------------------------------------
# Detección del panel XFCE
# ------------------------------------------------

# Devuelve la lista de plugins genmon del panel.
genmon_plugins() {
    xfconf-query -c xfce4-panel -lv 2>/dev/null |
        awk '$2 == "genmon" {print $1}'
}

genmon_command() {
    xfconf-query -c xfce4-panel -p "/plugins/$1/command" 2>/dev/null || true
}

# Elige qué Generic Monitor usar. Prioridades:
#   1) el que ya apunta a nuestro indicador
#   2) el primero sin comando asignado
#   3) el primero existente (preguntando antes de pisarlo)
panel_detect() {
    PLUGIN_ID=""
    PANEL_MSG=""

    if ! command -v xfconf-query >/dev/null 2>&1; then
        PANEL_MSG="xfconf-query no está instalado: hay que agregar el Generic Monitor a mano desde XFCE."
        return 0
    fi

    local plugins p cmd
    plugins="$(genmon_plugins)"

    if [ -z "$plugins" ]; then
        PANEL_MSG="No hay ningún Generic Monitor en el panel. Agrega uno desde Configuración del panel."
        return 0
    fi

    for p in $plugins; do
        cmd="$(genmon_command "${p##*/}")"
        if [ "$cmd" = "$IND" ]; then
            PLUGIN_ID="${p##*/}"
            PANEL_MSG="Generic Monitor existente reutilizado."
            return 0
        fi
    done

    for p in $plugins; do
        cmd="$(genmon_command "${p##*/}")"
        if [ -z "$cmd" ]; then
            PLUGIN_ID="${p##*/}"
            PANEL_MSG="Generic Monitor libre encontrado en el panel."
            return 0
        fi
    done

    p="${plugins%% *}"
    PLUGIN_ID="${p##*/}"
    cmd="$(genmon_command "$PLUGIN_ID")"

    printf '\n  %sTodos los Generic Monitor ya están en uso.%s\n' "$YEL" "$R"
    printf '  %s%s ejecuta: %s%s\n' "$DIM" "$PLUGIN_ID" "$cmd" "$R"

    if confirm "  ¿Pisar ese comando con el indicador VPN Target?"; then
        PANEL_MSG="Generic Monitor $PLUGIN_ID reasignado."
    else
        PLUGIN_ID=""
        PANEL_MSG="No se tocó el panel. Configúralo a mano desde XFCE."
    fi

    return 0
}

# ------------------------------------------------
# Pasos: directorios y dependencias
# ------------------------------------------------

step_dirs() {
    mkdir -p "$BASE" "$CONFIG"
}

step_check_deps() {
    if ! command -v zenity >/dev/null 2>&1; then
        echo "zenity ausente: se instalará en el siguiente paso."
    fi
    command -v notify-send >/dev/null 2>&1 ||
        echo "aviso: notify-send no está disponible (los avisos no se verán)"
    return 0
}

step_verify_deps() {
    if ! command -v zenity >/dev/null 2>&1; then
        echo "zenity sigue sin instalarse."
        return 1
    fi
    return 0
}

step_install_zenity() {
    sudo apt update
    sudo apt install -y zenity
}

# ------------------------------------------------
# Pasos: creación de los 3 archivos
# ------------------------------------------------

step_indicator() {
    cat > "$IND" <<'INDICATOR_EOF'
#!/bin/bash

TARGET_FILE="$HOME/.config/vpn-target"
GUI="$HOME/.local/bin/vpn-set-target"

VPN_IP=$(ip -4 addr show tun0 2>/dev/null |
    awk '/inet / {print $2}' |
    cut -d/ -f1 |
    head -n1)

OPENVPN=$(pgrep -x openvpn 2>/dev/null)

VPN_ROUTE=$(ip route show dev tun0 2>/dev/null |
    grep -E 'via|proto kernel' |
    head -n1)

if [ -n "$OPENVPN" ] && [ -n "$VPN_IP" ] && [ -n "$VPN_ROUTE" ]; then
    VPN="VPN: $VPN_IP"
else
    VPN="VPN: OFF"
fi

if [ -f "$TARGET_FILE" ]; then
    TARGET=$(cat "$TARGET_FILE")
else
    TARGET=""
fi

if [ -n "$TARGET" ]; then
    echo "<txt>🔒 $VPN  │  🎯 TARGET: $TARGET</txt>"
    echo "<tool>Clic para cambiar el target (opcional)</tool>"
else
    echo "<txt>🔒 $VPN</txt>"
    echo "<tool>Clic para escribir un target (opcional)</tool>"
fi

echo "<txtclick>$GUI</txtclick>"
INDICATOR_EOF
}

step_gui() {
    cat > "$GUI" <<'GUI_EOF'
#!/bin/bash

# El target es OPCIONAL: sin archivo, el indicador funciona igual y sólo
# muestra el estado de la VPN. Cancelar también es una respuesta válida.

TARGET_FILE="$HOME/.config/vpn-target"
LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/vpn-set-target.lock"

# Evita diálogos apilados si el panel lanza este script varias veces seguidas
# (por ejemplo, si quedó como comando de un Generic Monitor).
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    OLDPID="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$OLDPID" ] && kill -0 "$OLDPID" 2>/dev/null; then
        exit 0
    fi
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    mkdir "$LOCK_DIR" 2>/dev/null || exit 0
fi
echo "$$" > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

CURRENT=""
if [ -f "$TARGET_FILE" ]; then
    CURRENT="$(cat "$TARGET_FILE")"
fi

if [ -n "$CURRENT" ]; then
    TEXT="Target actual: $CURRENT"
    HINT="Escribí otra IP o hostname para reemplazarlo.
Dejalo vacío y aceptá para BORRAR el target.
Cancelar no cambia nada."
else
    TEXT="No hay target guardado."
    HINT="El target es opcional: sin él el indicador sólo muestra la VPN.
Escribí la IP o el hostname de la máquina en la que estás trabajando.
Cancelar y no hacer nada más también está bien."
fi

TEXT="$TEXT"$'\n\n'"$HINT"

TARGET=$(zenity \
    --entry \
    --title="Target (opcional)" \
    --text="$TEXT" \
    --entry-text="$CURRENT" \
    --ok-label="Guardar" \
    --cancel-label="Cancelar" \
    --width=460) || exit 0

TARGET="$(printf '%s' "$TARGET" | tr -d '[:space:]')"

if [ -z "$TARGET" ]; then

    rm -f "$TARGET_FILE"

    notify-send \
        "Target" \
        "Target eliminado." \
        2>/dev/null || true

elif [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ||
     [[ "$TARGET" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]; then

    printf '%s\n' "$TARGET" > "$TARGET_FILE"

    notify-send \
        "Target" \
        "Target: $TARGET" \
        2>/dev/null || true

else

    zenity \
        --error \
        --title="Target" \
        --text="\"$TARGET\" no es una IP ni un hostname válido.

Opciones:  10.10.14.5   ·   dc01   ·   dc01.lab
Podés cancelar y seguir trabajando sin target."

fi
GUI_EOF
}

step_clear() {
    cat > "$CLR" <<'CLEAR_EOF'
#!/bin/bash

rm -f "$HOME/.config/vpn-target"

notify-send \
    "Target" \
    "Target eliminado." \
    2>/dev/null || true
CLEAR_EOF
}

step_chmod() {
    chmod +x "$IND" "$GUI" "$CLR"
}

# ------------------------------------------------
# Pasos: panel XFCE
# ------------------------------------------------

step_panel() {
    xfconf-query \
        -c xfce4-panel \
        -p "/plugins/$PLUGIN_ID/command" \
        -n -t string \
        -s "$IND" \
        2>/dev/null || true

    xfconf-query \
        -c xfce4-panel \
        -p "/plugins/$PLUGIN_ID/period" \
        -n -t int \
        -s 2 \
        2>/dev/null || true

    echo "$PLUGIN_ID" > "$STATE_FILE"
}

step_test() {
    "$IND"
}

# ------------------------------------------------
# Auditoría del panel
#
# Un Generic Monitor cuyo comando apunte al diálogo (vpn-set-target) abre
# esa ventana cada refresh: el panel seLlena de diálogos y el target parece
# "pedirse" solo. Estos helpers lo detectan y lo corrigen.
# ------------------------------------------------

# Imprime los plugins mal configurados (comando = diálogo).
# Devuelve 0 si encontró alguno, 1 si no.
panel_wrong_plugins() {
    local plugins p cmd found=1
    plugins="$(genmon_plugins)"

    for p in $plugins; do
        cmd="$(genmon_command "${p##*/}")"
        case "$cmd" in
            *vpn-set-target*|*vpn-clear-target*)
                printf '  %s✘%s %s → %s%s%s\n' \
                    "$RED" "$R" "${p##*/}" "$DIM" "$cmd" "$R"
                found=0
                ;;
        esac
    done

    return "$found"
}

# Devuelve 0 si algún Generic Monitor apunta al diálogo en vez del indicador.
panel_needs_fix() {
    command -v xfconf-query >/dev/null 2>&1 || return 1
    panel_wrong_plugins >/dev/null 2>&1
}

step_fix_panel() {
    local plugins p cmd
    plugins="$(genmon_plugins)"

    for p in $plugins; do
        cmd="$(genmon_command "${p##*/}")"
        case "$cmd" in
            *vpn-set-target*|*vpn-clear-target*)
                xfconf-query \
                    -c xfce4-panel \
                    -p "/plugins/${p##*/}/command" \
                    -n -t string \
                    -s "$IND" \
                    2>/dev/null || true
                echo "${p##*/} corregido"
                ;;
        esac
    done
}

# ------------------------------------------------
# Pasos: desinstalación
# ------------------------------------------------

step_unpanel() {
    local plugins p cmd
    plugins="$(genmon_plugins)"

    for p in $plugins; do
        cmd="$(genmon_command "${p##*/}")"
        if [ "$cmd" = "$IND" ]; then
            xfconf-query \
                -c xfce4-panel \
                -p "/plugins/${p##*/}/command" \
                -n -t string \
                -s "" \
                2>/dev/null || true
            xfconf-query \
                -c xfce4-panel \
                -p "/plugins/${p##*/}/period" \
                -n -t int \
                -s 0 \
                2>/dev/null || true
            echo "plugin" >/dev/null
        fi
    done
}

step_rm_indicator() { rm -f "$IND"; }
step_rm_gui()       { rm -f "$GUI"; }
step_rm_clear()     { rm -f "$CLR"; }
step_rm_target()    { rm -f "$TARGET_FILE"; }
step_rm_state()     { rm -f "$STATE_FILE"; }
step_reload_panel() { xfce4-panel -r >/dev/null 2>&1 || true; }

# ------------------------------------------------
# Validadores de compatibilidad
# ------------------------------------------------

CHK_SYM=()
CHK_MSG=()
CHK_COL=()
CHK_HINT=()
CHK_OK=0
CHK_WARN=0
CHK_FAIL=0

add_chk() {
    local kind="$1" msg="$2" hint="${3:-}"

    case "$kind" in
        ok)
            CHK_SYM+=("✔"); CHK_COL+=("$GRN"); CHK_OK=$((CHK_OK + 1))
            ;;
        info)
            CHK_SYM+=("›"); CHK_COL+=("$CYN")
            ;;
        warn)
            CHK_SYM+=("!"); CHK_COL+=("$YEL"); CHK_WARN=$((CHK_WARN + 1))
            ;;
        fail)
            CHK_SYM+=("✘"); CHK_COL+=("$RED"); CHK_FAIL=$((CHK_FAIL + 1))
            ;;
    esac

    CHK_MSG+=("$msg")
    CHK_HINT+=("$hint")
}

# Ruta de libgenmon.so, si el plugin está instalado.
genmon_plugin_lib() {
    local d f
    for d in /usr/lib/xfce4/panel/plugins \
        /usr/lib64/xfce4/panel/plugins \
        /usr/lib/*/xfce4/panel/plugins \
        /usr/local/lib/xfce4/panel/plugins \
        "$HOME/.local/lib/xfce4/panel/plugins"; do
        for f in "$d"/libgenmon.so; do
            if [ -e "$f" ]; then
                echo "$f"
                return 0
            fi
        done
    done
    return 1
}

check_compat() {
    local de plugin_lib tools

    CHK_SYM=(); CHK_MSG=(); CHK_COL=(); CHK_HINT=()
    CHK_OK=0; CHK_WARN=0; CHK_FAIL=0

    # --- sesión gráfica ---
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        add_chk ok "Sesión gráfica disponible (${DISPLAY:-wayland})"
    else
        add_chk fail "No hay sesión gráfica: el indicador del panel no puede funcionar." \
            "ejecuta el script desde una terminal dentro de tu sesión de escritorio"
    fi

    # --- escritorio ---
    de="$(printf '%s' "${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}" |
        tr '[:upper:]' '[:lower:]')"

    if printf '%s' "$de" | grep -q xfce; then
        add_chk ok "Escritorio XFCE detectado (${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-xfce}})"
    elif [ -n "$de" ]; then
        add_chk warn "El escritorio actual no es XFCE (${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-desconocido}})." \
            "los scripts se instalarán, pero el paso del panel se saltará"
    else
        add_chk warn "No se pudo detectar el escritorio actual." \
            "si no usas XFCE, el indicador del panel no se podrá configurar"
    fi

    # --- panel corriendo ---
    if pgrep -x xfce4-panel >/dev/null 2>&1; then
        add_chk ok "xfce4-panel está en ejecución"
    else
        add_chk warn "xfce4-panel no está corriendo." \
            "los scripts se instalan igual; el panel se configurará al abrir la sesión"
    fi

    # --- plugin Generic Monitor ---
    plugin_lib="$(genmon_plugin_lib || true)"
    if [ -n "$plugin_lib" ]; then
        add_chk ok "Plugin Generic Monitor instalado"
    else
        add_chk warn "No se encontró libgenmon.so (Generic Monitor)." \
            "instálalo con: sudo apt install xfce4-genmon-plugin"
    fi

    # --- Generic Monitor en el panel ---
    if command -v xfconf-query >/dev/null 2>&1; then
        if [ -n "$(genmon_plugins)" ]; then
            add_chk ok "Generic Monitor presente en el panel"
        else
            add_chk warn "No hay ningún Generic Monitor en el panel." \
                "agrégalo en: Configuración del panel ▸ Elementos ▸ Añadir ▸ Generic Monitor"
        fi
    else
        add_chk warn "xfconf-query no está disponible: el panel no se puede configurar." \
            "instálalo con: sudo apt install xfconf"
    fi

    # --- herramientas base ---
    tools=""
    for t in ip pgrep awk sed grep cat chmod mktemp; do
        if ! command -v "$t" >/dev/null 2>&1; then
            tools="$tools $t"
        fi
    done
    if [ -z "$tools" ]; then
        add_chk ok "Herramientas base disponibles (ip, pgrep, awk, sed...)"
    else
        add_chk fail "Faltan herramientas:$tools" \
            "instálalas con: sudo apt install iproute2 procps gawk sed grep coreutils"
    fi

    # --- dependencias de la app ---
    if command -v zenity >/dev/null 2>&1; then
        add_chk ok "zenity disponible"
    else
        add_chk warn "zenity no está instalado: el instalador lo instalará en el siguiente bloque." \
            "si prefieres: sudo apt install zenity"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        add_chk ok "notify-send disponible"
    else
        add_chk warn "notify-send no está instalado: no habrá avisos al cambiar el target." \
            "instálalo con: sudo apt install libnotify-bin"
    fi

    # --- permisos ---
    if mkdir -p "$BASE" "$CONFIG" 2>/dev/null &&
        [ -w "$BASE" ] && [ -w "$CONFIG" ]; then
        add_chk ok "Rutas escribibles ($BASE, $CONFIG)"
    else
        add_chk fail "Sin permiso de escritura en $HOME/.local/bin o $HOME/.config" \
            "corrige los permisos o ejecuta el script con otro usuario"
    fi

    # --- contexto ---
    if [ "${EUID:-$(id -u)}" = "0" ]; then
        add_chk warn "Ejecutando como root: se instalará en /root y el panel no lo verá." \
            "ejecuta el script como tu usuario normal de escritorio"
    fi

    if [ -f "$IND" ] || [ -f "$GUI" ] || [ -f "$CLR" ]; then
        add_chk info "Ya hay una versión instalada: se va a actualizar."
    fi

    print_checks
}

print_checks() {
    local i
    for ((i = 0; i < ${#CHK_SYM[@]}; i++)); do
        printf '  %s%s%s %s\n' "${CHK_COL[$i]}" "${CHK_SYM[$i]}" "$R" "${CHK_MSG[$i]}"
        if [ -n "${CHK_HINT[$i]}" ]; then
            printf '      %s→ %s%s\n' "$DIM" "${CHK_HINT[$i]}" "$R"
        fi
    done

    printf '  %s──────────────────────────────────────────────%s\n' "$DIM" "$R"
    printf '  %s%d correctos%s' "$B" "$CHK_OK" "$R"
    [ "$CHK_WARN" -gt 0 ] && printf ' │ %s%d avisos%s' "$YEL" "$CHK_WARN" "$R"
    [ "$CHK_FAIL" -gt 0 ] && printf ' │ %s%d bloqueos%s' "$RED" "$CHK_FAIL" "$R"
    printf '\n'
}

# ------------------------------------------------
# Instalación
# ------------------------------------------------

do_install() {
    local need_zenity=0
    local need_fix=0
    local do_panel=0

    section "COMPROBANDO COMPATIBILIDAD"
    check_compat

    if [ "$CHK_FAIL" -gt 0 ]; then
        if ! confirm_no "  Hay bloqueos. ¿Continuar de todos modos?"; then
            printf '\n  %sInstalación cancelada.%s\n\n' "$YEL" "$R"
            return 0
        fi
        printf '\n'
    fi

    command -v zenity >/dev/null 2>&1 || need_zenity=1

    panel_needs_fix && need_fix=1 || need_fix=0

    if [ "$need_fix" = 1 ]; then
        printf '\n  %s✘ El panel tiene un Generic Monitor apuntando al diálogo:%s\n' "$RED" "$R"
        panel_wrong_plugins
        printf '  %sCon esa configuración el panel abre esa ventana cada 2 s.%s\n' "$YEL" "$R"
        printf '  %sEl comando correcto es:%s %s%s\n' "$DIM" "$R" "$IND" "$R"
        printf '  %sSe corrige automáticamente al final de la instalación.%s\n' "$DIM" "$R"
        printf '\n'
    fi

    panel_detect
    [ -n "$PLUGIN_ID" ] && do_panel=1

    # 9 pasos fijos + zenity (si falta)
    # + corrección del panel (si algo apunta al diálogo) - panel (si no aplica)
    TOTAL=$((9 + need_zenity + need_fix))
    [ "$do_panel" = 1 ] || TOTAL=$((TOTAL - 1))
    STEP=0
    DETAIL=()

    section "INSTALANDO"

    run_step "Preparando directorios"                  step_dirs
    run_step "Verificando dependencias"               step_check_deps

    if [ "$need_zenity" = 1 ]; then
        STREAM=1
        run_step "Instalando zenity"                   step_install_zenity
    fi

    run_step "Comprobando dependencias"               step_verify_deps
    run_step "Creando vpn-indicator.sh"               step_indicator
    run_step "Creando vpn-set-target"            step_gui
    run_step "Creando vpn-clear-target"          step_clear
    run_step "Dando permisos de ejecución"             step_chmod

    if [ "$do_panel" = 1 ]; then
        run_step "Configurando Generic Monitor ($PLUGIN_ID)" step_panel
    fi

    if [ "$need_fix" = 1 ]; then
        run_step "Corrigiendo comando del panel"        step_fix_panel
    fi

    run_step "Probando el indicador"                  step_test

    if [ "$TTY" = 1 ]; then
        render "$TOTAL" "$TOTAL" "instalación completa" "" "$GRN"
        printf '\n'
    fi
    printf '\n'

    # ---------------- resultado ----------------
    printf '%s  INSTALACIÓN TERMINADA%s\n' "$GRN" "$R"
    printf '\n'
    printf '  %sArchivos en %s%s\n' "$B" "$BASE" "$R"
    printf '    %svpn-indicator.sh%s   indicador del panel (VPN + target)\n' "$GRN" "$R"
    printf '    %svpn-set-target%s     ventana para escribir la IP del target\n' "$GRN" "$R"
    printf '    %svpn-clear-target%s   borra el target guardado\n' "$GRN" "$R"

    if [ -f "$TARGET_FILE" ]; then
        printf '  %sEn %s%s\n' "$B" "$CONFIG" "$R"
        printf '    %svpn-target%s        target actual: %s\n' \
            "$GRN" "$R" "$(cat "$TARGET_FILE")"
    fi

    if [ "$do_panel" = 1 ]; then
        printf '    %svpn-panel-plugin%s   %s del panel (periodo 2s)\n' \
            "$GRN" "$R" "$PLUGIN_ID"
    fi

    printf '\n  %sPrueba del indicador:%s\n' "$B" "$R"
    sed 's/^/    /' "$LOG"

    if [ -n "$PANEL_MSG" ]; then
        printf '\n  %s%s%s\n' "$YEL" "$PANEL_MSG" "$R"
    fi

    printf '\n'
    printf '  %sRepo:%s %s\n' "$DIM" "$R" "$REPO_URL"
    printf '\n'
    printf '  %sPara escribir el target:%s clic sobre el indicador (opcional).\n' "$B" "$R"
    printf '  %sPara borrar el target:%s  clic, campo vacío y Guardar.\n' "$B" "$R"
    printf '  %sCancelar:%s no cambia nada. El target es opcional.\n' "$B" "$R"
    printf '  %sSin target:%s el indicador muestra solo %s🔒 VPN: OFF%s o %s🔒 VPN: 10.10.2.2%s.\n' \
        "$B" "$R" "$B" "$R" "$B" "$R"
    printf '\n'
}

# ------------------------------------------------
# Desinstalación
# ------------------------------------------------

do_uninstall() {
    local do_panel=0
    local do_target=0
    local do_state=0
    local do_reload=0
    local had_files=0

    if command -v xfconf-query >/dev/null 2>&1; then
        local plugins p cmd
        plugins="$(genmon_plugins)"
        for p in $plugins; do
            cmd="$(genmon_command "${p##*/}")"
            if [ "$cmd" = "$IND" ]; then
                PLUGIN_ID="${p##*/}"
                do_panel=1
                break
            fi
        done
    fi

    [ -f "$TARGET_FILE" ] && do_target=1 || true
    [ -f "$STATE_FILE" ] && do_state=1 || true

    if [ -f "$IND" ] || [ -f "$GUI" ] || [ -f "$CLR" ]; then
        had_files=1
    fi

    if [ "$do_panel" = 1 ] && confirm "Recargar el panel de XFCE al terminar?"; then
        do_reload=1
    fi

    TOTAL=$((3 + do_panel + do_target + do_state + do_reload))
    STEP=0
    DETAIL=()

    section "DESINSTALANDO"

    if [ "$do_panel" = 1 ]; then
        run_step "Desvinculando el panel XFCE ($PLUGIN_ID)" step_unpanel
    fi

    run_step "Borrando vpn-indicator.sh"  step_rm_indicator
    run_step "Borrando vpn-set-target"    step_rm_gui
    run_step "Borrando vpn-clear-target"  step_rm_clear

    if [ "$do_target" = 1 ]; then
        run_step "Borrando vpn-target"        step_rm_target
    fi

    if [ "$do_state" = 1 ]; then
        run_step "Borrando vpn-panel-plugin" step_rm_state
    fi

    if [ "$do_reload" = 1 ]; then
        run_step "Recargando el panel"       step_reload_panel
    fi

    if [ "$TTY" = 1 ]; then
        render "$TOTAL" "$TOTAL" "desinstalación completa" "" "$GRN"
        printf '\n'
    fi
    printf '\n'

    # ---------------- resultado ----------------
    if [ "$had_files" = 1 ] || [ "$do_target" = 1 ] || [ "$do_panel" = 1 ]; then
        printf '%s  DESINSTALACIÓN TERMINADA%s\n' "$GRN" "$R"
        printf '\n'
        printf '  %sSe borraron:%s\n' "$B" "$R"
        for d in "${DETAIL[@]}"; do
            printf '    %s✔%s %s\n' "$GRN" "$R" "$d"
        done

        if [ "$do_panel" = 1 ] && [ "$do_reload" = 0 ]; then
            printf '\n  %sEl plugin-%s quedó con el comando vacío.%s\n' \
                "$YEL" "$PLUGIN_ID" "$R"
            printf '  %sRecarga el panel o reinicia sesión para liberar el proceso viejo.%s\n' \
                "$DIM" "$R"
        fi
    else
        printf '%s  No hay nada instalado que borrar.%s\n\n' "$YEL" "$R"
    fi

    printf '\n'
}

# ------------------------------------------------
# Estado / diagnóstico
# ------------------------------------------------

do_status() {
    local plugins p cmd n=0

    section "ARCHIVOS"

    if [ -x "$IND" ]; then
        n=$((n + 1)); printf '  %s✔%s %s\n' "$GRN" "$R" "$IND"
    else
        printf '  %s✘%s %s %s(falta)%s\n' "$RED" "$R" "$IND" "$DIM" "$R"
    fi

    if [ -x "$GUI" ]; then
        n=$((n + 1)); printf '  %s✔%s %s\n' "$GRN" "$R" "$GUI"
    else
        printf '  %s✘%s %s %s(falta)%s\n' "$RED" "$R" "$GUI" "$DIM" "$R"
    fi

    if [ -x "$CLR" ]; then
        n=$((n + 1)); printf '  %s✔%s %s\n' "$GRN" "$R" "$CLR"
    else
        printf '  %s✘%s %s %s(falta)%s\n' "$RED" "$R" "$CLR" "$DIM" "$R"
    fi

    printf '  %s%s/3 scripts instalados%s\n' "$DIM" "$n" "$R"

    section "TARGET (opcional)"

    if [ -f "$TARGET_FILE" ]; then
        printf '  %svpn-target%s = %s\n' "$GRN" "$R" "$(cat "$TARGET_FILE")"
    else
        printf '  %ssin target: el panel muestra sólo el estado de la VPN%s\n' "$DIM" "$R"
    fi

    section "PANEL XFCE"

    if ! command -v xfconf-query >/dev/null 2>&1; then
        printf '  %sxfconf-query no está instalado%s\n' "$YEL" "$R"
    elif [ -z "$(genmon_plugins)" ]; then
        printf '  %sno hay ningún Generic Monitor en el panel%s\n' "$YEL" "$R"
    else
        for p in $(genmon_plugins); do
            cmd="$(genmon_command "${p##*/}")"
            case "$cmd" in
                "")
                    printf '  %s%s%s %ssin comando%s\n' "$B" "${p##*/}" "$R" "$DIM" "$R"
                    ;;
                *vpn-set-target*|*vpn-clear-target*)
                    printf '  %s%s%s %s✘ apunta al diálogo: el panel lo abriría cada 2 s%s\n' \
                        "$B" "${p##*/}" "$R" "$RED" "$R"
                    ;;
                *vpn-indicator.sh*)
                    printf '  %s%s%s %s✔ indicador%s\n' "$B" "${p##*/}" "$R" "$GRN" "$R"
                    ;;
                *)
                    printf '  %s%s%s %s→ %s%s\n' "$B" "${p##*/}" "$R" "$DIM" "$cmd" "$R"
                    ;;
            esac
        done
    fi

    section "SALIDA DEL INDICADOR"

    if [ -x "$IND" ]; then
        "$IND" | sed 's/^/  /'
    else
        printf '  %sno se puede probar: %s no existe%s\n' "$YEL" "$IND" "$R"
    fi

    printf '\n  %sRepo:%s %s\n\n' "$DIM" "$R" "$REPO_URL"
}

# ------------------------------------------------
# Menú
# ------------------------------------------------

banner() {
    printf '\n%s==============================================%s\n' "$CYN" "$R"
    printf '%s     VPN TARGET INDICATOR  %sv%s%s\n' "$B" "$DIM" "$VERSION" "$R"
    printf '%s==============================================%s\n' "$CYN" "$R"
}

section() {
    clear_line
    printf '\n  %s%s%s\n' "$B" "$1" "$R"
    printf '  %s%s%s\n' "$DIM" "──────────────────────────────────────────────" "$R"
}

status_line() {
    local n=0
    [ -f "$IND" ] && n=$((n + 1))
    [ -f "$GUI" ] && n=$((n + 1))
    [ -f "$CLR" ] && n=$((n + 1))

    printf '\n  %sEstado:%s' "$DIM" "$R"
    if [ "$n" -eq 0 ]; then
        printf ' no instalado\n'
    else
        printf ' %d/3 scripts en %s' "$n" "$BASE"
        [ -f "$TARGET_FILE" ] && printf ' │ target %s' "$(cat "$TARGET_FILE")"
        printf '\n'
    fi
}

usage() {
    printf '  %sUso:%s %s [instalar|estado|desinstalar|salir]\n' \
        "$B" "$R" "$(basename "$0")"
    printf '  %sRepo:%s %s\n' "$DIM" "$R" "$REPO_URL"
    printf '\n'
}

bye() {
    printf '\n  Hasta luego.\n\n'
}

run_choice() {
    case "$1" in
        1|install|instalar|instala|i)
            do_install
            ;;
        2|status|estado|diag|diagnostico)
            do_status
            ;;
        3|uninstall|desinstalar|desinstala|remove|d)
            do_uninstall
            ;;
        4|exit|salir|s|q)
            bye
            ;;
        -h|--help|help|ayuda)
            usage
            ;;
        *)
            printf '  %sOpción no válida: %s%s\n' "$YEL" "$1" "$R"
            return 1
            ;;
    esac
    return 0
}

main() {
    local opt="${1:-}"

    if [ -n "$opt" ]; then
        run_choice "$opt" || usage
        return 0
    fi

    while :; do
        banner
        status_line
        printf '\n'
        printf '  %s1%s)  Instalar / reinstalar\n' "$B" "$R"
        printf '  %s2%s)  Estado / diagnóstico\n' "$B" "$R"
        printf '  %s3%s)  Desinstalar\n' "$B" "$R"
        printf '  %s4%s)  Salir\n' "$B" "$R"
        printf '\n'
        printf '  %sRepo:%s %s\n' "$DIM" "$R" "$REPO_URL"
        printf '\n'
        printf '  Elige una opción [1-4]: '
        read -r opt || opt=4
        opt="${opt// /}"
        [ -z "$opt" ] && opt=4

        run_choice "$opt" && return 0
        sleep 1
    done
}

main "$@"
