// Segmented choice: pills side by side. choices = [{label, value}], current = value of the selected one.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: c
    property string title: ""
    property var choices: []
    property var current
    signal picked(var value)
    Layout.fillWidth: true
    implicitHeight: (title.length > 0 ? 34 : 0) + 64
    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 10; anchors.bottomMargin: 10; spacing: 8
        QQC2.Label { visible: c.title.length > 0; text: c.title; font.pixelSize: 17 }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 22
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
            RowLayout {
                anchors.fill: parent; anchors.margins: 3; spacing: 3
                Repeater {
                    model: c.choices
                    delegate: Rectangle {
                        readonly property bool sel: c.current === modelData.value
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 19
                        color: sel ? Kirigami.Theme.highlightColor : "transparent"
                        QQC2.Label { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 15
                            color: parent.sel ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor }
                        TapHandler { onTapped: c.picked(modelData.value) }
                    }
                }
            }
        }
    }
}
