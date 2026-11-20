// DorothyOS Settings — a touch-first front door to the settings of a Plasma tablet (sidebar of categories, big controls, real
// values).  Everything it shows or changes goes through dorothyos-settings-helper (Wi-Fi, Bluetooth, brightness, volume, dark mode,
// accent colour, dock ...); for anything deeper each page has a link that opens the matching KDE settings module (kcmshell6), and
// "All settings" opens System Settings itself.  Runs in a normal window through plasmawindowed (see dorothyos-settings).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    Plasmoid.icon: "preferences-system"
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Settings"

    // ---- backend ------------------------------------------------------------------------------------------------------------
    property var st: ({ wifi: "off", ssid: "", bt: "off", night: "off", rotlock: "off", dnd: "off", bright: 50, vol: 50, mute: "off",
                        scale: 2.5, dark: "off", accent: "#e85d00", kbd: "off", battery: -1, batstatus: "", profile: "" })
    property var wifiList: []
    property var btList: []
    property var about: ({})
    property var dock: ({ dockSize: 56, dockAlpha: 85, dockRadius: 18, barAlpha: 55, dockHide: 0 })
    property string busyKey: ""
    property string notice: ""
    property var pending: ({})
    property int seq: 0

    function call(args, cb) {
        var src = "env PATH=\"$HOME/.local/bin:$PATH\" dorothyos-settings-helper " + args + " #" + (++seq)
        if (cb) pending[src] = cb
        exec.connectSource(src)
    }
    function kcm(id) { exec.connectSource("kcmshell6 " + id + " #" + (++seq)) }
    function launch(cmd) { exec.connectSource(cmd + " #" + (++seq)) }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            var cb = root.pending[source]
            if (!cb) return
            delete root.pending[source]
            var v = null
            try { v = JSON.parse(String(data["stdout"]).trim().split("\n").pop()) } catch (e) { v = null }
            cb(v)
        }
    }
    function patch(key, value) { var c = {}; for (var k in st) c[k] = st[k]; c[key] = value; st = c }
    function refresh() { call("state", function(v) { if (v) root.st = v }) }
    function refreshWifi() { call("wifi-list", function(v) { if (v) root.wifiList = v }) }
    function refreshBt() { call("bt-list", function(v) { if (v) root.btList = v }) }
    function refreshAbout() { call("about", function(v) { if (v) root.about = v }) }
    function refreshDock() { call("dock-get", function(v) { if (v && v.dockSize !== undefined) root.dock = v }) }
    function settle(ms) { settleTimer.interval = ms; settleTimer.restart() }
    Timer { id: settleTimer; interval: 1500; onTriggered: { root.refresh(); if (root.current === "wifi") root.refreshWifi(); if (root.current === "bluetooth") root.refreshBt() } }
    Timer { interval: 6000; repeat: true; running: root.expanded || true; onTriggered: root.refresh() }

    // ---- pages --------------------------------------------------------------------------------------------------------------
    readonly property var entries: [
        { section: "Connectivity", key: "wifi", title: "Wi-Fi", icon: "network-wireless", color: "#2f80ed", kw: "wireless network internet" },
        { key: "bluetooth", title: "Bluetooth", icon: "network-bluetooth", color: "#2f80ed", kw: "devices keyboard mouse headphones" },
        { section: "Device", key: "display", title: "Display & Brightness", icon: "video-display", color: "#f2994a", kw: "screen scale night light rotation" },
        { key: "sound", title: "Sound", icon: "audio-volume-high", color: "#eb5757", kw: "volume speaker mute audio" },
        { key: "battery", title: "Battery & Power", icon: "battery", color: "#27ae60", kw: "charge power profile performance" },
        { key: "notifications", title: "Notifications", icon: "notifications", color: "#eb5757", kw: "do not disturb focus" },
        { section: "Personal", key: "appearance", title: "Appearance & Wallpaper", icon: "preferences-desktop-theme", color: "#9b51e0", kw: "dark light accent colour wallpaper icons theme" },
        { key: "home", title: "Home Screen & Dock", icon: "view-grid", color: "#9b51e0", kw: "dock bar size transparency" },
        { key: "input", title: "Keyboard & Input", icon: "input-keyboard", color: "#828282", kw: "on-screen keyboard layout touch" },
        { section: "System", key: "apps", title: "Apps & Updates", icon: "system-software-install", color: "#2f80ed", kw: "discover software default apps startup" },
        { key: "general", title: "Language, Time & Users", icon: "preferences-system-time", color: "#828282", kw: "region date clock accounts" },
        { key: "storage", title: "Storage", icon: "drive-harddisk", color: "#828282", kw: "disk space" },
        { key: "privacy", title: "Privacy & Security", icon: "security-high", color: "#27ae60", kw: "lock screen firewall" },
        { key: "about", title: "About DorothyOS", icon: "dorothyos", color: "#e85d00", kw: "version device kernel system information" },
        { key: "all", title: "All settings", icon: "configure", color: "#4f4f4f", kw: "system settings advanced" }
    ]
    property string current: ""
    property string query: ""
    function entryFor(k) { for (var i = 0; i < entries.length; i++) if (entries[i].key === k) return entries[i]; return null }
    function visibleEntries() {
        var q = query.toLowerCase(), res = [], last = ""
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            var sec = e.section ? e.section : last
            if (e.section) last = e.section
            if (q.length && (e.title + " " + e.kw).toLowerCase().indexOf(q) < 0) continue
            res.push({ header: false, e: e, section: sec })
        }
        return res
    }
    function select(k) {
        if (k === "all") { launch("systemsettings"); return }
        current = k
        refresh()
        if (k === "wifi") refreshWifi()
        else if (k === "bluetooth") refreshBt()
        else if (k === "about" || k === "storage") refreshAbout()
        else if (k === "home") refreshDock()
    }
    Component.onCompleted: { refresh(); refreshAbout() }

    // ---- UI -----------------------------------------------------------------------------------------------------------------
    fullRepresentation: Item {
        id: win
        implicitWidth: 1000
        implicitHeight: 640
        Layout.minimumWidth: 480
        Layout.minimumHeight: 360
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        readonly property bool narrow: width < 780
        readonly property string shownPage: narrow ? root.current : (root.current !== "" ? root.current : "wifi")
        Component.onCompleted: if (!narrow && root.current === "") root.select("wifi")

        RowLayout {
            anchors.fill: parent; spacing: 0

            // ---- sidebar
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: win.narrow ? win.width : 330
                visible: !win.narrow || root.current === ""
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10
                    QQC2.Label { text: "Settings"; font.pixelSize: 30; font.bold: true; Layout.leftMargin: 6; Layout.topMargin: 4 }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 23
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 8
                            Kirigami.Icon { source: "search"; Layout.preferredWidth: 22; Layout.preferredHeight: 22; opacity: 0.7 }
                            QQC2.TextField {
                                Layout.fillWidth: true; background: null; font.pixelSize: 16; placeholderText: "Search settings"
                                inputMethodHints: Qt.ImhNoPredictiveText
                                text: root.query; onTextEdited: root.query = text
                            }
                        }
                    }
                    Flickable {
                        id: side
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: sideCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: sideCol; width: side.width; spacing: 3
                            Repeater {
                                model: root.visibleEntries()
                                delegate: ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    readonly property bool firstOfSection: index === 0 || root.visibleEntries()[index - 1].section !== modelData.section
                                    QQC2.Label { visible: firstOfSection; text: modelData.section; font.pixelSize: 12; opacity: 0.55; Layout.topMargin: index === 0 ? 0 : 12; Layout.leftMargin: 8 }
                                    SidebarItem {
                                        title: modelData.e.title; iconName: modelData.e.icon; iconColor: modelData.e.color
                                        current: win.shownPage === modelData.e.key
                                        onClicked: root.select(modelData.e.key)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- page
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: !win.narrow || root.current !== ""
                ColumnLayout {
                    anchors.fill: parent; spacing: 0
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 72; Layout.leftMargin: 20; Layout.rightMargin: 20; spacing: 10
                        Rectangle {
                            visible: win.narrow; Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 23
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                            Kirigami.Icon { anchors.centerIn: parent; width: 24; height: 24; source: "go-previous-symbolic" }
                            TapHandler { onTapped: root.current = "" }
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: root.entryFor(win.shownPage) ? root.entryFor(win.shownPage).title : ""
                            font.pixelSize: 28; font.bold: true; elide: Text.ElideRight
                        }
                    }
                    Flickable {
                        id: pageView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: pageHolder.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
                        Item {
                            id: pageHolder
                            x: Math.max(20, (pageView.width - 680) / 2); width: Math.min(680, pageView.width - 40)
                            height: pageLoader.item ? pageLoader.item.implicitHeight : 0
                            Loader {
                                id: pageLoader; width: parent.width
                                sourceComponent: ({ wifi: pgWifi, bluetooth: pgBt, display: pgDisplay, sound: pgSound, battery: pgBattery,
                                                    notifications: pgNotif, appearance: pgAppearance, home: pgHome, input: pgInput, apps: pgApps,
                                                    general: pgGeneral, storage: pgStorage, privacy: pgPrivacy, about: pgAbout })[win.shownPage]
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- page components -------------------------------------------------------------------------------------------------------
    function sigIcon(s) { return s > 75 ? "network-wireless-signal-excellent-symbolic" : s > 50 ? "network-wireless-signal-good-symbolic" : s > 25 ? "network-wireless-signal-ok-symbolic" : "network-wireless-signal-weak-symbolic" }
    function connectWifi(n) {
        if (!n.known && n.sec !== "") { kcm("kcm_networkmanagement"); return }
        busyKey = n.ssid
        call("wifi-connect '" + n.ssid.replace(/'/g, "'\\''") + "'", function(v) { root.busyKey = ""; root.notice = (v && v.ok) ? "" : "Could not connect"; root.refresh(); root.refreshWifi() })
    }
    function btToggle(d) {
        busyKey = d.mac
        call((d.connected ? "bt-disconnect " : "bt-connect ") + d.mac, function(v) { root.busyKey = ""; root.refreshBt() })
    }

    Component { id: pgWifi
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: "Wi-Fi"; iconName: "network-wireless"; iconColor: "#2f80ed"; separator: false
                    subtitle: root.st.wifi === "on" ? (root.st.ssid !== "" ? "Connected to " + root.st.ssid : "On") : "Off"
                    ToggleSwitch { checked: root.st.wifi === "on"; onToggled: (v) => { root.patch("wifi", v ? "on" : "off"); root.call("wifi " + (v ? "on" : "off")); root.settle(3000); if (v) root.settle(4000) } } }
            }
            SettingsGroup { header: "Networks"; visible: root.st.wifi === "on"
                footer: "Saved networks connect with one tap. For a new protected network the system network settings open so you can type the password."
                Repeater { model: root.wifiList
                    delegate: SettingRow { title: modelData.ssid; iconName: ""; tappable: !modelData.active; busy: root.busyKey === modelData.ssid
                        separator: index < root.wifiList.length - 1
                        subtitle: modelData.active ? "Connected" : modelData.known ? "Saved" : modelData.sec === "" ? "Open network" : "Protected"
                        onClicked: root.connectWifi(modelData)
                        Kirigami.Icon { visible: modelData.sec !== ""; source: "object-locked-symbolic"; width: 18; height: 18; opacity: 0.6 }
                        Kirigami.Icon { source: root.sigIcon(modelData.signal); width: 24; height: 24 } } }
                SettingRow { visible: root.wifiList.length === 0; title: "No networks found"; subtitle: "Move closer to the router"; separator: false }
            }
            SettingsGroup {
                SettingRow { title: "Network settings"; subtitle: "Add a network, VPN, hotspot, proxy"; iconName: "preferences-system-network"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_networkmanagement") }
            }
        }
    }
    Component { id: pgBt
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: "Bluetooth"; iconName: "network-bluetooth"; iconColor: "#2f80ed"; separator: false
                    subtitle: root.st.bt === "on" ? "On" : "Off"
                    ToggleSwitch { checked: root.st.bt === "on"; onToggled: (v) => { root.patch("bt", v ? "on" : "off"); root.call("bt " + (v ? "on" : "off")); root.settle(2500) } } }
            }
            SettingsGroup { header: "My devices"; visible: root.st.bt === "on"
                footer: "Tap a device to connect or disconnect it."
                Repeater { model: root.btList
                    delegate: SettingRow { title: modelData.name; subtitle: modelData.connected ? "Connected" : "Not connected"; tappable: true
                        iconName: modelData.icon === "input-keyboard" ? "input-keyboard" : modelData.icon === "input-mouse" ? "input-mouse" : modelData.icon.indexOf("audio") === 0 ? "audio-headphones" : "network-bluetooth"
                        iconColor: modelData.connected ? "#27ae60" : "#828282"; busy: root.busyKey === modelData.mac
                        separator: index < root.btList.length - 1; onClicked: root.btToggle(modelData) } }
                SettingRow { visible: root.btList.length === 0; title: "No paired devices"; separator: false }
            }
            SettingsGroup {
                SettingRow { title: "Pair a new device"; subtitle: "Opens the Bluetooth settings"; iconName: "list-add"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_bluetooth") }
            }
        }
    }
    Component { id: pgDisplay
        ColumnLayout { spacing: 22
            SettingsGroup {
                SliderRow { iconName: "brightness-high"; value: root.st.bright / 100; valueText: root.st.bright + " %"
                    onMoved: (v) => { root.patch("bright", Math.round(v * 100)) }
                    onReleased: (v) => root.call("bright " + Math.max(3, Math.round(v * 100))) }
            }
            SettingsGroup {
                SettingRow { title: "Night light"; subtitle: "Warmer colours in the evening"; iconName: "redshift-status-on"; iconColor: "#f2994a"
                    ToggleSwitch { checked: root.st.night === "on"; onToggled: (v) => { root.patch("night", v ? "on" : "off"); root.call("night " + (v ? "on" : "off")) } } }
                SettingRow { title: "Rotation lock"; subtitle: root.st.rotlock === "on" ? "The screen stays as it is" : "The screen follows how you hold the tablet"; iconName: "object-rotate-right"; iconColor: "#f2994a"; separator: false
                    ToggleSwitch { checked: root.st.rotlock === "on"; onToggled: (v) => { root.patch("rotlock", v ? "on" : "off"); root.call("rotlock " + (v ? "on" : "off")) } } }
            }
            SettingsGroup {
                footer: "Display size, resolution, refresh rate and colour profile."
                SettingRow { title: "Display size"; subtitle: Math.round(root.st.scale * 100) + " %"; iconName: "view-fullscreen"; iconColor: "#f2994a"; chevron: true; tappable: true
                    onClicked: root.kcm("kcm_kscreen") }
                SettingRow { title: "Night light schedule"; iconName: "preferences-system-time"; iconColor: "#f2994a"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_nighttime") }
            }
        }
    }
    Component { id: pgSound
        ColumnLayout { spacing: 22
            SettingsGroup {
                SliderRow { iconName: root.st.mute === "on" ? "audio-volume-muted" : "audio-volume-high"; value: root.st.mute === "on" ? 0 : root.st.vol / 100; valueText: root.st.mute === "on" ? "Muted" : root.st.vol + " %"
                    onMoved: (v) => { root.patch("vol", Math.round(v * 100)); root.patch("mute", "off") }
                    onReleased: (v) => root.call("volume " + Math.round(v * 100)) }
                SettingRow { title: "Mute"; iconName: "audio-volume-muted"; iconColor: "#eb5757"; separator: false
                    ToggleSwitch { checked: root.st.mute === "on"; onToggled: (v) => { root.patch("mute", v ? "on" : "off"); root.call("mute " + (v ? "on" : "off")) } } }
            }
            SettingsGroup {
                SettingRow { title: "Sound devices and effects"; iconName: "audio-card"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_pulseaudio") }
            }
        }
    }
    Component { id: pgBattery
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: root.st.battery >= 0 ? root.st.battery + " %" : "No battery found"; subtitle: root.st.batstatus; iconName: "battery"; iconColor: root.st.battery > 20 ? "#27ae60" : "#eb5757"; separator: false
                    Rectangle { width: 140; height: 14; radius: 7; color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                        Rectangle { width: Math.max(14, parent.width * Math.max(0, root.st.battery) / 100); height: 14; radius: 7; color: root.st.battery > 20 ? "#27ae60" : "#eb5757" } } }
            }
            SettingsGroup { header: "Performance"
                footer: "Power saver makes the battery last longer; Performance makes apps faster and the tablet warmer."
                ChoiceRow { current: root.st.profile
                    choices: [ { label: "Power saver", value: "power-saver" }, { label: "Balanced", value: "balanced" }, { label: "Performance", value: "performance" } ]
                    onPicked: (v) => { root.patch("profile", v); root.call("profile " + v, function() { root.refresh() }) } }
            }
            SettingsGroup {
                SettingRow { title: "Screen off and power saving"; iconName: "preferences-system-power-management"; iconColor: "#27ae60"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_powerdevilprofilesconfig") }
            }
        }
    }
    Component { id: pgNotif
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: "Do not disturb"; subtitle: "Silences notification pop-ups"; iconName: "notifications-disabled"; iconColor: "#eb5757"; separator: false
                    ToggleSwitch { checked: root.st.dnd === "on"; onToggled: (v) => { root.patch("dnd", v ? "on" : "off"); root.call("dnd " + (v ? "on" : "off")) } } }
            }
            SettingsGroup {
                SettingRow { title: "Notification settings"; subtitle: "Per app, sounds, pop-up position"; iconName: "preferences-desktop-notification"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_notifications") }
            }
        }
    }
    Component { id: pgAppearance
        ColumnLayout { spacing: 22
            SettingsGroup { header: "Mode"
                Item { Layout.fillWidth: true; implicitHeight: 150
                    RowLayout { anchors.centerIn: parent; spacing: 36
                        Repeater { model: [ { l: "Light", v: "off", bg: "#f6f7f8", fg: "#232629" }, { l: "Dark", v: "on", bg: "#202326", fg: "#fcfcfc" } ]
                            delegate: ColumnLayout { spacing: 8
                                Rectangle { Layout.preferredWidth: 150; Layout.preferredHeight: 92; radius: 14; color: modelData.bg
                                    border.width: root.st.dark === modelData.v ? 4 : 1; border.color: root.st.dark === modelData.v ? Kirigami.Theme.highlightColor : Qt.rgba(0.5, 0.5, 0.5, 0.5)
                                    Rectangle { x: 14; y: 14; width: 70; height: 10; radius: 5; color: modelData.fg; opacity: 0.8 }
                                    Rectangle { x: 14; y: 34; width: 100; height: 8; radius: 4; color: modelData.fg; opacity: 0.35 }
                                    Rectangle { x: 14; y: 62; width: 50; height: 18; radius: 9; color: root.st.accent }
                                    TapHandler { onTapped: { root.patch("dark", modelData.v); root.call("dark " + modelData.v, function() { root.settle(800) }) } } }
                                QQC2.Label { Layout.alignment: Qt.AlignHCenter; text: modelData.l; font.pixelSize: 15 } } } } }
            }
            SettingsGroup { header: "Accent colour"
                Flow { Layout.fillWidth: true; Layout.margins: 16; spacing: 14
                    Repeater { model: ["#e85d00", "#3daee9", "#1abc9c", "#27ae60", "#f5a623", "#da4453", "#e5429c", "#9b59b6", "#7f8c8d"]
                        delegate: Rectangle { width: 48; height: 48; radius: 24; color: modelData
                            border.width: root.st.accent.toLowerCase() === modelData ? 4 : 0; border.color: Kirigami.Theme.textColor
                            Kirigami.Icon { anchors.centerIn: parent; width: 22; height: 22; source: "checkmark"; isMask: true; color: "white"; visible: root.st.accent.toLowerCase() === modelData }
                            TapHandler { onTapped: { root.patch("accent", modelData); root.call("accent " + modelData) } } } } }
            }
            SettingsGroup { header: "Home screen icons"; footer: "The look of the app tiles on the home screen and in the dock."
                ChoiceRow { current: ""; choices: [ { label: "Light", value: "light" }, { label: "Dark", value: "dark" }, { label: "Glass", value: "glass" } ]
                    onPicked: (v) => { root.call("icons-style " + v) } }
            }
            SettingsGroup { header: "Wallpaper"
                SettingRow { title: "Next wallpaper"; subtitle: "The wallpaper also changes by itself every hour"; iconName: "preferences-desktop-wallpaper"; iconColor: "#9b51e0"; tappable: true; chevron: true
                    onClicked: root.call("wallpaper-next") }
                SettingRow { title: "Choose a wallpaper"; iconName: "folder-pictures"; iconColor: "#9b51e0"; tappable: true; chevron: true
                    onClicked: root.kcm("kcm_wallpaper") }
                SettingRow { title: "Fonts, window style and more"; iconName: "preferences-desktop-font"; iconColor: "#4f4f4f"; tappable: true; chevron: true; separator: false
                    onClicked: root.kcm("kcm_fonts") }
            }
        }
    }
    Component { id: pgHome
        ColumnLayout { spacing: 22
            SettingsGroup { header: "Dock"
                SliderRow { title: "Size"; valueText: root.dock.dockSize + " px"; value: (root.dock.dockSize - 40) / 56
                    onReleased: (v) => root.call("dock-set dockSize=" + Math.round(40 + v * 56), function() { root.refreshDock() }) }
                SliderRow { title: "Transparency"; valueText: (100 - root.dock.dockAlpha) + " %"; value: 1 - root.dock.dockAlpha / 100
                    onReleased: (v) => root.call("dock-set dockAlpha=" + Math.round(100 - v * 100), function() { root.refreshDock() }) }
                SettingRow { title: "Hide the dock automatically"; subtitle: "It slides in when you swipe up from the bottom edge"; separator: false
                    ToggleSwitch { checked: root.dock.dockHide === 1; onToggled: (v) => root.call("dock-set dockHide=" + (v ? 1 : 0), function() { root.refreshDock() }) } }
            }
            SettingsGroup { header: "Status bar"
                SliderRow { title: "Transparency"; valueText: (100 - root.dock.barAlpha) + " %"; value: 1 - root.dock.barAlpha / 100
                    onReleased: (v) => root.call("dock-set barAlpha=" + Math.round(100 - v * 100), function() { root.refreshDock() }) }
            }
            SettingsGroup { footer: "Apps on the home screen: touch and hold an app, then choose Edit."
                SettingRow { title: "Restore the original look"; iconName: "edit-undo"; iconColor: "#4f4f4f"; tappable: true; separator: false
                    onClicked: root.launch("$HOME/.local/bin/pipa-dock reset") }
            }
        }
    }
    Component { id: pgInput
        ColumnLayout { spacing: 22
            SettingsGroup { footer: "The on-screen keyboard appears when you tap a text field. Turn it off if you always use a physical keyboard."
                SettingRow { title: "On-screen keyboard"; iconName: "input-keyboard-virtual"; iconColor: "#828282"; separator: false
                    ToggleSwitch { checked: root.st.kbd === "on"; onToggled: (v) => { root.patch("kbd", v ? "on" : "off"); root.call("kbd " + (v ? "on" : "off")) } } }
            }
            SettingsGroup {
                SettingRow { title: "Keyboard layouts"; iconName: "input-keyboard"; iconColor: "#828282"; chevron: true; tappable: true; onClicked: root.kcm("kcm_keyboard") }
                SettingRow { title: "On-screen keyboard options"; iconName: "input-keyboard-virtual"; iconColor: "#828282"; chevron: true; tappable: true; onClicked: root.kcm("kcm_plasmakeyboard") }
                SettingRow { title: "Touch screen"; iconName: "input-touchscreen"; iconColor: "#828282"; chevron: true; tappable: true; onClicked: root.kcm("kcm_touchscreen") }
                SettingRow { title: "Mouse"; iconName: "input-mouse"; iconColor: "#828282"; chevron: true; tappable: true; separator: false; onClicked: root.kcm("kcm_mouse") }
            }
        }
    }
    Component { id: pgApps
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: "Software and updates"; subtitle: "Discover: install apps, update the system"; iconName: "plasmadiscover"; iconColor: "#2f80ed"; chevron: true; tappable: true
                    onClicked: root.launch("plasma-discover") }
                SettingRow { title: "Default apps"; subtitle: "Browser, mail, files, photos ..."; iconName: "preferences-desktop-default-applications"; iconColor: "#4f4f4f"; chevron: true; tappable: true
                    onClicked: root.kcm("kcm_componentchooser") }
                SettingRow { title: "Apps that start with the tablet"; iconName: "system-run"; iconColor: "#4f4f4f"; chevron: true; tappable: true
                    onClicked: root.kcm("kcm_autostart") }
                SettingRow { title: "App permissions"; iconName: "security-medium"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false
                    onClicked: root.kcm("kcm_app-permissions") }
            }
        }
    }
    Component { id: pgGeneral
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: "Language and region"; iconName: "preferences-desktop-locale"; iconColor: "#828282"; chevron: true; tappable: true; onClicked: root.kcm("kcm_regionandlang") }
                SettingRow { title: "Date and time"; iconName: "preferences-system-time"; iconColor: "#828282"; chevron: true; tappable: true; onClicked: root.kcm("kcm_clock") }
                SettingRow { title: "Users"; subtitle: "Name, picture and password"; iconName: "system-users"; iconColor: "#828282"; chevron: true; tappable: true; onClicked: root.kcm("kcm_users") }
                SettingRow { title: "Online accounts"; iconName: "preferences-online-accounts"; iconColor: "#828282"; chevron: true; tappable: true; separator: false; onClicked: root.kcm("kcm_kaccounts") }
            }
        }
    }
    Component { id: pgStorage
        ColumnLayout { spacing: 22
            SettingsGroup { header: "This tablet"
                SettingRow { title: (root.about.disk_used || "—") + " of " + (root.about.disk_total || "—") + " used"; subtitle: (root.about.disk_percent || 0) + " %"; iconName: "drive-harddisk"; iconColor: "#828282"; separator: false
                    Rectangle { width: 160; height: 14; radius: 7; color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                        Rectangle { width: Math.max(14, parent.width * (root.about.disk_percent || 0) / 100); height: 14; radius: 7; color: Kirigami.Theme.highlightColor } } }
            }
            SettingsGroup {
                SettingRow { title: "Disks and drives"; iconName: "drive-harddisk"; iconColor: "#4f4f4f"; chevron: true; tappable: true; onClicked: root.kcm("kcm_disks") }
                SettingRow { title: "Trash"; iconName: "user-trash"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false; onClicked: root.kcm("kcm_trash") }
            }
        }
    }
    Component { id: pgPrivacy
        ColumnLayout { spacing: 22
            SettingsGroup {
                SettingRow { title: "Screen lock"; subtitle: "When and how the tablet locks"; iconName: "system-lock-screen"; iconColor: "#27ae60"; chevron: true; tappable: true; onClicked: root.kcm("kcm_screenlocker") }
                SettingRow { title: "Login screen"; iconName: "system-log-out"; iconColor: "#27ae60"; chevron: true; tappable: true; onClicked: root.kcm("kcm_plasmalogin") }
                SettingRow { title: "Firewall"; iconName: "security-high"; iconColor: "#27ae60"; chevron: true; tappable: true; onClicked: root.kcm("kcm_firewall") }
                SettingRow { title: "Recent files"; iconName: "document-open-recent"; iconColor: "#27ae60"; chevron: true; tappable: true; separator: false; onClicked: root.kcm("kcm_recentFiles") }
            }
        }
    }
    Component { id: pgAbout
        ColumnLayout { spacing: 22
            ColumnLayout { Layout.fillWidth: true; Layout.topMargin: 6; spacing: 8
                Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 96; Layout.preferredHeight: 96; source: "dorothyos"; fallback: "start-here-kde" }
                QQC2.Label { Layout.alignment: Qt.AlignHCenter; text: (root.about.name || "DorothyOS") + (root.about.version ? " " + root.about.version : ""); font.pixelSize: 24; font.bold: true }
                QQC2.Label { Layout.alignment: Qt.AlignHCenter; text: root.about.device || ""; opacity: 0.65; font.pixelSize: 15 }
            }
            SettingsGroup {
                SettingRow { title: "Device"; subtitle: root.about.device || "—"; separator: true }
                SettingRow { title: "Operating system"; subtitle: root.about.pretty || "DorothyOS" }
                SettingRow { title: "Build date"; subtitle: root.about.build || "—"; visible: !!root.about.build }
                SettingRow { title: "KDE Plasma"; subtitle: root.about.plasma || "—" }
                SettingRow { title: "Kernel"; subtitle: root.about.kernel || "—" }
                SettingRow { title: "Memory"; subtitle: root.about.memory || "—" }
                SettingRow { title: "Storage"; subtitle: (root.about.disk_used || "—") + " of " + (root.about.disk_total || "—") }
                SettingRow { title: "Running for"; subtitle: root.about.uptime || "—"; separator: false }
            }
            SettingsGroup {
                SettingRow { title: "Website"; subtitle: (root.about.home_url || "").replace(/^https?:\/\//, ""); visible: !!root.about.home_url; iconName: "internet-web-browser"; iconColor: "#e85d00"; chevron: true; tappable: true; onClicked: Qt.openUrlExternally(root.about.home_url) }
                SettingRow { title: "More system details"; iconName: "kinfocenter"; iconColor: "#4f4f4f"; chevron: true; tappable: true; separator: false; onClicked: root.launch("kinfocenter") }
            }
            // credits are given, but quietly: one muted line, the full text one tap away
            QQC2.Label { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4; text: "Acknowledgements"; color: Kirigami.Theme.textColor; opacity: 0.45; font.pixelSize: 13; font.underline: true
                MouseArea { anchors.fill: parent; anchors.margins: -12; onClicked: root.call("credits") } }
        }
    }
}
