import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cPink: "#ff2975"
    readonly property color cCyan: "#2de2e6"
    readonly property color cYellow: "#ffd319"
    readonly property color cDeep: "#1a0b2e"
    readonly property color cText: "#fdf6ff"
    readonly property color cDim: "#8a7ba8"

    PanelWindow {
        id: win
        objectName: "launcher"
        visible: true
        focusable: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real cx: width / 2
        readonly property real cy: height / 2 + 40
        readonly property real horizon: height * 0.62
        property string query: ""
        property string pending: ""
        property var deck: []
        property int center: 0
        property bool launching: false
        property var icons: ({})
        property real gridOff: 0
        property string term: "alacritty"

        onQueryChanged: { /* deck rebuilt by debounce below */ }

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 480; onTriggered: Qt.quit() }
        Timer { id: debounce; interval: 70; onTriggered: { win.query = win.pending.trim().toLowerCase(); win.deck = win.computeDeck(); win.center = 0; } }
        Timer { interval: 66; repeat: true; running: true; onTriggered: { win.gridOff = (win.gridOff + 0.016) % 1; sceneCanvas.requestPaint(); } }

        Component.onCompleted: {
            win.deck = win.computeDeck();
            search.forceActiveFocus();
        }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }

        function computeDeck() {
            const q = win.query;
            return AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1);
        }
        function cardX(k) {
            if (k === 0) return 0;
            const a = Math.abs(k);
            return (k > 0 ? 1 : -1) * (125 + (a - 1) * 70);
        }
        function launchApp(a) {
            if (!a || !a.exec) return;
            if (a.terminal) launcher.command = ["setsid", "-f", win.term, "-e", "bash", "-c", String(a.exec)];
            else launcher.command = ["setsid", "-f", "bash", "-c", String(a.exec) + " >/dev/null 2>&1"];
            launcher.running = true;
            win.launching = true;
            win.quitTimer.start();
        }
        function launchCenter() {
            if (win.deck.length > 0 && win.center < win.deck.length)
                win.launchApp(win.deck[win.center]);
        }

        // ── THE OUTRUN SCENE ──
        Canvas {
            id: sceneCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();
                const W = win.width, H = win.height, hz = win.horizon, cx = win.cx;

                // sky
                const sky = ctx.createLinearGradient(0, 0, 0, hz);
                sky.addColorStop(0, "#0d0518");
                sky.addColorStop(0.55, "#2b1055");
                sky.addColorStop(1, "#7597de");
                ctx.fillStyle = sky;
                ctx.fillRect(0, 0, W, hz);

                // stars
                for (let i = 0; i < 70; i++) {
                    const x = ((Math.sin(i * 127.1) * 43758.5 % 1) + 1) % 1 * W;
                    const y = ((Math.sin(i * 311.7) * 43758.5 % 1) + 1) % 1 * hz * 0.8;
                    const tw = 0.3 + 0.6 * Math.abs(Math.sin(t / 800 + i * 1.7));
                    ctx.fillStyle = "rgba(253,246,255," + tw.toFixed(3) + ")";
                    ctx.fillRect(x, y, 1.5, 1.5);
                }

                // striped sun
                const sunY = hz - H * 0.10;
                const sunR = H * 0.17;
                ctx.save();
                ctx.beginPath();
                ctx.arc(cx, sunY, sunR, 0, 6.2832);
                ctx.clip();
                const sg = ctx.createLinearGradient(0, sunY - sunR, 0, sunY + sunR);
                sg.addColorStop(0, "#ffd319");
                sg.addColorStop(0.5, "#ff901f");
                sg.addColorStop(1, "#ff2975");
                ctx.fillStyle = sg;
                ctx.fillRect(cx - sunR, sunY - sunR, sunR * 2, sunR * 2);
                ctx.fillStyle = "#2b1055";
                for (let s = 0; s < 6; s++) {
                    const sy = sunY + s * (sunR / 4.2) + ((t / 60) % (sunR / 4.2)) - sunR / 4.2;
                    ctx.fillRect(cx - sunR, sy, sunR * 2, 2 + s * 1.6);
                }
                ctx.restore();
                // sun glow
                const gg = ctx.createRadialGradient(cx, sunY, sunR * 0.4, cx, sunY, sunR * 2.2);
                gg.addColorStop(0, "rgba(255,41,117,0.25)");
                gg.addColorStop(1, "rgba(255,41,117,0)");
                ctx.fillStyle = gg;
                ctx.fillRect(cx - sunR * 2.2, sunY - sunR * 2.2, sunR * 4.4, sunR * 4.4);

                // mountains
                ctx.fillStyle = "#140825";
                ctx.beginPath();
                ctx.moveTo(0, hz);
                ctx.lineTo(W * 0.10, hz - H * 0.10);
                ctx.lineTo(W * 0.22, hz - H * 0.03);
                ctx.lineTo(W * 0.33, hz - H * 0.12);
                ctx.lineTo(W * 0.46, hz);
                ctx.closePath();
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(W * 0.55, hz);
                ctx.lineTo(W * 0.68, hz - H * 0.11);
                ctx.lineTo(W * 0.80, hz - H * 0.04);
                ctx.lineTo(W * 0.92, hz - H * 0.13);
                ctx.lineTo(W, hz);
                ctx.closePath();
                ctx.fill();
                ctx.strokeStyle = "rgba(255,41,117,0.6)";
                ctx.lineWidth = 1.2;
                ctx.beginPath();
                ctx.moveTo(0, hz); ctx.lineTo(W * 0.10, hz - H * 0.10); ctx.lineTo(W * 0.22, hz - H * 0.03); ctx.lineTo(W * 0.33, hz - H * 0.12); ctx.lineTo(W * 0.46, hz);
                ctx.moveTo(W * 0.55, hz); ctx.lineTo(W * 0.68, hz - H * 0.11); ctx.lineTo(W * 0.80, hz - H * 0.04); ctx.lineTo(W * 0.92, hz - H * 0.13); ctx.lineTo(W, hz);
                ctx.stroke();

                // ground
                const gr = ctx.createLinearGradient(0, hz, 0, H);
                gr.addColorStop(0, "#12042e");
                gr.addColorStop(1, "#05010d");
                ctx.fillStyle = gr;
                ctx.fillRect(0, hz, W, H - hz);

                // horizon glow line
                ctx.fillStyle = "rgba(45,226,230,0.8)";
                ctx.fillRect(0, hz - 1, W, 2);

                // perspective grid: horizontal lines scrolling toward you
                for (let i = 0; i < 16; i++) {
                    const p = (i + win.gridOff) / 16;
                    const y = hz + (H - hz) * p * p;
                    ctx.strokeStyle = "rgba(45,226,230," + (0.10 + 0.45 * p).toFixed(3) + ")";
                    ctx.lineWidth = 1 + p * 1.5;
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(W, y);
                    ctx.stroke();
                }
                // vertical fan
                for (let k = -14; k <= 14; k++) {
                    ctx.strokeStyle = "rgba(255,41,117,0.22)";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(cx + k * 26, hz);
                    ctx.lineTo(cx + k * 170, H + 30);
                    ctx.stroke();
                }
            }
        }

        // escape hatch + wheel
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
            onWheel: (wheel) => {
                win.center = Math.max(0, Math.min(win.deck.length - 1, win.center + (wheel.angleDelta.y > 0 ? 1 : -1)));
                wheel.accepted = true;
            }
        }

        // launch flash
        Rectangle {
            anchors.fill: parent
            color: "#ffd319"
            opacity: win.launching ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            z: 500
        }

        // ── neon coverflow deck ──
        Repeater {
            model: win.deck
            delegate: Item {
                id: card
                readonly property int k: index - win.center
                readonly property int ak: Math.abs(k)
                property bool entered: false
                width: 120; height: 140
                x: win.cx - 60 + win.cardX(k)
                y: win.cy - 70 + ak * 10
                z: 200 - ak
                scale: (k === 0 ? 1.16 : (ak === 1 ? 0.94 : 0.82)) * (entered ? 1 : 0.6)
                opacity: ak > 4 ? 0 : (entered ? (k === 0 ? 1 : 0.8 - ak * 0.14) : 0)
                visible: ak <= 4
                Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: win.launching && k === 0 ? 420 : 340; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                transform: Rotation {
                    origin.x: 60; origin.y: 70
                    axis { x: 0; y: 1; z: 0 }
                    angle: k === 0 ? 0 : (k > 0 ? -44 : 44)
                    Behavior on angle { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                }
                Component.onCompleted: { entered = true; }

                // neon glow frame
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -7
                    radius: 20
                    color: "transparent"
                    border.color: k === 0 ? "#66ff2975" : "#332de2e6"
                    border.width: 2
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "#cc12081f"
                    border.color: k === 0 ? cPink : cCyan
                    border.width: k === 0 ? 2 : 1
                }
                // top neon strip
                Rectangle {
                    x: 8; y: 0
                    width: parent.width - 16; height: 2
                    color: k === 0 ? cPink : cCyan
                    opacity: 0.9
                }
                Image {
                    id: ico
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 24
                    width: 56; height: 56
                    source: (modelData && modelData.icon) ? "file://" + modelData.icon : ""
                    sourceSize: Qt.size(96, 96)
                    asynchronous: true
                    Component.onCompleted: { win.icons[index] = ico; }
                }
                Text {
                    visible: !modelData.icon || ico.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 34
                    text: modelData.label ? modelData.label.charAt(0).toUpperCase() : ""
                    color: cCyan
                    font.pixelSize: 28
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 92
                    width: 110
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: k === 0 ? cText : "#bfa8d8"
                    font.pixelSize: 11
                    font.bold: k === 0
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 114
                    width: 30; height: 4; radius: 2
                    color: k === 0 ? cPink : "#3a2b55"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (k === 0) win.launchCenter();
                        else win.center = index;
                    }
                    onEntered: { if (card.ak <= 2 && card.ak > 0) win.center = index; }
                }
            }
        }

        // chrome title
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.cy + 108
            text: win.deck.length > 0 && win.center < win.deck.length ? win.deck[win.center].label.toUpperCase() : "NO SIGNAL"
            color: cPink
            font.pixelSize: 26
            font.bold: true
            font.italic: true
            opacity: 0.6
            z: 300
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.cy + 105
            text: win.deck.length > 0 && win.center < win.deck.length ? win.deck[win.center].label.toUpperCase() : "NO SIGNAL"
            color: cText
            font.pixelSize: 26
            font.bold: true
            font.italic: true
            z: 301
        }

        // neon search pill
        Rectangle {
            x: win.cx - 210; y: 36
            width: 420; height: 50
            radius: 25
            color: "#aa12081f"
            border.color: search.activeFocus ? cPink : cCyan
            border.width: 1
            z: 300
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                radius: 30
                color: "transparent"
                border.color: search.activeFocus ? "#44ff2975" : "#332de2e6"
                border.width: 2
            }
            Text {
                x: 24; anchors.verticalCenter: parent.verticalCenter
                text: "»"
                color: cYellow
                font.pixelSize: 18
            }
            Text {
                visible: search.text === ""
                x: 48; anchors.verticalCenter: parent.verticalCenter
                text: "search the grid…"
                color: cDim
                font.pixelSize: 14
            }
            TextInput {
                id: search
                x: 48; anchors.verticalCenter: parent.verticalCenter
                width: 320
                color: cText
                font.pixelSize: 15
                clip: true
                selectByMouse: true
                onTextChanged: { win.pending = text; debounce.start(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchCenter(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { win.center = Math.min(win.deck.length - 1, win.center + 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { win.center = Math.max(0, win.center - 1); event.accepted = true; }
                }
            }
            Text {
                x: parent.width - 64; anchors.verticalCenter: parent.verticalCenter
                text: (win.center + 1) + "/" + win.deck.length
                color: cDim
                font.pixelSize: 11
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 32
            text: "← → / wheel / drag deck = cruise · hover = focus · click / ↵ = launch · esc = jack out"
            color: cDim
            font.pixelSize: 11
            opacity: 0.85
            z: 300
        }
    }
}
