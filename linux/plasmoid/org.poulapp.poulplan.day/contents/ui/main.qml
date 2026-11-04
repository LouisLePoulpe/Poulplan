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

    function open(entry) {
        const base = Plasmoid.configuration.launchCommand;
        executable.run(entry && entry.openable ? base + " --open-event=" + entry.id : base);
    }

    function create() {
        executable.run(Plasmoid.configuration.launchCommand + " --new-event");
    }

    compactRepresentation: Kirigami.Icon {
        source: "view-calendar-day"
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        readonly property real rowHeight: Kirigami.Units.gridUnit * 2.6
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredHeight: heading.implicitHeight + Kirigami.Units.largeSpacing * 2
            + Math.max(1, root.entries.length) * rowHeight
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        spacing: Kirigami.Units.smallSpacing
        clip: true

        RowLayout {
            id: heading
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaExtras.Heading {
                    level: 4
                    text: "Journée"
                }
                PlasmaComponents.Label {
                    text: Qt.locale("fr_FR").toString(new Date(), "dddd d MMMM")
                    opacity: 0.7
                }
                MouseArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onClicked: root.open(null)
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

        PlasmaComponents.Label {
            visible: root.entries.length === 0
            text: "Rien de prévu aujourd'hui"
            opacity: 0.7
        }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.entries.length > 0

            ListView {
                clip: true
                model: root.entries
                delegate: PlasmaComponents.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    height: rowHeight
                    opacity: root.finished(modelData) ? 0.45 : 1
                    onClicked: root.open(modelData)
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label {
                            text: root.timeText(modelData)
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.fillHeight: true
                            radius: 2
                            color: "#" + (modelData.color >>> 0).toString(16).padStart(8, "0").slice(2)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PlasmaComponents.Label {
                                text: modelData.title
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents.Label {
                                visible: !!modelData.location
                                text: modelData.location || ""
                                elide: Text.ElideRight
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
