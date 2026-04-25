import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // Edit copies — bound from settings, written back on every slider move so
    // the open Panel reflects changes in real time.
    property real editZoom: cfg.zoom ?? defaults.zoom ?? 1.0
    property real editCropTop: cfg.cropTop ?? defaults.cropTop ?? 0
    property real editCropBottom: cfg.cropBottom ?? defaults.cropBottom ?? 0
    property real editCropLeft: cfg.cropLeft ?? defaults.cropLeft ?? 0
    property real editCropRight: cfg.cropRight ?? defaults.cropRight ?? 0
    property int editMaxTitles: cfg.maxTitles ?? defaults.maxTitles ?? 3
    property bool editRoundedCorners: cfg.roundedCorners ?? defaults.roundedCorners ?? true
    property bool editShowWorkspaceName: cfg.showWorkspaceName ?? defaults.showWorkspaceName ?? true
    property real editCardInnerGap: cfg.cardInnerGap ?? defaults.cardInnerGap ?? 8

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("WorkspaceOverview", "Cannot save: pluginApi is null")
            return
        }
        pluginApi.pluginSettings.zoom = root.editZoom
        pluginApi.pluginSettings.cropTop = root.editCropTop
        pluginApi.pluginSettings.cropBottom = root.editCropBottom
        pluginApi.pluginSettings.cropLeft = root.editCropLeft
        pluginApi.pluginSettings.cropRight = root.editCropRight
        pluginApi.pluginSettings.maxTitles = root.editMaxTitles
        pluginApi.pluginSettings.roundedCorners = root.editRoundedCorners
        pluginApi.pluginSettings.showWorkspaceName = root.editShowWorkspaceName
        pluginApi.pluginSettings.cardInnerGap = root.editCardInnerGap
        pluginApi.saveSettings()
    }

    // ─── Rounded Corners ───
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.rounded-corners")
        description: pluginApi?.tr("settings.rounded-corners-desc")
        checked: root.editRoundedCorners
        onToggled: checked => {
            root.editRoundedCorners = checked
            root.saveSettings()
        }
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.roundedCorners ?? true
    }

    // ─── Show Workspace Name ───
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-workspace-name")
        description: pluginApi?.tr("settings.show-workspace-name-desc")
        checked: root.editShowWorkspaceName
        onToggled: checked => {
            root.editShowWorkspaceName = checked
            root.saveSettings()
        }
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.showWorkspaceName ?? true
    }

    // ─── Max Window Titles ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.max-titles") + ": " + root.editMaxTitles
            description: pluginApi?.tr("settings.max-titles-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 10
            stepSize: 1
            value: root.editMaxTitles
            onMoved: {
                root.editMaxTitles = Math.round(value)
                root.saveSettings()
            }
        }
    }

    // ─── Zoom ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.zoom") + ": " + root.editZoom.toFixed(2) + "x"
            description: pluginApi?.tr("settings.zoom-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.5
            to: 3.0
            stepSize: 0.05
            value: root.editZoom
            onMoved: {
                root.editZoom = Math.round(value * 100) / 100
                root.saveSettings()
            }
        }
    }

    // ─── Crop Top ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.crop-top") + ": " + Math.round(root.editCropTop) + " px"
            description: pluginApi?.tr("settings.crop-top-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 500
            stepSize: 1
            value: root.editCropTop
            onMoved: {
                root.editCropTop = Math.round(value)
                root.saveSettings()
            }
        }
    }

    // ─── Crop Bottom ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.crop-bottom") + ": " + Math.round(root.editCropBottom) + " px"
            description: pluginApi?.tr("settings.crop-bottom-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 500
            stepSize: 1
            value: root.editCropBottom
            onMoved: {
                root.editCropBottom = Math.round(value)
                root.saveSettings()
            }
        }
    }

    // ─── Crop Left ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.crop-left") + ": " + Math.round(root.editCropLeft) + " px"
            description: pluginApi?.tr("settings.crop-left-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 500
            stepSize: 1
            value: root.editCropLeft
            onMoved: {
                root.editCropLeft = Math.round(value)
                root.saveSettings()
            }
        }
    }

    // ─── Crop Right ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.crop-right") + ": " + Math.round(root.editCropRight) + " px"
            description: pluginApi?.tr("settings.crop-right-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 500
            stepSize: 1
            value: root.editCropRight
            onMoved: {
                root.editCropRight = Math.round(value)
                root.saveSettings()
            }
        }
    }

    // ─── Card Inner Gap ───
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.card-inner-gap") + ": " + Math.round(root.editCardInnerGap) + " px"
            description: pluginApi?.tr("settings.card-inner-gap-desc")
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 32
            stepSize: 1
            value: root.editCardInnerGap
            onMoved: {
                root.editCardInnerGap = Math.round(value)
                root.saveSettings()
            }
        }
    }
}
