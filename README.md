<div align="center">

# Niri Dots

**Arch Linux** · [Niri](https://github.com/YaLTeR/niri) · [iNiR](https://github.com/snowarch/inir) · Kitty

Личный снапшот рабочего стола — один конфиг, без чужих waybar/minimal-стеков.

[![Niri](https://img.shields.io/badge/Niri-26.04-5E9FD6?style=flat-square)](https://github.com/YaLTeR/niri)
[![Shell](https://img.shields.io/badge/Shell-iNiR-8B5CF6?style=flat-square)](https://github.com/snowarch/inir)
[![Terminal](https://img.shields.io/badge/Terminal-Kitty-714FDD?style=flat-square)](https://sw.kovidgoyal.net/kitty/)
[![Distro](https://img.shields.io/badge/Arch-Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)](https://archlinux.org/)

Снято с **ARZOPA 27″** · HDMI · `2560×1440@144`

</div>

---

## Quick start

```bash
git clone git@github.com:putniikiis/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Скрипт ставит пакеты из `packages.txt`, копирует конфиги в `~/.config`, подставляет `$HOME` пользователя и **генерирует мониторы под текущее железо**. Старые файлы сохраняются в `~/.local/state/niri-dots/backups/`.

После установки — сессия **Niri**. Если iNiR ещё не в `PATH`, поставь его отдельно (AUR/git), затем:

```bash
./install.sh --configs
```

---

## Installer

`install.sh` рассчитан на **чужое устройство**: не копирует слепо `eDP`/`HDMI` автора, а читает DRM и собирает `90-user-extra.kdl`.

| Команда | Назначение |
|---------|------------|
| `./install.sh` | Полная установка (пакеты + конфиги + systemd) |
| `./install.sh --packages` | Только `pacman` из `packages.txt` |
| `./install.sh --configs` | Только конфиги + автодетект мониторов |
| `./install.sh --fix-outputs` | Пересобрать выходы после смены мониторов |
| `./install.sh --detect-only` | Показать JSON детекта (без записи) |
| `./install.sh --validate` | Проверить `niri validate` |

### Что делает автоматически

1. **Детект выходов** — `/sys/class/drm` + `edid-decode` (если есть): connector, режим, scale, позиция слева направо.
2. **Scale** — по PPI из EDID; для ноутбуков 2.8K без EDID size — ~1.5; для обычного QHD/FHD — 1.
3. **Пути** — все `/home/<кто-то>/…` в конфигах заменяются на `$HOME` текущего пользователя.
4. **Validate + fix** — `niri validate`; при ошибке снижает scale до 1, затем минимальный stub на `eDP-1`.
5. **Опционально** — `arzopa-picture-balance` и Muslim Reminder подключаются только если бинарники уже есть.
6. **Обои** — абсолютные пути к несуществующим файлам в `inir` config очищаются.

Переменная окружения:

```bash
NIRI_KB_LAYOUT=us ./install.sh --fix-outputs   # по умолчанию us,ru
```

Не запускай от root. `sudo` нужен только для `pacman`.

---

## Preview

| Desktop | Overview |
|:-------:|:--------:|
| ![Desktop](media/screenshots/01-desktop-arzopa.png) | ![Overview](media/screenshots/03-overview.png) |
| *Пустой стол (HDMI)* | *Niri overview* |

| Launcher | Control panel |
|:--------:|:-------------:|
| ![Launcher](media/screenshots/04-launcher.png) | ![Control panel](media/screenshots/07-control-panel.png) |
| *iNiR overview / apps* | *Быстрые настройки* |

| Settings | Terminal |
|:--------:|:--------:|
| ![Settings](media/screenshots/05-settings-inir.png) | ![Kitty](media/screenshots/06-terminal-kitty.png) |
| *iNiR · Plugins* | *Kitty + fish + fastfetch* |

<p align="center">
  <img src="media/screenshots/02-desktop-laptop.png" alt="Laptop eDP" width="720" />
  <br />
  <sub>Ноутбук · eDP · пустой workspace</sub>
</p>

---

## Stack

| Layer | Choice |
|-------|--------|
| Compositor | **Niri** 26.04 |
| Desktop shell | **iNiR** (Quickshell) |
| Terminal | **Kitty** |
| Shell | fish + Starship |
| Icons | Papirus-Dark |
| Cursor | capitaine-cursors-light |
| Portals | xdg-desktop-portal-gnome (ScreenCast) + gtk |
| Plugins | `quickshell/inir-plugins` |

---

## Keybindings

`Mod` = Super/Win. Полный список в сессии: **Mod+/** (iNiR cheatsheet).  
Конфиг: `configs/niri/config.d/70-binds.kdl`, личное — `90-user-extra.kdl` (генерируется установщиком).

### Applications

| Keys | Action |
|------|--------|
| `Mod+T` / `Mod+Return` | Terminal (Kitty) |
| `Super+W` | Browser |
| `Super+E` | Files (Nautilus) |
| `Mod+Space` | iNiR overview / launcher |
| `Mod+Tab` | Niri overview |

### Shell & UI

| Keys | Action |
|------|--------|
| `Mod+,` | iNiR settings |
| `Mod+Ctrl+P` | Plugins page |
| `Mod+/` | Cheatsheet |
| `Mod+V` | Clipboard history |
| `Super+G` | Overlay tools |
| `Ctrl+Alt+T` | Wallpaper picker |

### Windows & workspaces

| Keys | Action |
|------|--------|
| `Mod+Q` | Close window |
| `Mod+D` | Maximize column |
| `Mod+F` | Fullscreen |
| `Mod+1` … `Mod+9` | Focus workspace |

### Capture & media

| Keys | Action |
|------|--------|
| `Mod+Shift+S` / `Ctrl+Shift+S` | Region screenshot |
| `Print` / `Ctrl+Print` / `Alt+Print` | Screen / output / window |
| `Mod+Shift+R` | Record with sound |

### Session

| Keys | Action |
|------|--------|
| `Mod+L` | Lock |
| `Mod+Shift+Q` / `Ctrl+Alt+Delete` | Session menu |
| `Mod+Ctrl+O` | Quran Reminder (если установлен) |

---

## Layout

```text
dotfiles/
├── install.sh                 # установщик + адаптация под устройство
├── packages.txt               # pacman-зависимости
├── scripts/
│   └── detect-outputs.py      # DRM/EDID → Niri output blocks
├── configs/                   # niri, kitty, fish, inir, portals, …
├── quickshell/inir-plugins/   # host плагинов
├── systemd/                   # inir + inir-plugins (user units)
├── bin/                       # вспомогательные скрипты
└── media/screenshots/         # превью HDMI
```

---

## Notes

- После смены мониторов: `./install.sh --fix-outputs`.
- Не запускай upstream `setup` из чужого клона поверх этого снапшота.
- iNiR в этот репозиторий не вендорится (тяжёлый); нужен установленный `inir` / `qs`.
- Экспорт снимка: `2026-10-05` · niri `26.04`.
