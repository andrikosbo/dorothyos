// Pipa Home Grid v3 — iPad-style home screen for the Xiaomi Pad 6 (Plasma 6 desktop widget, fills the whole desktop).
// Clock + date top left, a "Search" pill at the top centre, pages of app icons (squircle tiles) with page dots, nothing dark drawn over the wallpaper.
//   long press an icon / the background  -> edit mode: icons wiggle, drag an icon to reorder it (drag to a screen edge to change page),
//                                           drag an icon onto another one and wait = new folder (drop onto a folder = add to it),
//                                           red "-" removes one (a folder: dissolves it), the "Add apps" tile opens the picker
//   tap a folder                          -> panel with its apps; long press there: rename suggestions and red "-" (takes an app out of the folder)
//   sliders button (top right)           -> "Home screen" sheet: tab Icons (style Light / Dark / Glass / Auto, icon size, labels, search pill)
//                                           and tab Dock & bar (dock apps, dock / status bar opacity, roundness, size, hide in apps)
//   "+" button (top right)                -> picker with every installed app that is not on the home screen yet
// Settings are the config keys ids / iconStyle / iconScale / labels / showSearch (contents/config/main.xml).
// "ids" = desktop-file ids separated by ";"; a folder is written "@Name|id1,id2,..." (name without ; | , @).
// The catalog of installed apps comes from ~/.local/bin/pipa-home-apps (JSON), launching is `kioclient exec <desktop file>`,
// the dock follows the icon style through ~/.local/bin/pipa-icons (copies the matching tile set into the hicolor theme).
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ---- settings -----------------------------------------------------------------------------------------------------
    readonly property string idsStr: Plasmoid.configuration.ids
    readonly property string iconStyle: ["light", "dark", "glass"].indexOf(Plasmoid.configuration.iconStyle) >= 0 ? Plasmoid.configuration.iconStyle : "light"
    readonly property real iconScale: Math.max(0.6, Math.min(1.5, Plasmoid.configuration.iconScale))
    readonly property bool showLabels: Plasmoid.configuration.labels
    readonly property bool showSearch: Plasmoid.configuration.showSearch
    readonly property bool iconAuto: Plasmoid.configuration.iconAuto
    readonly property string tileDir: Qt.resolvedUrl("../tiles/") + iconStyle + "/512/"

    // ---- data ---------------------------------------------------------------------------------------------------------
    property var catalog: ({})
    property var allApps: []
    property int catalogRev: 0
    property int modelRev: 0
    property int seq: 0
    ListModel { id: lm }        // the home screen, sorted by screen. roles: appId, title, iconName, desk (desktop file path), kind ("app"/"folder"), members ("id1,id2" of a folder), page (0-based screen)
    property int openFolder: -1         // index in lm of the folder whose panel is open
    property bool folderEditing: false

    // ---- screens (pages) -----------------------------------------------------------------------------------------------------------------
    // pageCount real screens (empty ones are allowed and kept); pageStart[p] = index in lm of the first item of screen p, pageStart[pageCount] = lm.count.
    // Saved form: screens separated by "~" ("a;b~c;d~" = 3 screens, the last one empty). An old flat list (no "~") is cut into full screens once.
    property int pageCount: 1
    property var pageStart: [0, 0]
    property int perPage: 0             // icons per screen as the grid shows them right now (0 = grid not laid out yet)
    property int perPageStable: 0       // the same once the size has stopped changing: this one is used to re-flow screens
    readonly property bool lastNonEmpty: pageCount > 0 && pageStart.length > pageCount && pageStart[pageCount] - pageStart[pageCount - 1] > 0
    function pageLen(p) { return (p >= 0 && p < pageCount && pageStart.length > p + 1) ? pageStart[p + 1] - pageStart[p] : 0 }
    function pageOf(i) { for (var p = pageCount - 1; p > 0; p--) if (i >= pageStart[p]) return p; return 0 }
    function reindex() {
        var ps = [], i = 0
        for (var p = 0; p < pageCount; p++) { ps.push(i); while (i < lm.count && lm.get(i).page === p) i++ }
        ps.push(i)
        pageStart = ps
    }
    function ensurePage(p) { if (p >= pageCount) { pageCount = p + 1; reindex() } }

    function appItem(id, page) { var a = catalog[id]; return { appId: a.id, title: a.name, iconName: a.icon, desk: a.path, kind: "app", members: "", page: page || 0 } }
    function folderItem(name, members, page) { return { appId: "folder", title: name, iconName: "", desk: "", kind: "folder", members: members, page: page || 0 } }
    function tokenOfItem(m) { return m.kind === "folder" ? "@" + m.title + "|" + m.members : m.appId }
    function layoutString(toks, pgs, n) {
        var out = [], cur = [], p = 0
        for (var i = 0; i < toks.length; i++) {
            while (p < pgs[i]) { out.push(cur.join(";")); cur = []; p++ }
            cur.push(toks[i])
        }
        out.push(cur.join(";")); p++
        while (p < n) { out.push(""); p++ }
        return out.join("~")
    }
    function modelIds() {
        var t = [], g = []
        for (var i = 0; i < lm.count; i++) { var m = lm.get(i); t.push(tokenOfItem(m)); g.push(m.page) }
        return layoutString(t, g, pageCount)
    }
    function cleanName(n) { var c = String(n).replace(/[;|,@~]/g, "").trim(); return c.length > 0 ? c.substring(0, 24) : "Folder" }
    function homeApps() {            // every app on the home screen, folders included
        var r = []
        for (var i = 0; i < lm.count; i++) { var m = lm.get(i); if (m.kind === "folder") r = r.concat(m.members.split(",")); else r.push(m.appId) }
        return r
    }
    function parseLayout(str) {      // config string -> { items (with their screen), n = number of screens } (unknown apps dropped, folders with fewer than 2 apps dissolved)
        var raw = str.split("~"), items = [], n = raw.length
        for (var p = 0; p < raw.length; p++) {
            var l = raw[p].split(";")
            for (var i = 0; i < l.length; i++) {
                var t = l[i]
                if (t.length === 0) continue
                if (t.charAt(0) === "@") {
                    var bar = t.indexOf("|")
                    if (bar < 0) continue
                    var mem = t.substring(bar + 1).split(",").filter(function (id) { return catalog[id] })
                    if (mem.length >= 2) items.push(folderItem(cleanName(t.substring(1, bar)), mem.join(","), p))
                    else for (var k = 0; k < mem.length; k++) items.push(appItem(mem[k], p))
                } else if (catalog[t]) items.push(appItem(t, p))
            }
        }
        if (n === 1 && perPageStable > 0 && items.length > perPageStable) {      // an old flat list: one full screen after the other
            n = Math.ceil(items.length / perPageStable)
            for (var j = 0; j < items.length; j++) items[j].page = Math.floor(j / perPageStable)
        }
        return { items: items, n: n }
    }
    function rebuild() {
        if (catalogRev === 0 || perPageStable <= 0) return
        var L = parseLayout(idsStr)
        var want = layoutString(L.items.map(tokenOfItem), L.items.map(function (m) { return m.page }), L.n)
        if (want === modelIds()) return                                      // nothing to change (e.g. the catalog was only refreshed)
        var migrated = L.n > 1 && idsStr.indexOf("~") < 0
        lm.clear()
        for (var j = 0; j < L.items.length; j++) lm.append(L.items[j])
        pageCount = Math.max(1, L.n)
        reindex()
        openFolder = -1
        if (fit() || migrated) saveIds(); else modelRev++
    }
    // no screen may hold more icons than the grid shows: the extra ones move to the start of the next screen
    function fit() {
        if (perPageStable <= 0) return false
        var changed = false
        reindex()
        for (var p = 0; p < pageCount; p++) {
            while (pageStart[p + 1] - pageStart[p] > perPageStable) {
                if (p === pageCount - 1) pageCount++
                lm.setProperty(pageStart[p + 1] - 1, "page", p + 1)
                reindex(); changed = true
            }
        }
        return changed
    }
    function saveIds() { fit(); reindex(); var s = modelIds(); if (s !== Plasmoid.configuration.ids) Plasmoid.configuration.ids = s; modelRev++ }
    function addApp(id, p) {         // onto screen p (the next one with room when it is full; a new screen when p is the blank one)
        if (!catalog[id] || homeApps().indexOf(id) >= 0) return
        if (p === undefined || p === null || p < 0) p = pageCount - 1
        ensurePage(p)
        var cap = perPage > 0 ? perPage : 1000
        while (pageLen(p) >= cap) { p++; ensurePage(p) }
        lm.insert(pageStart[p + 1], appItem(id, p))
        saveIds()
    }
    function removeAt(i) {           // an app leaves the home screen; a folder is dissolved (its apps stay, in its place)
        var m = lm.get(i)
        if (m.kind === "folder") {
            var mem = m.members.split(","), pg = m.page
            lm.remove(i)
            for (var k = 0; k < mem.length; k++) lm.insert(i + k, appItem(mem[k], pg))
            if (openFolder >= 0) openFolder = -1
        } else lm.remove(i)
        saveIds()
    }
    function canMerge(a, b) { return a >= 0 && b >= 0 && a !== b && a < lm.count && b < lm.count && lm.get(a).kind === "app" }
    function mergeInto(a, b) {       // app a was dropped on item b: new folder, or added to the folder b
        if (!canMerge(a, b)) { saveIds(); return }
        var id = lm.get(a).appId, B = lm.get(b)
        if (B.kind === "folder") lm.setProperty(b, "members", B.members + "," + id)
        else lm.set(b, folderItem("Folder", B.appId + "," + id, B.page))
        lm.remove(a)
        saveIds()
    }
    function renameFolder(i, name) { if (i >= 0 && i < lm.count && lm.get(i).kind === "folder") { lm.setProperty(i, "title", cleanName(name)); saveIds() } }
    function folderTakeOut(i, id) {  // returns true when the folder was dissolved (one app or none left)
        var rest = lm.get(i).members.split(",").filter(function (x) { return x !== id })
        if (rest.length === lm.get(i).members.split(",").length) return false          // not a member
        var pg = lm.get(i).page
        lm.insert(i + 1, appItem(id, pg))
        var gone = rest.length < 2
        if (gone) { if (rest.length === 1) lm.set(i, appItem(rest[0], pg)); else lm.remove(i) }
        else lm.setProperty(i, "members", rest.join(","))
        saveIds()
        return gone
    }
    function folderAdd(fi, id) {     // app id goes into folder fi (an app that sits on the home screen moves in); returns the folder's index (it can shift)
        if (fi < 0 || fi >= lm.count || lm.get(fi).kind !== "folder" || !catalog[id]) return fi
        var mem = lm.get(fi).members.split(",")
        if (mem.indexOf(id) >= 0) return fi
        for (var j = 0; j < lm.count; j++) {
            if (j !== fi && lm.get(j).kind === "app" && lm.get(j).appId === id) { lm.remove(j); if (j < fi) fi--; break }
        }
        lm.setProperty(fi, "members", mem.concat([id]).join(","))
        saveIds()
        return fi
    }
    // item `from` goes to screen p, position q (q past the end = last); returns its new index. A full screen refuses icons from other screens.
    function moveTo(from, p, q) {
        var it = lm.get(from), srcPage = it.page
        ensurePage(p)
        var start = pageStart[p], end = pageStart[p + 1], same = srcPage === p
        var others = end - start - (same ? 1 : 0)
        var cap = perPage > 0 ? perPage : 1000
        if (!same && others >= cap) return from
        q = Math.max(0, Math.min(q, others))
        var to = (from < start ? start - 1 : start) + q
        if (to !== from) lm.move(from, to, 1)
        if (!same) lm.setProperty(to, "page", p)
        reindex()
        return to
    }
    function newPage(after) {        // an empty screen right after screen `after` (counting from 0); returns its number
        after = Math.max(-1, Math.min(after, pageCount - 1))
        for (var i = 0; i < lm.count; i++) { var pg = lm.get(i).page; if (pg > after) lm.setProperty(i, "page", pg + 1) }
        pageCount++
        reindex(); saveIds()
        return after + 1
    }
    function deletePage(p) {         // only an empty screen can go
        if (pageCount <= 1 || p < 0 || p >= pageCount || pageLen(p) > 0) return false
        for (var i = 0; i < lm.count; i++) { var pg = lm.get(i).page; if (pg > p) lm.setProperty(i, "page", pg - 1) }
        pageCount--
        reindex(); saveIds()
        return true
    }
    function trimPages(keep) {       // empty screens at the end that a drag made up and did not use
        while (pageCount > Math.max(1, keep) && pageLen(pageCount - 1) === 0) pageCount--
        reindex()
    }
    onIdsStrChanged: if (idsStr !== modelIds()) rebuild()
    onCatalogRevChanged: rebuild()
    onPerPageChanged: ppTimer.restart()
    Timer { id: ppTimer; interval: 700; onTriggered: root.perPageStable = root.perPage }
    onPerPageStableChanged: { if (catalogRev > 0) { if (lm.count === 0) rebuild(); else if (fit()) saveIds() } }
    readonly property var folderCandidates: {      // for "Add apps" inside a folder: everything that is not in a folder yet
        catalogRev; modelRev
        var inF = {}
        for (var i = 0; i < lm.count; i++) { var m = lm.get(i); if (m.kind === "folder") m.members.split(",").forEach(function (id) { inF[id] = true }) }
        return allApps.filter(function (a) { return !inF[a.id] })
    }
    readonly property var candidates: {
        catalogRev; modelRev
        var have = homeApps()
        return allApps.filter(function (a) { return have.indexOf(a.id) < 0 })
    }

    function quote(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }
    function launch(path) { runner.connectSource("kioclient exec " + quote(path) + " #" + (++seq)) }
    function openSearch() { runner.connectSource("qdbus6 org.kde.krunner /App org.kde.krunner.App.display #" + (++seq)) }
    function setStyle(s) { Plasmoid.configuration.iconStyle = s; runner.connectSource("$HOME/.local/bin/pipa-icons set " + s + " #" + (++seq)) }
    // "Auto": light by day, dark from 20:00 to 07:00 (checked once a minute while it is on)
    function applyAuto(force) {
        if (!force && !iconAuto) return
        var h = new Date().getHours(), want = (h >= 20 || h < 7) ? "dark" : "light"
        if (want !== iconStyle) setStyle(want)
    }
    function pickStyle(k) {
        if (k === "auto") { Plasmoid.configuration.iconAuto = true; applyAuto(true) }
        else { Plasmoid.configuration.iconAuto = false; setStyle(k) }
    }
    Timer { interval: 60000; running: root.iconAuto; repeat: true; triggeredOnStart: true; onTriggered: root.applyAuto(false) }
    function refresh() { lister.connectSource("$HOME/.local/bin/pipa-home-apps #" + (++seq)) }
    Component.onCompleted: { refresh(); refreshDock() }

    // ---- dock + status bar: the look is applied by ~/.local/bin/pipa-dock (Plasma theme + panel scripting), its apps are the Task Manager launchers ----
    property var dockApps: []        // [{ token, id, name, icon }]
    readonly property var dockCandidates: {
        catalogRev; dockApps
        var have = {}
        dockApps.forEach(function (d) { have[d.id] = true })
        return allApps.filter(function (a) { return !have[a.id] })
    }
    function refreshDock() { dockLister.connectSource("$HOME/.local/bin/pipa-dock launchers #" + (++seq)) }
    function dockAdd(id) { dockLister.connectSource("$HOME/.local/bin/pipa-dock add " + quote(id) + " #" + (++seq)) }
    function dockRemove(d) { dockLister.connectSource("$HOME/.local/bin/pipa-dock remove " + quote(d.id !== "" ? d.id : d.token) + " #" + (++seq)) }
    function applyDock() {
        var c = Plasmoid.configuration
        runner.connectSource("$HOME/.local/bin/pipa-dock apply dockAlpha=" + c.dockAlpha + " dockRadius=" + c.dockRadius + " dockSize=" + c.dockSize +
                             " barAlpha=" + c.barAlpha + " dockHide=" + (c.dockHide ? 1 : 0) + " #" + (++seq))
    }
    function resetDock() {
        var c = Plasmoid.configuration
        c.dockAlpha = 85; c.dockRadius = 18; c.dockSize = 56; c.barAlpha = 55; c.dockHide = false
        runner.connectSource("$HOME/.local/bin/pipa-dock reset #" + (++seq))
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }
    P5Support.DataSource {
        id: dockLister
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            try { root.dockApps = JSON.parse(data["stdout"]) } catch (e) { console.log("homegrid: cannot read the dock apps:", e, data["stderr"]) }
        }
    }
    P5Support.DataSource {
        id: lister
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            try {
                var arr = JSON.parse(data["stdout"])
                var cat = {}
                for (var i = 0; i < arr.length; i++) cat[arr[i].id] = arr[i]
                root.catalog = cat
                root.allApps = arr
                root.catalogRev++
            } catch (e) {
                console.log("homegrid: cannot read the app list:", e, data["stderr"])
            }
        }
    }

    // ---- icon: squircle tiles (pipa-tile-*, one PNG set per style) are drawn as they are; every other icon sits on a plate in the same style ----
    component AppIcon: Item {
        id: ai
        property string iconName
        property string tileDir
        property string styleName: "light"
        readonly property bool isTile: iconName.indexOf("pipa-tile-") === 0
        readonly property real plate: width * 0.86            // the PNG tiles keep 7 % of margin on every side for the shadow
        Image {
            visible: ai.isTile
            anchors.fill: parent
            source: ai.isTile ? ai.tileDir + "pipa-tile-" + ai.iconName.replace(/^pipa-tile-(dark-|glass-)?/, "") + ".png" : ""
            sourceSize: Qt.size(Math.ceil(ai.width * 2), Math.ceil(ai.height * 2))
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
        }
        Rectangle {
            visible: !ai.isTile
            anchors.centerIn: parent
            width: ai.plate
            height: ai.plate
            radius: width * 0.225
            border.width: 1
            border.color: ai.styleName === "glass" ? "#A6FFFFFF" : (ai.styleName === "dark" ? "#2EFFFFFF" : "#22000000")
            gradient: Gradient {
                GradientStop { position: 0.0; color: ai.styleName === "dark" ? "#3C3D44" : (ai.styleName === "glass" ? "#8FFFFFFF" : "#FFFFFF") }
                GradientStop { position: 1.0; color: ai.styleName === "dark" ? "#17181C" : (ai.styleName === "glass" ? "#47FFFFFF" : "#E3E6EB") }
            }
        }
        Kirigami.Icon {
            visible: !ai.isTile
            anchors.centerIn: parent
            width: ai.plate * 0.66
            height: width
            source: ai.iconName.charAt(0) === "/" ? "file://" + ai.iconName : ai.iconName
        }
    }

    // folder: frosted plate with up to 9 mini icons (3 x 3), like iPadOS
    component FolderIcon: Item {
        id: fi
        property string members
        property var catalog: ({})
        property string tileDir
        property string styleName: "light"
        readonly property real plate: width * 0.86
        readonly property var list: members.length > 0 ? members.split(",").slice(0, 9) : []
        Rectangle {
            anchors.centerIn: parent
            width: fi.plate
            height: fi.plate
            radius: width * 0.225
            color: fi.styleName === "dark" ? "#D92B2D34" : (fi.styleName === "glass" ? "#66FFFFFF" : "#DDEEF1F6")
            border.width: 1
            border.color: fi.styleName === "dark" ? "#38FFFFFF" : (fi.styleName === "glass" ? "#B3FFFFFF" : "#4D000000")
        }
        Grid {
            anchors.centerIn: parent
            columns: 3
            spacing: 0
            Repeater {
                model: fi.list
                delegate: AppIcon {
                    required property string modelData
                    width: fi.plate * 0.31
                    height: width
                    iconName: fi.catalog[modelData] ? fi.catalog[modelData].icon : ""
                    tileDir: fi.tileDir
                    styleName: fi.styleName
                }
            }
        }
    }
    component ItemIcon: Item {
        id: ii
        property string kind: "app"
        property string iconName
        property string members
        property var catalog: ({})
        property string tileDir
        property string styleName: "light"
        AppIcon { anchors.fill: parent; visible: ii.kind !== "folder"; iconName: ii.iconName; tileDir: ii.tileDir; styleName: ii.styleName }
        FolderIcon { anchors.fill: parent; visible: ii.kind === "folder"; members: ii.members; catalog: ii.catalog; tileDir: ii.tileDir; styleName: ii.styleName }
    }

    // small helpers for the sheet
    component Switch: Rectangle {
        id: sw
        property bool on: false
        signal toggled(bool value)
        width: 58
        height: 34
        radius: 17
        color: on ? "#34C759" : "#5A5F69"
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            y: 3
            x: sw.on ? sw.width - width - 3 : 3
            width: 28
            height: 28
            radius: 14
            color: "white"
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: sw.toggled(!sw.on) }
    }

    // labelled slider; shows the value while dragging and reports it only on release (applying a dock look takes a moment)
    component PSlider: Item {
        id: ps
        property string label
        property real from: 0
        property real to: 100
        property real value: 0
        property string unit: ""
        property real live: -1
        signal committed(int v)
        width: parent ? parent.width : 300
        height: 48
        readonly property real shown: live >= 0 ? live : value
        Text { id: psl; anchors.verticalCenter: parent.verticalCenter; width: 190; text: ps.label; color: "white"; font.pixelSize: 19; elide: Text.ElideRight }
        Text { id: psv; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 66; horizontalAlignment: Text.AlignRight; text: Math.round(ps.shown) + ps.unit; color: "#B3FFFFFF"; font.pixelSize: 17 }
        Item {
            id: pst
            anchors.left: psl.right
            anchors.leftMargin: 8
            anchors.right: psv.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 48
            readonly property real v: Math.max(0, Math.min(1, (ps.shown - ps.from) / (ps.to - ps.from)))
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 10; radius: 5; color: "#4A505C" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(10, parent.width * pst.v); height: 10; radius: 5; color: "#2F7BFF" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, parent.width * pst.v - width / 2)); width: 32; height: 32; radius: 16; color: "white" }
            MouseArea {
                anchors.fill: parent
                function setFrom(x) { ps.live = ps.from + (ps.to - ps.from) * Math.max(0, Math.min(1, x / width)) }
                onPressed: (m) => setFrom(m.x)
                onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
                onReleased: { var v = Math.round(ps.live); ps.live = -1; ps.committed(v) }
                onCanceled: ps.live = -1
            }
        }
    }

    fullRepresentation: Item {
        id: home
        property bool editing: false
        property bool picking: false
        property bool customizing: false
        property bool dragging: false
        property int dragIdx: -1
        property int page: 0
        property real scaleOverride: -1
        property real ghostX: 0
        property real ghostY: 0
        property real grabDx: 0
        property real grabDy: 0
        property point lastPointer: Qt.point(0, 0)
        property int edgeDir: 0
        property int mergeTarget: -1
        property int hoverKey: -1          // what the pointer hovers while dragging: screen * 1000 + slot
        property int hoverPage: 0
        property int hoverPos: 0
        property int dragStartPages: 1
        property int dragSrcPage: 0
        property int dragSrcLen: 0
        property int pickPage: 0           // the screen the "Add apps" picker adds to
        property int pickFolder: -1        // >= 0: the picker adds into that folder instead
        property bool pickDock: false      // true: the picker adds to the dock
        property int sheetTab: 0           // sheet: 0 = Icons, 1 = Dock & bar
        onPickingChanged: if (!picking) { pickFolder = -1; pickDock = false }
        property bool hoverCenter: false

        readonly property bool landscape: width > height
        readonly property real margin: landscape ? 56 : 36
        readonly property real clockTop: landscape ? 30 : 52
        readonly property real areaY: clockTop + clockCol.height + (landscape ? 22 : 34)
        readonly property real areaH: Math.max(200, height - areaY - (landscape ? 26 : 40))
        readonly property real dotsH: 26
        readonly property real pagerH: areaH - dotsH
        readonly property real areaW: Math.max(200, width - 2 * margin)

        // ---- geometry: icon size from the "Icon size" setting, columns / rows / pages follow from it -----------------------
        readonly property real scl: scaleOverride > 0 ? scaleOverride : root.iconScale
        readonly property real iconSize: Math.round(112 * scl)               // tile canvas (the visible tile is 86 % of it)
        readonly property real labelBlock: root.showLabels ? 32 : 0
        readonly property int cols: Math.max(2, Math.floor(areaW / (iconSize * 1.3)))
        readonly property real cellW: Math.min(areaW / cols, iconSize * 1.9)
        readonly property real cellH0: iconSize + labelBlock + 22
        readonly property int rows: Math.max(1, Math.floor(pagerH / cellH0))
        readonly property real cellH: Math.min(pagerH / rows, cellH0 * 1.3)
        readonly property int perPage: cols * rows
        readonly property int pages: root.pageCount + ((editing && root.lastNonEmpty) ? 1 : 0)       // + one blank screen to drop icons on while editing
        Binding { target: root; property: "perPage"; value: home.perPage; when: home.scaleOverride < 0 && home.width > 300 && home.height > 300; restoreMode: Binding.RestoreNone }
        readonly property real gridX0: (width - cols * cellW) / 2
        readonly property real gridY0: Math.max(4, (pagerH - rows * cellH) * 0.4)
        readonly property real iconTop: (cellH - iconSize - labelBlock) / 2

        // an item's place = (screen, position on it): slotX / slotY of the item with index i in lm
        function slotX(i) { var p = root.pageOf(i), q = i - root.pageStart[p]; return p * width + gridX0 + (q % cols) * cellW }
        function slotY(i) { var p = root.pageOf(i), q = i - root.pageStart[p]; return gridY0 + Math.floor(q / cols) * cellH }
        function cellAt(cx, cy) {        // grid cell under a point of the pager content: { p: screen, q: position } or null
            var p = Math.floor(cx / width)
            var col = Math.floor((cx - p * width - gridX0) / cellW)
            var row = Math.floor((cy - gridY0) / cellH)
            if (col < 0 || col >= cols || row < 0 || row >= rows || p < 0 || p >= pages) return null
            return { p: p, q: row * cols + col }
        }
        function slotAt(cx, cy) {        // index in lm of the icon there, or -1
            var c = cellAt(cx, cy)
            return (c && c.q < root.pageLen(c.p)) ? root.pageStart[c.p] + c.q : -1
        }
        function addPageAt(cx, cy) {     // the screen whose "Add apps" tile is there (edit mode), or -1
            var c = cellAt(cx, cy)
            return (c && editing && c.q === root.pageLen(c.p) && c.q < perPage) ? c.p : -1
        }
        function goTo(p) {
            p = Math.max(0, Math.min(pages - 1, p))
            page = p
            snap.stop(); snap.from = pager.contentX; snap.to = p * width; snap.start()
        }
        onPagesChanged: if (page > pages - 1) goTo(pages - 1)
        onWidthChanged: pager.contentX = page * width

        // ---- drag to reorder ------------------------------------------------------------------------------------------------
        function beginDrag(idx, mx, my) {
            if (idx < 0 || idx >= lm.count) return
            var m = lm.get(idx)
            dragging = true; dragIdx = idx; mergeTarget = -1; hoverKey = -1
            dragStartPages = root.pageCount; dragSrcPage = m.page; dragSrcLen = root.pageLen(m.page)
            grabDx = mx - (slotX(idx) + cellW / 2)
            grabDy = my - (slotY(idx) + iconTop + iconSize / 2)
            ghostIcon.kind = m.kind; ghostIcon.iconName = m.iconName; ghostIcon.members = m.members
        }
        // pointer over the middle of another icon for a moment = merge (folder), over its edge or an empty slot = the icons make room (reorder / move to that screen)
        function dragMove(ph) {          // ph: pointer in home coordinates
            lastPointer = ph
            ghostX = ph.x - grabDx - iconSize / 2
            ghostY = ph.y - grabDy - iconSize / 2
            edgeDir = ph.x < 64 ? -1 : (ph.x > width - 64 ? 1 : 0)
            var cx = pager.contentX + ph.x - pager.x, cy = ph.y - pager.y
            var p = Math.max(0, Math.min(pages - 1, Math.floor(cx / width)))
            var col = Math.max(0, Math.min(cols - 1, Math.floor((cx - p * width - gridX0) / cellW)))
            var row = Math.max(0, Math.min(rows - 1, Math.floor((cy - gridY0) / cellH)))
            var q = row * cols + col, len = root.pageLen(p)
            var t = q < len ? root.pageStart[p] + q : -1          // the icon under the pointer, or -1 for an empty slot
            if (t === dragIdx) { hoverKey = -1; mergeTarget = -1; hoverTimer.stop(); return }
            hoverCenter = false
            if (t >= 0) {
                var dx = cx - (slotX(t) + cellW / 2), dy = cy - (slotY(t) + iconTop + iconSize / 2)
                hoverCenter = Math.sqrt(dx * dx + dy * dy) < iconSize * (lm.get(t).kind === "folder" ? 0.52 : 0.36)      // a folder takes the whole icon
            }
            var key = p * 1000 + (t >= 0 ? q : len)
            if (key !== hoverKey) { hoverKey = key; hoverPage = p; hoverPos = q; mergeTarget = -1; hoverTimer.restart() }
            else if (!hoverCenter && mergeTarget >= 0) mergeTarget = -1
        }
        function endDrag() {
            hoverTimer.stop()
            var from = dragIdx, target = mergeTarget, srcPage = dragSrcPage, srcLen = dragSrcLen
            if (target < 0 && hoverKey >= 0 && hoverCenter) {          // let go over a folder: it goes in at once, no waiting
                var ht = hoverPos < root.pageLen(hoverPage) ? root.pageStart[hoverPage] + hoverPos : -1
                if (ht >= 0 && ht !== from && lm.get(ht).kind === "folder" && root.canMerge(from, ht)) target = ht
            }
            dragging = false; dragIdx = -1; edgeDir = 0; mergeTarget = -1; hoverKey = -1
            root.trimPages(dragStartPages)
            if (target >= 0) root.mergeInto(from, target); else root.saveIds()
            // the last icon left its screen: the empty screen goes away, like on an iPad
            if (srcLen === 1 && root.pageLen(srcPage) === 0 && root.pageCount > 1) root.deletePage(srcPage)
        }
        Timer {
            id: hoverTimer
            interval: 380
            onTriggered: {
                if (!home.dragging || home.hoverKey < 0) return
                var t = home.hoverPos < root.pageLen(home.hoverPage) ? root.pageStart[home.hoverPage] + home.hoverPos : -1
                if (t === home.dragIdx) return
                if (home.hoverCenter && t >= 0 && root.canMerge(home.dragIdx, t)) home.mergeTarget = t
                else { home.dragIdx = root.moveTo(home.dragIdx, home.hoverPage, home.hoverPos); home.hoverKey = -1 }
            }
        }
        Timer {           // page flip while an icon is held at the screen edge, and re-evaluation while the pages slide
            interval: 700
            repeat: true
            running: home.dragging
            onTriggered: { if (home.edgeDir !== 0) home.goTo(home.page + home.edgeDir); home.dragMove(home.lastPointer) }
        }



        property date now: new Date()
        Timer { interval: 10000; running: true; repeat: true; onTriggered: home.now = new Date() }

        Column {
            id: clockCol
            x: home.margin + 8
            y: home.clockTop
            spacing: 0
            Text {
                text: Qt.formatTime(home.now, "HH:mm")
                color: "white"
                font.pixelSize: home.landscape ? 76 : 72
                font.weight: Font.Light
                style: Text.Raised
                styleColor: "#66000000"
            }
            Text {
                text: Qt.locale("en_GB").toString(home.now, "dddd, d MMMM")
                color: "#F2FFFFFF"
                font.pixelSize: 22
                font.weight: Font.Medium
                style: Text.Raised
                styleColor: "#66000000"
            }
        }

        // ---- search pill (opens KRunner) ---------------------------------------------------------------------------------------
        Rectangle {
            visible: root.showSearch && home.width > 980
            anchors.horizontalCenter: parent.horizontalCenter
            y: home.clockTop + 22
            width: 300
            height: 46
            radius: 23
            color: searchTap.pressed ? "#66FFFFFF" : "#40FFFFFF"
            border.width: 1
            border.color: "#40FFFFFF"
            Row {
                anchors.centerIn: parent
                spacing: 10
                Kirigami.Icon { width: 22; height: 22; source: "search"; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Search"; color: "#F2FFFFFF"; font.pixelSize: 19; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: searchTap; anchors.fill: parent; onClicked: root.openSearch() }
        }

        // ---- the pages ----------------------------------------------------------------------------------------------------------
        Flickable {
            id: pager
            x: 0
            y: home.areaY
            width: home.width
            height: home.pagerH
            contentWidth: home.pages * home.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: !home.dragging && home.pages > 1
            clip: true
            onFlickStarted: {
                var t = home.page + (horizontalVelocity > 0 ? 1 : -1)
                cancelFlick(); home.goTo(t)
            }
            onMovementEnded: if (!snap.running && !home.dragging) home.goTo(Math.round(contentX / home.width))
            NumberAnimation { id: snap; target: pager; property: "contentX"; duration: 260; easing.type: Easing.OutCubic }

            MouseArea {
                id: ma
                width: pager.contentWidth
                height: pager.height
                pressAndHoldInterval: 420
                property int pressIdx: -1
                property int pressAdd: -1
                property real px: 0
                property real py: 0
                property bool moved: false
                onPressed: (m) => {
                    pressIdx = home.slotAt(m.x, m.y)
                    pressAdd = home.addPageAt(m.x, m.y)
                    px = m.x; py = m.y; moved = false
                    preventStealing = home.editing && pressIdx >= 0 && pressIdx < lm.count
                }
                onPositionChanged: (m) => {
                    if (!pressed) return
                    if (!moved && Math.abs(m.x - px) + Math.abs(m.y - py) > 14) moved = true
                    if (home.editing && pressIdx >= 0 && pressIdx < lm.count && moved && !home.dragging) home.beginDrag(pressIdx, m.x, m.y)
                    if (home.dragging) home.dragMove(ma.mapToItem(home, m.x, m.y))
                }
                onReleased: (m) => {
                    if (home.dragging) { home.endDrag(); return }
                    // iPad: pull the home screen down to search (mostly vertical, long enough, not while editing)
                    var dy = m.y - py, dx = m.x - px
                    if (!home.editing && dy > 110 && dy > Math.abs(dx) * 1.6 && Plasmoid.configuration.showSearch) root.openSearch()
                }
                onCanceled: { if (home.dragging) home.endDrag(); pressIdx = -1; preventStealing = false }
                onPressAndHold: {
                    if (home.editing) return
                    home.editing = true
                    if (pressIdx >= 0 && pressIdx < lm.count) preventStealing = true
                }
                onClicked: (m) => {
                    if (moved) return
                    var i = pressIdx
                    if (i >= 0 && i < lm.count && lm.get(i).kind === "folder") { root.folderEditing = home.editing; root.openFolder = i }
                    else if (home.editing) {
                        if (pressAdd >= 0) { root.refresh(); home.pickPage = pressAdd; home.picking = true }
                        else if (i < 0) home.editing = false
                    } else if (i >= 0 && i < lm.count) root.launch(lm.get(i).desk)
                }
            }

            Repeater {
                model: lm
                delegate: Item {
                    id: cell
                    required property int index
                    required property string appId
                    required property string title
                    required property string iconName
                    required property string desk
                    required property string kind
                    required property string members
                    width: home.cellW
                    height: home.cellH
                    x: home.slotX(index)
                    y: home.slotY(index)
                    opacity: home.dragging && index === home.dragIdx ? 0 : 1
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                    property real wig: 0
                    SequentialAnimation on wig {
                        running: home.editing
                        loops: Animation.Infinite
                        NumberAnimation { from: -1.5; to: 1.5; duration: 120 + (cell.index % 3) * 25; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.5; to: -1.5; duration: 120 + (cell.index % 3) * 25; easing.type: Easing.InOutSine }
                    }

                    Item {
                        id: box
                        anchors.fill: parent
                        rotation: home.editing ? cell.wig : 0
                        readonly property bool down: ma.pressed && ma.pressIdx === cell.index && !ma.moved && !home.editing
                        scale: down ? 0.9 : 1.0
                        opacity: down ? 0.8 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 90 } }

                        Rectangle {       // drop highlight: this icon becomes / receives a folder
                            readonly property bool on: home.dragging && home.mergeTarget === cell.index
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: home.iconTop + home.iconSize * 0.07 - 6
                            width: home.iconSize * 0.86 + 12
                            height: width
                            radius: width * 0.24
                            color: "#59FFFFFF"
                            opacity: on ? 1 : 0
                            scale: on ? 1.1 : 0.9
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 120 } }
                        }
                        ItemIcon {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: home.iconTop
                            width: home.iconSize
                            height: home.iconSize
                            kind: cell.kind
                            iconName: cell.iconName
                            members: cell.members
                            catalog: root.catalog
                            tileDir: root.tileDir
                            styleName: root.iconStyle
                        }
                        // label on a soft dark pill: stays readable on bright wallpapers (sand, snow, sky)
                        Rectangle {
                            id: pill
                            visible: root.showLabels
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: icon.bottom
                            anchors.topMargin: 2
                            width: Math.min(cell.width - 4, label.implicitWidth + 20)
                            height: label.implicitHeight + 4
                            radius: height / 2
                            color: "#66000000"
                            Text {
                                id: label
                                anchors.centerIn: parent
                                width: pill.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.title
                                color: "white"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }
                        }
                    }
                    // remove badge (edit mode) — big touch target, small circle
                    Item {
                        visible: home.editing
                        x: icon.x + home.iconSize * 0.07 - 20
                        y: icon.y + home.iconSize * 0.07 - 20
                        width: 56
                        height: 56
                        rotation: box.rotation
                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: 16
                            color: "#E5484D"
                            border.width: 2
                            border.color: "white"
                            Rectangle { anchors.centerIn: parent; width: 15; height: 3.5; radius: 1.7; color: "white" }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.removeAt(cell.index) }
                    }
                }
            }

            // "add" tile: right after the last icon of every screen that has room (edit mode only)
            Repeater {
              model: home.pages
              delegate: Item {
                id: addCell
                required property int index
                readonly property int q: root.pageLen(index)
                visible: home.editing && q < home.perPage
                width: home.cellW
                height: home.cellH
                x: index * home.width + home.gridX0 + (q % home.cols) * home.cellW
                y: home.gridY0 + Math.floor(q / home.cols) * home.cellH
                Rectangle {
                    id: plusBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: home.iconTop + home.iconSize * 0.07
                    width: home.iconSize * 0.86
                    height: width
                    radius: width * 0.225
                    color: "#33FFFFFF"
                    border.width: 2
                    border.color: "#B3FFFFFF"
                    Rectangle { anchors.centerIn: parent; width: parent.width * 0.4; height: 5; radius: 2.5; color: "white" }
                    Rectangle { anchors.centerIn: parent; width: 5; height: parent.width * 0.4; radius: 2.5; color: "white" }
                }
                Text {
                    visible: root.showLabels
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: plusBox.bottom
                    anchors.topMargin: 10
                    text: "Add apps"
                    color: "white"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    style: Text.Raised
                    styleColor: "#B3000000"
                }
              }
            }
        }

        // the icon that follows the finger while it is dragged
        ItemIcon {
            id: ghostIcon
            visible: home.dragging
            z: 50
            x: home.ghostX
            y: home.ghostY
            width: home.iconSize
            height: home.iconSize
            scale: 1.12
            opacity: 0.95
            catalog: root.catalog
            tileDir: root.tileDir
            styleName: root.iconStyle
        }

        // ---- page dots ------------------------------------------------------------------------------------------------------------
        Rectangle {
            id: dotsBg
            visible: home.pages > 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: pager.y + home.pagerH + 2
            width: dotsRow.width + 20
            height: 24
            radius: 12
            color: "#40000000"
        }
        // edit mode: new screen / delete the empty screen you are on
        Rectangle {
            visible: home.editing
            anchors.right: dotsBg.left
            anchors.rightMargin: 14
            y: dotsBg.y - 4
            width: newLabel.implicitWidth + 32
            height: 32
            radius: 16
            color: newTap.pressed ? "#99000000" : "#73000000"
            Text { id: newLabel; anchors.centerIn: parent; text: "+  New screen"; color: "white"; font.pixelSize: 16; font.weight: Font.Medium }
            MouseArea { id: newTap; anchors.fill: parent; anchors.margins: -6; onClicked: home.goTo(root.newPage(home.page)) }
        }
        Rectangle {
            visible: home.editing && home.page < root.pageCount && root.pageCount > 1 && root.pageLen(home.page) === 0
            anchors.left: dotsBg.right
            anchors.leftMargin: 14
            y: dotsBg.y - 4
            width: delLabel.implicitWidth + 32
            height: 32
            radius: 16
            color: delTap.pressed ? "#F0E5484D" : "#CCE5484D"
            Text { id: delLabel; anchors.centerIn: parent; text: "Delete screen"; color: "white"; font.pixelSize: 16; font.weight: Font.Medium }
            MouseArea { id: delTap; anchors.fill: parent; anchors.margins: -6; onClicked: root.deletePage(home.page) }
        }
        Row {
            id: dotsRow
            visible: home.pages > 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: pager.y + home.pagerH + 5
            spacing: 8
            Repeater {
                model: home.pages
                delegate: Item {
                    required property int index
                    width: 14
                    height: 18
                    Rectangle {
                        readonly property bool blank: index >= root.pageCount        // the not yet created screen that edit mode offers
                        anchors.centerIn: parent
                        width: index === home.page ? 10 : 8
                        height: width
                        radius: width / 2
                        color: blank ? "transparent" : (index === home.page ? "white" : "#99FFFFFF")
                        border.width: blank ? 2 : 1
                        border.color: blank ? "#CCFFFFFF" : "#26000000"
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: home.goTo(index) }
                }
            }
        }

        // ---- top right: sliders / "+" (always), "Done" (edit mode) -------------------------------------------------------------
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: home.landscape ? 26 : 44
            anchors.rightMargin: home.margin
            spacing: 12
            Rectangle {
                visible: home.editing
                width: doneLabel.implicitWidth + 40
                height: 48
                radius: 24
                color: "#2F7BFF"
                Text { id: doneLabel; anchors.centerIn: parent; text: "Done"; color: "white"; font.pixelSize: 19; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: home.editing = false }
            }
            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: sliderTap.pressed ? "#66FFFFFF" : "#40FFFFFF"
                Column {
                    anchors.centerIn: parent
                    spacing: 7
                    Item { width: 22; height: 6; Rectangle { y: 2; width: 22; height: 2.5; radius: 1.2; color: "white" } Rectangle { x: 12; width: 6; height: 6; radius: 3; color: "white" } }
                    Item { width: 22; height: 6; Rectangle { y: 2; width: 22; height: 2.5; radius: 1.2; color: "white" } Rectangle { x: 3; width: 6; height: 6; radius: 3; color: "white" } }
                }
                MouseArea { id: sliderTap; anchors.fill: parent; anchors.margins: -6; onClicked: home.customizing = true }
            }
            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: addTap.pressed ? "#66FFFFFF" : "#40FFFFFF"
                Rectangle { anchors.centerIn: parent; width: 20; height: 3.5; radius: 1.7; color: "white" }
                Rectangle { anchors.centerIn: parent; width: 3.5; height: 20; radius: 1.7; color: "white" }
                MouseArea { id: addTap; anchors.fill: parent; anchors.margins: -6; onClicked: { root.refresh(); home.pickPage = Math.min(home.page, root.pageCount); home.picking = true } }
            }
        }

        // ---- "Home screen" sheet: icon style, size, labels, search (no dimming of the wallpaper) ------------------------------------
        Item {
            id: custom
            anchors.fill: parent
            z: 20
            visible: opacity > 0.01
            opacity: home.customizing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            MouseArea { anchors.fill: parent; onClicked: home.customizing = false }
            Rectangle {
                id: csheet
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: home.landscape ? 14 : 30
                width: Math.min(parent.width - 2 * home.margin, 700)
                height: ccol.implicitHeight + 44
                radius: 28
                color: "#F0232830"
                border.width: 1
                border.color: "#33FFFFFF"
                MouseArea { anchors.fill: parent }
                Column {
                    id: ccol
                    x: 26
                    y: 22
                    width: parent.width - 52
                    spacing: home.sheetTab === 0 ? 18 : 12

                    Item {
                        width: parent.width
                        height: 44
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Home screen"; color: "white"; font.pixelSize: 24; font.weight: Font.DemiBold }
                        Rectangle {
                            anchors.right: parent.right
                            width: cDone.implicitWidth + 40
                            height: 44
                            radius: 22
                            color: "#2F7BFF"
                            Text { id: cDone; anchors.centerIn: parent; text: "Done"; color: "white"; font.pixelSize: 19; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; onClicked: home.customizing = false }
                        }
                    }

                    Row {
                        spacing: 10
                        Repeater {
                            model: ["Icons", "Dock & bar"]
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                width: tabText.implicitWidth + 44
                                height: 38
                                radius: 19
                                color: home.sheetTab === index ? "#2F7BFF" : "#33FFFFFF"
                                Text { id: tabText; anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 18; font.weight: Font.Medium }
                                MouseArea { anchors.fill: parent; onClicked: { home.sheetTab = index; if (index === 1) root.refreshDock() } }
                            }
                        }
                    }

                    // ---- tab "Dock & bar" ------------------------------------------------------------------------------------------------
                    Column {
                        visible: home.sheetTab === 1
                        width: parent.width
                        spacing: 10
                        Text { text: "Dock apps"; color: "#B3FFFFFF"; font.pixelSize: 16 }
                        Flickable {
                            width: parent.width
                            height: 84
                            contentWidth: dockRow.width
                            clip: true
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: dockRow
                                spacing: 8
                                Repeater {
                                    model: root.dockApps
                                    delegate: Item {
                                        id: da
                                        required property var modelData
                                        width: 70
                                        height: 80
                                        AppIcon { id: daIcon; x: 3; y: 8; width: 64; height: 64; iconName: da.modelData.icon; tileDir: root.tileDir; styleName: root.iconStyle }
                                        Item {
                                            x: -6; y: -2; width: 44; height: 44; z: 2
                                            Rectangle {
                                                anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: "#E5484D"; border.width: 2; border.color: "white"
                                                Rectangle { anchors.centerIn: parent; width: 12; height: 3; radius: 1.5; color: "white" }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: root.dockRemove(da.modelData) }
                                        }
                                    }
                                }
                                Item {
                                    width: 70
                                    height: 80
                                    Rectangle {
                                        x: 3 + 64 * 0.07; y: 8 + 64 * 0.07; width: 64 * 0.86; height: width; radius: width * 0.225
                                        color: "#33FFFFFF"; border.width: 2; border.color: "#B3FFFFFF"
                                        Rectangle { anchors.centerIn: parent; width: parent.width * 0.4; height: 4; radius: 2; color: "white" }
                                        Rectangle { anchors.centerIn: parent; width: 4; height: parent.width * 0.4; radius: 2; color: "white" }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: { root.refresh(); home.pickDock = true; home.picking = true } }
                                }
                            }
                        }
                        PSlider { label: "Dock opacity"; from: 0; to: 100; unit: " %"; value: Plasmoid.configuration.dockAlpha; onCommitted: (v) => { Plasmoid.configuration.dockAlpha = v; root.applyDock() } }
                        PSlider { label: "Dock roundness"; from: 0; to: 30; value: Plasmoid.configuration.dockRadius; onCommitted: (v) => { Plasmoid.configuration.dockRadius = v; root.applyDock() } }
                        PSlider { label: "Dock size"; from: 40; to: 96; unit: " px"; value: Plasmoid.configuration.dockSize; onCommitted: (v) => { Plasmoid.configuration.dockSize = v; root.applyDock() } }
                        PSlider { label: "Status bar opacity"; from: 0; to: 100; unit: " %"; value: Plasmoid.configuration.barAlpha; onCommitted: (v) => { Plasmoid.configuration.barAlpha = v; root.applyDock() } }
                        Item {
                            width: parent.width
                            height: 40
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Hide dock inside apps"; color: "white"; font.pixelSize: 19 }
                            Switch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: Plasmoid.configuration.dockHide; onToggled: (v) => { Plasmoid.configuration.dockHide = v; root.applyDock() } }
                        }
                        Rectangle {
                            width: resetLabel.implicitWidth + 40
                            height: 38
                            radius: 19
                            color: resetTap.pressed ? "#66FFFFFF" : "#33FFFFFF"
                            Text { id: resetLabel; anchors.centerIn: parent; text: "Reset dock and bar"; color: "white"; font.pixelSize: 17 }
                            MouseArea { id: resetTap; anchors.fill: parent; onClicked: root.resetDock() }
                        }
                    }

                    // icon style
                    Row {
                        visible: home.sheetTab === 0
                        width: parent.width
                        spacing: 14
                        Repeater {
                            model: [ { key: "light", label: "Light", pv: ["light", "light", "light"] }, { key: "dark", label: "Dark", pv: ["dark", "dark", "dark"] },
                                     { key: "glass", label: "Glass", pv: ["glass", "glass", "glass"] }, { key: "auto", label: "Auto", pv: ["light", "dark"] } ]
                            delegate: Item {
                                id: sc
                                required property var modelData
                                width: (ccol.width - 42) / 4
                                height: 138
                                readonly property bool sel: root.iconAuto ? modelData.key === "auto" : root.iconStyle === modelData.key
                                Rectangle {
                                    anchors.top: parent.top
                                    width: parent.width
                                    height: 108
                                    radius: 20
                                    clip: true
                                    border.width: sc.sel ? 3 : 1
                                    border.color: sc.sel ? "#2F7BFF" : "#33FFFFFF"
                                    gradient: Gradient {     // a bright-to-dark backdrop so the glass look is visible
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#4E8CD9" }
                                        GradientStop { position: 0.55; color: "#E7CFA6" }
                                        GradientStop { position: 1.0; color: "#6F5B4A" }
                                    }
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 0
                                        Repeater {
                                            model: sc.modelData.pv
                                            delegate: Image {
                                                required property string modelData
                                                required property int index
                                                width: 46; height: 46
                                                source: Qt.resolvedUrl("../tiles/") + modelData + "/256/" + ["pipa-tile-okular", "pipa-tile-org.kde.dolphin", "pipa-tile-accessories-calculator"][sc.modelData.key === "auto" ? 0 : index] + ".png"
                                                sourceSize: Qt.size(92, 92)
                                                smooth: true
                                            }
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.pickStyle(sc.modelData.key) }
                                }
                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: sc.modelData.label
                                    color: sc.sel ? "white" : "#B3FFFFFF"
                                    font.pixelSize: 18
                                    font.weight: sc.sel ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }

                    // icon size
                    Item {
                        visible: home.sheetTab === 0
                        width: parent.width
                        height: 56
                        Rectangle { id: smallIcon; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; radius: 5; color: "#B3FFFFFF" }
                        Rectangle { id: bigIcon; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 10; color: "#B3FFFFFF" }
                        Item {
                            id: track
                            anchors.left: smallIcon.right
                            anchors.leftMargin: 18
                            anchors.right: bigIcon.left
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            height: 56
                            readonly property real v: (home.scl - 0.6) / 0.9
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 10; radius: 5; color: "#4A505C" }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(10, parent.width * track.v); height: 10; radius: 5; color: "#2F7BFF" }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; x: Math.max(0, Math.min(parent.width - width, parent.width * track.v - width / 2)); width: 34; height: 34; radius: 17; color: "white" }
                            MouseArea {
                                anchors.fill: parent
                                function setFrom(x) { home.scaleOverride = 0.6 + 0.9 * Math.max(0, Math.min(1, x / width)) }
                                onPressed: (m) => setFrom(m.x)
                                onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
                                onReleased: { Plasmoid.configuration.iconScale = Math.round(home.scaleOverride * 20) / 20; home.scaleOverride = -1 }
                                onCanceled: { Plasmoid.configuration.iconScale = Math.round(home.scaleOverride * 20) / 20; home.scaleOverride = -1 }
                            }
                        }
                    }

                    Item {
                        visible: home.sheetTab === 0
                        width: parent.width
                        height: 40
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Icon names"; color: "white"; font.pixelSize: 19 }
                        Switch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: root.showLabels; onToggled: (v) => { Plasmoid.configuration.labels = v } }
                    }
                    Item {
                        visible: home.sheetTab === 0
                        width: parent.width
                        height: 40
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Search bar"; color: "white"; font.pixelSize: 19 }
                        Switch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: root.showSearch; onToggled: (v) => { Plasmoid.configuration.showSearch = v } }
                    }
                }
            }
        }

        // ---- folder panel: the apps of the folder that was tapped --------------------------------------------------------------------
        Item {
            id: folderView
            anchors.fill: parent
            z: 25
            readonly property bool open: root.openFolder >= 0 && fData.valid
            readonly property var fData: {
                root.modelRev; root.openFolder
                var i = root.openFolder
                if (i >= 0 && i < lm.count && lm.get(i).kind === "folder") return { valid: true, title: lm.get(i).title, members: lm.get(i).members.split(",") }
                return { valid: false, title: "", members: [] }
            }
            visible: opacity > 0.01
            opacity: open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: { titleInput.focus = false; root.openFolder = -1; root.folderEditing = false } }
            Rectangle {
                id: fpanel
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -20
                readonly property int n: folderView.fData.members.length + 1       // + the "Add apps" tile
                readonly property int fcols: Math.max(1, Math.min(n, 4))
                readonly property int frows: Math.ceil(n / fcols)
                readonly property real cw: home.iconSize * 1.4
                readonly property real ch: home.iconSize + (root.showLabels ? 40 : 16)
                readonly property real topPad: root.folderEditing ? 150 : 96
                width: Math.max(420, fcols * cw + 72)
                height: topPad + frows * ch + 26
                radius: 36
                color: root.iconStyle === "glass" ? "#CC2A3140" : "#E6262B33"
                border.width: 1
                border.color: "#38FFFFFF"
                scale: folderView.open ? 1 : 0.92
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: 140 } }
                MouseArea { anchors.fill: parent }

                TextInput {
                    id: titleInput
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 26
                    width: Math.min(parent.width - 190, 360)
                    horizontalAlignment: Text.AlignHCenter
                    color: "white"
                    selectionColor: "#2F7BFF"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    maximumLength: 24
                    onEditingFinished: { root.renameFolder(root.openFolder, text); focus = false }
                }
                Binding { target: titleInput; property: "text"; value: folderView.fData.title; when: !titleInput.activeFocus }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 68; width: titleInput.width; height: 2; radius: 1; color: "#66FFFFFF"; visible: titleInput.activeFocus }
                Rectangle {
                    visible: root.folderEditing
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 18
                    width: fDone.implicitWidth + 36
                    height: 42
                    radius: 21
                    color: "#2F7BFF"
                    Text { id: fDone; anchors.centerIn: parent; text: "Done"; color: "white"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: { titleInput.focus = false; root.folderEditing = false } }
                }
                // quick names (no keyboard needed) while editing
                Row {
                    visible: root.folderEditing
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 90
                    spacing: 8
                    Repeater {
                        model: ["Work", "Media", "Tools", "Games", "Social", "Web"]
                        delegate: Rectangle {
                            required property string modelData
                            width: chipText.implicitWidth + 28
                            height: 36
                            radius: 18
                            color: chipTap.pressed ? "#66FFFFFF" : "#33FFFFFF"
                            Text { id: chipText; anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 16 }
                            MouseArea { id: chipTap; anchors.fill: parent; onClicked: root.renameFolder(root.openFolder, modelData) }
                        }
                    }
                }
                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: fpanel.topPad
                    columns: fpanel.fcols
                    Repeater {
                        model: folderView.fData.members
                        delegate: Item {
                            id: mem
                            required property string modelData
                            required property int index
                            readonly property var app: root.catalog[modelData]
                            width: fpanel.cw
                            height: fpanel.ch
                            property real wig: 0
                            SequentialAnimation on wig {
                                running: root.folderEditing
                                loops: Animation.Infinite
                                NumberAnimation { from: -1.5; to: 1.5; duration: 120 + (mem.index % 3) * 25; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.5; to: -1.5; duration: 120 + (mem.index % 3) * 25; easing.type: Easing.InOutSine }
                            }
                            Item {
                                anchors.fill: parent
                                rotation: root.folderEditing ? mem.wig : 0
                                scale: mTap.pressed && !root.folderEditing ? 0.92 : 1
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                AppIcon {
                                    id: mIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: home.iconSize
                                    height: home.iconSize
                                    iconName: mem.app ? mem.app.icon : ""
                                    tileDir: root.tileDir
                                    styleName: root.iconStyle
                                }
                                Rectangle {
                                    visible: root.showLabels
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: mIcon.bottom
                                    anchors.topMargin: 2
                                    width: Math.min(mem.width - 4, mLabel.implicitWidth + 20)
                                    height: mLabel.implicitHeight + 4
                                    radius: height / 2
                                    color: "#66000000"
                                    Text {
                                        id: mLabel
                                        anchors.centerIn: parent
                                        width: parent.width - 12
                                        horizontalAlignment: Text.AlignHCenter
                                        text: mem.app ? mem.app.name : mem.modelData
                                        color: "white"
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        font.pixelSize: 16
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                            MouseArea {
                                id: mTap
                                anchors.fill: parent
                                pressAndHoldInterval: 420
                                onClicked: if (!root.folderEditing && mem.app) { root.launch(mem.app.path); root.openFolder = -1 }
                                onPressAndHold: root.folderEditing = true
                            }
                            Item {      // takes the app out of the folder (back to the home screen)
                                visible: root.folderEditing
                                x: mIcon.x + home.iconSize * 0.07 - 20
                                y: home.iconSize * 0.07 - 20
                                width: 56
                                height: 56
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: "#E5484D"
                                    border.width: 2
                                    border.color: "white"
                                    Rectangle { anchors.centerIn: parent; width: 15; height: 3.5; radius: 1.7; color: "white" }
                                }
                                MouseArea { anchors.fill: parent; onClicked: { if (root.folderTakeOut(root.openFolder, mem.modelData)) { root.openFolder = -1; root.folderEditing = false } } }
                            }
                        }
                    }
                    Item {      // "Add apps": every app that is not in a folder yet can go into this one
                        width: fpanel.cw
                        height: fpanel.ch
                        Rectangle {
                            id: fPlus
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: home.iconSize * 0.07
                            width: home.iconSize * 0.86
                            height: width
                            radius: width * 0.225
                            color: "#33FFFFFF"
                            border.width: 2
                            border.color: "#B3FFFFFF"
                            scale: fPlusTap.pressed ? 0.92 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Rectangle { anchors.centerIn: parent; width: parent.width * 0.4; height: 5; radius: 2.5; color: "white" }
                            Rectangle { anchors.centerIn: parent; width: 5; height: parent.width * 0.4; radius: 2.5; color: "white" }
                        }
                        Text {
                            visible: root.showLabels
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: fPlus.bottom
                            anchors.topMargin: 10
                            text: "Add apps"
                            color: "white"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }
                        MouseArea { id: fPlusTap; anchors.fill: parent; onClicked: { titleInput.focus = false; root.refresh(); home.pickFolder = root.openFolder; home.picking = true } }
                    }
                }
            }
        }

        // ---- picker: every installed app that is not on the home screen -------------------------------------------------------------
        Item {
            id: picker
            anchors.fill: parent
            z: 30
            visible: opacity > 0.01
            opacity: home.picking ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            MouseArea { anchors.fill: parent; onClicked: home.picking = false }     // tap outside closes
            Rectangle { anchors.fill: parent; color: "#8C000000" }

            Rectangle {
                id: sheet
                anchors.centerIn: parent
                width: Math.min(home.width - 2 * home.margin, 1000)
                height: Math.min(home.height - 90, 560)
                radius: 28
                color: "#F2232830"
                border.width: 1
                border.color: "#33FFFFFF"
                MouseArea { anchors.fill: parent }       // keep taps inside the sheet

                Text {
                    x: 28
                    y: 26
                    text: home.pickDock ? "Add apps to the dock" : (home.pickFolder >= 0 ? "Add apps to the folder" : "Add apps to the home screen")
                    color: "white"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 16
                    width: pickDone.implicitWidth + 40
                    height: 48
                    radius: 24
                    color: "#2F7BFF"
                    Text { id: pickDone; anchors.centerIn: parent; text: "Done"; color: "white"; font.pixelSize: 19; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; onClicked: home.picking = false }
                }
                Text {
                    anchors.centerIn: parent
                    visible: pickGrid.count === 0
                    text: home.pickDock ? "Every app is already in the dock." : (home.pickFolder >= 0 ? "Every app is already in a folder." : "Every installed app is already on the home screen.")
                    color: "#B3FFFFFF"
                    font.pixelSize: 18
                }
                GridView {
                    id: pickGrid
                    anchors.fill: parent
                    anchors.topMargin: 84
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 16
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 150)))
                    cellHeight: 138
                    clip: true
                    model: home.pickDock ? root.dockCandidates : (home.pickFolder >= 0 ? root.folderCandidates : root.candidates)
                    delegate: Item {
                        id: pc
                        required property var modelData
                        width: pickGrid.cellWidth
                        height: pickGrid.cellHeight
                        AppIcon {
                            id: pcIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4
                            width: 84
                            height: 84
                            iconName: pc.modelData.icon
                            tileDir: root.tileDir
                            styleName: root.iconStyle
                            scale: pcTap.pressed ? 0.9 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                        }
                        Text {
                            anchors.top: pcIcon.bottom
                            anchors.topMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 12
                            horizontalAlignment: Text.AlignHCenter
                            text: pc.modelData.name
                            color: "white"
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                        }
                        MouseArea { id: pcTap; anchors.fill: parent; onClicked: {
                            if (home.pickDock) root.dockAdd(pc.modelData.id)
                            else if (home.pickFolder >= 0) { var fi = root.folderAdd(home.pickFolder, pc.modelData.id); home.pickFolder = fi; root.openFolder = fi }
                            else root.addApp(pc.modelData.id, home.pickPage)
                        } }
                    }
                }
            }
        }
    }
}
