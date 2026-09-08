import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property var candy: ["#ff6b8a", "#ffb347", "#ffe066", "#69db7c", "#4dabf7", "#b197fc", "#f783ac", "#63e6be"]
    readonly property color cInk: "#4a3f35"
    readonly property color cDim: "#a0937f"

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
        property var bubbles: []
        property int sel: 0
        property int poppingIdx: -1
        property real popT: 0
        property real jumpT: -9999
        property var parts: []
        property var icons: ({})
        property int frame: 0
        property real mouseX: 0
        property real mouseY: 0
        property string term: "alacritty"

        readonly property int cols: Math.max(4, Math.min(8, Math.floor((width - 100) / 128)))
        readonly property real ox: (width - (cols * 128 - 12)) / 2
        readonly property real oy: 170

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 700; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); win.buildBubbles(); } }
        Timer {
            interval: 80; repeat: true; running: true
            onTriggered: { win.frame++; fxCanvas.requestPaint(); }
        }

        Component.onCompleted: {
            win.buildBubbles();
            win.confettiBurst(width / 2, 120, 60);
            search.forceActiveFocus();
        }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }

        function rnd(i, s) { const x = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); }

        function buildBubbles() {
            const q = win.query;
            win.bubbles = AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1)
                .slice(0, 40);
            win.sel = 0;
        }

        function confettiBurst(x, y, n) {
            for (let k = 0; k < n; k++) {
                const a = -1.5708 + (Math.random() - 0.5) * 2.4;
                const sp = 4 + Math.random() * 8;
                win.parts.push({
                    x: x, y: y,
                    vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
                    rot: Math.random() * 6.28, vr: (Math.random() - 0.5) * 0.4,
                    col: root.candy[Math.floor(Math.random() * root.candy.length)],
                    t0: Date.now(), life: 900 + Math.random() * 900,
                    sz: 4 + Math.random() * 5, round: Math.random() < 0.4
                });
            }
        }

        function launchApp(a, idx) {
            if (!a || !a.exec) return;
            win.poppingIdx = idx;
            win.popT = Date.now();
            win.jumpT = Date.now();
            const bx = win.ox + (idx % win.cols) * 128 + 60;
            const by = win.oy + Math.floor(idx / win.cols) * 132 + 60;
            win.confettiBurst(bx, by, 40);
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            quitTimer.start();
        }
        function launchSel() {
            if (win.sel >= 0 && win.sel < win.bubbles.length)
                win.launchApp(win.bubbles[win.sel], win.sel);
        }

        // ── candy sky ──
        Canvas {
            id: skyCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const g = ctx.createLinearGradient(0, 0, win.width, win.height);
                g.addColorStop(0, "#ffe9f0");
                g.addColorStop(0.5, "#fff7e0");
                g.addColorStop(1, "#e0f7fa");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, win.width, win.height);
                // polka dots
                for (let y = 0, r = 0; y < win.height + 40; y += 46, r++) {
                    for (let x = (r % 2) * 23; x < win.width + 40; x += 46) {
                        ctx.beginPath();
                        ctx.arc(x, y, 3, 0, 6.2832);
                        ctx.fillStyle = "rgba(255,255,255,0.5)";
                        ctx.fill();
                    }
                }
                // soft rainbow arc top-left
                const cols = ["#ff6b8a", "#ffb347", "#ffe066", "#69db7c", "#4dabf7", "#b197fc"];
                for (let i = 0; i < 6; i++) {
                    ctx.beginPath();
                    ctx.arc(-60, -60, 190 + i * 14, 0, 1.5708);
                    ctx.strokeStyle = cols[i] + "55";
                    ctx.lineWidth = 10;
                    ctx.stroke();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onPositionChanged: (mouse) => { win.mouseX = mouse.x; win.mouseY = mouse.y; }
            onClicked: Qt.quit()
            onWheel: (wheel) => {
                const n = win.bubbles.length;
                if (n) win.sel = (win.sel + (wheel.angleDelta.y > 0 ? 1 : -1) + n) % n;
                wheel.accepted = true;
            }
        }

        // ── candy bubbles ──
        Repeater {
            model: win.bubbles
            delegate: Item {
                id: bub
                readonly property bool selHere: index === win.sel
                readonly property color myCol: root.candy[index % root.candy.length]
                property bool entered: false
                x: win.ox + (index % win.cols) * 128
                y: win.oy + Math.floor(index / win.cols) * 132
                width: 120; height: 126
                rotation: (win.rnd(index, 9) - 0.5) * 8
                scale: entered ? (selHere ? 1.14 : 1) : 0
                Behavior on scale { NumberAnimation { duration: selHere ? 220 : 420; easing.type: Easing.OutBack } }
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Timer { interval: 50 * index; running: true; onTriggered: bub.entered = true }

                // bubble
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: 96; height: 96
                    radius: 48
                    color: "#ffffff"
                    border.color: bub.myCol
                    border.width: bub.selHere ? 5 : 3
                    Rectangle {
                        x: 16; y: 12
                        width: 26; height: 16
                        radius: 10
                        rotation: -25
                        color: "#66ffffff"
                    }
                }
                Image {
                    id: ico
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    width: 52; height: 52
                    source: (modelData && modelData.icon) ? "file://" + modelData.icon : ""
                    sourceSize: Qt.size(64, 64)
                    asynchronous: true
                    Component.onCompleted: { win.icons[index] = ico; }
                }
                Text {
                    visible: !modelData.icon || ico.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 32
                    text: modelData.label ? modelData.label.charAt(0).toUpperCase() : ""
                    color: bub.myCol
                    font.pixelSize: 26
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 100
                    width: 116
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: cInk
                    font.pixelSize: 11
                    font.bold: bub.selHere
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { win.sel = index; }
                    onClicked: { win.launchApp(modelData, index); }
                }
            }
        }

        // ── FX: mascot cat, balloons, confetti, WOOHOO ──
        Canvas {
            id: fxCanvas
            anchors.fill: parent
            z: 500
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();

                // floating balloons
                for (let i = 0; i < 5; i++) {
                    const speed = 0.02 + win.rnd(i, 1) * 0.02;
                    const y = win.height + 80 - ((t * speed + win.rnd(i, 2) * (win.height + 200)) % (win.height + 200));
                    const x = win.rnd(i, 3) * win.width + Math.sin(t / 1500 + i * 2) * 30;
                    ctx.strokeStyle = "rgba(74,63,53,0.25)";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(x, y + 26);
                    ctx.quadraticCurveTo(x + Math.sin(t / 700 + i) * 6, y + 50, x, y + 70);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.ellipse(x, y, 20, 25, 0, 0, 6.2832);
                    ctx.fillStyle = root.candy[i % 8] + "cc";
                    ctx.fill();
                    ctx.beginPath();
                    ctx.ellipse(x - 7, y - 9, 5, 8, -0.5, 0, 6.2832);
                    ctx.fillStyle = "rgba(255,255,255,0.5)";
                    ctx.fill();
                }

                // ── mascot cat (bottom center) ──
                const jt = t - win.jumpT;
                const jump = jt < 600 ? Math.sin(jt / 600 * Math.PI) * 46 : 0;
                const mx = win.width / 2, my = win.height - 90 - jump;
                const blink = (t % 3200) < 140;
                // look at cursor
                const la = Math.atan2(win.mouseY - my, win.mouseX - mx);
                const lx = Math.cos(la) * 4, ly = Math.sin(la) * 3;

                ctx.save();
                ctx.translate(mx, my);
                const squash = jt < 600 ? 1 + Math.sin(jt / 600 * Math.PI) * 0.12 : 1 + Math.sin(t / 600) * 0.02;
                ctx.scale(2 - squash, squash);
                // ears
                ctx.fillStyle = "#ffb347";
                ctx.beginPath(); ctx.moveTo(-34, -34); ctx.lineTo(-22, -62); ctx.lineTo(-8, -40); ctx.closePath(); ctx.fill();
                ctx.beginPath(); ctx.moveTo(34, -34); ctx.lineTo(22, -62); ctx.lineTo(8, -40); ctx.closePath(); ctx.fill();
                ctx.fillStyle = "#ff8fab";
                ctx.beginPath(); ctx.moveTo(-27, -38); ctx.lineTo(-21, -53); ctx.lineTo(-14, -41); ctx.closePath(); ctx.fill();
                ctx.beginPath(); ctx.moveTo(27, -38); ctx.lineTo(21, -53); ctx.lineTo(14, -41); ctx.closePath(); ctx.fill();
                // head
                ctx.beginPath(); ctx.arc(0, 0, 46, 0, 6.2832);
                ctx.fillStyle = "#ffcf6e";
                ctx.fill();
                ctx.strokeStyle = "#e8a33d";
                ctx.lineWidth = 2;
                ctx.stroke();
                // blush
                ctx.fillStyle = "rgba(255,143,171,0.55)";
                ctx.beginPath(); ctx.ellipse(-26, 12, 9, 6, 0, 0, 6.2832); ctx.fill();
                ctx.beginPath(); ctx.ellipse(26, 12, 9, 6, 0, 0, 6.2832); ctx.fill();
                // eyes follow cursor (or happy arcs when jumping)
                if (jump > 4) {
                    ctx.strokeStyle = "#4a3f35";
                    ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.arc(-15, -6, 8, Math.PI, 0); ctx.stroke();
                    ctx.beginPath(); ctx.arc(15, -6, 8, Math.PI, 0); ctx.stroke();
                } else if (blink) {
                    ctx.strokeStyle = "#4a3f35";
                    ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.moveTo(-22, -6); ctx.lineTo(-8, -6); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(8, -6); ctx.lineTo(22, -6); ctx.stroke();
                } else {
                    ctx.fillStyle = "#ffffff";
                    ctx.beginPath(); ctx.ellipse(-15, -6, 9, 10, 0, 0, 6.2832); ctx.fill();
                    ctx.beginPath(); ctx.ellipse(15, -6, 9, 10, 0, 0, 6.2832); ctx.fill();
                    ctx.fillStyle = "#4a3f35";
                    ctx.beginPath(); ctx.arc(-15 + lx, -6 + ly, 4.5, 0, 6.2832); ctx.fill();
                    ctx.beginPath(); ctx.arc(15 + lx, -6 + ly, 4.5, 0, 6.2832); ctx.fill();
                }
                // mouth
                ctx.strokeStyle = "#4a3f35";
                ctx.lineWidth = 2.5;
                ctx.beginPath(); ctx.arc(0, 10, 8, 0.2, Math.PI - 0.2); ctx.stroke();
                // whiskers
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(-46, 0); ctx.lineTo(-62, -4);
                ctx.moveTo(-46, 8); ctx.lineTo(-62, 10);
                ctx.moveTo(46, 0); ctx.lineTo(62, -4);
                ctx.moveTo(46, 8); ctx.lineTo(62, 10);
                ctx.stroke();
                ctx.restore();

                // confetti
                for (let i = win.parts.length - 1; i >= 0; i--) {
                    const p = win.parts[i];
                    const age = t - p.t0;
                    if (age > p.life) { win.parts.splice(i, 1); continue; }
                    p.x += p.vx; p.y += p.vy;
                    p.vy += 0.18;
                    p.vx *= 0.99;
                    p.rot += p.vr;
                    ctx.save();
                    ctx.translate(p.x, p.y);
                    ctx.rotate(p.rot);
                    ctx.globalAlpha = 1 - age / p.life;
                    ctx.fillStyle = p.col;
                    if (p.round) { ctx.beginPath(); ctx.arc(0, 0, p.sz / 2, 0, 6.2832); ctx.fill(); }
                    else ctx.fillRect(-p.sz / 2, -p.sz / 4, p.sz, p.sz / 2);
                    ctx.restore();
                }

                // WOOHOO stamp
                if (jt < 700 && jt >= 0) {
                    ctx.save();
                    ctx.translate(win.width / 2, win.height / 2 - 40);
                    ctx.rotate(-0.12 + Math.sin(jt / 120) * 0.02);
                    const s = 1 + (1 - Math.min(1, jt / 200)) * 0.6;
                    ctx.scale(s, s);
                    ctx.font = "bold 52px sans-serif";
                    ctx.textAlign = "center";
                    ctx.fillStyle = "#ff6b8a";
                    ctx.strokeStyle = "#ffffff";
                    ctx.lineWidth = 8;
                    ctx.strokeText("WOOHOO!!", 0, 0);
                    ctx.fillText("WOOHOO!!", 0, 0);
                    ctx.restore();
                }
            }
        }

        // ── header ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 34
            text: "🎉  T A - D A !  🎉"
            color: cInk
            font.pixelSize: 28
            font.bold: true
            z: 600
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 74
            text: "pick a bubble, any bubble — go on, poke it"
            color: cDim
            font.pixelSize: 12
            font.italic: true
            z: 600
        }

        // search pill
        Rectangle {
            x: win.cx - 190; y: win.height - 84
            width: 380; height: 44
            radius: 22
            color: "#ffffff"
            border.color: search.activeFocus ? "#ff6b8a" : "#e8ddc8"
            border.width: 2
            z: 600
            Text { visible: search.text === ""; anchors.centerIn: parent; text: "🔍  search the party…"; color: cDim; font.pixelSize: 13 }
            TextInput {
                id: search
                anchors.centerIn: parent
                width: 330
                horizontalAlignment: TextInput.AlignHCenter
                color: cInk
                font.pixelSize: 14
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchSel(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { const n = win.bubbles.length; if (n) win.sel = (win.sel + 1) % n; event.accepted = true; }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { const n = win.bubbles.length; if (n) win.sel = (win.sel - 1 + n) % n; event.accepted = true; }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 28
            text: "poke = boing · click / ↵ = POP + confetti · wheel = next bubble · esc = leave the party"
            color: cDim
            font.pixelSize: 10
            opacity: 0.9
            z: 600
        }
    }
}
