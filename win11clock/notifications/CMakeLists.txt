# C++ QML-плагин win11clock: окна всплывающих уведомлений (toast).
#
# Форк applets/notifications из plasma-workspace 6.7.5 (GPL-2.0+/GPL-3.0+).
# Отдельный QML-модуль, потому что C++ QML-плагин нельзя положить внутрь
# KPackage-архива: он ставится в ~/.local/lib/qt6/qml и подхватывается
# plasmashell через QML_IMPORT_PATH (systemd drop-in).

cmake_minimum_required(VERSION 3.20)

project(win11clock-notifications VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM REQUIRED 5.240.0)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Qt6 6.7 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF6 REQUIRED COMPONENTS
    ConfigWidgets
    CoreAddons
    GlobalAccel
    I18n
    KIO
    Notifications
    WindowSystem
)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)
find_package(PlasmaWaylandProtocols REQUIRED)
find_package(LibNotificationManager REQUIRED)

# --- plasma-shell протокол -------------------------------------------------
# В системе нет WaylandScannerConfig.cmake и пакета Qt6WaylandClient, поэтому
# заголовок Qt-обёртки генерируется напрямую wayland-scanner/qtwaylandscanner
# (так же, как это делает qt_generate_wayland_protocol_client_sources).
find_program(WAYLAND_SCANNER_EXECUTABLE NAMES wayland-scanner REQUIRED)
find_program(QTWAYLANDSCANNER_EXECUTABLE NAMES qtwaylandscanner
    HINTS ${Qt6_DIR}/../../../qt6 /usr/lib/qt6 /usr/libexec)

set(PLASMA_SHELL_XML ${PLASMA_WAYLAND_PROTOCOLS_DIR}/plasma-shell.xml)
set(WAYLAND_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/wayland)
set(WAYLAND_INCLUDE_SUBDIR wayland-protocols)
file(MAKE_DIRECTORY ${WAYLAND_GEN_DIR}/${WAYLAND_INCLUDE_SUBDIR})

add_custom_command(
    OUTPUT ${WAYLAND_GEN_DIR}/${WAYLAND_INCLUDE_SUBDIR}/wayland-plasma-shell-client-protocol.h
    COMMAND ${WAYLAND_SCANNER_EXECUTABLE} client-header
            ${PLASMA_SHELL_XML}
            ${WAYLAND_GEN_DIR}/${WAYLAND_INCLUDE_SUBDIR}/wayland-plasma-shell-client-protocol.h
    DEPENDS ${PLASMA_SHELL_XML}
    COMMENT "Generating wayland-plasma-shell-client-protocol.h"
)
add_custom_command(
    OUTPUT ${WAYLAND_GEN_DIR}/qwayland-plasma-shell.h
    COMMAND ${QTWAYLANDSCANNER_EXECUTABLE} client-header
            ${PLASMA_SHELL_XML}
            --header-path=${WAYLAND_INCLUDE_SUBDIR}
            > ${WAYLAND_GEN_DIR}/qwayland-plasma-shell.h
    DEPENDS ${PLASMA_SHELL_XML}
            ${WAYLAND_GEN_DIR}/${WAYLAND_INCLUDE_SUBDIR}/wayland-plasma-shell-client-protocol.h
    COMMENT "Generating qwayland-plasma-shell.h"
)

# --- QML-модуль ------------------------------------------------------------
# QTP0004: qmldir для подкаталогов (components/, delegates/, global/) —
# без них относительные импорты вида `import "../components"` не резолвятся.
qt_policy(SET QTP0004 NEW)

set_source_files_properties(global/Globals.qml PROPERTIES QT_QML_SINGLETON_TYPE ON)

qt_add_qml_module(win11clocknotifications
    URI org.mops1k.win11clock.notifications
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/org/mops1k/win11clock/notifications
    SOURCES
        src/notificationwindow.cpp
        src/notificationwindow.h
        src/inputdisabler.cpp
        src/inputdisabler.h
        src/draghelper.cpp
        src/draghelper.h
        src/fileinfo.cpp
        src/fileinfo.h
        src/filemenu.cpp
        src/filemenu.h
        src/globalshortcuts.cpp
        src/globalshortcuts.h
        src/jobaggregator.cpp
        src/jobaggregator.h
        src/thumbnailer.cpp
        src/thumbnailer.h
    QML_FILES
        NotificationPopup.qml
        DraggableDelegate.qml
        delegates/BaseDelegate.qml
        delegates/DelegateHistory.qml
        delegates/DelegateHistoryGrouped.qml
        delegates/DelegatePopup.qml
        components/ActionContainer.qml
        components/Body.qml
        components/DraggableFileArea.qml
        components/EditContextMenu.qml
        components/FooterLoader.qml
        components/HeadingButtons.qml
        components/Icon.qml
        components/JobDetails.qml
        components/JobIconItem.qml
        components/JobItem.qml
        components/ModelInterface.qml
        components/NotificationHeader.qml
        components/NotificationReplyField.qml
        components/SpeedChart.qml
        components/Summary.qml
        components/ThumbnailStrip.qml
        global/Globals.qml
        global/PulseAudio.qml
)

# --- Лог-категория (используется в fileinfo.cpp) ---------------------------
include(ECMQtDeclareLoggingCategory)
ecm_qt_declare_logging_category(win11clocknotifications
    HEADER notifications_debug.h
    IDENTIFIER PLASMA_APPLET_NOTIFICATIONS_DEBUG
    CATEGORY_NAME org.mops1k.win11clock.notifications
    DESCRIPTION "win11clock notification popups"
)

target_include_directories(win11clocknotifications PRIVATE
    ${WAYLAND_GEN_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Сгенерированный заголовок нужен до сборки исходников плагина.
add_custom_target(win11clock_wayland_gen
    DEPENDS ${WAYLAND_GEN_DIR}/qwayland-plasma-shell.h
)
add_dependencies(win11clocknotifications win11clock_wayland_gen)

target_link_libraries(win11clocknotifications PRIVATE
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    KF6::ConfigWidgets
    KF6::CoreAddons
    KF6::GlobalAccel
    KF6::I18n
    KF6::KIOGui
    KF6::KIOWidgets
    KF6::Notifications
    KF6::WindowSystem
    Plasma::PlasmaQuick
    PW::LibNotificationManager
)

# Плагин и backing-библиотека лежат в одном каталоге QML-модуля, поэтому
# RUNPATH по умолчанию (…/lib) не находит libwin11clocknotifications.so.
set_target_properties(win11clocknotificationsplugin PROPERTIES
    BUILD_RPATH "$ORIGIN"
    INSTALL_RPATH "$ORIGIN"
)

# --- Установка -------------------------------------------------------------
set(WIN11CLOCK_QML_DIR ${QT6_INSTALL_QML}/org/mops1k/win11clock/notifications)

install(TARGETS win11clocknotifications
    LIBRARY DESTINATION ${WIN11CLOCK_QML_DIR}
    RUNTIME DESTINATION ${WIN11CLOCK_QML_DIR}
)
install(TARGETS win11clocknotificationsplugin
    LIBRARY DESTINATION ${WIN11CLOCK_QML_DIR}
    RUNTIME DESTINATION ${WIN11CLOCK_QML_DIR}
)
install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/org/mops1k/win11clock/notifications/
    DESTINATION ${WIN11CLOCK_QML_DIR}
    FILES_MATCHING
    PATTERN "*.qml"
    PATTERN "qmldir"
    PATTERN "*.qmltypes"
)
