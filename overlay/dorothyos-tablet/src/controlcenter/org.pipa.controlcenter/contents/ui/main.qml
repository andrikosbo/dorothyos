// Pipa Control Center — touch-first quick settings for the Xiaomi Pad 6 (Plasma 6 panel widget, opens as a popup from the dock).
// Big tiles (Wi-Fi, Bluetooth, Night light, Rotation lock, Do not disturb, Next wallpaper), finger-sized brightness / volume sliders and
// four action buttons (Screenshot, Lock, Sleep, Settings). All the work is done by ~/.local/bin/pipa-cc (shell helper, easy to test by hand).
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    // the panel is a Plasma dialog that drops down at the top right (like the iPad); it opens from the dock button, from the
    // global shortcut (Meta+Shift+C, which is also what the swipe-down from the top edge triggers, see the KWin script pipa-top-edge)
    activationTogglesExpanded: false
    Plasmoid.onActivated: root.toggleCC()
    toolTipMainText: "Control center"
    toolTipSubText: "Wi-Fi, Bluetooth, brightness, volume"

    property var st: ({ wifi: "off", ssid: "", bt: "off", night: "off", rotlock: "off", dnd: "off", bright: 50, vol: 50, mute: "off" })
    property int seq: 0
    readonly property string cc: "$HOME/.local/bin/pipa-cc"

    function run(args) { exec.connectSource(cc + " " + args + " #" + (++seq)) }
    function refresh() { exec.connectSource(cc + " state #" + (++seq)) }
    function patch(key, value) {
        var c = {}
        for (var k in st) c[k] = st[k]
        c[key] = value
        st = c
    }
    function toggle(key) {
        var turnOn = st[key] !== "on"
        patch(key, turnOn ? "on" : "off")
        run(key + " " + (turnOn ? "on" : "off"))
        settle.restart()
    }
    function action(verb) { dlg.visible = false; run(verb) }
    function toggleCC() { dlg.visible = !dlg.visible }

    Timer { id: settle; interval: 1200; onTriggered: root.refresh() }
    property real pendBright: -1
    property real pendVol: -1
    Timer { id: brightTimer; interval: 90; onTriggered: root.run("bright " + Math.round(root.pendBright * 100)) }
    Timer { id: volTimer; interval: 90; onTriggered: root.run("volume " + Math.round(root.pendVol * 100)) }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.indexOf(" state #") < 0) return
            var lines = String(data["stdout"]).split("\n")
            var c = {}
            for (var k in root.st) c[k] = root.st[k]
            for (var i = 0; i < lines.length; i++) {
                var eq = lines[i].indexOf("=")
                if (eq < 1) continue
                var key = lines[i].substring(0, eq), val = lines[i].substring(eq + 1)
                c[key] = (key === "bright" || key === "vol") ? Number(val) : val
            }
            root.st = c
        }
    }

    // ---- building blocks ----------------------------------------------------------------------------------------------
    component CCTile: Rectangle {
        id: t
        property string icon
        property string title
        property string sub
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 100        // same preferred width -> equal columns
        Layout.preferredHeight: 104
        radius: 22
        color: active ? (tap.pressed ? "#2568D8" : "#2F7BFF") : (tap.pressed ? "#555B66" : "#3A3F47")
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Kirigami.Icon { source: t.icon; width: 32; height: 32; color: "white" }
            Text { width: parent.width; text: t.title; color: "white"; font.pixelSize: 17; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; text: t.sub; color: "#D9FFFFFF"; font.pixelSize: 13; elide: Text.ElideRight }
        }
        MouseArea { id: tap; anchors.fill: parent; onClicked: t.clicked() }
    }

    component BigSlider: Item {
        id: bs
        property real value: 0.5            // 0..1, as the system reports it
        property string icon
        signal moved(real v)
        readonly property real shown: area.pressed ? local : value
        property real local: value
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        Rectangle { anchors.fill: parent; radius: 32; color: "#3A3F47" }
        Rectangle {
            width: Math.max(parent.height, parent.width * bs.shown)
            height: parent.height
            radius: 32
            color: "#E9EEF7"
        }
        Kirigami.Icon { x: 20; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; source: bs.icon; color: "#2B3140" }
        MouseArea {
            id: area
            anchors.fill: parent
            function setFrom(x) {
                var v = Math.max(0, Math.min(1, x / width))
                bs.local = v
                bs.moved(v)
            }
            onPressed: (m) => setFrom(m.x)
            onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property string icon
        property string title
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 100
        Layout.preferredHeight: 76
        radius: 20
        color: abTap.pressed ? "#555B66" : "#3A3F47"
        Column {
            anchors.centerIn: parent
            spacing: 4
            Kirigami.Icon { anchors.horizontalCenter: parent.horizontalCenter; source: ab.icon; width: 28; height: 28; color: "white" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: ab.title; color: "white"; font.pixelSize: 13 }
        }
        MouseArea { id: abTap; anchors.fill: parent; onClicked: ab.clicked() }
    }

    // ---- dock button ------------------------------------------------------------------------------------------------------
    fullRepresentation: MouseArea {
        Layout.minimumWidth: 52
        Layout.preferredWidth: 52
        onClicked: root.toggleCC()
        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: 6
            source: "pipa-tile-pipa-controls"
            scale: parent.pressed ? 0.9 : 1.0
        }
    }

    // ---- the popup ----------------------------------------------------------------------------------------------------
    PlasmaCore.Dialog {
        id: dlg
        visible: false
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.Normal
        backgroundHints: PlasmaCore.Types.StandardBackground
        hideOnWindowDeactivate: true
        readonly property real scrW: Qt.application.screens.length > 0 ? Qt.application.screens[0].width : 1152
        x: scrW - width - 14
        y: 40          // just below the 32 px status bar (phase14); the bar is absent on older setups, 40 still looks fine
        onVisibleChanged: if (visible) root.refresh()

        mainItem: Item {
        id: panel
        implicitWidth: 470
        implicitHeight: content.implicitHeight + 32
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight

        ColumnLayout {
            id: content
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 12
                rowSpacing: 12
                CCTile { icon: root.st.wifi === "on" ? "network-wireless" : "network-wireless-disconnected"; title: "Wi-Fi"
                         sub: root.st.wifi === "on" ? (root.st.ssid !== "" ? root.st.ssid : "On") : "Off"; active: root.st.wifi === "on"; onClicked: root.toggle("wifi") }
                CCTile { icon: "network-bluetooth"; title: "Bluetooth"
                         sub: root.st.bt === "on" ? "On" : "Off"; active: root.st.bt === "on"; onClicked: root.toggle("bt") }
                CCTile { icon: "redshift-status-on"; title: "Night light"
                         sub: root.st.night === "on" ? "On" : "Off"; active: root.st.night === "on"; onClicked: root.toggle("night") }
                CCTile { icon: "object-rotate-right"; title: "Rotation lock"
                         sub: root.st.rotlock === "on" ? "Locked" : "Auto"; active: root.st.rotlock === "on"; onClicked: root.toggle("rotlock") }
                CCTile { icon: "notifications-disabled"; title: "Focus"
                         sub: root.st.dnd === "on" ? "Do not disturb" : "Off"; active: root.st.dnd === "on"; onClicked: root.toggle("dnd") }
                CCTile { icon: "preferences-desktop-wallpaper"; title: "Wallpaper"
                         sub: "Next picture"; onClicked: root.action("wallpaper") }
            }

            BigSlider {
                icon: "brightness-high"
                value: root.st.bright / 100
                onMoved: (v) => { root.patch("bright", Math.round(v * 100)); root.pendBright = v; if (!brightTimer.running) brightTimer.start() }
            }
            BigSlider {
                icon: root.st.mute === "on" ? "audio-volume-muted" : "audio-volume-high"
                value: root.st.mute === "on" ? 0 : root.st.vol / 100
                onMoved: (v) => { root.patch("vol", Math.round(v * 100)); root.patch("mute", "off"); root.pendVol = v; if (!volTimer.running) volTimer.start() }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ActionButton { icon: "spectacle"; title: "Screenshot"; onClicked: root.action("shot") }
                ActionButton { icon: "system-lock-screen"; title: "Lock"; onClicked: root.action("lock") }
                ActionButton { icon: "system-suspend"; title: "Sleep"; onClicked: root.action("sleep") }
                ActionButton { icon: "configure"; title: "Settings"; onClicked: root.action("settings") }
            }
        }
    }
    }
}
