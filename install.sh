#!/usr/bin/env bash
# Niri Dots — install / adapt / validate for the current machine.
# Usage:
#   ./install.sh                 # full install
#   ./install.sh --packages      # packages only
#   ./install.sh --configs       # configs only (adapt + validate)
#   ./install.sh --fix-outputs # regenerate 90-user-extra.kdl from DRM
#   ./install.sh --detect-only   # print detected outputs (JSON)
#   ./install.sh --validate      # niri validate only
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:-}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME_DIR/.local/share}"
BIN_DIR="${HOME_DIR}/.local/bin"
STATE_DIR="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/niri-dots"
BACKUP_ROOT="${STATE_DIR}/backups/$(date +%Y%m%d-%H%M%S)"
DETECT_PY="$ROOT/scripts/detect-outputs.py"
NIRI_KB_LAYOUT="${NIRI_KB_LAYOUT:-us,ru}"
export NIRI_KB_LAYOUT

DO_PACKAGES=1
DO_CONFIGS=1
DO_SYSTEMD=1
MODE="install"

log()  { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
    --packages) MODE="packages"; DO_PACKAGES=1; DO_CONFIGS=0; DO_SYSTEMD=0 ;;
    --configs) MODE="configs"; DO_PACKAGES=0; DO_CONFIGS=1; DO_SYSTEMD=0 ;;
    --fix-outputs) MODE="fix-outputs"; DO_PACKAGES=0; DO_CONFIGS=0; DO_SYSTEMD=0 ;;
    --detect-only) MODE="detect-only"; DO_PACKAGES=0; DO_CONFIGS=0; DO_SYSTEMD=0 ;;
    --validate) MODE="validate"; DO_PACKAGES=0; DO_CONFIGS=0; DO_SYSTEMD=0 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --no-systemd) DO_SYSTEMD=0 ;;
    *) die "unknown argument: $arg (see --help)" ;;
  esac
done

[[ -n "$HOME_DIR" && "$HOME_DIR" != "/" ]] || die "HOME is unset"
[[ "$(id -u)" -ne 0 ]] || die "do not run as root — run as your user (sudo is used only for pacman)"
[[ -f "$DETECT_PY" ]] || die "missing $DETECT_PY"
command -v python3 >/dev/null || die "python3 is required"

rewrite_home_paths() {
  local target="$1"
  # Replace previous owner's absolute home with the installing user.
  if [[ -d "$target" ]]; then
    find "$target" -type f \( \
      -name '*.kdl' -o -name '*.conf' -o -name '*.json' -o -name '*.jsonc' \
      -o -name '*.fish' -o -name '*.toml' -o -name '*.ini' -o -name '*.list' \
    \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
      if grep -q '/home/[^/]\+' "$f" 2>/dev/null; then
        sed -i -E "s|/home/[^/]+|${HOME_DIR}|g" "$f"
      fi
    done
  elif [[ -f "$target" ]]; then
    sed -i -E "s|/home/[^/]+|${HOME_DIR}|g" "$target"
  fi
}

backup_path() {
  local src="$1"
  [[ -e "$src" ]] || return 0
  mkdir -p "$BACKUP_ROOT"
  local dest="$BACKUP_ROOT/${src#"$HOME_DIR"/}"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  log "backup: $src → $dest"
}

install_packages() {
  [[ -f "$ROOT/packages.txt" ]] || die "missing packages.txt"
  mapfile -t pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$ROOT/packages.txt")
  [[ ${#pkgs[@]} -gt 0 ]] || die "packages.txt is empty"
  log "installing ${#pkgs[@]} packages (pacman)"
  sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
  # Optional helpers used by detect / ARZOPA path
  if pacman -Si edid-decode >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm edid-decode || true
  fi
  if ! command -v inir >/dev/null 2>&1; then
    warn "inir not found in PATH — install iNiR separately (AUR/git), then re-run: ./install.sh --configs"
  fi
  if ! command -v qs >/dev/null 2>&1; then
    warn "quickshell (qs) not found — package 'quickshell' should provide it"
  fi
}

link_or_copy() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    backup_path "$dest"
    rm -rf "$dest"
  fi
  cp -a "$src" "$dest"
}

install_bins() {
  mkdir -p "$BIN_DIR"
  if [[ -d "$ROOT/bin" ]]; then
    for f in "$ROOT/bin"/*; do
      [[ -f "$f" ]] || continue
      local base
      base="$(basename "$f")"
      install -m 0755 "$f" "$BIN_DIR/$base"
      rewrite_home_paths "$BIN_DIR/$base"
    done
    log "installed helpers → $BIN_DIR"
  fi
}

install_systemd_units() {
  local unit_dir="$HOME_DIR/.config/systemd/user"
  mkdir -p "$unit_dir"
  if [[ -d "$ROOT/systemd" ]]; then
    cp -a "$ROOT/systemd/." "$unit_dir/"
    systemctl --user daemon-reload
    if [[ -f "$unit_dir/inir-plugins.service" ]]; then
      systemctl --user enable inir-plugins.service || true
    fi
    if command -v inir >/dev/null 2>&1; then
      inir service enable 2>/dev/null || true
    elif [[ -f "$unit_dir/inir.service" ]]; then
      mkdir -p "$HOME_DIR/.config/systemd/user/niri.service.wants"
      ln -sfn ../inir.service "$HOME_DIR/.config/systemd/user/niri.service.wants/inir.service"
    fi
    log "systemd user units installed"
  fi
}

install_quickshell_plugins() {
  local qs="$XDG_CONFIG_HOME/quickshell"
  mkdir -p "$qs"
  if [[ -d "$ROOT/quickshell/inir-plugins" ]]; then
    link_or_copy "$ROOT/quickshell/inir-plugins" "$qs/inir-plugins"
    rewrite_home_paths "$qs/inir-plugins"
    log "quickshell inir-plugins → $qs/inir-plugins"
  fi
}

generate_outputs_kdl() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  local extra=(--kdl)
  [[ -x "$HOME_DIR/.local/bin/arzopa-picture-balance" || -f "$ROOT/bin/arzopa-picture-balance" ]] && extra+=(--with-arzopa)
  [[ -x "$HOME_DIR/.local/share/muslim-reminder/run.sh" ]] && extra+=(--with-muslim)
  python3 "$DETECT_PY" "${extra[@]}" >"$tmp"
  mkdir -p "$(dirname "$dest")"
  mv "$tmp" "$dest"
  rewrite_home_paths "$dest"
}

validate_niri() {
  local cfg="${1:-$XDG_CONFIG_HOME/niri/config.kdl}"
  if ! command -v niri >/dev/null 2>&1; then
    warn "niri not installed — skip validate"
    return 0
  fi
  if niri validate -c "$cfg" >/dev/null 2>&1; then
    log "niri validate: OK ($cfg)"
    return 0
  fi
  # Show errors
  warn "niri validate failed — attempting auto-fix"
  niri validate -c "$cfg" 2>&1 | tail -40 || true
  return 1
}

fix_outputs_until_valid() {
  local extra="$XDG_CONFIG_HOME/niri/config.d/90-user-extra.kdl"
  local cfg="$XDG_CONFIG_HOME/niri/config.kdl"
  generate_outputs_kdl "$extra"
  if validate_niri "$cfg"; then
    return 0
  fi

  warn "retrying with scale=1 on all outputs"
  python3 - "$extra" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = re.sub(r'(?m)^(\s*scale\s+)\S+', r'\g<1>1', text)
p.write_text(text)
PY
  if validate_niri "$cfg"; then
    return 0
  fi

  warn "retrying with minimal single-output stub"
  cat >"$extra" <<EOF
// Minimal fallback generated by install.sh after validate failures.
output "eDP-1" {
    scale 1
    transform "normal"
    position x=0 y=0
    focus-at-startup
}

input {
    keyboard {
        xkb {
            layout "${NIRI_KB_LAYOUT}"
            options "grp:alt_shift_toggle,compose:rctrl,ctrl:nocaps"
        }
        numlock
    }
    touchpad {
        tap
        natural-scroll
    }
}

binds {
    Ctrl+Alt+Delete allow-inhibiting=false { spawn "inir" "session" "toggle"; }
    Mod+L allow-when-locked=true { spawn "inir" "lock" "activate"; }
}
EOF
  if validate_niri "$cfg"; then
    warn "used minimal fallback — re-run ./install.sh --fix-outputs after plugging monitors"
    return 0
  fi
  die "niri config still invalid after auto-fix — see backup in $BACKUP_ROOT"
}

install_configs() {
  [[ -d "$ROOT/configs" ]] || die "missing configs/"
  mkdir -p "$XDG_CONFIG_HOME" "$BIN_DIR" "$STATE_DIR"

  # Map of package config dirs → ~/.config
  local name
  for name in niri kitty fish qt6ct gtk-3.0 gtk-4.0 fastfetch starship \
              xdg-desktop-portal environment.d inir alacritty; do
    if [[ -e "$ROOT/configs/$name" ]]; then
      link_or_copy "$ROOT/configs/$name" "$XDG_CONFIG_HOME/$name"
      rewrite_home_paths "$XDG_CONFIG_HOME/$name"
      log "config: $name"
    fi
  done

  for name in mimeapps.list xdg-terminals.list; do
    if [[ -f "$ROOT/configs/$name" ]]; then
      link_or_copy "$ROOT/configs/$name" "$XDG_CONFIG_HOME/$name"
      rewrite_home_paths "$XDG_CONFIG_HOME/$name"
    fi
  done

  install_bins
  install_quickshell_plugins

  # Device-specific outputs always regenerated for this machine
  fix_outputs_until_valid

  # Soften absolute wallpaper paths that may not exist on this host
  local inir_json="$XDG_CONFIG_HOME/inir/config.json"
  if [[ -f "$inir_json" ]] && command -v python3 >/dev/null; then
    python3 - "$inir_json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
state = {"changed": False}

def scrub(obj):
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if k in ("wallpaperPath", "fallback") and isinstance(v, str) and v.startswith("/"):
                if not pathlib.Path(v).exists():
                    obj[k] = ""
                    state["changed"] = True
            else:
                scrub(v)
    elif isinstance(obj, list):
        for i in obj:
            scrub(i)

scrub(data)
if state["changed"]:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print("cleared missing wallpaper paths in inir config")
PY
  fi
}

# ── modes ────────────────────────────────────────────────────────────────────
case "$MODE" in
  detect-only)
    python3 "$DETECT_PY"
    exit 0
    ;;
  validate)
    validate_niri || exit 1
    exit 0
    ;;
  fix-outputs)
    [[ -f "$XDG_CONFIG_HOME/niri/config.kdl" ]] || die "niri config missing — run full install first"
    backup_path "$XDG_CONFIG_HOME/niri/config.d/90-user-extra.kdl"
    fix_outputs_until_valid
    log "outputs fixed"
    exit 0
    ;;
esac

log "Niri Dots install → $HOME_DIR (mode=$MODE)"
mkdir -p "$STATE_DIR"

if [[ "$DO_PACKAGES" -eq 1 ]]; then
  install_packages
fi

if [[ "$DO_CONFIGS" -eq 1 ]]; then
  install_configs
fi

if [[ "$DO_SYSTEMD" -eq 1 ]]; then
  install_systemd_units
fi

log "done"
echo
echo "Next:"
echo "  1. Log into a Niri session (or: niri msg action load-config-file)"
echo "  2. If monitors look wrong:  ./install.sh --fix-outputs"
echo "  3. Preview detection:       ./install.sh --detect-only"
echo "  4. Keyboard layout override: NIRI_KB_LAYOUT=us ./install.sh --fix-outputs"
echo "Backups: $BACKUP_ROOT"
