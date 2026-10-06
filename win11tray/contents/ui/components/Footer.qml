import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.battery
import org.kde.kirigami as Kirigami
import org.kde.kcmutils
import "../lib" as Lib
import "." as Components

Rectangle {
    id: footer

    property real scale: 1
    property int footerHeight: 36 * scale
    property bool showBattery: false
    property bool hasBattery: false

    signal batteryClicked
    signal batteryInfoClicked
    signal inhibitSleepClicked

    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)

    implicitHeight: footerHeight + 8

    BatteryControlModel {
        id: batteryControl
    }

    readonly property string batteryTooltipText: {
        if (!hasBattery)
            return "";
        const pct = batteryControl.percent + "%";
        const charging = batteryControl.state === BatteryControlModel.Charging || batteryControl.state === BatteryControlModel.FullyCharged;
        if (charging)
            return i18n("Charging — %1").arg(pct);
        const remaining = batteryControl.remainingMsec;
        if (remaining && remaining > 0) {
            const h = Math.floor(remaining / 3600);
            const m = Math.floor((remaining % 3600) / 60);
            return i18n("%1 — %2h %3m remaining").arg(pct).arg(h).arg(m);
        }
        return pct;
    }

    Item {
        anchors.fill: parent
        anchors.margins: 8
        anchors.leftMargin: 22
        anchors.rightMargin: 22

        Lib.FooterButton {
            id: batteryFooterBtn
            buttonSize: 22
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: footer.showBattery && footer.hasBattery
            iconSource: batteryControl.state === BatteryControlModel.Charging ? "battery-100-charging" : "battery-100"
            tooltipText: footer.batteryTooltipText
            onClicked: footer.batteryClicked()
            onRightClicked: batteryMenu.popup()
        }

        Lib.FooterButton {
            id: powerBtn
            anchors.right: settingsBtn.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            iconSource: "system-shutdown"
            tooltipText: i18n("Power off / Log out")
            onClicked: {
                var session = Qt.createQmlObject('import org.kde.plasma.private.sessions as Sessions; Sessions.SessionManagement {}', powerBtn, "powerDyn");
                session.requestLogoutPrompt();
                session.destroy();
            }
            onRightClicked: powerMenu.popup()
        }

        Lib.FooterButton {
            id: settingsBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconSource: "configure"
            tooltipText: i18n("Open System Settings")
            onClicked: KCMLauncher.openSystemSettings("")
            onRightClicked: gearMenu.popup()
        }
    }

    PlasmaComponents3.Menu {
        id: batteryMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Power settings")
            icon.name: "configure"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_powerdevilprofilesconfig")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Show battery info")
            icon.name: "battery"
            onClicked: footer.batteryInfoClicked()
        }
    }

    PlasmaComponents3.Menu {
        id: gearMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Display settings")
            icon.name: "preferences-desktop-display"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_kscreen")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Sound settings")
            icon.name: "audio-volume-high"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_pulseaudio")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Network settings")
            icon.name: "network-wireless"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_networkmanagement")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Power settings")
            icon.name: "battery"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_powerdevilprofilesconfig")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Notification settings")
            icon.name: "notifications"
            onClicked: Qt.openUrlExternally("systemsettings://kcm_notifications")
        }
    }

    PlasmaComponents3.Menu {
        id: powerMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Lock")
            icon.name: "system-lock-screen"
            onClicked: footer._lockScreen()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Log out")
            icon.name: "system-log-out"
            onClicked: footer._logOut()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Suspend")
            icon.name: "system-suspend"
            onClicked: footer._suspend()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Hibernate")
            icon.name: "system-hibernate"
            onClicked: footer._hibernate()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Restart")
            icon.name: "system-restart"
            onClicked: footer._restart()
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Shut down")
            icon.name: "system-shutdown"
            onClicked: footer._shutDown()
        }
    }

    function _lockScreen() {
        var bus = Qt.createQmlObject('import org.kde.plasma.workspace.dbus as DBus; QtObject { function call(svc, p, iface, mem) { DBus.SessionBus.asyncCall({service: svc, path: p, iface: iface, member: mem}) } }', footer, "lockDyn");
        bus.call("org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock");
        bus.destroy();
    }

    function _suspend() {
        var bus = Qt.createQmlObject('import org.kde.plasma.workspace.dbus as DBus; QtObject { function call(svc, p, iface, mem, args) { DBus.SystemBus.asyncCall({service: svc, path: p, iface: iface, member: mem, arguments: args}) } }', footer, "susDyn");
        bus.call("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "Suspend", [false]);
        bus.destroy();
    }

    function _hibernate() {
        var bus = Qt.createQmlObject('import org.kde.plasma.workspace.dbus as DBus; QtObject { function call(svc, p, iface, mem, args) { DBus.SystemBus.asyncCall({service: svc, path: p, iface: iface, member: mem, arguments: args}) } }', footer, "hibDyn");
        bus.call("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "Hibernate", [false]);
        bus.destroy();
    }

    function _logOut() {
        var bus = Qt.createQmlObject('import org.kde.plasma.workspace.dbus as DBus; QtObject { function call(svc, p, iface, mem, args) { DBus.SystemBus.asyncCall({service: svc, path: p, iface: iface, member: mem, arguments: args}) } }', footer, "logDyn");
        bus.call("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "TerminateSession", [""]);
        bus.destroy();
    }

    function _restart() {
        var bus = Qt.createQmlObject('import org.kde.plasma.workspace.dbus as DBus; QtObject { function call(svc, p, iface, mem, args) { DBus.SystemBus.asyncCall({service: svc, path: p, iface: iface, member: mem, arguments: args}) } }', footer, "rstDyn");
        bus.call("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "Reboot", [false]);
        bus.destroy();
    }

    function _shutDown() {
        var bus = Qt.createQmlObject('import org.kde.plasma.workspace.dbus as DBus; QtObject { function call(svc, p, iface, mem, args) { DBus.SystemBus.asyncCall({service: svc, path: p, iface: iface, member: mem, arguments: args}) } }', footer, "shtDyn");
        bus.call("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "PowerOff", [false]);
        bus.destroy();
    }
}
