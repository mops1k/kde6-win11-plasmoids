import QtQuick
import org.kde.plasma.private.batterymonitor
import "../lib" as Lib

Lib.SplitTile {
    id: tile

    PowerProfilesControl {
        id: powerProfiles
    }

    readonly property bool saverOn: powerProfiles.activeProfile === "power-saver"
    readonly property bool available: powerProfiles.isPowerProfileDaemonInstalled && powerProfiles.profiles.indexOf("power-saver") >= 0

    visible: available
    label: i18n("Battery Saver")
    iconSource: "battery-low-symbolic"
    active: saverOn

    onClicked: {
        if (saverOn) {
            powerProfiles.setProfile(powerProfiles.configuredProfile || "balanced");
        } else {
            powerProfiles.setProfile("power-saver");
        }
    }

    tooltipText: {
        switch (powerProfiles.activeProfile) {
        case "performance":
            return i18n("Power Mode — Performance");
        case "power-saver":
            return i18n("Power Mode — Power Saver");
        default:
            return i18n("Power Mode — Balanced");
        }
    }
}
