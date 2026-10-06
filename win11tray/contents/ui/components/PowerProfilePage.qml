import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.batterymonitor
import org.kde.kcmutils
import "../lib" as Lib

Lib.Page {
    id: page

    title: i18n("Power Mode")
    contentFillsHeight: false

    PowerProfilesControl {
        id: powerProfiles
    }

    footer: Lib.MoreSettingsLink {
        text: i18n("More power settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig")
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Lib.SectionHeader {
            text: i18n("Power Profiles")
        }

        Repeater {
            model: powerProfiles.profiles

            delegate: Lib.ListRow {
                Layout.fillWidth: true
                text: {
                    switch (modelData) {
                    case "performance":
                        return i18n("Performance");
                    case "balanced":
                        return i18n("Balanced");
                    case "power-saver":
                        return i18n("Power Saver");
                    default:
                        return modelData;
                    }
                }
                iconSource: {
                    switch (modelData) {
                    case "performance":
                        return "emblem-favorite";
                    case "balanced":
                        return "emblem-ok";
                    case "power-saver":
                        return "battery-low";
                    default:
                        return "";
                    }
                }
                selected: powerProfiles.activeProfile === modelData
                onClicked: powerProfiles.setProfile(modelData)
            }
        }
    }
}
