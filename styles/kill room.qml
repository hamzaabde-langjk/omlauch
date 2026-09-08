import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cBlood: "#c40000"
    readonly property color cBright: "#ff1a1a"
    readonly property color cDark: "#8a0303"
    readonly property color cBone: "#d8cfc4"
    readonly property color cDim: "#6b5252"
    readonly property color cBg: "#050203"

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
        property var tags: []
        property int sel: 0
        property int launchingIdx: -1
        property real lungeT: 0
        property var parts: []
        property var drips: []
        property var icons: ({})
        property int frame: 0
        property real mouseX: 0
        property real mouseY: 0
        property string whisper: ""
        property real whisperT: 0
        property real whisperX: 0
        property real whisperY: 0
        property string term: "alacritty"
        readonly property var whispers: ["behind you", "he sees you", "don't blink", "run.", "it's too late", "why did you open this", "one more"]

        readonly property int cols: Math.max(4, Math.min(8, Math.floor((width - 80) / 150)))
        readonly property real ox: (width - (cols * 150 - 14)) / 2
        readonly property real oy: 150

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 560; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); win.buildTags(); } }
        Timer {
            interval: 80; repeat: true; running: true
            onTriggered: {
                win.frame++;
                // spawn drips
                if (win.drips.length < 14 && Math.random() < 0.15)
                    win.drips.push({ x: Math.random() * win.width, len: 0, max: 40 + Math.random() * 140, v: 0.5 + Math.random() * 1.2 });
                for (let i = 0; i < win.drips.length; i++)
                    if (win.drips[i].len < win.drips[i].max) win.drips[i].len += win.drips[i].v;
                // whispers
                if (win.frame % 90 === 0 && Math.random() < 0.5) {
                    win.whisper = win.whispers[Math.floor(Math.random() * win.whispers.length)];
                    win.whisperX = 100 + Math.random() * (win.width - 300);
                    win.whisperY = 120 + Math.random() * (win.height - 300);
                    win.whisperT = Date.now();
                }
                fxCanvas.requestPaint();
            }
        }

        Component.onCompleted: { win.buildTags(); search.forceActiveFocus(); }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }

        function rnd(i, s) { const x = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); }

        function buildTags() {
            const q = win.query;
            win.tags = AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1)
                .slice(0, 48);
            win.sel = 0;
        }

        function launchApp(a, idx) {
            if (!a || !a.exec) return;
            win.launchingIdx = idx;
            win.lungeT = Date.now();
            const tx = win.ox + (idx % win.cols) * 150 + 68;
            const ty = win.oy + Math.floor(idx / win.cols) * 118 + 52;
            for (let k = 0; k < 22; k++) {
                const a2 = Math.random() * 6.283;
                const sp = 1.5 + Math.random() * 5;
                win.parts.push({
                    x: tx, y: ty,
                    vx: Math.cos(a2) * sp, vy: Math.sin(a2) * sp + 1.5,
                    t0: Date.now(), life: 500 + Math.random() * 500,
                    sz: 2 + Math.floor(Math.random() * 5)
                });
            }
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            quitTimer.start();
        }
        function launchSel() {
            if (win.sel >= 0 && win.sel < win.tags.length)
                win.launchApp(win.tags[win.sel], win.sel);
        }

        // ── room walls: gradient + scratches + old stains ──
        Canvas {
            id: roomCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const g = ctx.createLinearGradient(0, 0, 0, win.height);
                g.addColorStop(0, "#0a0405");
                g.addColorStop(0.6, "#070203");
                g.addColorStop(1, "#030101");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, win.width, win.height);

                // old blood stains
                for (let i = 0; i < 7; i++) {
                    const x = win.rnd(i, 1) * win.width, y = win.rnd(i, 2) * win.height;
                    const r = 40 + win.rnd(i, 3) * 120;
                    const sg = ctx.createRadialGradient(x, y, 0, x, y, r);
                    sg.addColorStop(0, "rgba(90,5,5,0.10)");
                    sg.addColorStop(1, "rgba(90,5,5,0)");
                    ctx.fillStyle = sg;
                    ctx.fillRect(x - r, y - r, r * 2, r * 2);
                }
                // scratches
                ctx.strokeStyle = "rgba(216,207,196,0.05)";
                ctx.lineWidth = 1;
                for (let i = 0; i < 12; i++) {
                    const x = win.rnd(i, 4) * win.width, y = win.rnd(i, 5) * win.height;
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                    ctx.lineTo(x + (win.rnd(i, 6) - 0.5) * 90, y + (win.rnd(i, 7) - 0.5) * 40);
                    ctx.stroke();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.BlankCursor
            onPositionChanged: (mouse) => { win.mouseX = mouse.x; win.mouseY = mouse.y; }
            onClicked: Qt.quit()
            onWheel: (wheel) => {
                const n = win.tags.length;
                if (n) win.sel = (win.sel + (wheel.angleDelta.y > 0 ? 1 : -1) + n) % n;
                wheel.accepted = true;
            }
        }

        // ── victim tags ──
        Repeater {
            model: win.tags
            delegate: Item {
                id: tag
                readonly property bool selHere: index === win.sel
                property bool entered: false
                x: win.ox + (index % win.cols) * 150
                y: win.oy + Math.floor(index / win.cols) * 118
                width: 136; height: 104
                rotation: (win.rnd(index, 9) - 0.5) * 7
                scale: entered ? (selHere ? 1.08 : 1) * (win.launchingIdx === index ? 0.9 : 1) : 0.6
                opacity: entered ? (win.launchingIdx === index ? 0.25 : 1) : 0
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Timer { interval: 30 * index; running: true; onTriggered: tag.entered = true }

                Rectangle {
                    anchors.fill: parent
                    color: "#100808"
                    border.color: selHere ? cBright : "#3a1010"
                    border.width: selHere ? 2 : 1
                }
                // nail
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 6; height: 6
                    radius: 3
                    color: "#5a4a4a"
                }
                Image {
                    id: ico
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    width: 44; height: 44
                    source: (modelData && modelData.icon) ? "file://" + modelData.icon : ""
                    sourceSize: Qt.size(64, 64)
                    asynchronous: true
                    opacity: 0.9
                    Component.onCompleted: { win.icons[index] = ico; }
                }
                Text {
                    visible: !modelData.icon || ico.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    text: modelData.label ? modelData.label.charAt(0).toUpperCase() : ""
                    color: cDark
                    font.pixelSize: 22
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 68
                    width: 124
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: selHere ? cBone : "#9a8a80"
                    font.family: "monospace"
                    font.pixelSize: 10
                    font.bold: selHere
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 84
                    text: "VICTIM " + String(index + 1).padStart(2, "0")
                    color: cDim
                    font.family: "monospace"
                    font.pixelSize: 8
                }

                // bloody target circle when marked
                Rectangle {
                    visible: tag.selHere
                    anchors.centerIn: parent
                    width: 96; height: 96
                    radius: 48
                    color: "transparent"
                    border.color: "#ccff1a1a"
                    border.width: 2
                    rotation: win.frame * 2
                }

                // ELIMINATED stamp
                Text {
                    visible: win.launchingIdx === index
                    anchors.centerIn: parent
                    text: "ELIMINATED"
                    color: cBright
                    font.family: "monospace"
                    font.pixelSize: 16
                    font.bold: true
                    rotation: -14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { win.sel = index; }
                    onClicked: { win.launchApp(modelData, index); }
                }
            }
        }

        // ── FX: fog, drips, heartbeat, flicker, slashes, splatter, whispers, crosshair ──
        Canvas {
            id: fxCanvas
            anchors.fill: parent
            z: 500
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();

                // fog
                for (let i = 0; i < 3; i++) {
                    const x = ((t / (9000 + i * 3000)) % 1.4 - 0.2) * win.width + i * win.width * 0.3;
                    const y = win.height * (0.75 + i * 0.08);
                    const g = ctx.createRadialGradient(x, y, 0, x, y, 260);
                    g.addColorStop(0, "rgba(120,110,110,0.05)");
                    g.addColorStop(1, "rgba(120,110,110,0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(x - 260, y - 260, 520, 520);
                }

                // blood drips from ceiling
                for (let i = 0; i < win.drips.length; i++) {
                    const d = win.drips[i];
                    ctx.strokeStyle = "rgba(140,0,0,0.7)";
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(d.x, 0);
                    ctx.lineTo(d.x, d.len);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(d.x, d.len + 2, 2.5, 0, 6.2832);
                    ctx.fillStyle = "rgba(160,0,0,0.8)";
                    ctx.fill();
                }

                // slash + splatter on launch
                if (win.launchingIdx >= 0) {
                    const idx = win.launchingIdx;
                    const tx = win.ox + (idx % win.cols) * 150 + 68;
                    const ty = win.oy + Math.floor(idx / win.cols) * 118 + 52;
                    const pr = Math.min(1, (t - win.lungeT) / 560);
                    ctx.save();
                    ctx.globalAlpha = 1 - pr;
                    ctx.translate(tx, ty);
                    ctx.strokeStyle = "#ffe8e8";
                    ctx.lineWidth = 3;
                    ctx.shadowColor = "#ff1a1a";
                    ctx.shadowBlur = 14;
                    const L = 30 + pr * 90;
                    ctx.beginPath(); ctx.moveTo(-L, -L * 0.6); ctx.lineTo(L, L * 0.6); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(-L, L * 0.7); ctx.lineTo(L * 0.9, -L * 0.5); ctx.stroke();
                    ctx.restore();
                }
                for (let i = win.parts.length - 1; i >= 0; i--) {
                    const p = win.parts[i];
                    const age = t - p.t0;
                    if (age > p.life) { win.parts.splice(i, 1); continue; }
                    p.x += p.vx; p.y += p.vy;
                    p.vy += 0.1;
                    ctx.fillStyle = "rgba(150,0,0," + (1 - age / p.life).toFixed(3) + ")";
                    ctx.fillRect(p.x, p.y, p.sz, p.sz);
                }

                // heartbeat vignette (thump-thump)
                const ph = t % 1200;
                const i1 = Math.max(0, 1 - Math.abs(ph - 100) / 120);
                const i2 = Math.max(0, 1 - Math.abs(ph - 420) / 140) * 0.6;
                const vig = 0.22 + 0.30 * (i1 + i2);
                const vg = ctx.createRadialGradient(win.width / 2, win.height / 2, win.height * 0.3, win.width / 2, win.height / 2, win.height * 0.9);
                vg.addColorStop(0, "rgba(0,0,0,0)");
                vg.addColorStop(1, "rgba(120,0,0," + vig.toFixed(3) + ")");
                ctx.fillStyle = vg;
                ctx.fillRect(0, 0, win.width, win.height);

                // light flicker
                if (Math.random() < 0.04) {
                    ctx.fillStyle = "rgba(255,230,220,0.03)";
                    ctx.fillRect(0, 0, win.width, win.height);
                }

                // whisper
                if (t - win.whisperT < 400 && win.whisper !== "") {
                    ctx.font = "italic 15px monospace";
                    ctx.fillStyle = "rgba(200,180,180,0.25)";
                    ctx.fillText(win.whisper, win.whisperX, win.whisperY);
                }

                // killer crosshair
                ctx.save();
                ctx.translate(win.mouseX, win.mouseY);
                ctx.rotate(t / 2000);
                ctx.strokeStyle = "rgba(255,26,26,0.9)";
                ctx.lineWidth = 1.4;
                ctx.beginPath(); ctx.arc(0, 0, 10, 0, 6.2832); ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(-16, 0); ctx.lineTo(-6, 0); ctx.moveTo(6, 0); ctx.lineTo(16, 0);
                ctx.moveTo(0, -16); ctx.lineTo(0, -6); ctx.moveTo(0, 6); ctx.lineTo(0, 16);
                ctx.stroke();
                ctx.beginPath(); ctx.arc(0, 0, 1.6, 0, 6.2832);
                ctx.fillStyle = "#ff1a1a";
                ctx.fill();
                ctx.restore();
            }
        }

        // ── HUD ─
        Text { x: 30; y: 26; text: "KILL LIST // " + win.tags.length + " NAMES"; color: cDark; font.family: "monospace"; font.pixelSize: 13; font.bold: true; z: 600 }
        Text { x: 30; y: 46; text: "MARK: " + (win.sel < win.tags.length ? win.tags[win.sel].label.toUpperCase() : "—"); color: cBone; font.family: "monospace"; font.pixelSize: 10; z: 600 }
        Text {
            x: win.width - 90; y: 26
            text: "● REC"
            color: cBright
            font.family: "monospace"
            font.pixelSize: 13
            font.bold: true
            visible: Math.floor(win.frame / 8) % 2 === 0
            z: 600
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            text: "T H E   RED  R O O M"
            color: cBlood
            font.family: "monospace"
            font.pixelSize: 26
            font.bold: true
            z: 600
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 74
            text: "every app dies tonight"
            color: cDim
            font.family: "monospace"
            font.pixelSize: 10
            font.italic: true
            z: 600
        }

        // search = the ledger
        Rectangle {
            x: win.cx - 200; y: win.height - 92
            width: 400; height: 42
            color: "#0d0606"
            border.color: search.activeFocus ? cBlood : "#3a1010"
            border.width: 1
            z: 600
            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "✗"; color: cBright; font.pixelSize: 15 }
            Text { visible: search.text === ""; x: 38; anchors.verticalCenter: parent.verticalCenter; text: "mark your next victim…"; color: cDim; font.family: "monospace"; font.pixelSize: 12 }
            TextInput {
                id: search
                x: 38; anchors.verticalCenter: parent.verticalCenter
                width: 330
                color: cBone
                font.family: "monospace"
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchSel(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right) { win.sel = Math.min(win.tags.length - 1, win.sel + 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Left) { win.sel = Math.max(0, win.sel - 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { win.sel = Math.min(win.tags.length - 1, win.sel + win.cols); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { win.sel = Math.max(0, win.sel - win.cols); event.accepted = true; }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 34
            text: "HOVER = MARK · CLICK / ↵ = KILL · WHEEL / ARROWS = NEXT VICTIM · ESC = ESCAPE THE ROOM"
            color: cDim
            font.family: "monospace"
            font.pixelSize: 10
            opacity: 0.9
            z: 600
        }
    }
}
