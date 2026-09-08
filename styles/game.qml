
import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cYellow: "#ffd700"
    readonly property color cMagenta: "#ff00ff"
    readonly property color cCyan: "#00ffff"
    readonly property color cGreen: "#00ff00"
    readonly property color cRed: "#ff3355"
    readonly property color cText: "#f8f8ff"
    readonly property color cDim: "#6a7a9a"

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
        property int sel: 0
        property int launchingIdx: -1
        property real lungeT: 0
        property var parts: []
        property var icons: ({})
        property int frame: 0
        property int score: 0
        property string term: "alacritty"

        readonly property int cols: Math.max(4, Math.min(8, Math.floor((width - 80) / 146)))
        readonly property real ox: (width - (cols * 146 - 14)) / 2
        readonly property real oy: 150

        readonly property var arcadePal: [cYellow, cMagenta, cCyan, cGreen]
        readonly property color cycle: arcadePal[Math.floor(frame / 10) % 4]

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 520; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); win.buildTiles(); } }
        Timer {
            interval: 80; repeat: true; running: true
            onTriggered: { win.frame++; win.score += 10; fxCanvas.requestPaint(); }
        }
        Timer { interval: 500; repeat: true; running: true; onTriggered: { win.score += 100; } }

        Component.onCompleted: { win.buildTiles(); search.forceActiveFocus(); }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }

        function buildTiles() {
            const q = win.query;
            win.tiles = AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1)
                .slice(0, 48);
            win.sel = 0;
        }

        function launchApp(a, idx) {
            if (!a || !a.exec) return;
            win.launchingIdx = idx;
            win.lungeT = Date.now();
            const tx = win.ox + (idx % win.cols) * 146 + 66;
            const ty = win.oy + Math.floor(idx / win.cols) * 110 + 48;
            for (let k = 0; k < 18; k++) {
                const a2 = Math.random() * 6.283;
                const sp = 2 + Math.random() * 5;
                win.parts.push({
                    x: tx, y: ty,
                    vx: Math.cos(a2) * sp, vy: Math.sin(a2) * sp - 1,
                    t0: Date.now(), life: 400 + Math.random() * 400,
                    sz: 3 + Math.floor(Math.random() * 5),
                    col: Math.floor(Math.random() * 4)
                });
            }
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            win.quitTimer.start();
        }
        function launchSel() {
            if (win.sel >= 0 && win.sel < win.tiles.length)
                win.launchApp(win.tiles[win.sel], win.sel);
        }

        Rectangle { anchors.fill: parent; color: "#05060f" }

        // pixel starfield
        Canvas {
            id: starCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                for (let i = 0; i < 90; i++) {
                    const x = ((Math.sin(i * 127.1) * 43758.5 % 1) + 1) % 1 * win.width;
                    const y = ((Math.sin(i * 311.7) * 43758.5 % 1) + 1) % 1 * win.height;
                    const s = 1 + (i % 3);
                    ctx.fillStyle = i % 7 === 0 ? "rgba(255,215,0,0.5)" : (i % 5 === 0 ? "rgba(0,255,255,0.4)" : "rgba(248,248,255,0.35)");
                    ctx.fillRect(Math.floor(x / 3) * 3, Math.floor(y / 3) * 3, s, s);
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
            onWheel: (wheel) => {
                const n = win.tiles.length;
                if (n) win.sel = (win.sel + (wheel.angleDelta.y > 0 ? 1 : -1) + n) % n;
                wheel.accepted = true;
            }
        }

        // ── HUD ──
        Text {
            x: 30; y: 24
            text: "1UP\n" + String(win.score).padStart(6, "0")
            color: cText
            font.family: "monospace"
            font.pixelSize: 14
            font.bold: true
            lineHeight: 1.3
            z: 60
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            text: "★ APP ARCADE ★"
            color: win.cycle
            font.family: "monospace"
            font.pixelSize: 22
            font.bold: true
            z: 60
        }
        Text {
            x: win.width - 190; y: 24
            text: "HI-SCORE\n999999"
            color: cRed
            font.family: "monospace"
            font.pixelSize: 14
            font.bold: true
            lineHeight: 1.3
            z: 60
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 62
            text: "INSERT COIN"
            color: cYellow
            font.family: "monospace"
            font.pixelSize: 12
            visible: Math.floor(win.frame / 8) % 2 === 0
            z: 60
        }

        // search = coin slot
        Rectangle {
            x: win.cx - 200; y: 92
            width: 400; height: 40
            color: "#0a0c18"
            border.color: search.activeFocus ? win.cycle : "#2a3050"
            border.width: 3
            z: 60
            Text {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                text: "»"
                color: cCyan
                font.family: "monospace"
                font.pixelSize: 16
            }
            Text {
                visible: search.text === ""
                x: 38; anchors.verticalCenter: parent.verticalCenter
                text: "type to filter cartridges…"
                color: cDim
                font.family: "monospace"
                font.pixelSize: 13
            }
            TextInput {
                id: search
                x: 38; anchors.verticalCenter: parent.verticalCenter
                width: 320
                color: cText
                font.family: "monospace"
                font.pixelSize: 14
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchSel(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right) { win.sel = Math.min(win.tiles.length - 1, win.sel + 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Left) { win.sel = Math.max(0, win.sel - 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { win.sel = Math.min(win.tiles.length - 1, win.sel + win.cols); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { win.sel = Math.max(0, win.sel - win.cols); event.accepted = true; }
                }
            }
        }

        // ── cartridge tiles ──
        Repeater {
            model: win.tiles
            delegate: Item {
                id: tile
                readonly property bool selHere: index === win.sel
                property bool entered: false
                x: win.ox + (index % win.cols) * 146
                y: win.oy + Math.floor(index / win.cols) * 110
                width: 132; height: 96
                scale: entered ? (selHere ? 1.06 : 1) * (win.launchingIdx === index ? 0.85 : 1) : 0.6
                opacity: entered ? (win.launchingIdx === index ? 0 : 1) : 0
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Timer { interval: 30 * index; running: true; onTriggered: tile.entered = true }

                Rectangle {
                    anchors.fill: parent
                    color: "#0d1022"
                    border.color: tile.selHere ? win.cycle : "#232a4a"
                    border.width: 3
                }
                // chunky pixel corners
                Rectangle { x: -3; y: -3; width: 6; height: 6; color: "#05060f" }
                Rectangle { x: parent.width - 3; y: -3; width: 6; height: 6; color: "#05060f" }
                Rectangle { x: -3; y: parent.height - 3; width: 6; height: 6; color: "#05060f" }
                Rectangle { x: parent.width - 3; y: parent.height - 3; width: 6; height: 6; color: "#05060f" }

                // bouncing ▶ cursor
                Text {
                    visible: tile.selHere
                    x: 6 + (Math.floor(win.frame / 8) % 2) * 3
                    y: 6
                    text: "▶"
                    color: cYellow
                    font.family: "monospace"
                    font.pixelSize: 14
                }

                Image {
                    id: ico
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 40; height: 40
                    source: (modelData && modelData.icon) ? "file://" + modelData.icon : ""
                    sourceSize: Qt.size(64, 64)
                    asynchronous: true
                    Component.onCompleted: { win.icons[index] = ico; }
                }
                Text {
                    visible: !modelData.icon || ico.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    text: modelData.label ? modelData.label.charAt(0).toUpperCase() : ""
                    color: cCyan
                    font.family: "monospace"
                    font.pixelSize: 20
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 64
                    width: 120
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: tile.selHere ? cText : "#9aa8cc"
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.bold: tile.selHere
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { win.sel = index; }
                    onClicked: { win.launchApp(modelData, index); }
                }
            }
        }

        Text {
            visible: win.tiles.length === 0
            anchors.centerIn: parent
            text: "GAME OVER — NO CARTRIDGES FOUND"
            color: cRed
            font.family: "monospace"
            font.pixelSize: 18
            font.bold: true
            z: 60
        }

        // ── FX: pixel explosions + GAME START + rolling CRT band ──
        Canvas {
            id: fxCanvas
            anchors.fill: parent
            z: 500
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();
                const pal = ["#ffd700", "#ff00ff", "#00ffff", "#00ff00"];

                for (let i = win.parts.length - 1; i >= 0; i--) {
                    const p = win.parts[i];
                    const age = t - p.t0;
                    if (age > p.life) { win.parts.splice(i, 1); continue; }
                    p.x += p.vx; p.y += p.vy;
                    p.vy += 0.12;
                    ctx.globalAlpha = 1 - age / p.life;
                    ctx.fillStyle = pal[p.col];
                    ctx.fillRect(Math.floor(p.x / 3) * 3, Math.floor(p.y / 3) * 3, p.sz, p.sz);
                }
                ctx.globalAlpha = 1;

                if (win.launchingIdx >= 0) {
                    const pr = Math.min(1, (t - win.lungeT) / 520);
                    if (pr < 0.7) {
                        ctx.font = "bold 34px monospace";
                        ctx.textAlign = "center";
                        ctx.fillStyle = pr < 0.35 ? "#ffd700" : "#ff00ff";
                        ctx.fillText("GAME START!", win.width / 2, win.height / 2);
                    }
                }

                // rolling CRT band
                const by = (t / 22) % (win.height + 160) - 80;
                const g = ctx.createLinearGradient(0, by - 40, 0, by + 40);
                g.addColorStop(0, "rgba(255,255,255,0)");
                g.addColorStop(0.5, "rgba(255,255,255,0.03)");
                g.addColorStop(1, "rgba(255,255,255,0)");
                ctx.fillStyle = g;
                ctx.fillRect(0, by - 40, win.width, 80);
            }
        }

        // CRT scanlines + vignette overlay
        Canvas {
            id: crtCanvas
            anchors.fill: parent
            z: 600
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "rgba(0,0,0,0.16)";
                for (let y = 0; y < win.height; y += 3)
                    ctx.fillRect(0, y, win.width, 1);
                const g = ctx.createRadialGradient(win.width / 2, win.height / 2, win.height * 0.35, win.width / 2, win.height / 2, win.height * 0.95);
                g.addColorStop(0, "rgba(0,0,0,0)");
                g.addColorStop(1, "rgba(0,0,0,0.55)");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, win.width, win.height);
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 30
            text: "ARROWS/WHEEL = MOVE CURSOR · CLICK/↵ = START GAME · ESC = QUIT TO CONTINUE"
            color: cDim
            font.family: "monospace"
            font.pixelSize: 11
            opacity: 0.9
            z: 601
        }
    }
}

