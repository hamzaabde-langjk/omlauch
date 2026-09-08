import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cWall: "#1a1410"
    readonly property color cWood: "#3a2a1c"
    readonly property color cNight: "#0d1220"
    readonly property color cAmber: "#ffb347"
    readonly property color cWarm: "#f0a35e"
    readonly property color cCream: "#f5e9d6"
    readonly property color cDim: "#8a7a66"
    readonly property color cRain: "#9fc3e8"

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
        property var results: []
        property var rows: []
        property int sel: 0
        property real spin: 0
        property real spinV: 0.02
        property real armA: -0.35
        property real armTarget: -0.35
        property var rain: []
        property var parts: []
        property int frame: 0
        property string term: "alacritty"

        readonly property real wx: 50
        readonly property real wy: 70
        readonly property real ww: width * 0.36
        readonly property real wh: height - 250
        readonly property real px: width * 0.56
        readonly property real py: height * 0.54
        readonly property real pr: Math.min(150, height * 0.22)

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 650; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); win.rerank(); } }
        Timer {
            interval: 80; repeat: true; running: true
            onTriggered: {
                win.frame++;
                win.spin += win.spinV;
                win.armA += (win.armTarget - win.armA) * 0.12;
                for (let i = 0; i < win.rain.length; i++) {
                    const d = win.rain[i];
                    d.y += d.v;
                    if (d.y > win.wh) { d.y = -20; d.x = Math.random() * win.ww; d.v = 2 + Math.random() * 3; }
                }
                fxCanvas.requestPaint();
            }
        }

        Component.onCompleted: {
            const r = [];
            for (let i = 0; i < 26; i++)
                r.push({ x: Math.random() * 2000, y: Math.random() * 1000, v: 2 + Math.random() * 3 });
            win.rain = r;
            win.rerank();
            search.forceActiveFocus();
        }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }

        function rerank() {
            const q = win.query;
            win.results = AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1);
            win.sel = 0;
            win.syncRows();
        }
        function syncRows() {
            const start = Math.max(0, Math.min(win.results.length - 11, win.sel - 5));
            const out = [];
            for (let i = start; i < Math.min(win.results.length, start + 11); i++)
                out.push({ app: win.results[i], ri: i });
            win.rows = out;
        }
        function moveSel(d) {
            const n = win.results.length;
            if (!n) return;
            win.sel = Math.max(0, Math.min(n - 1, win.sel + d));
            win.armTarget = -0.30 - (win.sel % 6) * 0.035;
            win.syncRows();
        }
        function selApp() {
            return win.sel < win.results.length ? win.results[win.sel].app : null;
        }
        function launchIdx(i) {
            if (i < 0 || i >= win.results.length) return;
            const a = win.results[i];
            if (!a || !a.exec) return;
            win.spinV = 0.16;
            win.armTarget = -0.85;
            for (let k = 0; k < 14; k++)
                win.parts.push({ x: win.px + (Math.random() - 0.5) * 60, y: win.py + (Math.random() - 0.5) * 60, vx: (Math.random() - 0.5) * 2, vy: -Math.random() * 1.5, t0: Date.now(), life: 400 + Math.random() * 300 });
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            quitTimer.start();
        }

        // ── the room ──
        Canvas {
            id: roomCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const g = ctx.createLinearGradient(0, 0, 0, win.height);
                g.addColorStop(0, "#241a12");
                g.addColorStop(1, "#120c08");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, win.width, win.height);

                // window with night city
                ctx.fillStyle = cNight;
                ctx.beginPath();
                ctx.roundRect ? ctx.roundRect(win.wx, win.wy, win.ww, win.wh, 14) : ctx.rect(win.wx, win.wy, win.ww, win.wh);
                ctx.fill();
                ctx.save();
                ctx.beginPath();
                ctx.rect(win.wx, win.wy, win.ww, win.wh);
                ctx.clip();
                const bokeh = ["#f0a35e", "#6ec3f0", "#f7d154", "#e88aa0", "#8ee8c2"];
                for (let i = 0; i < 16; i++) {
                    const bx = win.wx + rnd2(i, 1) * win.ww;
                    const by = win.wy + win.wh * 0.35 + rnd2(i, 2) * win.wh * 0.6;
                    const br = 8 + rnd2(i, 3) * 22;
                    const bg = ctx.createRadialGradient(bx, by, 0, bx, by, br);
                    bg.addColorStop(0, bokeh[i % 5] + "44");
                    bg.addColorStop(1, bokeh[i % 5] + "00");
                    ctx.fillStyle = bg;
                    ctx.fillRect(bx - br, by - br, br * 2, br * 2);
                }
                ctx.restore();
                // frame + sill
                ctx.strokeStyle = cWood;
                ctx.lineWidth = 8;
                ctx.strokeRect(win.wx - 4, win.wy - 4, win.ww + 8, win.wh + 8);
                ctx.fillStyle = "#4a3626";
                ctx.fillRect(win.wx - 14, win.wy + win.wh + 4, win.ww + 28, 12);

                // lamp glow right
                const lg = ctx.createRadialGradient(win.width - 120, 140, 0, win.width - 120, 140, 300);
                lg.addColorStop(0, "rgba(255,179,71,0.16)");
                lg.addColorStop(1, "rgba(255,179,71,0)");
                ctx.fillStyle = lg;
                ctx.fillRect(win.width - 420, 0, 420, 440);

                // turntable deck
                ctx.fillStyle = "#2c2016";
                ctx.beginPath();
                ctx.roundRect ? ctx.roundRect(win.px - win.pr - 40, win.py - win.pr - 30, (win.pr + 40) * 2, (win.pr + 30) * 2, 18) : ctx.rect(win.px - win.pr - 40, win.py - win.pr - 30, (win.pr + 40) * 2, (win.pr + 30) * 2);
                ctx.fill();
                ctx.strokeStyle = "#4a3626";
                ctx.lineWidth = 2;
                ctx.stroke();
            }
            function rnd2(i, s) { const x = Math.sin(i * 91.7 + s * 47.3) * 24634.6345; return x - Math.floor(x); }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
            onWheel: (wheel) => { win.moveSel(wheel.angleDelta.y > 0 ? 1 : -1); wheel.accepted = true; }
        }

        // ── living layer: rain, cat, steam, vinyl, tonearm, vu ──
        Canvas {
            id: fxCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();

                // rain on the window
                ctx.save();
                ctx.beginPath();
                ctx.rect(win.wx, win.wy, win.ww, win.wh);
                ctx.clip();
                ctx.strokeStyle = "rgba(159,195,232,0.35)";
                ctx.lineWidth = 1.2;
                for (let i = 0; i < win.rain.length; i++) {
                    const d = win.rain[i];
                    const x = win.wx + (d.x % win.ww) + Math.sin(d.y / 30 + i) * 2;
                    ctx.beginPath();
                    ctx.moveTo(x, win.wy + d.y);
                    ctx.lineTo(x - 1.5, win.wy + d.y + 10 + d.v * 2);
                    ctx.stroke();
                }
                ctx.restore();

                // cat on the sill
                const sillY = win.wy + win.wh + 4;
                const cx2 = win.wx + win.ww * 0.68;
                ctx.fillStyle = "#0a0806";
                ctx.beginPath();
                ctx.ellipse(cx2, sillY - 12, 30, 14, 0, 0, 6.2832);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(cx2 + 24, sillY - 22, 12, 0, 6.2832);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(cx2 + 16, sillY - 30); ctx.lineTo(cx2 + 20, sillY - 40); ctx.lineTo(cx2 + 25, sillY - 31);
                ctx.moveTo(cx2 + 27, sillY - 31); ctx.lineTo(cx2 + 32, sillY - 40); ctx.lineTo(cx2 + 35, sillY - 29);
                ctx.fill();
                const tail = Math.sin(t / 900) * 0.5;
                ctx.strokeStyle = "#0a0806";
                ctx.lineWidth = 5;
                ctx.beginPath();
                ctx.moveTo(cx2 - 28, sillY - 10);
                ctx.quadraticCurveTo(cx2 - 46, sillY - 18 + tail * 10, cx2 - 40, sillY - 34 + tail * 14);
                ctx.stroke();
                ctx.font = "10px sans-serif";
                ctx.fillStyle = "rgba(245,233,214," + (0.3 + 0.2 * Math.sin(t / 700)).toFixed(3) + ")";
                ctx.fillText("z", cx2 + 40, sillY - 44 - (t / 40 % 12));
                ctx.fillText("z", cx2 + 48, sillY - 56 - (t / 40 % 12));

                // mug + steam
                const mx = win.wx + win.ww * 0.22, my = sillY - 2;
                ctx.fillStyle = "#c96f4a";
                ctx.beginPath();
                ctx.roundRect ? ctx.roundRect(mx - 10, my - 18, 20, 18, 4) : ctx.rect(mx - 10, my - 18, 20, 18);
                ctx.fill();
                ctx.strokeStyle = "#c96f4a";
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(mx + 13, my - 9, 5, -1.2, 1.2);
                ctx.stroke();
                ctx.strokeStyle = "rgba(245,233,214,0.14)";
                ctx.lineWidth = 2;
                for (let k = 0; k < 3; k++) {
                    ctx.beginPath();
                    for (let s = 0; s <= 8; s++) {
                        const yy = my - 22 - s * 6;
                        const xx = mx - 6 + k * 6 + Math.sin(t / 600 + s * 0.7 + k * 2) * 4;
                        if (s === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                    }
                    ctx.stroke();
                }

                // ── the vinyl ──
                const px = win.px, py = win.py, pr = win.pr;
                ctx.beginPath();
                ctx.arc(px, py, pr, 0, 6.2832);
                ctx.fillStyle = "#0c0c0e";
                ctx.fill();
                ctx.strokeStyle = "#26262a";
                for (let g2 = 1; g2 < 7; g2++) {
                    ctx.beginPath();
                    ctx.arc(px, py, pr * (0.45 + g2 * 0.085), 0, 6.2832);
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
                // sheen
                ctx.save();
                ctx.translate(px, py);
                ctx.rotate(t / 3000);
                const sh = ctx.createLinearGradient(-pr, -pr, pr, pr);
                sh.addColorStop(0.42, "rgba(255,255,255,0)");
                sh.addColorStop(0.5, "rgba(255,255,255,0.07)");
                sh.addColorStop(0.58, "rgba(255,255,255,0)");
                ctx.fillStyle = sh;
                ctx.fillRect(-pr, -pr, pr * 2, pr * 2);
                ctx.restore();
                // label (spins) with selected app icon
                ctx.save();
                ctx.translate(px, py);
                ctx.rotate(win.spin);
                ctx.beginPath();
                ctx.arc(0, 0, pr * 0.38, 0, 6.2832);
                ctx.fillStyle = cAmber;
                ctx.fill();
                ctx.beginPath();
                ctx.arc(0, 0, 3, 0, 6.2832);
                ctx.fillStyle = "#120c08";
                ctx.fill();
                const img = selIcon;
                if (img.status === Image.Ready) {
                    ctx.save();
                    ctx.beginPath();
                    ctx.arc(0, 0, pr * 0.30, 0, 6.2832);
                    ctx.clip();
                    ctx.drawImage(img, -pr * 0.28, -pr * 0.28, pr * 0.56, pr * 0.56);
                    ctx.restore();
                }
                ctx.restore();

                // tonearm
                const pivX = px + pr + 26, pivY = py - pr - 12;
                ctx.save();
                ctx.translate(pivX, pivY);
                ctx.rotate(win.armA);
                ctx.strokeStyle = "#c9c9cf";
                ctx.lineWidth = 4;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(-pr * 1.15, pr * 0.75);
                ctx.stroke();
                ctx.fillStyle = "#8a8a92";
                ctx.fillRect(-pr * 1.15 - 5, pr * 0.75 - 4, 12, 10);
                ctx.restore();
                ctx.beginPath();
                ctx.arc(pivX, pivY, 9, 0, 6.2832);
                ctx.fillStyle = "#3a3a40";
                ctx.fill();

                // crackle pops
                for (let i = win.parts.length - 1; i >= 0; i--) {
                    const p = win.parts[i];
                    const age = t - p.t0;
                    if (age > p.life) { win.parts.splice(i, 1); continue; }
                    p.x += p.vx; p.y += p.vy;
                    ctx.fillStyle = "rgba(255,240,210," + (1 - age / p.life).toFixed(3) + ")";
                    ctx.fillRect(p.x, p.y, 2, 2);
                }

                // VU meters
                for (let v = 0; v < 2; v++) {
                    const vx = win.px - 46 + v * 52, vy = win.py + win.pr + 26;
                    ctx.fillStyle = "#181210";
                    ctx.fillRect(vx, vy, 40, 10);
                    const lvl = 8 + Math.abs(Math.sin(t / (180 + v * 70) + v)) * 30;
                    ctx.fillStyle = lvl > 30 ? "#e8843a" : cAmber;
                    ctx.fillRect(vx + 1, vy + 1, lvl, 8);
                }

                // now spinning
                ctx.font = "italic 13px sans-serif";
                ctx.textAlign = "center";
                ctx.fillStyle = "rgba(245,233,214,0.8)";
                const sa = win.selApp();
                ctx.fillText("now spinning: " + (sa ? sa.label : "—"), win.px, win.py + win.pr + 56);
                ctx.textAlign = "left";
            }
        }

        // selected icon loader (single, outside repeater)
        Image {
            id: selIcon
            opacity: 0
            source: {
                const a = win.selApp();
                return a && a.icon ? "file://" + a.icon : "";
            }
            sourceSize: Qt.size(96, 96)
            asynchronous: true
        }

        // ── tracklist queue ──
        Text {
            x: win.width - 320; y: 96
            text: "SIDE A · " + win.results.length + " TRACKS"
            color: cDim
            font.family: "monospace"
            font.pixelSize: 10
            z: 600
        }
        Repeater {
            model: win.rows
            delegate: Item {
                readonly property bool selHere: modelData.ri === win.sel
                x: win.width - 330
                y: 120 + index * 46
                width: 300; height: 42
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: selHere ? "#2e2117" : "transparent"
                }
                Rectangle {
                    visible: selHere
                    x: 0; y: 8
                    width: 3; height: 26
                    radius: 2
                    color: cAmber
                }
                Text {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    text: selHere ? "▶" : String(modelData.ri + 1).padStart(2, "0")
                    color: selHere ? cAmber : cDim
                    font.family: "monospace"
                    font.pixelSize: 10
                }
                Image {
                    x: 36; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    source: (modelData.app && modelData.app.icon) ? "file://" + modelData.app.icon : ""
                    sourceSize: Qt.size(48, 48)
                    asynchronous: true
                }
                Text {
                    x: 70; anchors.verticalCenter: parent.verticalCenter
                    width: 170
                    elide: Text.ElideRight
                    text: modelData.app.label
                    color: selHere ? cCream : "#bfae97"
                    font.pixelSize: 12
                    font.bold: selHere
                }
                Text {
                    x: 252; anchors.verticalCenter: parent.verticalCenter
                    text: "3:" + String(10 + (modelData.ri * 7) % 50)
                    color: cDim
                    font.family: "monospace"
                    font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { win.sel = modelData.ri; win.armTarget = -0.30 - (win.sel % 6) * 0.035; }
                    onClicked: { win.launchIdx(modelData.ri); }
                }
            }
        }

        // ── header + search ──
        Text {
            x: win.wx; y: 26
            text: ""
            color: cCream
            font.pixelSize: 18
            font.italic: true
            z: 600
        }
        Rectangle {
            x: win.cx - 180; y: 20
            width: 360; height: 40
            radius: 20
            color: "#241a12dd"
            border.color: search.activeFocus ? cAmber : "#4a3626"
            z: 600
            Text { visible: search.text === ""; anchors.centerIn: parent; text: "search the crate…"; color: cDim; font.pixelSize: 12; font.italic: true }
            TextInput {
                id: search
                anchors.centerIn: parent
                width: 310
                horizontalAlignment: TextInput.AlignHCenter
                color: cCream
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchIdx(win.sel); event.accepted = true; }
                    else if (event.key === Qt.Key_Down) { win.moveSel(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { win.moveSel(-1); event.accepted = true; }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 30
            text: "hover a track = tonearm swings · click / ↵ = drop the needle · wheel / ↑↓ = flip tracks · esc = lights out"
            color: cDim
            font.pixelSize: 10
            font.italic: true
            opacity: 0.9
            z: 600
        }
    }
}
