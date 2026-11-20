// DorothyOS Start — the touch-first start menu of DorothyOS (replaces Kickoff in the dock).
// Everything Kickoff offers is here: pinned apps (long-press an app to pin / unpin it), recent apps, every app by category and
// alphabetically, search (apps, system settings, files, calculator ...), and the session buttons (lock, sleep, restart, shut down,
// log out).  Built on the same data models as Kickoff / Kicker (org.kde.plasma.private.kicker), so launching, "recent" tracking and
// the application menu stay exactly the ones of Plasma.  The search field is NOT focused automatically: the on-screen keyboard
// only appears when the user taps it (it would cover half of the menu otherwise).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: root
    toolTipMainText: "Start"
    toolTipSubText: "Apps, search and power"
    Plasmoid.icon: "dorothyos"
    preferredRepresentation: compactRepresentation

    // ---- data -------------------------------------------------------------------------------------------------------------
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: root
        flat: false
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: true
        showRecentApps: true
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
    }
    Kicker.SimpleFavoritesModel {
        id: favModel
        enabled: true
        maxFavorites: 48
        // loaded once (a live binding in both directions would loop); every change made by the user is written back
        Component.onCompleted: favorites = Plasmoid.configuration.favorites
        onFavoritesChanged: if (Plasmoid.configuration.favorites.join() !== favorites.join()) Plasmoid.configuration.favorites = favorites
    }
    Kicker.SystemModel { id: sysModel }
    Kicker.RunnerModel {
        id: runner
        appletInterface: root
        mergeResults: true
        runners: ["krunner_services", "krunner_systemsettings", "baloosearch", "krunner_recentdocuments", "krunner_bookmarks", "calculator", "unitconverter"]
    }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    property int seq: 0
    function run(cmd) { exec.connectSource(cmd + " #" + (++seq)) }

    Component.onCompleted: rootModel.refresh()
    onExpandedChanged: { if (root.expanded) { rootModel.refresh(); page = "pinned"; query = "" } }

    // ---- state -------------------------------------------------------------------------------------------------------------
    // page: "pinned" | "recent" | "all" | "cat:<row>"
    property string page: "pinned"
    property string query: ""
    readonly property bool searching: query.length > 0
    function closeMenu() { root.expanded = false }

    // ---- compact representation: the DorothyOS mark in the dock --------------------------------------------------------------
    compactRepresentation: Item {
        id: compact
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium
        Kirigami.Icon {
            anchors.fill: parent
            source: "dorothyos"
            fallback: "start-here-kde"
            active: tap.pressed
        }
        TapHandler { id: tap; onTapped: root.expanded = !root.expanded }
    }

    // ---- full representation: the menu ---------------------------------------------------------------------------------------
    fullRepresentation: Item {
        id: menu
        readonly property real maxW: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth - 24 : 960
        implicitWidth: Math.min(960, maxW)
        implicitHeight: 560
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        readonly property bool narrow: width < 800

        // one app tile (used by every page); inline components cannot see the ids of this file, so they talk through signals
        component Tile: Item {
            id: tile
            property string tName: ""
            property var tIcon: ""
            property real cellW: 132
            property real cellH: 116
            signal activated()
            signal menuRequested()
            width: cellW; height: cellH
            Rectangle {
                anchors.fill: parent; anchors.margins: 4; radius: 16
                color: tap.pressed ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.22) : "transparent"
            }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 6
                Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 64; Layout.preferredHeight: 64; source: tile.tIcon; fallback: "application-x-executable" }
                QQC2.Label {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    text: tile.tName; font.pixelSize: 13; color: Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignTop
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                }
            }
            TapHandler { id: tap; gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: tile.activated()
                onLongPressed: tile.menuRequested() }
        }
        // cell width that fills the row exactly (at least 3 columns)
        // round / pill icon button (QQC2 buttons draw no icon in every style, these always do)
        component IconButton: Rectangle {
            id: ib
            property string iconName: ""
            property string label: ""
            property int iconSize: 26
            signal clicked()
            implicitHeight: 48
            implicitWidth: label.length > 0 ? 24 + iconSize + 10 + lbl.implicitWidth + 24 : 48
            radius: height / 2
            color: ibTap.pressed ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.30) : Kirigami.Theme.alternateBackgroundColor
            RowLayout {
                anchors.centerIn: parent; spacing: 10
                Kirigami.Icon { source: ib.iconName; Layout.preferredWidth: ib.iconSize; Layout.preferredHeight: ib.iconSize }
                QQC2.Label { id: lbl; text: ib.label; visible: ib.label.length > 0; font.pixelSize: 15 }
            }
            TapHandler { id: ibTap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: ib.clicked() }
        }
        function cellFor(w) { return Math.floor(w / Math.max(3, Math.floor(w / 132))) }
                function openMenu(favId, theModel, theIndex) { if (favId === "") return; ctx.fid = favId; ctx.tm = theModel; ctx.ti = theIndex; ctx.popup() }
        QQC2.Menu {
            id: ctx
            property string fid: ""
            property var tm: null
            property int ti: -1
            QQC2.MenuItem { text: "Open"; icon.name: "media-playback-start"; onTriggered: { if (ctx.tm) ctx.tm.trigger(ctx.ti, "", null); root.closeMenu() } }
            QQC2.MenuItem {
                text: favModel.isFavorite(ctx.fid) ? "Unpin from Start" : "Pin to Start"
                icon.name: favModel.isFavorite(ctx.fid) ? "window-unpin" : "pin"
                onTriggered: { if (favModel.isFavorite(ctx.fid)) favModel.removeFavorite(ctx.fid); else favModel.addFavorite(ctx.fid) }
            }
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 14; spacing: 12

            // ---- top bar: search + settings
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 26
                    color: Kirigami.Theme.alternateBackgroundColor
                    border.width: search.activeFocus ? 2 : 0; border.color: Kirigami.Theme.highlightColor
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 8; spacing: 10
                        Kirigami.Icon { source: "search"; Layout.preferredWidth: 24; Layout.preferredHeight: 24; opacity: 0.7 }
                        QQC2.TextField {
                            id: search
                            Layout.fillWidth: true
                            placeholderText: "Search apps, settings and files"
                            font.pixelSize: 17
                            background: null
                            inputMethodHints: Qt.ImhNoPredictiveText
                            text: root.query
                            onTextEdited: queryTimer.restart()
                            Keys.onEscapePressed: { if (text.length) { root.query = ""; runner.query = "" } else root.closeMenu() }
                        }
                        Kirigami.Icon {
                            visible: root.searching; source: "edit-clear"; Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            TapHandler { onTapped: { root.query = ""; runner.query = ""; search.focus = false } }
                        }
                    }
                }
            }
            Timer { id: queryTimer; interval: 180; onTriggered: { root.query = search.text; runner.query = search.text } }

            // ---- body
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12

                // left rail: pages and categories
                Flickable {
                    id: rail
                    visible: !root.searching
                    Layout.preferredWidth: menu.narrow ? 150 : 200
                    Layout.fillHeight: true
                    contentHeight: railCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: railCol; width: rail.width; spacing: 4
                        component RailItem: Rectangle {
                            id: ri
                            property string label: ""
                            property string iconName: ""
                            property bool current: false
                            signal selected()
                            Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 14
                            color: current ? Kirigami.Theme.highlightColor : (rtap.pressed ? Kirigami.Theme.alternateBackgroundColor : "transparent")
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 10
                                Kirigami.Icon { source: ri.iconName; Layout.preferredWidth: 22; Layout.preferredHeight: 22; color: ri.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor }
                                QQC2.Label { Layout.fillWidth: true; text: ri.label; elide: Text.ElideRight; font.pixelSize: 15
                                    color: ri.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor }
                            }
                            TapHandler { id: rtap; onTapped: ri.selected() }
                        }
                        RailItem { label: "Pinned"; iconName: "pin"; current: root.page === "pinned"; onSelected: root.page = "pinned" }
                        RailItem { label: "Recent"; iconName: "view-history"; current: root.page === "recent"; onSelected: root.page = "recent" }
                        RailItem { label: "All apps"; iconName: "applications-all-symbolic"; current: root.page === "all"; onSelected: root.page = "all" }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: 6; Layout.bottomMargin: 6; color: Kirigami.Theme.textColor; opacity: 0.15 }
                        Repeater {
                            model: rootModel
                            delegate: RailItem {
                                visible: index >= 2 && model.isParent === true
                                Layout.preferredHeight: visible ? 46 : 0
                                label: model.display
                                iconName: model.decoration
                                current: root.page === "cat:" + index
                                onSelected: root.page = "cat:" + index
                            }
                        }
                    }
                }

                // right: content
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    // ---- search results
                    ListView {
                        id: results
                        anchors.fill: parent; visible: root.searching; clip: true
                        model: root.searching && runner.count > 0 ? runner.modelForRow(0) : null
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 4
                        delegate: Rectangle {
                            width: results.width; height: 62; radius: 14
                            color: rtp.pressed ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.22) : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 14
                                Kirigami.Icon { source: model.decoration; Layout.preferredWidth: 40; Layout.preferredHeight: 40; fallback: "application-x-executable" }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    QQC2.Label { Layout.fillWidth: true; text: model.display; font.pixelSize: 16; elide: Text.ElideRight }
                                    QQC2.Label { Layout.fillWidth: true; text: model.description; font.pixelSize: 12; opacity: 0.65; elide: Text.ElideRight; visible: text.length > 0 }
                                }
                                QQC2.Label { text: model.group; font.pixelSize: 12; opacity: 0.55; visible: !menu.narrow }
                            }
                            TapHandler { id: rtp; onTapped: { results.model.trigger(index, "", null); root.closeMenu() } }
                        }
                        QQC2.Label {
                            anchors.centerIn: parent; visible: results.count === 0
                            text: runner.querying ? "Searching…" : "No results for “" + root.query + "”"; opacity: 0.6; font.pixelSize: 16
                        }
                    }

                    // ---- pinned
                    Flickable {
                        id: pinnedView
                        anchors.fill: parent; visible: !root.searching && root.page === "pinned"
                        contentHeight: pinnedFlow.height + 8; clip: true; boundsBehavior: Flickable.StopAtBounds
                        Flow {
                            id: pinnedFlow; width: pinnedView.width
                            Repeater { model: favModel
                                delegate: Tile { cellW: menu.cellFor(pinnedView.width); tName: model.display; tIcon: model.decoration
                                    onActivated: { favModel.trigger(index, "", null); root.closeMenu() }
                                    onMenuRequested: menu.openMenu(model.favoriteId, favModel, index) } }
                        }
                        QQC2.Label {
                            anchors.centerIn: parent; visible: favModel.count === 0; opacity: 0.6; font.pixelSize: 16
                            text: "Nothing pinned yet — touch and hold an app, then choose “Pin to Start”."
                        }
                    }

                    // ---- recent
                    Flickable {
                        id: recentView
                        anchors.fill: parent; visible: !root.searching && root.page === "recent"
                        contentHeight: recentFlow.height + 8; clip: true; boundsBehavior: Flickable.StopAtBounds
                        readonly property var recent: rootModel.count > 0 ? rootModel.modelForRow(0) : null
                        Flow {
                            id: recentFlow; width: recentView.width
                            Repeater { model: rootModel.count > 0 ? recentView.recent : null
                                delegate: Tile { cellW: menu.cellFor(recentView.width); tName: model.display; tIcon: model.decoration
                                    onActivated: { recentView.recent.trigger(index, "", null); root.closeMenu() }
                                    onMenuRequested: menu.openMenu(model.favoriteId, recentView.recent, index) } }
                        }
                        QQC2.Label {
                            anchors.centerIn: parent; visible: recentView.recent !== null && recentView.recent.count === 0; opacity: 0.6; font.pixelSize: 16
                            text: "Apps you open will show up here."
                        }
                    }

                    // ---- all apps, A-Z
                    Flickable {
                        id: allView
                        anchors.fill: parent; visible: !root.searching && root.page === "all"
                        contentHeight: allCol.height + 8; clip: true; boundsBehavior: Flickable.StopAtBounds
                        readonly property var letters: rootModel.count > 1 ? rootModel.modelForRow(1) : null
                        Column {
                            id: allCol; width: allView.width; spacing: 4
                            Repeater {
                                model: allView.letters
                                delegate: Column {
                                    id: letterBlock
                                    width: allCol.width
                                    readonly property var apps: allView.letters.modelForRow(index)
                                    QQC2.Label { text: model.display; font.pixelSize: 15; font.bold: true; color: Kirigami.Theme.highlightColor; leftPadding: 10; padding: 6 }
                                    Flow {
                                        width: parent.width
                                        Repeater { model: letterBlock.apps
                                            delegate: Tile { cellW: menu.cellFor(allView.width); tName: model.display; tIcon: model.decoration
                                                onActivated: { letterBlock.apps.trigger(index, "", null); root.closeMenu() }
                                                onMenuRequested: menu.openMenu(model.favoriteId, letterBlock.apps, index) } }
                                    }
                                }
                            }
                        }
                    }

                    // ---- one category
                    Flickable {
                        id: catView
                        anchors.fill: parent; visible: !root.searching && root.page.indexOf("cat:") === 0
                        contentHeight: catFlow.height + 8; clip: true; boundsBehavior: Flickable.StopAtBounds
                        readonly property var catModel: root.page.indexOf("cat:") === 0 && rootModel.count > 0 ? rootModel.modelForRow(parseInt(root.page.substring(4))) : null
                        Flow {
                            id: catFlow; width: catView.width
                            Repeater { model: catView.catModel
                                delegate: Tile { cellW: menu.cellFor(catView.width); tName: model.display; tIcon: model.decoration
                                    onActivated: { catView.catModel.trigger(index, "", null); root.closeMenu() }
                                    onMenuRequested: menu.openMenu(model.favoriteId, catView.catModel, index) } }
                        }
                    }
                }
            }

            // ---- bottom bar: session buttons
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                QQC2.Label { text: "DorothyOS"; font.pixelSize: 13; opacity: 0.55; Layout.leftMargin: 6 }
                Item { Layout.fillWidth: true }
                IconButton {
                    iconName: "preferences-system"; label: menu.narrow ? "" : "Settings"
                    onClicked: { root.run("dorothyos-settings || systemsettings"); root.closeMenu() }
                }
                Item { Layout.preferredWidth: 12 }
                Repeater {
                    model: sysModel
                    delegate: IconButton {
                        // lock, sleep, restart, shut down, log out (switch user is of no use on a tablet)
                        visible: ["lock-screen", "suspend", "reboot", "shutdown", "logout"].indexOf(model.favoriteId) >= 0
                        Layout.preferredWidth: visible ? 48 : 0
                        iconName: model.decoration
                        onClicked: { sysModel.trigger(index, "", null); root.closeMenu() }
                    }
                }
            }
        }
    }
}
