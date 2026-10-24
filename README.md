# Niri Dots

Личный снапшот рабочего стола: **Niri** + **iNiR** + **Kitty** + плагины.  
Только мой конфиг — без чужих waybar/minimal-стеков.

Снято с внешнего монитора **ARZOPA 27″ HDMI · 2560×1440@144**.

## Скриншоты (HDMI)

### Пустой рабочий стол

![Desktop](media/screenshots/01-desktop-arzopa.png)

### Overview

![Overview](media/screenshots/03-overview.png)

### Launcher

![Launcher](media/screenshots/04-launcher.png)

### Настройки iNiR (Plugins)

![Settings](media/screenshots/05-settings-inir.png)

### Kitty

![Kitty](media/screenshots/06-terminal-kitty.png)

### Control panel

![Control panel](media/screenshots/07-control-panel.png)

### Ноутбук (eDP, пустой workspace)

![Laptop](media/screenshots/02-desktop-laptop.png)

## Бинды

Источник правды: `configs/niri/config.d/70-binds.kdl` + личные оверрайды в `90-user-extra.kdl`.  
Полный список в сессии: **Mod+/** (cheatsheet iNiR).

| Клавиши | Действие |
|---------|----------|
| Mod+T / Mod+Return | Терминал (Kitty) |
| Mod+Space | Overview / лаунчер iNiR |
| Mod+Tab | Overview Niri |
| Super+W | Браузер |
| Super+E | Файлы (Nautilus) |
| Mod+V | Буфер обмена |
| Mod+, | Настройки iNiR |
| Mod+Ctrl+P | Плагины (settings page) |
| Mod+/ | Шпаргалка биндов |
| Mod+Shift+S / Ctrl+Shift+S | Скрин региона |
| Print / Ctrl+Print / Alt+Print | Скрин / экран / окно |
| Mod+Shift+R | Запись экрана со звуком |
| Mod+Q | Закрыть окно |
| Mod+D | Maximize column |
| Mod+F | Fullscreen |
| Mod+L | Lock (личный оверрайд) |
| Mod+Shift+Q / Ctrl+Alt+Delete | Меню сессии |
| Super+G | Overlay (заметки/тулзы) |
| Ctrl+Alt+T | Выбор обоев |
| Mod+1…9 | Воркспейсы |
| Mod+Ctrl+O | Quran Reminder |

## Установка

```bash
cd ~/Desktop/Yettalor-Niri-Dots
chmod +x install.sh
./install.sh
```

Ставит пакеты из `packages.txt`, шелл, Niri `config.d`, Kitty/fish/portals и `inir-plugins` **как на этой машине**.

После установки — сессия Niri. Мониторы в `configs/niri/config.d/90-user-extra.kdl` поправь под себя.

## Стек

| Компонент | Выбор |
|-----------|--------|
| Compositor | Niri |
| Shell | iNiR (Quickshell) |
| Terminal | Kitty |
| Icons | Papirus-Dark |
| Cursor | capitaine-cursors-light |
| Portals | gnome ScreenCast + gtk |
| Plugins | `quickshell/inir-plugins` |

## Структура

- `configs/` — niri, kitty, fish, qt6ct, portals, inir `config.json`
- `shell/` — снапшот iNiR без `.git`
- `quickshell/inir-plugins/` — host плагинов
- `systemd/` — `inir` + `inir-plugins`
- `bin/` — вспомогательные скрипты
- `media/screenshots/` — скрины HDMI
