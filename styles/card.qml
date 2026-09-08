import QtQuick
import Quickshell
import Quickshell.Io
import "apps.js" as AppsDB

ShellRoot {
    id: root

    readonly property color cViolet: "#7c3aed"
    readonly property color cPink: "#ec4899"
    readonly property color cCyan: "#22d3ee"
    readonly property color cText: "#f4f7ff"
    readonly property color cDim: "#8b93b8"

    PanelWindow {
        id: win
        objectName: "launcher"
        visible: true
        focusable: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real cx: width / 2
        readonly property real cy: height / 2 + 30
        property string query: ""
        property var deck: []
        property int center: 0
        property bool launching: false
        property var icons: ({})
        property string term: "alacritty"

        onQueryChanged: { win.deck = win.computeDeck(); win.center = 0; }

        Process { id: launcher; command: ["true"] }
        Timer { id: quitTimer; interval: 480; onTriggered: Qt.quit() }

        Component.onCompleted: {
            win.deck = win.computeDeck();
            search.forceActiveFocus();
        }
        Timer { interval: 100; running: true; onTriggered: search.forceActiveFocus() }
        Timer { interval: 250; repeat: true; running: true; onTriggered: auroraCanvas.requestPaint() }

        function computeDeck() {
            const q = win.query;
            return AppsDB.list.slice()
                .sort((x, y) => String(x.label).localeCompare(String(y.label)))
                .filter(a => !q || (a.label + " " + a.cat + " " + a.keywords).toLowerCase().indexOf(q) !== -1);
        }
        function cardX(k) {
            if (k === 0) return 0;
            const a = Math.abs(k);
            return (k > 0 ? 1 : -1) * (120 + (a - 1) * 68);
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

        Rectangle { anchors.fill: parent; color: "#0b1020" }

        // ── aurora background ──
        Canvas {
            id: auroraCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = Date.now();
                const blobs = [
                    [0.25 + 0.06 * Math.sin(t / 9000), 0.30 + 0.05 * Math.cos(t / 11000), 0.55, "124,58,237"],
                    [0.75 + 0.05 * Math.cos(t / 8000), 0.65 + 0.06 * Math.sin(t / 10000), 0.60, "236,72,153"],
                    [0.55 + 0.07 * Math.sin(t / 12000), 0.15 + 0.04 * Math.cos(t / 9000), 0.45, "34,211,238"]
                ];
                for (let b = 0; b < blobs.length; b++) {
                    const bx = blobs[b][0] * win.width, by = blobs[b][1] * win.height;
                    const br = blobs[b][2] * Math.min(win.width, win.height);
                    const g = ctx.createRadialGradient(bx, by, 0, bx, by, br);
                    g.addColorStop(0, "rgba(" + blobs[b][3] + ",0.16)");
                    g.addColorStop(1, "rgba(" + blobs[b][3] + ",0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, win.width, win.height);
                }
                for (let i = 0; i < 40; i++) {
                    const x = (Math.sin(i * 127.1) * 43758.5 % 1 + 1) % 1 * win.width;
                    const y = ((Math.sin(i * 311.7) * 43758.5 % 1 + 1) % 1 * win.height + t * 0.008 * (0.4 + (i % 5) * 0.2)) % win.height;
                    ctx.beginPath();
                    ctx.arc(x, win.height - y, 1 + (i % 3) * 0.6, 0, 6.2832);
                    ctx.fillStyle = "rgba(244,247,255," + (0.06 + (i % 4) * 0.04) + ")";
                    ctx.fill();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            property real pressX: 0
            property real acc: 0
            property bool dragged: false
            onPressed: (mouse) => { pressX = mouse.x; acc = 0; dragged = false; }
            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const dx = mouse.x - pressX;
                if (Math.abs(dx) > 6) dragged = true;
                acc = dx;
                const steps = Math.floor(Math.abs(acc) / 90);
                if (steps > 0) {
                    win.center = Math.max(0, Math.min(win.deck.length - 1, win.center + (acc < 0 ? steps : -steps)));
                    acc = 0;
                }
            }
            onWheel: (wheel) => {
                win.center = Math.max(0, Math.min(win.deck.length - 1, win.center + (wheel.angleDelta.y > 0 ? 1 : -1)));
                wheel.accepted = true;
            }
            onClicked: (mouse) => { if (!dragged && Math.abs(mouse.y - win.cy) > 220) Qt.quit(); }
        }

        // ── launch burst ring ──
        Rectangle {
            x: win.cx - 70; y: win.cy - 80
            width: 140; height: 160
            radius: 22
            color: "transparent"
            border.color: "#aa22d3ee"
            border.width: 2
            scale: win.launching ? 3.2 : 0.6
            opacity: win.launching ? 0 : 0.9
            Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 450 } }
            z: 400
        }

        // ── glass coverflow deck ──
        Repeater {
            model: win.deck
            delegate: Item {
                id: card
                readonly property int k: index - win.center
                readonly property int ak: Math.abs(k)
                property bool entered: false
                width: 120; height: 140
                x: win.cx - 60 + win.cardX(k)
                y: win.cy - 70 + ak * 8
                z: 200 - ak
                scale: (k === 0 ? 1.14 : (ak === 1 ? 0.94 : 0.82)) * (entered ? 1 : 0.6)
                opacity: ak > 4 ? 0 : (entered ? (k === 0 ? 1 : 0.75 - ak * 0.12) : 0)
                visible: ak <= 4
                Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: win.launching && k === 0 ? 420 : 340; easing.type: win.launching && k === 0 ? Easing.OutCubic : Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                transform: Rotation {
                    origin.x: 60; origin.y: 70
                    axis { x: 0; y: 1; z: 0 }
                    angle: k === 0 ? 0 : (k > 0 ? -44 : 44)
                    Behavior on angle { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                }
                Component.onCompleted: { entered = true; }

                // glow behind center card
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -10
                    radius: 26
                    color: "#22d3ee"
                    opacity: k === 0 ? 0.14 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
                // frosted glass
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: k === 0 ? "#30ffffff" : "#1cffffff"
                    border.color: k === 0 ? "#6622d3ee" : "#26ffffff"
                    border.width: 1
                }
                // top light edge
                Rectangle {
                    x: 10; y: 1
                    width: parent.width - 20; height: 1
                    color: "#55ffffff"
                }
                Image {
                    id: ico
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    width: 56; height: 56
                    source: modelData.icon !== "" ? "file://" + modelData.icon : ""
                    sourceSize: Qt.size(96, 96)
                    asynchronous: true
                    Component.onCompleted: { win.icons[index] = ico; }
                }
                Text {
                    visible: modelData.icon === "" || ico.status !== Image.Ready
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 32
                    text: modelData.label.charAt(0).toUpperCase()
                    color: "#dfe6ff"
                    font.pixelSize: 30
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 90
                    width: 110
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.label
                    color: k === 0 ? "#f4f7ff" : "#aeb6d8"
                    font.pixelSize: 12
                    font.bold: k === 0
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 110
                    width: catLabel.width + 14; height: 16
                    radius: 8
                    color: "#1422d3ee"
                    border.color: "#3322d3ee"
                    Text {
                        id: catLabel
                        anchors.centerIn: parent
                        text: modelData.cat
                        color: "#7dd7f0"
                        font.pixelSize: 9
                    }
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

        // ── big name under the deck ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.cy + 110
            text: win.deck.length > 0 && win.center < win.deck.length ? win.deck[win.center].label : ""
            color: "#f4f7ff"
            font.pixelSize: 26
            font.bold: true
            opacity: 0.95
            z: 300
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.cy + 142
            text: win.deck.length > 0 && win.center < win.deck.length ? win.deck[win.center].cat : ""
            color: cDim
            font.pixelSize: 12
            z: 300
        }

        // ── glass search bar ──
        Rectangle {
            x: win.cx - 210; y: 40
            width: 420; height: 52
            radius: 26
            color: "#1affffff"
            border.color: search.activeFocus ? "#6622d3ee" : "#26ffffff"
            border.width: 1
            z: 300
            Text {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: cCyan
                font.pixelSize: 20
            }
            Text {
                visible: search.text === ""
                x: 52
                anchors.verticalCenter: parent.verticalCenter
                text: "Search apps…"
                color: cDim
                font.pixelSize: 15
            }
            TextInput {
                id: search
                x: 52
                anchors.verticalCenter: parent.verticalCenter
                width: 330
                color: cText
                font.pixelSize: 15
                clip: true
                selectByMouse: true
                onTextChanged: { win.query = text.trim().toLowerCase(); }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) { Qt.quit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launchCenter(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { win.center = Math.min(win.deck.length - 1, win.center + 1); event.accepted = true; }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { win.center = Math.max(0, win.center - 1); event.accepted = true; }
                }
            }
            Text {
                x: parent.width - 60
                anchors.verticalCenter: parent.verticalCenter
                text: (win.center + 1) + "/" + win.deck.length
                color: cDim
                font.pixelSize: 11
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.height - 34
            text: "← → / wheel / drag = flip deck · hover = focus · click / ↵ = open · esc close"
            color: cDim
            font.pixelSize: 11
            opacity: 0.8
            z: 300
        }
    }
}
