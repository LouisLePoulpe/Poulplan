import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_launchCommand: launchCommand.text
    property alias cfg_maxEvents: maxEvents.value

    Kirigami.FormLayout {
        QQC2.TextField {
            id: launchCommand
            Kirigami.FormData.label: "Commande de lancement :"
            placeholderText: "flatpak run org.poulapp.poulplan"
        }
        QQC2.Label {
            text: "Version de développement : distrobox enter claude -- ~/dev/Poulplan/build/linux/x64/release/bundle/poulplan"
            wrapMode: Text.Wrap
            opacity: 0.7
        }
        QQC2.SpinBox {
            id: maxEvents
            Kirigami.FormData.label: "Nombre d'événements :"
            from: 1
            to: 20
        }
    }
}
