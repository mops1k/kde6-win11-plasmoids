import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "../lib" as Lib

Lib.Tile {
    id: tile

    PlasmaNM.Handler {
        id: handler
    }

    label: i18n("Airplane")
    iconSource: "network-flightmode-on-symbolic"
    active: PlasmaNM.Configuration.airplaneModeEnabled

    onClicked: {
        var enable = !PlasmaNM.Configuration.airplaneModeEnabled;
        handler.enableAirplaneMode(enable);
        PlasmaNM.Configuration.airplaneModeEnabled = enable;
    }

    tooltipText: active ? i18n("Airplane Mode — On") : i18n("Airplane Mode — Off")
}
