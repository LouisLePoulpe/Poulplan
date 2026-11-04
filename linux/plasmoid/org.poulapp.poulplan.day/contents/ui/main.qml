import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// « Journée »: every event of today (finished ones dimmed), from the
// snapshot exported by Poulplan (widget.json, agenda of the coming week).
PlasmoidItem {
    id: root

    property var snapshot: null
    property var entries: []
    property string todayKey: ""
    readonly property string readCommand:
        "cat \"$HOME/.local/share/org.poulapp.poulplan/widget.json\" 2>/dev/null"
        + " || cat \"$HOME/.var/app/org.poulapp.poulplan/data/org.poulapp.poulplan/widget.json\""

    Plasmoid.icon: "view-calendar-day"
    toolTipMainText: "Poulplan — Journée"
    toolTipSubText: entries.length > 0
        ? entries.length + (entries.length > 1 ? " événements aujourd'hui" : " événement aujourd'hui")
        : "Rien de prévu aujourd'hui"

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.readCommand) root.load(data["stdout"]);
            disconnectSource(source);
        }
        function run(command) {
            connectSource(command);
        }
    }

    // Re-read every minute: picks up changes and moves to the next day at
    // midnight, and refreshes the « finished » state.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.run(root.readCommand)
    }

    function dayKey(date) {
        const pad = n => (n < 10 ? "0" : "") + n;
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
    }

    function load(text) {
        try {
            snapshot = JSON.parse(text);
        } catch (error) {
            snapshot = null;
        }
        todayKey = dayKey(new Date());
        const agenda = snapshot && snapshot.agenda ? snapshot.agenda : {};
        entries = (agenda[todayKey] || []).slice(0, Plasmoid.configuration.maxEvents);
    }

    function finished(entry) {
        return !entry.allDay && entry.end <= Date.now();
    }

    function timeText(entry) {
        return entry.allDay ? "Journée" : entry.time + " – " + (entry.endTime || "");
    }

    // Asks the running Poulplan (it stays in the background) over D-Bus;
    // starts it with the configured command when it is not running.
    function action(name, args) {
        const dbus = "gdbus call --session --dest org.poulapp.poulplan"
            + " --object-path /org/poulapp/poulplan --method org.gtk.Actions.Activate"
            + " widget-action \"[<'" + name + "'>]\" \"{}\"";
        const command = Plasmoid.configuration.launchCommand;
        const launch = command
            ? command + args
            : "{ test -x \"$HOME/.local/bin/poulplan\" && \"$HOME/.local/bin/poulplan\"" + args
                + "; } || flatpak run org.poulapp.poulplan" + args;
        executable.run(dbus + " >/dev/null 2>&1 || " + launch);
    }

    function open(entry) {
        if (entry && entry.openable) {
            action("event/" + entry.id, " --open-event=" + entry.id);
        } else {
            action("open", "");
        }
    }

    function create() {
        action("new", " --new-event");
    }

    property int nowMinute: 0

    function minutes(time) {
        if (!time) return 0;
        const parts = time.split(":");
        return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }

    // Timed events with their column when they overlap.
    function layoutTimed(list) {
        const items = list.filter(e => !e.allDay).map(e => {
            const start = minutes(e.time);
            let end = minutes(e.endTime);
            if (end <= start) end = 24 * 60;
            return { entry: e, start: start, end: end, column: 0 };
        }).sort((a, b) => a.start - b.start || b.end - a.end);
        const ends = [];
        for (const item of items) {
            let col = ends.findIndex(end => end <= item.start);
            if (col === -1) { col = ends.length; ends.push(item.end); } else { ends[col] = item.end; }
            item.column = col;
        }
        return { items: items, columns: Math.max(1, ends.length) };
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            root.nowMinute = d.getHours() * 60 + d.getMinutes();
        }
    }

    compactRepresentation: Kirigami.Icon {
        source: "view-calendar-day"
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        id: full
        readonly property real hourHeight: Kirigami.Units.gridUnit * 2.4
        readonly property real gutter: Kirigami.Units.gridUnit * 2.6
        readonly property var timed: root.layoutTimed(root.entries)
        readonly property var allDay: root.entries.filter(e => e.allDay)

        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
        spacing: Kirigami.Units.smallSpacing
        clip: true

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaExtras.Heading {
                    level: 4
                    text: "Journée"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.open(null)
                    }
                }
                PlasmaComponents.Label {
                    text: Qt.locale("fr_FR").toString(new Date(), "dddd d MMMM")
                    opacity: 0.7
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: "list-add"
                text: "Nouvel événement"
                display: PlasmaComponents.AbstractButton.IconOnly
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.create()
            }
        }

        // All-day events.
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: full.allDay.length > 0
            Repeater {
                model: full.allDay
                delegate: Rectangle {
                    required property var modelData
                    width: Math.min(allDayLabel.implicitWidth + Kirigami.Units.largeSpacing * 2, full.width)
                    height: Kirigami.Units.gridUnit * 1.4
                    radius: 4
                    color: "#" + (modelData.color >>> 0).toString(16).padStart(8, "0").slice(2)
                    PlasmaComponents.Label {
                        id: allDayLabel
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.title
                        color: "white"
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.open(modelData)
                    }
                }
            }
        }

        // Time line of the whole day, scrolled to the current time.
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                clip: true
                contentWidth: width
                contentHeight: 24 * full.hourHeight
                Component.onCompleted: contentY = Math.max(0,
                    (root.nowMinute / 60 - 1.5) * full.hourHeight)

                Repeater {
                    model: 24
                    delegate: Item {
                        required property int index
                        y: index * full.hourHeight
                        width: flick.width
                        height: full.hourHeight
                        PlasmaComponents.Label {
                            text: (index < 10 ? "0" : "") + index + ":00"
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            y: -height / 2
                            visible: index > 0
                        }
                        Rectangle {
                            x: full.gutter
                            width: parent.width - full.gutter
                            height: 1
                            color: Kirigami.Theme.textColor
                            opacity: 0.15
                        }
                    }
                }

                Repeater {
                    model: full.timed.items
                    delegate: Rectangle {
                        required property var modelData
                        readonly property real columnWidth: (flick.width - full.gutter) / full.timed.columns
                        x: full.gutter + modelData.column * columnWidth
                        y: modelData.start / 60 * full.hourHeight
                        width: columnWidth - 2
                        height: Math.max(Kirigami.Units.gridUnit, (modelData.end - modelData.start) / 60 * full.hourHeight - 1)
                        radius: 4
                        color: "#" + (modelData.entry.color >>> 0).toString(16).padStart(8, "0").slice(2)
                        opacity: root.finished(modelData.entry) ? 0.45 : 0.9
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 0
                            PlasmaComponents.Label {
                                text: modelData.entry.title
                                color: "white"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents.Label {
                                visible: parent.height > Kirigami.Units.gridUnit * 2
                                text: modelData.entry.time + " – " + (modelData.entry.endTime || "")
                                    + (modelData.entry.location ? " · " + modelData.entry.location : "")
                                color: "white"
                                opacity: 0.85
                                elide: Text.ElideRight
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }
                            Item { Layout.fillHeight: true }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.open(modelData.entry)
                        }
                    }
                }

                // « Now » line.
                Rectangle {
                    x: full.gutter - 4
                    y: root.nowMinute / 60 * full.hourHeight - 1
                    width: flick.width - full.gutter + 4
                    height: 2
                    color: "#E53935"
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: "#E53935"
                        anchors.verticalCenter: parent.verticalCenter
                        x: -4
                    }
                }
            }
        }
    }
}
