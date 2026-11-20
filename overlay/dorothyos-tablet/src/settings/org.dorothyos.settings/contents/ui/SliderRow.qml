// A finger-sized slider with an icon. value is 0..1; moved() while dragging, released() when the finger lifts.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: s
    property string title: ""
    property string iconName: ""
    property string valueText: ""
    property real value: 0.5
    property real local: value
    readonly property real shown: area.pressed ? local : value
    signal moved(real v)
    signal released(real v)
    Layout.fillWidth: true
    implicitHeight: s.title.length > 0 ? 92 : 70
    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 4
        RowLayout {
            visible: s.title.length > 0; Layout.fillWidth: true
            QQC2.Label { text: s.title; font.pixelSize: 17; Layout.fillWidth: true }
            QQC2.Label { text: s.valueText; font.pixelSize: 15; opacity: 0.65 }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
            Kirigami.Icon { visible: s.iconName.length > 0; source: s.iconName; Layout.preferredWidth: 26; Layout.preferredHeight: 26; opacity: 0.8 }
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 10; radius: 5
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(10, parent.width * s.shown); height: 10; radius: 5; color: Kirigami.Theme.highlightColor }
                Rectangle { width: 32; height: 32; radius: 16; color: "white"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25)
                    anchors.verticalCenter: parent.verticalCenter; x: (parent.width - width) * s.shown }
                MouseArea {
                    id: area; anchors.fill: parent
                    function setFrom(x) { var v = Math.max(0, Math.min(1, (x - 16) / (width - 32))); s.local = v; s.moved(v) }
                    onPressed: (m) => setFrom(m.x)
                    onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
                    onReleased: s.released(s.local)
                }
            }
        }
    }
}
