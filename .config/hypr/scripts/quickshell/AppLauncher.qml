import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: launcherRoot

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.anchors.top:    true
    WlrLayershell.anchors.bottom: true
    WlrLayershell.anchors.left:   true
    WlrLayershell.anchors.right:  true

    color: "transparent"
    visible: _showing

    MatugenColors { id: theme }
    Scaler        { id: scaler; currentWidth: Screen.width }
    function s(v) { return scaler.s(v) }

    // ─── State ───────────────────────────────────────────────────────────────

    property bool open:     false
    property bool _showing: false
    property string smartResult: ""
    property string smartType:   ""
    property bool   isSmartMode: false

    Timer {
        id: hideTimer; interval: 600
        onTriggered: launcherRoot._showing = false
    }

    // Tell island to hide (1) or show (0) — two static processes, no binding issues
    Process { id: islandHideProc; command: ["bash", "-c", "echo 1 > /tmp/qs_launcher_state"] }
    Process { id: islandShowProc; command: ["bash", "-c", "echo 0 > /tmp/qs_launcher_state"] }

    // On startup ensure island is visible (clears any stale state from previous session)
    Component.onCompleted: { islandShowProc.running = true }

    onOpenChanged: {
        if (open) {
            hideTimer.stop()
            _showing = true
            islandHideProc.running = false
            islandHideProc.running = true
            searchInput.text = ""
            filterApps("")
            appsProc.running = false
            appsProc.running = true
            Qt.callLater(function() { searchInput.forceActiveFocus() })
        } else {
            hideTimer.restart()
            islandShowProc.running = false
            islandShowProc.running = true
        }
    }

    // ─── App data ─────────────────────────────────────────────────────────────

    ListModel { id: allAppsModel }
    ListModel { id: filteredModel }

    function parseCurrency(text) {
        let t = text.trim()
        // число потім символ: 100$, 100 $, 100usd, 100 usd
        let m = t.match(/^(\d+(?:[.,]\d+)?)\s*([$€£¥₽]|usd|eur|gbp|jpy|rub|chf|pln|zł)$/i)
        if (m) return { amount: m[1], sym: m[2] }
        // символ потім число: $100, usd100, usd 100
        m = t.match(/^([$€£¥₽]|usd|eur|gbp|jpy|rub|chf|pln|zł)\s*(\d+(?:[.,]\d+)?)$/i)
        if (m) return { amount: m[2], sym: m[1] }
        return null
    }

    function parseUrl(text) {
        let t = text.trim()
        if (/^https?:\/\/\S+$/.test(t)) return { href: t }
        if (/^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}(\/\S*)?$/.test(t))
            return { href: "https://" + t }
        return null
    }

    function parseCalc(text) {
        let t = text.trim()
        if (/^(sqrt|sin|cos|tan|asin|acos|atan|log|log2|log10|abs|ceil|floor|round|pi|e)\b/i.test(t))
            return { expr: t }
        if (/^[\d\s()+\-*\/^%.,]+$/.test(t) && /[+\-*\/^%]/.test(t) && /\d/.test(t)
                && !/^-?\d+([.,]\d+)?$/.test(t))
            return { expr: t }
        return null
    }

    function parseUnits(text) {
        let t = text.trim()
        let m = t.match(/^(\d+(?:[.,]\d+)?)\s*([a-zA-Z°²³\/0-9.]+)\s+to\s+([a-zA-Z°²³\/0-9.]+)$/i)
        if (m) return { amount: m[1], from: m[2], to: m[3] }
        return null
    }

    function fuzzyScore(name, query) {
        let n = name.toLowerCase(), q = query.toLowerCase()
        if (n === q)          return 4
        if (n.startsWith(q))  return 3
        if (n.includes(q))    return 2
        let qi = 0
        for (let i = 0; i < n.length && qi < q.length; i++)
            if (n[i] === q[qi]) qi++
        return qi === q.length ? 1 : 0
    }

    function filterApps(query) {
        filteredModel.clear()
        let q = query.trim()
        if (!q) {
            for (let i = 0; i < allAppsModel.count; i++) {
                let a = allAppsModel.get(i)
                filteredModel.append({ name: a.name, exec: a.exec, icon: a.icon, desktop: a.desktop })
            }
        } else {
            let scored = []
            for (let i = 0; i < allAppsModel.count; i++) {
                let a = allAppsModel.get(i)
                let sc = fuzzyScore(a.name, q)
                if (sc > 0) scored.push({ sc, a })
            }
            scored.sort((x, y) => y.sc - x.sc || x.a.name.localeCompare(y.a.name))
            for (let i = 0; i < scored.length; i++) {
                let a = scored[i].a
                filteredModel.append({ name: a.name, exec: a.exec, icon: a.icon, desktop: a.desktop })
            }
        }
        appList.currentIndex = 0
    }

    function launchApp(idx) {
        if (idx < 0 || idx >= filteredModel.count) return
        let a = filteredModel.get(idx)
        launchProc.launchCmd = a.exec
        launchProc.running   = false
        launchProc.running   = true
        open = false
    }

    Process {
        id: appsProc
        command: ["bash", "-c", "bash $HOME/.config/hypr/scripts/get_apps.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                allAppsModel.clear()
                let lines = this.text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let p = lines[i].split("|")
                    if (p.length >= 2 && p[0])
                        allAppsModel.append({ name: p[0], exec: p[1], icon: p[2] || "", desktop: p[3] || "" })
                }
                filterApps(searchInput.text)
            }
        }
    }

    Process {
        id: launchProc
        property string launchCmd: ""
        command: ["bash", "-c", "nohup sh -c " + JSON.stringify(launchCmd) + " >/dev/null 2>&1 &"]
    }

    Timer {
        id: smartDebounce
        interval: 350
        onTriggered: {
            let t = searchInput.text
            let units = launcherRoot.parseUnits(t)
            let curr  = launcherRoot.parseCurrency(t)
            let calc  = launcherRoot.parseCalc(t)
            launcherRoot.smartResult = "..."
            if (units) {
                launcherRoot.smartType = "units"
                unitsProc.amount = units.amount
                unitsProc.from   = units.from
                unitsProc.to     = units.to
                unitsProc.running = false
                unitsProc.running = true
            } else if (curr) {
                launcherRoot.smartType = "currency"
                currencyProc.amount = curr.amount
                currencyProc.sym    = curr.sym
                currencyProc.running = false
                currencyProc.running = true
            } else if (calc) {
                launcherRoot.smartType = "calc"
                calcProc.expr = calc.expr
                calcProc.running = false
                calcProc.running = true
            }
        }
    }

    Process {
        id: currencyProc
        property string amount: ""
        property string sym: ""
        command: ["bash", "-c",
            "bash \"$HOME/.config/hypr/scripts/currency_convert.sh\" \"$1\" \"$2\"",
            "x", amount, sym]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = text.trim()
                launcherRoot.smartResult = r !== "" ? r : "Помилка отримання курсу"
            }
        }
    }

    Process {
        id: calcProc
        property string expr: ""
        command: ["bash", "-c",
            "bash \"$HOME/.config/hypr/scripts/calculator.sh\" \"$1\"",
            "x", expr]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = text.trim()
                launcherRoot.smartResult = r !== "" ? r : "Помилка обчислення"
            }
        }
    }

    Process {
        id: unitsProc
        property string amount: ""
        property string from: ""
        property string to: ""
        command: ["bash", "-c",
            "bash \"$HOME/.config/hypr/scripts/units_convert.sh\" \"$1\" \"$2\" \"$3\"",
            "x", amount, from, to]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = text.trim()
                launcherRoot.smartResult = r !== "" ? r : "Невідомі одиниці"
            }
        }
    }

    Process {
        id: searchProc
        property string query: ""
        command: ["bash", "-c",
            "q=$(python3 -c \"import urllib.parse,sys; print(urllib.parse.quote_plus(sys.argv[1]))\" \"$1\") && xdg-open \"https://www.google.com/search?q=$q\" &",
            "x", query]
    }

    Process {
        id: urlOpenProc
        property string url: ""
        command: ["bash", "-c", "xdg-open \"$1\" &", "x", url]
    }

    // ─── IPC ──────────────────────────────────────────────────────────────────

    Process {
        id: ipcWatcher; running: true
        command: ["bash", "-c",
            "inotifywait -qq -e close_write,moved_to --include 'qs_launcher$' /tmp/ 2>/dev/null; " +
            "[ -f /tmp/qs_launcher ] && cat /tmp/qs_launcher && rm -f /tmp/qs_launcher"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let cmd = this.text.trim()
                if      (cmd === "open")   launcherRoot.open = true
                else if (cmd === "close")  launcherRoot.open = false
                else if (cmd === "toggle") launcherRoot.open = !launcherRoot.open
                ipcWatcher.running = false
                ipcWatcher.running = true
            }
        }
    }

    // ─── UI ───────────────────────────────────────────────────────────────────

    // Dim — fades in behind the card
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, launcherRoot.open ? 0.55 : 0)
        Behavior on color { ColorAnimation { duration: 380 } }
        visible: color.a > 0.001
        MouseArea { anchors.fill: parent; onClicked: launcherRoot.open = false }
    }

    // ── Launcher card ────────────────────────────────────────────────────────
    // Starts at island position (top-center, y=8) and morphs to screen center.
    Rectangle {
        id: card

        // Final open height (used to compute target y before animation ends)
        property int openH: s(70)
            + (isSmartMode ? s(64) : Math.min(filteredModel.count, 9) * s(54))
            + (!isSmartMode && searchInput.text.trim().length > 0 ? s(54) : 0)

        width:  launcherRoot.open ? s(660) : s(230)
        height: launcherRoot.open ? openH  : s(40)
        radius: launcherRoot.open ? s(24)  : s(20)

        // Horizontal: always centered (mirrors island x = (Screen.width - width) / 2)
        x: Math.round((parent.width - width) / 2)
        // Vertical: island top position → screen center
        y: launcherRoot.open ? Math.round((parent.height - openH) / 2) : s(8)

        Behavior on width  { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }
        Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on y      { NumberAnimation { duration: 540; easing.type: Easing.OutExpo } }

        opacity: launcherRoot.open ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.97)

        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: "transparent"
            border.width: 1; border.color: Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.35)
        }

        // Content fades in after card expands
        Item {
            anchors { fill: parent; margins: s(16); topMargin: s(14) }
            opacity: launcherRoot.open ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            clip: true

            Column {
                width: parent.width
                spacing: 0

                // ── Search bar ───────────────────────────────────────────────
                Row {
                    width: parent.width; height: s(40)
                    spacing: s(10)

                    Text {
                        text: ""; font.family: "SF Pro Text"; font.pixelSize: s(20)
                        color: theme.subtext0; anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - s(30) - s(10); height: parent.height

                        Text {
                            visible: searchInput.text.length === 0
                            text: "Search apps..."
                            font.family: "SF Pro Text"; font.pixelSize: s(15)
                            color: Qt.rgba(theme.subtext0.r, theme.subtext0.g, theme.subtext0.b, 0.4)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            font.family: "SF Pro Text"; font.pixelSize: s(15); font.weight: Font.Bold
                            color: theme.text
                            verticalAlignment: TextInput.AlignVCenter
                            selectionColor: Qt.rgba(theme.mauve.r, theme.mauve.g, theme.mauve.b, 0.35)

                            onTextChanged: {
                                let url   = launcherRoot.parseUrl(text)
                                let units = launcherRoot.parseUnits(text)
                                let curr  = launcherRoot.parseCurrency(text)
                                let calc  = launcherRoot.parseCalc(text)
                                if (url) {
                                    launcherRoot.isSmartMode = true
                                    launcherRoot.smartType   = "url"
                                    launcherRoot.smartResult = url.href
                                    filteredModel.clear()
                                    smartDebounce.stop()
                                } else if (units || curr || calc) {
                                    if (!launcherRoot.isSmartMode) {
                                        launcherRoot.isSmartMode = true
                                        filteredModel.clear()
                                    }
                                    smartDebounce.restart()
                                } else {
                                    launcherRoot.isSmartMode = false
                                    smartDebounce.stop()
                                    launcherRoot.filterApps(text)
                                }
                            }

                            Keys.onUpPressed:     function(event) { appList.decrementCurrentIndex(); event.accepted = true }
                            Keys.onDownPressed:   function(event) { appList.incrementCurrentIndex(); event.accepted = true }
                            Keys.onReturnPressed: function(event) {
                                if (launcherRoot.smartType === "url") {
                                    urlOpenProc.url = launcherRoot.smartResult
                                    urlOpenProc.running = false
                                    urlOpenProc.running = true
                                    launcherRoot.open = false
                                } else if (!launcherRoot.isSmartMode && filteredModel.count === 0 && text.trim() !== "") {
                                    searchProc.query = text.trim()
                                    searchProc.running = false
                                    searchProc.running = true
                                    launcherRoot.open = false
                                } else {
                                    launcherRoot.launchApp(appList.currentIndex)
                                }
                                event.accepted = true
                            }
                            Keys.onEscapePressed: function(event) { launcherRoot.open = false; event.accepted = true }
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width; height: 1
                    color: Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.35)
                }

                // Google search hint row
                Rectangle {
                    visible: !launcherRoot.isSmartMode && searchInput.text.trim().length > 0
                    width: parent.width
                    height: visible ? s(54) : 0
                    radius: s(12)
                    color: "transparent"

                    Row {
                        anchors { fill: parent; leftMargin: s(10); rightMargin: s(10) }
                        spacing: s(10)

                        Text {
                            text: ""
                            font.family: "SF Pro Text"
                            font.pixelSize: s(18)
                            color: Qt.rgba(theme.subtext0.r, theme.subtext0.g, theme.subtext0.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: 'Search Google: "' + searchInput.text.trim() + '"'
                            font.family: "SF Pro Text"
                            font.pixelSize: s(13)
                            color: Qt.rgba(theme.subtext0.r, theme.subtext0.g, theme.subtext0.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - s(32) - s(10)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchProc.query = searchInput.text.trim()
                            searchProc.running = false
                            searchProc.running = true
                            launcherRoot.open = false
                        }
                    }
                }

                // Smart result row (currency / calculator / units)
                Rectangle {
                    visible: launcherRoot.isSmartMode
                    width: parent.width
                    height: launcherRoot.isSmartMode ? s(60) : 0
                    radius: s(12)
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.85)

                    Row {
                        anchors { fill: parent; leftMargin: s(12); rightMargin: s(12) }
                        spacing: s(10)

                        Text {
                            text: launcherRoot.smartType === "currency" ? "₴"
                                : launcherRoot.smartType === "calc"     ? "="
                                : launcherRoot.smartType === "url"      ? "↗"
                                : "→"
                            font.family: "SF Pro Text"
                            font.pixelSize: s(22)
                            color: launcherRoot.smartType === "currency" ? theme.green
                                 : launcherRoot.smartType === "calc"     ? theme.blue
                                 : launcherRoot.smartType === "url"      ? theme.sky
                                 : theme.peach
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: launcherRoot.smartResult
                            font.family: "SF Pro Text"
                            font.pixelSize: s(15)
                            font.weight: Font.Bold
                            color: theme.text
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - s(32) - s(10)
                        }
                    }
                }

                // ── Results list ─────────────────────────────────────────────
                ListView {
                    id: appList
                    width: parent.width
                    height: Math.min(filteredModel.count, 9) * s(54)
                    clip: true
                    model: filteredModel
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    // Ensure keyboard nav keeps selected item visible
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        width: appList.width; height: s(54)
                        radius: s(12)
                        color: appList.currentIndex === index
                            ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.85)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors { left: parent.left; right: parent.right; margins: s(10); verticalCenter: parent.verticalCenter }
                            spacing: s(10)

                            // Icon with letter fallback
                            Item {
                                width: s(32); height: s(32); anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: appIcon; anchors.fill: parent
                                    source: model.icon ? "file://" + model.icon : ""
                                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                                }
                                Rectangle {
                                    visible: appIcon.status !== Image.Ready
                                    anchors.fill: parent; radius: s(8)
                                    color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.7)
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.name.charAt(0).toUpperCase()
                                        font.family: "SF Pro Text"; font.pixelSize: s(14); font.weight: Font.Black
                                        color: theme.subtext0
                                    }
                                }
                            }

                            Text {
                                width: parent.width - s(32) - s(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.name
                                font.family: "SF Pro Text"; font.pixelSize: s(14); font.weight: Font.Bold
                                color: appList.currentIndex === index ? theme.text : theme.subtext0
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        MouseArea {
                            id: rowHover; anchors.fill: parent
                            onClicked: launcherRoot.launchApp(index)
                        }
                    }
                }
            }
        }
    }
}
