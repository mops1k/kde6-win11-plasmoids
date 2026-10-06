import QtQuick
import org.kde.notificationmanager as NotificationManager
import "../lib" as Lib
import "../js/funcs.js" as Funcs

Lib.Tile {
    id: tile

    NotificationManager.Settings {
        id: notificationSettings
    }

    label: i18n("Do Not Disturb")
    iconSource: Funcs.checkInhibition(notificationSettings) ? "notifications-disabled" : "notifications"
    active: Funcs.checkInhibition(notificationSettings)

    onClicked: Funcs.toggleDnd(notificationSettings)

    onMiddleClicked: {
        if (Funcs.checkInhibition(notificationSettings)) {
            notificationSettings.notificationsInhibitedUntil = undefined;
        } else {
            var d = new Date();
            d.setHours(d.getHours() + 1);
            notificationSettings.notificationsInhibitedUntil = d;
        }
        notificationSettings.save();
    }

    tooltipText: Funcs.checkInhibition(notificationSettings) ? i18n("Do Not Disturb — On") : i18n("Do Not Disturb — Off")
}
