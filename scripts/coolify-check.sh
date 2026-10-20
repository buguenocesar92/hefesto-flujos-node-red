#!/usr/bin/env bash
# Verifica que el compose del repo cumple el contrato Coolify:
#   - sin 'name' fijo a nivel raíz (Coolify pone el nombre de proyecto)
#   - sin keys prohibidas (ports, container_name, privileged, cap_add,
#     devices, network_mode host, pid/ipc host, security_opt unconfined)
#     en servicios sin profiles
#   - sin binds fuera del repo ni docker.sock (en servicios y en el
#     bloque raíz 'volumes:')
#   - sin redes con 'name' fijo
#
# Detección de 'name' fijo: se renderiza sin --project-name (dejando que
# docker compose use su auto-derivación desde --project-directory). Si el
# compose fuerza un 'name' propio, el .name renderizado NO coincidirá con
# el basename del directorio del proyecto. Lo mismo aplica a las redes:
# si una red tiene 'name' declarado, su .name renderizado NO será
# '<project>_<key>'.
#
# Uso: bash scripts/coolify-check.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/compose.yaml"
EXPECTED_PROJECT="$(basename "$REPO_ROOT")"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: no existe $COMPOSE_FILE" >&2
    exit 1
fi

# 1. Genera .env temporal con valores ficticios no secretos para cada ${VAR}
#    que aparezca en el compose. Las de host/URL van con https://ejemplo.invalid.
TMP_ENV="$(mktemp -t coolify-check.XXXXXX)"
STDERR_LOG="$(mktemp -t coolify-check-stderr.XXXXXX)"
trap 'rm -f "$TMP_ENV" "$STDERR_LOG"' EXIT

# Extrae el nombre de variable de ${VAR}, ${VAR:-default} y ${VAR:?error}.
# Solo el nombre va a TMP_ENV; la parte ':...' es sintaxis de docker compose
# y no debe contaminar el nombre del env var (docker compose no sustituye
# ${VAR:-default} si el env-file declara una clave con ':-default' incluido).
mapfile -t VARS < <(grep -oE '\$\{[A-Za-z_][A-Za-z_0-9]*(:[-=?+][^}]*)?\}' "$COMPOSE_FILE" \
    | sed -E 's/^\$\{//; s/:[-=?+].*//; s/\}.*//' \
    | sort -u)

if [ "${#VARS[@]}" -eq 0 ]; then
    echo "ERROR: no se encontraron variables en $COMPOSE_FILE" >&2
    exit 1
fi

: > "$TMP_ENV"
for V in "${VARS[@]}"; do
    case "$V" in
        *URL*|*HOST*|*DOMAIN*)
            echo "$V=https://ejemplo.invalid" >> "$TMP_ENV"
            ;;
        *)
            echo "$V=x1234567890abcdef" >> "$TMP_ENV"
            ;;
    esac
done

# 2. Render con docker compose config. stderr se guarda aparte para no
#    contaminar el JSON que va a jq (warnings de docker config.json, etc.).
#    NO pasamos --project-name: así docker compose auto-deriva el nombre
#    del proyecto a partir del basename de --project-directory, y podemos
#    detectar si el compose declara un 'name' propio.
if ! RENDERED="$(docker compose \
        --project-directory "$REPO_ROOT" \
        -f "$COMPOSE_FILE" \
        --env-file "$TMP_ENV" \
        config --format json 2>"$STDERR_LOG")"; then
    echo "ERROR: docker compose config falló:" >&2
    cat "$STDERR_LOG" >&2
    exit 1
fi

# 3. Validar contrato.

# 3a. Sin 'name' fijo a nivel raíz. Se detecta directamente sobre el archivo:
#     cualquier `name:` en la raíz del compose es rechazado sin importar si
#     coincide con el basename del directorio (Coolify pone el nombre).
if grep -qE '^name:' "$COMPOSE_FILE"; then
    echo "ERROR: compose: 'name' fijo a nivel raíz; Coolify pone el nombre de proyecto" >&2
    exit 1
fi

# Helper: valida que un path (tal cual lo entrega docker compose, absoluto
# o relativo al project_directory) esté dentro del repo o sea docker.sock.
# Normaliza con realpath para neutralizar '..' y symlinks.
check_bind() {
    local label="$1"
    local source="$2"
    case "$source" in
        /var/run/docker.sock|*"docker.sock")
            echo "ERROR: $label: bindea docker.sock ($source)" >&2
            return 1
            ;;
        *)
            local abs
            case "$source" in
                /*) abs="$source" ;;
                *)  abs="$(cd "$REPO_ROOT" && realpath -m "$source")" ;;
            esac
            abs="$(realpath -m "$abs")"
            case "$abs" in
                "$REPO_ROOT"/*|"$REPO_ROOT")
                    return 0
                    ;;
                *)
                    echo "ERROR: $label: bind fuera del repo ($source → $abs)" >&2
                    return 1
                    ;;
            esac
            ;;
    esac
}

# 3b. Servicios sin profiles.
SERVICES_NO_PROFILES="$(echo "$RENDERED" | jq -r '.services | to_entries[] | select(.value.profiles == null) | .key')"

for SVC in $SERVICES_NO_PROFILES; do
    JP=".services[\"$SVC\"]"

    # ports
    PORTS_COUNT="$(echo "$RENDERED" | jq -r "$JP.ports // [] | length")"
    if [ "$PORTS_COUNT" -gt 0 ]; then
        echo "ERROR: $SVC: tiene 'ports'; Coolify enruta el tráfico al servicio" >&2
        exit 1
    fi

    # container_name
    CN="$(echo "$RENDERED" | jq -r "$JP.container_name // \"\"")"
    if [ -n "$CN" ]; then
        echo "ERROR: $SVC: tiene 'container_name' fijo" >&2
        exit 1
    fi

    # privileged, cap_add, devices, pid, ipc
    for K in privileged cap_add devices pid ipc; do
        V="$(echo "$RENDERED" | jq -r "$JP.$K // null")"
        if [ "$V" != "null" ] && [ "$V" != "[]" ] && [ "$V" != "" ]; then
            echo "ERROR: $SVC: tiene '$K' no permitido ($V)" >&2
            exit 1
        fi
    done

    # network_mode
    NM="$(echo "$RENDERED" | jq -r "$JP.network_mode // \"\"")"
    if [ -n "$NM" ]; then
        echo "ERROR: $SVC: tiene 'network_mode: $NM'" >&2
        exit 1
    fi

    # security_opt: si contiene 'unconfined' en cualquier forma
    # (seccomp:unconfined, seccomp=unconfined, apparmor:unconfined,
    # systempaths=unconfined, etc.) falla. Regex case-insensitive.
    if echo "$RENDERED" | jq -e "$JP.security_opt // [] | any(test(\"(?i)unconfined\"))" >/dev/null; then
        echo "ERROR: $SVC: tiene 'security_opt' con unconfined" >&2
        exit 1
    fi

    # binds en este servicio.
    while IFS= read -r B; do
        [ -z "$B" ] && continue
        check_bind "$SVC" "$B" || exit 1
    done < <(echo "$RENDERED" | jq -r "$JP.volumes // [] | map(select(.type == \"bind\")) | .[].source // \"\"")
done

# 3c. Binds declarados en el bloque raíz 'volumes:'. Un volumen con nombre
#     puede montar una carpeta del host vía driver_opts ({type: none, o: bind,
#     device: <ruta>}), así que se recorre device en lugar de source/type.
while IFS= read -r B; do
    [ -z "$B" ] && continue
    check_bind "volumes:" "$B" || exit 1
done < <(echo "$RENDERED" | jq -r '.volumes // {} | to_entries[]
        | select((.value.driver_opts.o // "") | split(",") | any(. == "bind"))
        | .value.driver_opts.device // ""')

# 3d. Sin redes con name fijo. Cada red usada debe tener 'name' igual a
#     '<project>_<key>' (auto-derivación por defecto de docker compose).
#     Cualquier 'name' declarado en el compose deja de ser sobreescribible
#     por Coolify.
BAD_NET="$(echo "$RENDERED" | jq -r --arg p "$EXPECTED_PROJECT" \
    '.networks // {} | to_entries[]
        | select(.value.name != null and .value.name != ($p + "_" + .key))
        | .key')"
if [ -n "$BAD_NET" ]; then
    echo "ERROR: redes con 'name' fijo (no respeta el nombre de Coolify): $BAD_NET" >&2
    exit 1
fi

# 3e. Volúmenes sin 'name' fijo (o con name parametrizado). Coolify pone el
#     nombre del proyecto; cualquier 'name' declarado en el compose deja de
#     ser sobreescribible. Se acepta la forma '<project>_<key>' (auto-derivada)
#     y los nombres del source que contienen '${...}' (parametrizados).
#     Se detecta parametrización directamente en el archivo (no en el render)
#     para no caer en el tramp de substring del valor ficticio.
VOL_NAMES_PARAM="$(python3 -c '
import yaml, json
with open("'"$COMPOSE_FILE"'") as f:
    data = yaml.safe_load(f)
out = {}
for k, v in (data.get("volumes") or {}).items():
    if v and isinstance(v, dict) and "name" in v and v["name"] is not None:
        out[k] = "${" in str(v["name"])
print(json.dumps(out))
' 2>/dev/null || echo "{}")"
BAD_VOL="$(echo "$RENDERED" | jq -r --arg p "$EXPECTED_PROJECT" --argjson params "$VOL_NAMES_PARAM" \
    '.volumes // {} | to_entries[]
        | . as $v
        | select(.value.name != null)
        | select(
            (.value.name != ($p + "_" + $v.key))
            and (($params[$v.key] // false) | not)
        )
        | "\($v.key): \(.value.name)"')"
if [ -n "$BAD_VOL" ]; then
    echo "ERROR: volumes con 'name' fijo (no respeta el nombre de Coolify): $BAD_VOL" >&2
    exit 1
fi

echo "OK: compose cumple el contrato Coolify"