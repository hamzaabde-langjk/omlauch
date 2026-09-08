import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cBg: "#1a1b26"
    readonly property color cTile: "#24283b"
    readonly property color cLine: "#3b4261"
    readonly property color cText: "#c0caf5"
    readonly property color cDim: "#565f89"
    readonly property color cBlue: "#7aa2f7"
    readonly property color cCyan: "#7dcfff"
    readonly property color cPurple: "#bb9af7"
    readonly property color cGreen: "#9ece6a"
    readonly property color cRed: "#f7768e"
    readonly property color cOrange: "#ff9e64"
    readonly property color cYellow: "#e0af7a"

    PanelWindow {
        id: win
        objectName: "launcher"
        visible: true
        focusable: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        property string query: ""
        property string pending: ""
        property var tiles: []
        property var slots: []
        property int selApp: 0
        property int launchingIdx: -1
        property var icons: ({})
        property string now: ""
        property string dateStr: ""
        property bool coldStart: true
        property string term: "alacritty"

        readonly property int cols: Math.max(4, Math.min(7, Math.floor((width - 60 + 14) / 164)))
        readonly property int rows: height > 950 ? 5 : 4
        readonly property real ox: (width - (cols * 164 - 14)) / 2
        readonly property real oy: (height - (rows * 164 - 14)) / 2 + 8
        readonly property int appCount: tiles.length > 2 ? tiles.length - 2 : 0

        onColsChanged: { win.buildSlots(); win.rebuildTiles(); }
        onRowsChanged: { win.buildSlots(); win.rebuildTiles(); }
        onQueryChanged: win.rebuildTiles()

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 400; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); } }
        Timer { interval: 1200; running: true; onTriggered: { win.coldStart = false; } }

        Component.onCompleted: {
            win.buildSlots();
            win.rebuildTiles();
            win.tickClock();
            search.forceActiveFocus();
        }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }
        Timer { interval: 1000; repeat: true; running: true; onTriggered: win.tickClock() }

        function tickClock() {
            const d = new Date();
            now = Qt.formatTime(d, "HH:mm");
            dateStr = Qt.formatDate(d, "ddd · MMM d");
        }

        function buildSlots() {
            const cols = win.cols, rows = win.rows;
            const occ = [];
            for (let y = 0; y < rows; y++) {
                occ.push([]);
                for (let x = 0; x < cols; x++) occ[y].push(false);
            }
            const g = [];
            function place(x, y, w, h) {
                for (let yy = y; yy < y + h; yy++)
                    for (let xx = x; xx < x + w; xx++)
                        occ[yy][xx] = true;
                g.push({ x: x, y: y, w: w, h: h });
            }
            place(0, 0, 2, 2);
            place(2, 0, 2, 1);
            for (let y = 0; y < rows; y++)
                for (let x = 0; x < cols; x++)
                    if (!occ[y][x]) place(x, y, 1, 1);
            slots = g;
        }

        function rebuildTiles() {
            const q = win.query;
            const apps = AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1)
                .slice(0, Math.max(0, win.slots.length - 2));
            const t = [{ kind: "search" }, { kind: "eq" }];
            for (let i = 0; i < apps.length; i++)
                t.push({ kind: "app", app: apps[i], ai: i });
            tiles = t;
            selApp = 0;
        }

        function launchApp(a, idx) {
            if (!a || !a.exec) return;
            win.launchingIdx = idx;
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            win.quitTimer.start();
        }
        function launchSel() {
            const i = 2 + win.selApp;
            if (i < win.tiles.length && win.tiles[i].kind === "app")
                win.launchApp(win.tiles[i].app, i);
        }

        Rectangle { anchors.fill: parent; color: cBg }

        Canvas {
            id: dotCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "rgba(192,202,245,0.05)";
                for (let x = 20; x < win.width; x += 34)
                    for (let y = 20; y < win.height; y += 34)
                        ctx.fillRect(x, y, 1.5, 1.5);
            }
        }

        // escape hatch: click empty space = quit
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
            onWheel: (wheel) => {
                win.selApp = Math.max(0, Math.min(win.appCount - 1, win.selApp + (wheel.angleDelta.y > 0 ? 1 : -1)));
                wheel.accepted = true;
            }
        }

        Repeater {
            model: win.tiles
            delegate: Item {
                id: tile
                readonly property var sl: win.slots[index]
                readonly property bool isApp: modelData.kind === "app"
                readonly property bool hovered: ma.containsMouse
                readonly property bool sel: isApp && modelData.ai === win.selApp
                property bool entered: !win.coldStart
                x: win.ox + sl.x * 164
                y: win.oy + sl.y * 164
                width: sl.w * 164 - 14
                height: sl.h * 164 - 14
                scale: entered ? ((hovered && isApp) ? 1.04 : 1) * (win.launchingIdx === index ? 0.88 : 1) : 0.7
                opacity: entered ? (win.launchingIdx === index ? 0 : 1) : 0
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 240 } }
                Timer { interval: 40 * index; running: win.coldStart; onTriggered: tile.entered = true }

                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: cTile
                    border.color: tile.sel ? cBlue : (tile.hovered ? cCyan : cLine)
                    border.width: tile.sel ? 2 : 1
                }

                // ── clock tile (search input floats above, outside the grid) ──
                Item {
                    anchors.fill: parent
                    visible: modelData.kind === "search"
                    Text { x: 26; y: 22; text: win.now; color: cText; font.pixelSize: 46; font.bold: true }
                    Text { x: 28; y: 80; text: win.dateStr; color: cDim; font.pixelSize: 12 }
                    Text {
                        x: 28; y: parent.height - 36
                        text: win.appCount + " apps on the board"
                        color: cDim
                        font.pixelSize: 10
                    }
                    Rectangle { x: 26; y: parent.height - 26; width: 60; height: 4; radius: 2; color: cBlue }
                    Rectangle { x: 92; y: parent.height - 26; width: 24; height: 4; radius: 2; color: cPurple }
                    Rectangle { x: 122; y: parent.height - 26; width: 12; height: 4; radius: 2; color: cGreen }
                }

                // ── equalizer widget tile ──
                Item {
                    anchors.fill: parent
                    visible: modelData.kind === "eq"
                    Text { x: 20; y: 16; text: "NOW VIBING"; color: cDim; font.pixelSize: 10 }
                    Item {
                        x: 20; y: 46
                        width: parent.width - 40; height: parent.height - 66
                        Repeater {
                            model: 7
                            Rectangle {
                                readonly property var cols7: [cBlue, cCyan, cPurple, cGreen, cYellow, cOrange, cRed]
                                x: index * ((parent.width - 10) / 6)
                                width: 12
                                radius: 4
                                anchors.bottom: parent.bottom
                                color: cols7[index]
                                SequentialAnimation on height {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 26 + ((index * 37) % 44); duration: 320 + index * 80; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 12 + ((index * 23) % 22); duration: 280 + index * 60; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                // ── app tile ──
                Item {
                    anchors.fill: parent
                    visible: tile.isApp
                    Image {
                        id: ico
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 26
                        width: 56; height: 56
                        source: (modelData.app && modelData.app.icon) ? "file://" + modelData.app.icon : ""
                        sourceSize: Qt.size(96, 96)
                        asynchronous: true
                        rotation: tile.hovered ? -6 : 0
                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Component.onCompleted: { win.icons[index] = ico; }
                    }
                    Text {
                        visible: tile.isApp && (modelData.app.icon === "" || ico.status !== Image.Ready)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 36
                        text: modelData.app ? modelData.app.label.charAt(0).toUpperCase() : ""
                        color: cCyan
                        font.pixelSize: 28
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 96
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.app ? modelData.app.label : ""
                        color: tile.sel ? cText : "#9aa5ce"
                        font.pixelSize: 11
                        font.bold: tile.sel
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 118
                        width: 26; height: 5; radius: 3
                        color: tile.sel ? cBlue : cLine
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: tile.isApp ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: { if (tile.isApp) win.selApp = modelData.ai; }
                    onClicked: {
                        if (tile.isApp) win.launchApp(modelData.app, index);
                        else if (modelData.kind === "search") search.forceActiveFocus();
                    }
                }
            }
        }

        // ── search box: OUTSIDE the repeater, never destroyed ──
        Rectangle {
            x: win.ox + 26
            y: win.oy + 122
            width: 2 * 164 - 14 - 52
            height: 42
            radius: 12
            color: cBg
            border.color: search.activeFocus ? cBlue : cLine
            z: 500
            Text {
                visible: search.text === ""
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: "search apps…"
                color: cDim
                font.pixelSize: 13
            }
            TextInput {
                id: search
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28
                color: cText
                font.pixelSize: 14
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchSel(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right) { win.selApp = Math.min(win.appCount - 1, win.selApp + 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Left) { win.selApp = Math.max(0, win.selApp - 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { win.selApp = Math.min(win.appCount - 1, win.selApp + win.cols); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { win.selApp = Math.max(0, win.selApp - win.cols); event.accepted = true; }
                }
            }
        }

        Text {
            visible: win.appCount === 0
            anchors.centerIn: parent
            text: "no tiles match — the board is empty"
            color: cDim
            font.pixelSize: 14
            z: 500
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 34
            text: "type = reflow board · hover = select · click / ↵ = open · arrows / wheel = move · click empty = close · esc close"
            color: cDim
            font.pixelSize: 11
            opacity: 0.8
            z: 500
        }
    }
}
