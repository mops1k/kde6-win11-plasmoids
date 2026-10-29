/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kcmutils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras
import org.kde.plasma.plasmoid
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.workspace.osd

import "../js/funcs.js" as Funcs

// Ряд системных значков в панели, как в Windows 11: сеть, звук, яркость,
// батарея. Клик по значку открывает сводный поповер быстрых настроек —
// страницы модулей открываются стрелочками у плиток внутри него.
// Правый клик открывает контекстное меню самого значка (как в Windows 11):
// сеть — список Wi-Fi и системные настройки сети, звук — устройства вывода,
// микшер и настройки звука, яркость — настройки экрана и ночного света,
// батарея — экономия заряда и настройки питания.
Item {
    id: root

    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    property bool showNetwork: true
    property bool showVolume: true
    property bool showBrightness: true
    property bool showBattery: true

    // Отступ от области значков трея: в Windows 11 группа системных значков
    // отделена от значков приложений заметным промежутком, иначе всё
    // сливается в одно. Внутри самого ряда отступ маленький и фиксированный
    // (StatusIcon.iconPadding), настройка «Spacing» трея на ряд не влияет.
    property real leadingGap: Kirigami.Units.largeSpacing * 2

    // Шаг изменения громкости колесом мыши, в процентах (настройка трея).
    property int volumeScrollStep: 5

    // Экран панели: OSD-окно не может надёжно спросить Screen до первого
    // показа (у скрытого окна экран ещё не определён).
    readonly property int osdScreenX: Screen.virtualX
    readonly property int osdScreenY: Screen.virtualY
    readonly property int osdScreenWidth: Screen.width
    readonly property int osdScreenHeight: Screen.height

    // Имя значка, по которому кликнули ("network", "volume", "brightness",
    // "battery"), либо пустая строка при клике по свободной области ряда.
    signal iconClicked(string name)
    signal emptyAreaClicked()
    // Просьба открыть страницу модуля в поповере трея (пункт «Микшер
    // громкости» открывает страницу «Звук», где есть микшер приложений).
    signal requestPage(string name)

    // Внутренняя раскладка не зеркалится: ряд всегда идёт слева направо
    // (сеть, звук, яркость, батарея), а промежуток — всегда со стороны трея.
    // childrenInherit обязателен: без него RowLayout наследует зеркалирование
    // от панели трея и leftMargin превращается в правый — отступ уезжает
    // в конец апплета, к часам, вместо промежутка между треем и рядом.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    implicitWidth: leadingGap + row.implicitWidth
    implicitHeight: row.implicitHeight

    PlasmaNM.ConnectionIcon {
        id: connectionIcon
    }
    ScreenBrightnessControl {
        id: brightnessControl
    }

    BatteryControlModel {
        id: batteryControl
    }

    // --- Данные контекстных меню --------------------------------------------
    PlasmaNM.Handler {
        id: handler
    }
    PlasmaNM.AppletProxyModel {
        id: networkProxy
        sourceModel: PlasmaNM.NetworkModel {}
    }
    PowerProfilesControl {
        id: powerProfiles
    }
    // Устройства вывода: тот же фильтр, что и на странице «Звук»
    // (components/volume/VolumeModels.qml).
    readonly property var sinkFilterModel: Vol.PulseObjectFilterModel {
        sourceModel: Vol.SinkModel {}
        filterOutInactiveDevices: true
    }

    // Меню раскрывается в сторону от панели: панель снизу — вверх и т.д.
    function menuPlacement() {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.TopEdge:
            return Menu.BottomPosedLeftAlignedPopup;
        case PlasmaCore.Types.LeftEdge:
            return Menu.RightPosedTopAlignedPopup;
        case PlasmaCore.Types.RightEdge:
            return Menu.LeftPosedTopAlignedPopup;
        default:
            return Menu.TopPosedLeftAlignedPopup;
        }
    }

    function openIconMenu(menu, icon) {
        menu.visualParent = icon;
        menu.openRelative();
    }

    // Прокрутка колеса над значком звука меняет громкость устройства вывода,
    // как в Windows 11. Выше 100% не поднимаем: у устройства может быть запас
    // до 150%, но колесом — только до номинала.
    function changeVolume(delta) {
        const sink = Vol.PreferredDevice.sink;
        if (!sink || sink.name === "auto_null") {
            return;
        }
        const step = Math.max(1, root.volumeScrollStep) * 65536 / 100;
        // Уровень всегда кратен шагу: 5% → 0, 5, 10, …, 100.
        let volume = sink.volume + (delta > 0 ? step : -step);
        volume = Math.round(volume / step) * step;
        volume = Math.max(0, Math.min(65536, volume));
        sink.volume = volume;
        // Как в слайдере поповера: ноль глушит, прокрутка вверх снимает mute.
        sink.muted = volume === 0;
        volumeOsd.showLevel(volume, sink.muted);
    }

    // Свободная область ряда (если между значками есть место) тоже открывает
    // сводный поповер.
    MouseArea {
        anchors.fill: parent
        onClicked: root.emptyAreaClicked()
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: root.leadingGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StatusIcon {
            id: networkIcon
            name: "network"
            visible: root.showNetwork
            iconSize: root.iconSize
            source: connectionIcon.connectionIcon
            onClicked: root.iconClicked(name)
            onRightClicked: root.openIconMenu(networkMenu, networkIcon)
        }

        StatusIcon {
            id: volumeIcon
            name: "volume"
            visible: root.showVolume
            iconSize: root.iconSize
            source: Funcs.volIconName(sink ? sink.volume : 0, sink ? sink.muted : true)
            onClicked: root.iconClicked(name)
            onRightClicked: root.openIconMenu(volumeMenu, volumeIcon)
            onWheel: wheel => {
                if (wheel.angleDelta.y !== 0) {
                    root.changeVolume(wheel.angleDelta.y);
                }
            }

            readonly property var sink: Vol.PreferredDevice.sink
        }

        StatusIcon {
            id: brightnessIcon
            name: "brightness"
            visible: root.showBrightness && brightnessControl.isBrightnessAvailable
            iconSize: root.iconSize
            source: "brightness-high-symbolic"
            onClicked: root.iconClicked(name)
            onRightClicked: root.openIconMenu(brightnessMenu, brightnessIcon)
        }

        StatusIcon {
            id: batteryIcon
            name: "battery"
            visible: root.showBattery && batteryControl.hasBatteries
            iconSize: root.iconSize
            onClicked: root.iconClicked(name)
            onRightClicked: root.openIconMenu(batteryMenu, batteryIcon)

            BatteryIcon {
                // Батарея чуть меньше остальных значков: её корпус занимает
                // почти всю ширину ячейки, из-за чего она выглядела крупнее.
                anchors.centerIn: parent
                width: Math.round(root.iconSize * 0.8)
                height: width
                percent: batteryControl.percent
                charging: batteryControl.pluggedIn
            }
        }
    }

    // OSD уровня громкости при прокрутке колесом: штатное окно Plasma
    // (модуль org.kde.plasma.workspace.osd). Встроенного автоскрытия у окна
    // нет — его делает таймер, как в plasma-pa.
    Osd {
        id: volumeOsd

        visible: false
        timeout: 1800
        osdMaxValue: 100
        showingProgress: true

        // По центру экрана, ближе к нижней части — как OSD Plasma.
        x: Math.round(root.osdScreenX + (root.osdScreenWidth - width) / 2)
        y: Math.round(root.osdScreenY + root.osdScreenHeight * 0.8)

        function showLevel(volume, muted) {
            osdValue = Math.round(volume / 65536 * 100);
            icon = Funcs.volIconName(volume, muted);
            visible = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: volumeOsd.timeout
        onTriggered: volumeOsd.visible = false
    }

    // --- Контекстное меню значка сети ---------------------------------------
    // Пункты Wi-Fi вставляются динамически перед техническим якорем, поэтому
    // идут первыми, а системный пункт — последним.
    Menu {
        id: networkMenu
        placement: root.menuPlacement()

        MenuItem {
            id: networkAnchor
            visible: false
        }

        MenuItem {
            text: i18n("Network and Internet settings…")
            icon: "configure"
            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
        }
    }

    Instantiator {
        id: networkItems
        model: networkProxy

        delegate: MenuItem {
            // В меню значка сети — только беспроводные сети.
            visible: Type === PlasmaNM.Enums.Wireless
            text: ItemUniqueName
            icon: ConnectionIcon
            checkable: true
            checked: ConnectionState === PlasmaNM.Enums.Activated
            onClicked: {
                if (ConnectionState === PlasmaNM.Enums.Activated) {
                    handler.deactivateConnection(ConnectionPath, DevicePath);
                    return;
                }
                // Сеть без сохранённого профиля, но с паролем: ввод пароля есть
                // только на странице Wi-Fi поповера.
                const needsPassword = !Uuid && (SecurityType === PlasmaNM.Enums.StaticWep
                    || SecurityType === PlasmaNM.Enums.WpaPsk
                    || SecurityType === PlasmaNM.Enums.Wpa2Psk
                    || SecurityType === PlasmaNM.Enums.SAE);
                if (needsPassword) {
                    root.requestPage("network");
                } else if (!Uuid) {
                    handler.addAndActivateConnection(DevicePath, SpecificPath);
                } else {
                    handler.activateConnection(ConnectionPath, DevicePath, SpecificPath);
                }
            }
        }

        onObjectAdded: (index, object) => networkMenu.addMenuItem(object, networkAnchor)
        onObjectRemoved: (index, object) => networkMenu.removeMenuItem(object)
    }

    // --- Контекстное меню значка звука --------------------------------------
    Menu {
        id: volumeMenu
        placement: root.menuPlacement()

        MenuItem {
            id: volumeAnchor
            visible: false
        }

        MenuItem {
            text: i18n("Volume mixer")
            icon: "audio-volume-medium"
            onClicked: root.requestPage("volume")
        }

        MenuItem {
            text: i18n("Sound settings…")
            icon: "configure"
            onClicked: KCMLauncher.openSystemSettings("kcm_pulseaudio")
        }
    }

    Instantiator {
        id: volumeItems
        model: root.sinkFilterModel

        delegate: MenuItem {
            text: Description || Name || i18n("Unknown device")
            icon: Funcs.volIconName(Volume, Muted)
            checkable: true
            checked: PulseObject && PulseObject.default
            onClicked: if (PulseObject) {
                PulseObject.default = true;
            }
        }

        onObjectAdded: (index, object) => volumeMenu.addMenuItem(object, volumeAnchor)
        onObjectRemoved: (index, object) => volumeMenu.removeMenuItem(object)
    }

    // --- Контекстное меню значка яркости ------------------------------------
    Menu {
        id: brightnessMenu
        placement: root.menuPlacement()

        MenuItem {
            text: i18n("Screen settings…")
            icon: "preferences-desktop-display"
            onClicked: KCMLauncher.openSystemSettings("kcm_kscreen")
        }

        MenuItem {
            text: i18n("Night Light…")
            icon: "night-light-symbolic"
            onClicked: KCMLauncher.openSystemSettings("kcm_nightlight")
        }
    }

    // --- Контекстное меню значка батареи ------------------------------------
    Menu {
        id: batteryMenu
        placement: root.menuPlacement()

        MenuItem {
            text: i18n("Battery Saver")
            icon: "battery-low-symbolic"
            checkable: true
            checked: powerProfiles.activeProfile === "power-saver"
            visible: powerProfiles.isPowerProfileDaemonInstalled && powerProfiles.profiles.indexOf("power-saver") >= 0
            onClicked: {
                if (powerProfiles.activeProfile === "power-saver") {
                    powerProfiles.setProfile(powerProfiles.configuredProfile || "balanced");
                } else {
                    powerProfiles.setProfile("power-saver");
                }
            }
        }

        MenuItem {
            separator: true
        }

        MenuItem {
            text: i18n("Power settings…")
            icon: "configure"
            onClicked: KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig")
        }
    }
}
