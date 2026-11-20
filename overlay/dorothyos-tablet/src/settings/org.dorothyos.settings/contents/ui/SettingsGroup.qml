// A titled group of rows on a rounded card (iPad Settings look). Rows are added as children.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: g
    default property alias rows: col.data
    property string header: ""
    property string footer: ""
    Layout.fillWidth: true
    spacing: 8
    QQC2.Label {
        visible: g.header.length > 0
        text: g.header.toUpperCase(); font.pixelSize: 12; font.letterSpacing: 0.6; opacity: 0.6
        Layout.leftMargin: 16
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight
        radius: 18
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
        clip: true
        ColumnLayout { id: col; width: parent.width; spacing: 0 }
    }
    QQC2.Label {
        visible: g.footer.length > 0
        text: g.footer; font.pixelSize: 12; opacity: 0.6; wrapMode: Text.Wrap
        Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
    }
}
