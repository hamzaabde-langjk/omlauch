import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cCyan: "#4fd8ff"
    readonly property color cIce: "#eaf7ff"
    readonly property color cGold: "#ffb347"
    readonly property color cRed: "#ff4757"
    readonly property color cDim: "#4a7a9a"
    readonly property color cBg: "#04101d"

    PanelWindow {
        id: win
        objectName: "launcher"
        visible: true
        focusable: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        property string query: ""
        property string pending: ""
        property var deck: []
        property int sel: 0
        property real rot: 0
        property bool bootDone: false
        property int bootStep: 0
        property bool launching: false
        property real lungeT: 0
        property real beamX: 0
        property real beamY: 0
        property var icons: ({})
        property int frame: 0
        property string telem1: "0x0000"
        property string telem2: "0x0000"
        property string term: "alacritty"

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 520; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); win.deck = win.computeDeck(); win.sel = 0; } }
        Timer {
            interval: 80; repeat: true; running: true
            onTriggered: {
                win.frame++;
                win.telem1 = "0x" + Math.floor(Math.random() * 65535).toString(16).toUpperCase().padStart(4, "0");
                win.telem2 = "0x" + Math.floor(Math.random() * 65535).toString(16).toUpperCase().padStart(4, "0");
                reactorCanvas.requestPaint();
            }
        }
        Timer { interval: 350; running: true; onTriggered: { win.bootStep = 1; } }
        Timer { interval: 750; running: true; onTriggered: { win.bootStep = 2; } }
        Timer { interval: 1150; running: true; onTriggered: { win.bootStep = 3; } }
        Timer { interval: 1500; running: true; onTriggered: { win.bootDone = true; } }

        Component.onCompleted: {
            win.deck = win.computeDeck();
            search.forceActiveFocus();
        }
        Timer { interval: 1600; running: true; onTriggered: search.forceActiveFocus() }

        function computeDeck() {
            const q = win.query;
            const apps = AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1);
            const R1 = Math.min(win.width, win.height) * 0.36;
            const R2 = R1 + 110;
            const cap1 = Math.min(apps.length, 16);
            const out = [];
            for (let i = 0; i < apps.length; i++) {
                if (i < cap1) out.push({ app: apps[i], a: (i / cap1) * 6.283 - 1.5708, ring: R1 });
                else {
                    const j = i - cap1, m = apps.length - cap1;
                    out.push({ app: apps[i], a: (j / Math.max(1, m)) * 6.283 - 1.5708 + 0.2, ring: R2 });
                }
            }
            return out;
        }
        function chipPos(i) {
            const d = deck[i];
            const a = d.a + rot;
            return Qt.point(cx + Math.cos(a) * d.ring, cy + Math.sin(a) * d.ring * 0.78);
        }
        function launchApp(a) {
            if (!a || !a.exec) return;
            const p = win.chipPos(win.sel);
            win.beamX = p.x; win.beamY = p.y;
            win.lungeT = Date.now();
            win.launching = true;
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            win.quitTimer.start();
        }
        function launchSel() {
            if (sel >= 0 && sel < deck.length) win.launchApp(deck[sel].app);
        }

        Rectangle { anchors.fill: parent; color: cBg }

        // vignette + frame
        Canvas {
            id: frameCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const g = ctx.createRadialGradient(win.cx, win.cy, win.height * 0.3, win.cx, win.cy, win.height * 0.95);
                g.addColorStop(0, "rgba(0,0,0,0)");
                g.addColorStop(1, "rgba(0,0,0,0.6)");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, win.width, win.height);
                // corner brackets
                ctx.strokeStyle = "rgba(79,216,255,0.5)";
                ctx.lineWidth = 2;
                const L = 34, m = 18;
                ctx.beginPath();
                ctx.moveTo(m, m + L); ctx.lineTo(m, m); ctx.lineTo(m + L, m);
                ctx.moveTo(win.width - m - L, m); ctx.lineTo(win.width - m, m); ctx.lineTo(win.width - m, m + L);
                ctx.moveTo(win.width - m, win.height - m - L); ctx.lineTo(win.width - m, win.height - m); ctx.lineTo(win.width - m - L, win.height - m);
                ctx.moveTo(m + L, win.height - m); ctx.lineTo(m, win.height - m); ctx.lineTo(m, win.height - m - L);
                ctx.stroke();
            }
        }

        MouseArea {
            anchors.fill: parent
            property real lastX: 0
            property real pressX: 0
            property bool dragged: false
            onPressed: (mouse) => { lastX = mouse.x; pressX = mouse.x; dragged = false; }
            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const dx = mouse.x - lastX;
                if (Math.abs(mouse.x - pressX) > 6) dragged = true;
                win.rot += dx * 0.004;
                lastX = mouse.x;
            }
            onClicked: { if (!dragged) Qt.quit(); }
            onWheel: (wheel) => {
                const n = win.deck.length;
                if (n) win.sel = (win.sel + (wheel.angleDelta.y > 0 ? 1 : -1) + n) % n;
                wheel.accepted = true;
            }
        }

        // ── ARC REACTOR + beams ──
        Canvas {
            id: reactorCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();
                const cx = win.cx, cy = win.cy;
                const pulse = 0.5 + 0.5 * Math.sin(t / 450);

                // outer segmented ring (cw)
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(t / 4000);
                ctx.setLineDash([34, 14]);
                ctx.beginPath(); ctx.arc(0, 0, 118, 0, 6.2832);
                ctx.strokeStyle = "rgba(79,216,255,0.55)"; ctx.lineWidth = 5; ctx.stroke();
                ctx.setLineDash([]);
                ctx.restore();

                // mid ring (ccw)
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(-t / 2600);
                ctx.setLineDash([10, 8]);
                ctx.beginPath(); ctx.arc(0, 0, 96, 0, 6.2832);
                ctx.strokeStyle = "rgba(79,216,255,0.8)"; ctx.lineWidth = 2.5; ctx.stroke();
                ctx.setLineDash([]);
                ctx.restore();

                // tick ring
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(t / 6000);
                for (let k = 0; k < 36; k++) {
                    ctx.rotate(6.2832 / 36);
                    ctx.beginPath();
                    ctx.moveTo(0, -82); ctx.lineTo(0, k % 3 === 0 ? -74 : -78);
                    ctx.strokeStyle = "rgba(234,247,255,0.5)"; ctx.lineWidth = 1.5;
                    ctx.stroke();
                }
                ctx.restore();

                // core glow
                const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, 70);
                g.addColorStop(0, "rgba(234,247,255," + (0.75 + 0.2 * pulse) + ")");
                g.addColorStop(0.35, "rgba(79,216,255,0.5)");
                g.addColorStop(1, "rgba(79,216,255,0)");
                ctx.fillStyle = g;
                ctx.fillRect(cx - 70, cy - 70, 140, 140);

                // triangle core
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(t / 3000);
                ctx.beginPath();
                for (let k = 0; k < 3; k++) {
                    const a = k * 2.0944 - 1.5708;
                    const px = Math.cos(a) * 34, py = Math.sin(a) * 34;
                    if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                }
                ctx.closePath();
                ctx.strokeStyle = "#eaf7ff";
                ctx.lineWidth = 2.5;
                ctx.stroke();
                ctx.restore();

                // repulsor beam on launch
                if (win.launching) {
                    const pr = Math.min(1, (t - win.lungeT) / 520);
                    ctx.save();
                    ctx.globalAlpha = 1 - pr;
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.lineTo(win.beamX, win.beamY);
                    ctx.strokeStyle = "rgba(79,216,255,0.5)";
                    ctx.lineWidth = 10;
                    ctx.stroke();
                    ctx.strokeStyle = "#eaf7ff";
                    ctx.lineWidth = 3;
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.arc(win.beamX, win.beamY, 8 + pr * 90, 0, 6.2832);
                    ctx.strokeStyle = "rgba(234,247,255," + (0.9 * (1 - pr)).toFixed(3) + ")";
                    ctx.lineWidth = 2.5;
                    ctx.stroke();
                    ctx.restore();
                }
            }
        }

        // ── holo chips ──
        Repeater {
            model: win.deck
            delegate: Item {
                id: chip
                readonly property bool selHere: index === win.sel
                readonly property point p: win.chipPos(index)
                readonly property real depth: (Math.sin(win.deck[index].a + win.rot) + 1) / 2
                property bool entered: false
                x: p.x - 46
                y: p.y - 30
                z: 100 + Math.round(depth * 60)
                width: 92; height: 60
                scale: (0.85 + 0.3 * depth) * (entered ? 1 : 0.5) * (selHere ? 1.25 : 1)
                opacity: entered ? (0.45 + 0.55 * depth) : 0
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 240 } }
                Timer { interval: 30 * index; running: true; onTriggered: chip.entered = true }

                Rectangle {
                    anchors.fill: parent
                    color: selHere ? "#1a3a52" : "#0a1e30"
                    border.color: selHere ? cGold : "#2a5a7a"
                    border.width: selHere ? 2 : 1
                }
                Rectangle { x: 0; y: 0; width: 8; height: 2; color: cCyan }
                Rectangle { x: parent.width - 8; y: parent.height - 2; width: 8; height: 2; color: cCyan }

                Image {
                    id: ico
                    x: 8; y: 14
                    width: 30; height: 30
                    source: (modelData.app && modelData.app.icon) ? "file://" + modelData.app.icon : ""
                    sourceSize: Qt.size(64, 64)
                    asynchronous: true
                    Component.onCompleted: { win.icons[index] = ico; }
                }
                Text {
                    visible: !modelData.app.icon || ico.status !== Image.Ready
                    x: 14; y: 18
                    text: modelData.app.label ? modelData.app.label.charAt(0).toUpperCase() : ""
                    color: cCyan
                    font.family: "monospace"
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    x: 44; y: 12
                    width: 44
                    elide: Text.ElideRight
                    text: modelData.app.label
                    color: selHere ? cIce : "#9fc8e0"
                    font.family: "monospace"
                    font.pixelSize: 9
                    font.bold: selHere
                }
                Text {
                    x: 44; y: 26
                    text: "PWR " + String(80 + Math.floor(depth * 19))
                    color: selHere ? cGold : cDim
                    font.family: "monospace"
                    font.pixelSize: 8
                }
                Text {
                    x: 4; y: 48
                    text: String(index + 1).padStart(2, "0")
                    color: cDim
                    font.family: "monospace"
                    font.pixelSize: 8
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { win.sel = index; }
                    onClicked: { win.launchApp(modelData.app); }
                }
            }
        }

        // ── zoom preview card ──
        Item {
            id: zoomCard
            readonly property point zp: win.sel < win.deck.length ? win.chipPos(win.sel) : Qt.point(win.cx, win.cy)
            x: Math.max(16, Math.min(win.width - 196, zp.x - 90))
            y: zp.y > 300 ? zp.y - 216 : zp.y + 66
            width: 180; height: 150
            z: 800
            visible: win.deck.length > 0 && !win.launching && win.bootDone
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                color: "#0a1e30"
                opacity: 0.95
                border.color: cGold
                border.width: 2
            }
            Rectangle { x: 0; y: 0; width: 14; height: 3; color: cCyan }
            Rectangle { x: parent.width - 14; y: parent.height - 3; width: 14; height: 3; color: cCyan }
            Image {
                id: zoomIcon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                width: 72; height: 72
                source: (win.sel < win.deck.length && win.deck[win.sel].app.icon) ? "file://" + win.deck[win.sel].app.icon : ""
                sourceSize: Qt.size(128, 128)
                asynchronous: true
            }
            Text {
                visible: win.sel < win.deck.length && (!win.deck[win.sel].app.icon || zoomIcon.status !== Image.Ready)
                anchors.horizontalCenter: parent.horizontalCenter
                y: 30
                text: win.sel < win.deck.length ? win.deck[win.sel].app.label.charAt(0).toUpperCase() : ""
                color: cCyan
                font.family: "monospace"
                font.pixelSize: 40
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 94
                width: 170
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: win.sel < win.deck.length ? win.deck[win.sel].app.label : ""
                color: cIce
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 112
                width: 170
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: win.sel < win.deck.length ? win.deck[win.sel].app.cat : ""
                color: cDim
                font.family: "monospace"
                font.pixelSize: 9
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 128
                text: "↵ = LAUNCH"
                color: cGold
                font.family: "monospace"
                font.pixelSize: 9
                visible: Math.floor(win.frame / 8) % 2 === 0
            }
        }

        // ── readout panel ──
        Rectangle {
            x: win.width - 250; y: win.cy - 90
            width: 220; height: 180
            color: "#0a1e30cc"
            border.color: "#2a5a7a"
            z: 300
            Text { x: 14; y: 12; text: "TARGET ANALYSIS"; color: cGold; font.family: "monospace"; font.pixelSize: 10; font.bold: true }
            Text {
                x: 14; y: 34
                width: 190
                elide: Text.ElideRight
                text: win.sel < win.deck.length ? win.deck[win.sel].app.label.toUpperCase() : "—"
                color: cIce
                font.family: "monospace"
                font.pixelSize: 15
                font.bold: true
            }
            Text { x: 14; y: 56; text: win.sel < win.deck.length ? "CLASS: " + win.deck[win.sel].app.cat.toUpperCase() : ""; color: cDim; font.family: "monospace"; font.pixelSize: 9 }
            Text { x: 14; y: 72; text: "STATUS: FRIENDLY · CLEARED"; color: cCyan; font.family: "monospace"; font.pixelSize: 9 }
            Text { x: 14; y: 96; text: "PWR CORE"; color: cDim; font.family: "monospace"; font.pixelSize: 8 }
            Repeater {
                model: 5
                Rectangle {
                    x: 14 + index * 40
                    y: 108
                    width: 34; height: 8
                    color: "#06121e"
                    border.color: "#2a5a7a"
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 1; height: 6
                        radius: 2
                        color: index === 4 ? cGold : cCyan
                        SequentialAnimation on width {
                            loops: Animation.Infinite
                            NumberAnimation { to: 10 + ((index * 53) % 22); duration: 400 + index * 120; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 20 + ((index * 31) % 12); duration: 350 + index * 90; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Text { x: 14; y: 132; text: "MEM " + win.telem1 + "  IO " + win.telem2; color: cDim; font.family: "monospace"; font.pixelSize: 8 }
            Text { x: 14; y: 150; text: "REPULSORS: ARMED"; color: cRed; font.family: "monospace"; font.pixelSize: 8; visible: Math.floor(win.frame / 8) % 2 === 0 }
        }

        // ── HUD header ──
        Text { x: 30; y: 26; text: "STARK OS // MARK VII"; color: cCyan; font.family: "monospace"; font.pixelSize: 13; font.bold: true; z: 300 }
        Text { x: 30; y: 46; text: "ARC REACTOR OUTPUT: 8.4 GJ · " + win.telem1; color: cDim; font.family: "monospace"; font.pixelSize: 9; z: 300 }
        Text { x: win.width - 160; y: 26; text: win.deck.length + " SYSTEMS"; color: cGold; font.family: "monospace"; font.pixelSize: 12; font.bold: true; z: 300 }

        // search
        Rectangle {
            x: win.cx - 190; y: win.height - 92
            width: 380; height: 42
            color: "#0a1e30cc"
            border.color: search.activeFocus ? cCyan : "#2a5a7a"
            border.width: 1
            z: 300
            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "»"; color: cGold; font.family: "monospace"; font.pixelSize: 15 }
            Text { visible: search.text === ""; x: 36; anchors.verticalCenter: parent.verticalCenter; text: "query the mainframe…"; color: cDim; font.family: "monospace"; font.pixelSize: 12 }
            TextInput {
                id: search
                x: 36; anchors.verticalCenter: parent.verticalCenter
                width: 310
                color: cIce
                font.family: "monospace"
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchSel(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { const n = win.deck.length; if (n) win.sel = (win.sel + 1) % n; event.accepted = true; }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { const n = win.deck.length; if (n) win.sel = (sel - 1 + n) % n; event.accepted = true; }
                }
            }
        }

        // ── boot sequence ──
        Rectangle {
            anchors.fill: parent
            color: "#020a14"
            opacity: win.bootDone ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 450 } }
            z: 900
            Text { anchors.centerIn: parent; y: -40; text: "STARK INDUSTRIES"; color: cGold; font.family: "monospace"; font.pixelSize: 24; font.bold: true }
            Text { anchors.centerIn: parent; y: 0; text: "> ARC REACTOR ONLINE"; color: cCyan; font.family: "monospace"; font.pixelSize: 12; visible: win.bootStep >= 1 }
            Text { anchors.centerIn: parent; y: 22; text: "> CALIBRATING HUD RINGS…"; color: cCyan; font.family: "monospace"; font.pixelSize: 12; visible: win.bootStep >= 2 }
            Text { anchors.centerIn: parent; y: 44; text: "> MARK VII READY. WELCOME BACK, BOSS."; color: cIce; font.family: "monospace"; font.pixelSize: 12; visible: win.bootStep >= 3 }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 34
            text: "DRAG = SPIN ORBIT · WHEEL/ARROWS = CYCLE · HOVER = LOCK · CLICK/↵ = REPULSOR LAUNCH · ESC = POWER DOWN"
            color: cDim
            font.family: "monospace"
            font.pixelSize: 10
            opacity: 0.9
            z: 300
        }
    }
}
