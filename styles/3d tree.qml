import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cBg: "#070304"
    readonly property color cPanel: "#160b08"
    readonly property color cBorder: "#3a2012"
    readonly property color cText: "#ffedd5"
    readonly property color cDim: "#a6836b"
    readonly property color cGold: "#fbbf24"
    readonly property color cEmber: "#f97316"

    PanelWindow {
        id: win
        objectName: "launcher"
        visible: true
        focusable: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real cx: width / 2
        readonly property real cy: height / 2 - 10
        property string query: ""
        property real orbit: 0        // auto spin in the ring plane
        property real yaw: 0          // user rotation around Y (360°)
        property real pitch: 0.35     // user rotation around X (360°)
        property real vel: 0
        property real velP: 0
        property var nodes: []
        property var rings: []
        property var drag: ({})
        property int selId: -1
        property int hoverId: -1
        property int huntLock: -1
        property bool lunging: false
        property real lungeT: 0
        property string term: "alacritty"
        readonly property int matchCount: {
            let c = 0;
            for (let i = 0; i < nodes.length; i++) if (win.isMatch(nodes[i])) c++;
            return c;
        }

        onQueryChanged: baseCanvas.requestPaint()
        onNodesChanged: baseCanvas.requestPaint()

        Timer {
            interval: 80; repeat: true; running: true
            onTriggered: {
                win.orbit += 0.0025;
                win.yaw += win.vel;
                win.pitch += win.velP;
                win.vel *= 0.90;
                win.velP *= 0.90;
                fxCanvas.requestPaint();
            }
        }

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 480; onTriggered: Qt.quit() }

        Component.onCompleted: {
            win.buildLayout();
            baseCanvas.requestPaint();
            search.forceActiveFocus();
        }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }

        function rnd(i, s) { const x = Math.sin(i * 127.1 + s * 311.7) * 43758.5453; return x - Math.floor(x); }

        // ── full 3D projection: orbit → yaw(Y) → pitch(X) ──
        function project(a, R) {
            const x0 = Math.cos(a) * R, z0 = Math.sin(a) * R;
            const cyw = Math.cos(yaw), syw = Math.sin(yaw);
            const x1 = x0 * cyw + z0 * syw;
            const z1 = -x0 * syw + z0 * cyw;
            const cp = Math.cos(pitch), sp = Math.sin(pitch);
            const y2 = -z1 * sp;
            const z2 = z1 * cp;
            return { x: x1, y: y2, z: z2 };
        }

        function nodeState(i) {
            const m = nodes[i];
            const p = win.project(m.baseAngle + orbit, m.ringR);
            const depth = (p.z / m.ringR + 1) / 2;
            const d = drag[i];
            return {
                x: cx + p.x + (d ? d.x : 0),
                y: cy + p.y + 20 + (d ? d.y : 0),
                depth: depth,
                scale: 0.62 + 0.5 * depth,
                tilt: (0.5 - depth) * 26
            };
        }

        function hotIndex() {
            if (win.huntLock >= 0 && win.huntLock < win.nodes.length && win.isMatch(win.nodes[win.huntLock])) return win.huntLock;
            if (win.hoverId >= 0 && win.hoverId < win.nodes.length && win.isMatch(win.nodes[win.hoverId])) return win.hoverId;
            if (win.query && win.selId >= 0 && win.selId < win.nodes.length && win.isMatch(win.nodes[win.selId])) return win.selId;
            return -1;
        }

        function buildLayout() {
            const src = AppsDB.list.slice().sort((x, y) => String(x.label).localeCompare(String(y.label)));
            const n = src.length;
            const out = [];
            const ringList = [];
            const minPitch = 70;
            let r = n <= Math.floor(2 * Math.PI * 280 / minPitch) ? 280 : 195;
            let placed = 0;
            let ringIdx = 0;
            while (placed < n) {
                const cap = Math.max(1, Math.floor(2 * Math.PI * r / minPitch));
                const take = Math.min(cap, n - placed);
                ringList.push({ start: placed, count: take, r: r });
                for (let i = 0; i < take; i++) {
                    const a = (i / take) * 2 * Math.PI + ringIdx * 0.35;
                    const app = src[placed + i];
                    out.push({
                        label: app.label, path: app.path, cat: app.cat || "",
                        keywords: app.keywords || "", icon: app.icon || "",
                        exec: app.exec || "", terminal: app.terminal === true,
                        letter: String(app.label).charAt(0).toUpperCase(),
                        baseAngle: a, ringR: r
                    });
                }
                placed += take;
                r += 105;
                ringIdx++;
            }
            rings = ringList;
            nodes = out;
            selId = win.firstMatch();
        }

        function isMatch(m) {
            if (!win.query) return true;
            return (m.label + " " + m.cat + " " + m.keywords).toLowerCase().indexOf(win.query) !== -1;
        }
        function firstMatch() {
            for (let i = 0; i < nodes.length; i++) if (win.isMatch(nodes[i])) return i;
            return -1;
        }
        function navSel(dir) {
            const n = nodes.length;
            if (!n) return;
            let i = selId < 0 ? 0 : selId;
            for (let step = 0; step < n; step++) {
                i = (i + dir + n) % n;
                if (win.isMatch(nodes[i])) { selId = i; return; }
            }
        }
        function dragOf(i) { const d = drag[i]; return d ? d : Qt.point(0, 0); }
        function setDrag(i, x, y) { drag[i] = Qt.point(x, y); dragChanged(); }
        function launchSelected() {
            if (selId >= 0 && selId < nodes.length && win.isMatch(nodes[selId])) {
                huntLock = selId;
                win.launchApp(nodes[selId]);
            }
        }
        function launchApp(a) {
            if (!a || !a.exec) return;
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            win.lungeT = Date.now();
            win.lunging = true;
            win.quitTimer.start();
        }

        Rectangle { anchors.fill: parent; color: "#d8070308" }

        // ── trackball: drag tumbles 360° on X and Y ──
        MouseArea {
            id: spinArea
            anchors.fill: parent
            property real lastX: 0
            property real lastY: 0
            property real pressX: 0
            property bool dragged: false
            onPressed: (mouse) => { lastX = mouse.x; lastY = mouse.y; pressX = mouse.x; dragged = false; }
            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const dx = mouse.x - lastX, dy = mouse.y - lastY;
                if (Math.abs(mouse.x - pressX) > 6) dragged = true;
                win.yaw += dx * 0.005;
                win.pitch += dy * 0.005;
                win.vel = dx * 0.0008;
                win.velP = dy * 0.0008;
                lastX = mouse.x; lastY = mouse.y;
            }
            onReleased: { if (!dragged) Qt.quit(); }
            onWheel: (wheel) => { win.vel += (wheel.angleDelta.y > 0 ? 0.02 : -0.02); wheel.accepted = true; }
        }

        // ── BASE: starfield + forge glow ──
        Canvas {
            id: baseCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                for (let i = 0; i < 120; i++) {
                    ctx.beginPath();
                    ctx.arc(win.rnd(i, 1) * win.width, win.rnd(i, 2) * win.height, 0.4 + win.rnd(i, 3) * 1.2, 0, 6.2832);
                    ctx.fillStyle = "rgba(255,236,200," + (0.08 + win.rnd(i, 5) * 0.25).toFixed(3) + ")";
                    ctx.fill();
                }

                if (!win.rings.length) return;
                const maxR = win.rings[win.rings.length - 1].r;
                const g = ctx.createRadialGradient(win.cx, win.cy + 20, 0, win.cx, win.cy + 20, maxR + 80);
                g.addColorStop(0, "rgba(251,191,36,0.10)");
                g.addColorStop(0.7, "rgba(249,115,22,0.03)");
                g.addColorStop(1, "rgba(249,115,22,0)");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, win.width, win.height);
            }
        }

        // ── FX: projected orbit paths, beams, sparks, core rings, lightning, detonation ──
        Canvas {
            id: fxCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = win.cx, cy = win.cy + 20;
                const n = win.nodes.length;
                const t = Date.now();
                const hi = win.hotIndex();

                // projected orbit rings (follow yaw/pitch)
                for (let r = 0; r < win.rings.length; r++) {
                    ctx.beginPath();
                    for (let s = 0; s <= 64; s++) {
                        const p = win.project(s / 64 * 2 * Math.PI, win.rings[r].r);
                        const px = cx + p.x, py = cy + p.y;
                        if (s === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                    }
                    ctx.strokeStyle = "rgba(251,191,36,0.12)";
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }

                // beams in two depth passes
                for (let pass = 0; pass < 2; pass++) {
                    for (let i = 0; i < n; i++) {
                        const st = win.nodeState(i);
                        if ((pass === 0) !== (st.depth < 0.5)) continue;
                        const m = win.isMatch(win.nodes[i]);
                        const a = m ? (0.05 + 0.30 * st.depth) : 0.02;
                        ctx.beginPath();
                        ctx.moveTo(cx, cy);
                        ctx.lineTo(st.x, st.y);
                        ctx.strokeStyle = "rgba(251,191,36," + a.toFixed(3) + ")";
                        ctx.lineWidth = m ? 1.2 : 0.7;
                        ctx.stroke();
                    }
                }

                // rotating dashed core rings
                ctx.save();
                ctx.translate(win.cx, win.cy);
                ctx.beginPath(); ctx.arc(0, 0, 48, 0, 6.2832);
                ctx.setLineDash([10, 14]); ctx.lineDashOffset = t / 18;
                ctx.strokeStyle = "rgba(251,191,36,0.55)"; ctx.lineWidth = 1.4; ctx.stroke();
                ctx.beginPath(); ctx.arc(0, 0, 60, 0, 6.2832);
                ctx.setLineDash([4, 10]); ctx.lineDashOffset = -t / 26;
                ctx.strokeStyle = "rgba(249,115,22,0.45)"; ctx.lineWidth = 1; ctx.stroke();
                ctx.setLineDash([]);
                ctx.restore();

                // rising forge sparks
                for (let i = 0; i < 36; i++) {
                    const sp = 0.02 + win.rnd(i, 3) * 0.05;
                    const y = win.height + 20 - ((t * sp + win.rnd(i, 2) * (win.height + 60)) % (win.height + 60));
                    const x = win.rnd(i, 1) * win.width + Math.sin(t / 1400 + i) * 14;
                    const a = 0.08 + 0.22 * Math.abs(Math.sin(t / 700 + i * 1.7));
                    ctx.fillStyle = i % 5 === 0 ? "rgba(249,115,22," + a.toFixed(3) + ")" : "rgba(251,191,36," + a.toFixed(3) + ")";
                    ctx.fillRect(x, y, 2, 2);
                }

                // energy pulses
                let pc = 0;
                for (let i = 0; i < n && pc < 20; i++) {
                    if (!win.isMatch(win.nodes[i])) continue;
                    pc++;
                    const st = win.nodeState(i);
                    const f = ((t / 1100) + i * 0.37) % 1;
                    const px = win.cx + (st.x - win.cx) * f, py = win.cy + (st.y - win.cy) * f;
                    ctx.beginPath(); ctx.arc(px, py, 1.6, 0, 6.2832);
                    ctx.fillStyle = "rgba(255,244,214," + (0.7 * Math.sin(f * Math.PI) * st.depth).toFixed(3) + ")";
                    ctx.fill();
                }

                // lightning lock-on
                if (hi >= 0 && !win.lunging) {
                    const st = win.nodeState(hi);
                    const dist = Math.hypot(st.x - win.cx, st.y - win.cy) || 1;
                    ctx.beginPath();
                    for (let s = 0; s <= 9; s++) {
                        const f = s / 9;
                        const bx = win.cx + (st.x - win.cx) * f, by = win.cy + (st.y - win.cy) * f;
                        const amp = (s === 0 || s === 9) ? 0 : Math.sin(t / 40 + s * 7.3) * 9 * Math.sin(f * Math.PI);
                        const px = bx + (st.y - win.cy) / dist * amp;
                        const py = by - (st.x - win.cx) / dist * amp;
                        if (s === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                    }
                    ctx.strokeStyle = "rgba(249,115,22,0.7)"; ctx.lineWidth = 1.6; ctx.stroke();
                    ctx.strokeStyle = "rgba(255,244,214,0.85)"; ctx.lineWidth = 0.6; ctx.stroke();
                }

                // detonation
                if (win.lunging && hi >= 0) {
                    const st = win.nodeState(hi);
                    const pr = Math.min(1, (t - win.lungeT) / 480);
                    ctx.fillStyle = "rgba(255,244,214," + (0.16 * (1 - pr)).toFixed(3) + ")";
                    ctx.fillRect(0, 0, win.width, win.height);
                    ctx.beginPath(); ctx.arc(st.x, st.y, 10 + pr * 95, 0, 6.2832);
                    ctx.strokeStyle = "rgba(251,191,36," + (0.9 * (1 - pr)).toFixed(3) + ")";
                    ctx.lineWidth = 3; ctx.stroke();
                    for (let k = 0; k < 16; k++) {
                        const a = k * 0.3927 + pr * 0.5;
                        ctx.beginPath();
                        ctx.moveTo(st.x + Math.cos(a) * (12 + pr * 40), st.y + Math.sin(a) * (12 + pr * 40));
                        ctx.lineTo(st.x + Math.cos(a) * (20 + pr * 110), st.y + Math.sin(a) * (20 + pr * 110));
                        ctx.strokeStyle = k % 2 ? "rgba(251,191,36," + (0.8 * (1 - pr)).toFixed(3) + ")" : "rgba(249,115,22," + (0.8 * (1 - pr)).toFixed(3) + ")";
                        ctx.lineWidth = 1.5;
                        ctx.stroke();
                    }
                }
            }
        }

        // ── 3D NODES ──
        Repeater {
            model: win.nodes
            delegate: Item {
                id: nd
                readonly property bool m: win.isMatch(modelData)
                readonly property bool isSel: win.selId === index && nd.m
                readonly property bool hot: win.hoverId === index || nd.isSel
                property var st: win.nodeState(index)
                property bool spawned: false
                property real startGX: 0
                property real startGY: 0
                property real baseOX: 0
                property real baseOY: 0
                property bool moved: false
                x: st.x - 22
                y: st.y - 22
                z: Math.round(st.depth * 100)
                width: 44; height: 44
                scale: st.scale * (nd.spawned ? (nd.hot ? 1.14 : 1) : 0)
                opacity: (0.30 + 0.70 * st.depth) * (nd.m ? 1 : 0.06)
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Timer { interval: 60 + index * 10; running: true; onTriggered: nd.spawned = true }

                transform: Rotation {
                    origin.x: 22; origin.y: 22
                    axis { x: 1; y: 0; z: 0 }
                    angle: st.tilt
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 56; height: 56
                    radius: 28
                    color: "transparent"
                    border.color: "#66f97316"
                    border.width: 1.4
                    opacity: nd.hot ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 34; height: 34
                    radius: 9
                    color: nd.hot ? "#2a1206" : cPanel
                    border.color: nd.hot ? cEmber : (nd.m ? cGold : cBorder)
                    border.width: nd.hot ? 1.8 : 1
                }
                Image {
                    visible: modelData.icon !== ""
                    anchors.centerIn: parent
                    width: 24; height: 24
                    source: visible ? "file://" + modelData.icon : ""
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Text {
                    visible: modelData.icon === ""
                    anchors.centerIn: parent
                    text: modelData.letter
                    color: nd.hot ? cEmber : (nd.m ? cGold : "#5c4630")
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    x: -20; y: 44
                    width: 84
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: nd.hot ? cText : cDim
                    font.pixelSize: 10
                    opacity: st.depth > 0.4 ? 1 : 0
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: nd.m
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { win.hoverId = index; win.selId = index; }
                    onExited: { if (win.hoverId === index) win.hoverId = -1; }
                    onPressed: (mouse) => {
                        if (mouse.button !== Qt.LeftButton) return;
                        const g = ma.mapToGlobal(mouse.x, mouse.y);
                        nd.startGX = g.x; nd.startGY = g.y;
                        const d = win.dragOf(index);
                        nd.baseOX = d.x; nd.baseOY = d.y;
                        nd.moved = false;
                    }
                    onPositionChanged: (mouse) => {
                        if (!ma.pressed) return;
                        const g = ma.mapToGlobal(mouse.x, mouse.y);
                        const dx = g.x - nd.startGX, dy = g.y - nd.startGY;
                        if (Math.abs(dx) + Math.abs(dy) > 4) nd.moved = true;
                        if (nd.moved) win.setDrag(index, nd.baseOX + dx, nd.baseOY + dy);
                    }
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) { win.setDrag(index, 0, 0); return; }
                        if (!nd.moved) { win.selId = index; win.huntLock = index; win.launchApp(modelData); }
                    }
                }
            }
        }

        // ── THE CORE ──
        Item {
            id: hub
            x: win.cx - 42
            y: win.cy - 42
            width: 84; height: 84
            z: 50

            Rectangle {
                anchors.fill: parent; anchors.margins: -30; radius: 72
                color: cGold; opacity: 0.05
            }
            Rectangle {
                anchors.fill: parent
                radius: 42
                color: cPanel
                border.color: cGold
                border.width: 2
            }
            Rectangle {
                anchors.centerIn: parent
                width: 30; height: 30
                radius: 15
                color: "#fff7dd"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.75; to: 1; duration: 900 }
                    NumberAnimation { from: 1; to: 0.75; duration: 900 }
                }
            }
        }

        Text {
            visible: search.text === ""
            x: win.cx - 130; y: win.cy - 12
            width: 260; height: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "the forge ignites…"
            color: cDim
            font.pixelSize: 14
            z: 60
        }
        TextInput {
            id: search
            x: win.cx - 130; y: win.cy - 12
            width: 260; height: 24
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            color: cText
            font.pixelSize: 16
            clip: true
            selectByMouse: true
            z: 60
            onTextChanged: { win.query = text.trim().toLowerCase(); win.selId = win.firstMatch(); }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchSelected(); event.accepted = true; }
                else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) { win.navSel(1); event.accepted = true; }
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) { win.navSel(-1); event.accepted = true; }
            }
        }

        Text {
            x: win.cx - 130; y: win.cy + 54
            width: 260
            horizontalAlignment: Text.AlignHCenter
            text: win.query ? win.matchCount + " cores locked"
                            : win.nodes.length + " cores in orbit"
            color: cDim
            font.pixelSize: 11
            z: 60
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 32
            text: "drag → tumble 360° x+y · wheel spin · type → lock · ↵ detonate · esc eject · right-click snap"
            color: cDim
            font.pixelSize: 11
            opacity: 0.75
            z: 60
        }
    }
}

