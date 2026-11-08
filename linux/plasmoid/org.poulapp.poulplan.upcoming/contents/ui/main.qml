import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Reads the snapshot exported by Poulplan (widget.json, see
// lib/features/widgets/widget_exporter.dart) and lists the next events.
PlasmoidItem {
    id: root

    property var entries: []
    readonly property string readCommand:
        "cat \"$HOME/.local/share/org.poulapp.poulplan/widget.json\" 2>/dev/null"
        + " || cat \"$HOME/.var/app/org.poulapp.poulplan/data/org.poulapp.poulplan/widget.json\""

    Plasmoid.icon: "view-calendar-upcoming-events"
    toolTipMainText: "Poulplan"
    toolTipSubText: entries.length > 0
        ? "Prochain : " + entries[0].title + " — " + whenText(entries[0])
        : "Aucun événement à venir"

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

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.run(root.readCommand)
    }

    function load(text) {
        try {
            const snapshot = JSON.parse(text);
            const now = Date.now();
            const today = dayKey(new Date());
            entries = snapshot.upcoming.filter(e =>
                e.allDay ? e.localDay >= today || endDayKey(e) > today : e.end > now
            ).slice(0, Plasmoid.configuration.maxEvents);
        } catch (error) {
            entries = [];
        }
    }

    function dayKey(date) {
        const pad = n => (n < 10 ? "0" : "") + n;
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
    }

    // All-day end: UTC midnight of the exclusive end date.
    function endDayKey(entry) {
        return new Date(entry.end).toISOString().slice(0, 10);
    }

    function whenText(entry) {
        const today = new Date();
        const tomorrow = new Date(today.getTime() + 86400000);
        let day;
        if (entry.localDay === dayKey(today)) {
            day = "Aujourd'hui";
        } else if (entry.localDay === dayKey(tomorrow)) {
            day = "Demain";
        } else {
            const parts = entry.localDay.split("-");
            const date = new Date(parts[0], parts[1] - 1, parts[2]);
            day = Qt.locale("fr_FR").toString(date, "ddd d MMM");
        }
        return entry.time ? day + " à " + entry.time : day + " · Journée";
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

    compactRepresentation: Kirigami.Icon {
        source: "view-calendar-upcoming-events"
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        readonly property real rowHeight: Kirigami.Units.gridUnit * 2.6
        // The popup takes the size of its content (header + rows), the list
        // scrolls beyond, and nothing is drawn outside of it.
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredHeight: heading.implicitHeight + Kirigami.Units.largeSpacing * 2
            + Math.max(1, Math.min(root.entries.length, Plasmoid.configuration.maxEvents)) * rowHeight
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        spacing: Kirigami.Units.smallSpacing
        clip: true

        RowLayout {
            id: heading
            Layout.fillWidth: true
            PlasmaExtras.Heading {
                level: 4
                text: "À venir"
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open(null)
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: "org.poulapp.poulplan"
                text: "Ouvrir Poulplan"
                display: PlasmaComponents.AbstractButton.IconOnly
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
                onClicked: root.open(null)
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
            text: "Aucun événement à venir"
            opacity: 0.7
        }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.entries.length > 0

            ListView {
                id: list
                clip: true
                model: root.entries
                delegate: PlasmaComponents.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    height: rowHeight
                    onClicked: root.open(modelData)
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.fillHeight: true
                            radius: 2
                            // Exported as an ARGB integer.
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
                                text: root.whenText(modelData)
                                    + (modelData.location ? " · " + modelData.location : "")
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
