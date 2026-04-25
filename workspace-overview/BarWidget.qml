import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // Bar layout awareness — match the capsule sizing other plugins use.
    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    implicitWidth: capsuleHeight
    implicitHeight: capsuleHeight

    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    // Capsule background, matching the rest of the bar widgets.
    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.capsuleHeight
        height: root.capsuleHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        NIcon {
            anchors.centerIn: parent
            icon: "layout-dashboard"
            color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
    }

    // Right-click context menu — provides access to widget settings, matching other plugins.
    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": pluginApi?.tr("menu.settings") || "Widget settings",
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi) {
                    pluginApi.togglePanel(root.screen, root)
                }
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            }
        }
    }
}
