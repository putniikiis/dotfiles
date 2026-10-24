//@ pragma UseQApplication
//@ pragma ShellId inir-plugins
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import qs.services
import qs.modules

// Plugin host only — settings UI lives in iNiR (page "Plugins"), not a separate angelOS window.
ShellRoot {
    PluginHost {}
    Ipc {}
}
