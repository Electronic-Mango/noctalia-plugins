import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Commons
import qs.Widgets
import qs.Services.UI
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    // --- Mandatory Panel Properties (Injected by Noctalia) ---
    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    // --- Settings access ---
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // --- Tunable sizing (single source of truth) ---
    // Master zoom multiplier — change this single number to scale the whole
    // overview (cards, previews, paddings) up or down. 1.0 = default size.
    property real zoom: cfg.zoom ?? defaults.zoom ?? 1.0

    // Mini-monitor preview size. previewHeight is derived from the actual
    // monitor aspect (after crops) of a representative workspace, so the
    // preview rectangle exactly matches the rendered content — leaving no
    // centering slack and keeping the four card gaps visually equal.
    property real previewWidth: 199.663 * Style.uiScaleRatio * zoom
    // Reference monitor: pick the focused workspace's monitor if available,
    // else the first Hyprland monitor, else fall back to 16:9.
    readonly property var referenceMonitor: {
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor) {
            return Hyprland.focusedWorkspace.monitor
        }
        if (Hyprland.monitors && Hyprland.monitors.values && Hyprland.monitors.values.length > 0) {
            return Hyprland.monitors.values[0]
        }
        return null
    }
    readonly property real referenceAspect: {
        if (!referenceMonitor) return 16 / 9
        var s = referenceMonitor.scale > 0 ? referenceMonitor.scale : 1.0
        var w = (referenceMonitor.width > 0 ? referenceMonitor.width : 1920) / s
        var h = (referenceMonitor.height > 0 ? referenceMonitor.height : 1080) / s
        // Apply crops so the budget matches the cropped (visible) region.
        var cw = Math.max(1, w - cropLeft - cropRight)
        var ch = Math.max(1, h - cropTop - cropBottom)
        return cw / ch
    }
    property real previewHeight: previewWidth / referenceAspect

    // Maximum number of window titles listed under each workspace name.
    // 0 hides the list entirely. Excess titles are truncated with an ellipsis row.
    property int maxTitles: cfg.maxTitles ?? defaults.maxTitles ?? 3

    // Round the corners of the mini-monitor preview. Implemented via a
    // MultiEffect mask, which costs an extra render pass per workspace card
    // every frame the live ScreencopyView updates. Disable for sharper edges
    // and zero shader cost.
    property bool roundedCorners: cfg.roundedCorners ?? defaults.roundedCorners ?? true

    // Show the workspace name/title row above the preview. When disabled, the
    // top inner gap automatically grows from cardSideGap/2 to cardSideGap so
    // the visible space above the preview matches the side gaps.
    property bool showWorkspaceName: cfg.showWorkspaceName ?? defaults.showWorkspaceName ?? true

    // Card vertical padding is split into a fixed chrome (workspace name +
    // outer margins + spacing) and a dynamic title-list reservation that
    // shrinks/grows with `maxTitles`. This keeps the card just tall enough
    // for the configured number of title rows.
    property real titleRowHeight: 11 * Style.uiScaleRatio * zoom
    property real titleRowSpacing: 1 * Style.uiScaleRatio
    property real titleListHeight: maxTitles > 0
        ? (maxTitles * titleRowHeight) + (Math.max(0, maxTitles - 1) * titleRowSpacing)
        : 0

    // --- Unified card gaps ---
    // Gap (in logical pixels) between the mini-monitor preview and the card
    // edges. Sides and bottom use the full gap; the top uses half (since the
    // workspace title is short, a smaller gap looks balanced). The vertical
    // gap *between* items inside the card also matches the top gap, so when
    // `maxTitles == 0` the spacing above and below the workspace title is equal.
    // This is a fixed pixel value (not zoom-scaled) so users can tune it
    // independently of the master zoom multiplier.
    property real cardSideGap: cfg.cardInnerGap ?? defaults.cardInnerGap ?? 8
    // When the workspace name is shown the title is a small label so a half
    // gap above it looks balanced; without it, use the full side gap so the
    // preview sits symmetrically inside the card.
    property real cardTopMargin: showWorkspaceName ? cardSideGap / 2 : cardSideGap
    property real cardBottomMargin: cardSideGap
    property real cardSpacingV: cardSideGap / 2

    // Approximate height of the workspace title row (default NText, bold).
    property real workspaceNameHeight: Style.fontSizeM * Style.uiScaleRatio * zoom * 1.4

    // Chrome = name row (if shown) + top/bottom margins + spacings between
    // the visible items in the card column (name?, titles slot?, preview).
    readonly property int cardVisibleItems: (showWorkspaceName ? 1 : 0) + (maxTitles > 0 ? 1 : 0) + 1
    property real cardChrome: cardTopMargin
        + (showWorkspaceName ? workspaceNameHeight : 0)
        + cardSpacingV * Math.max(0, cardVisibleItems - 1)
        + cardBottomMargin
    property real cardPaddingV: cardChrome + titleListHeight
    // Horizontal padding around the preview — same gap on both sides as bottom.
    property real cardPaddingH: cardSideGap * 2
    // Derived card and grid-cell sizes.
    property real cardWidth: previewWidth + cardPaddingH
    property real cardHeight: previewHeight + cardPaddingV

    // Uniform gap between cards. Each cell reserves cardGap of internal
    // padding (half on every side), so two adjacent cells contribute one full
    // cardGap between them. Outer gaps are intentionally DOUBLE the inner gap
    // for visual breathing room around the grid: gridOuterPadding contributes
    // 1.5 * cardGap and the cell internal half-gap adds the remaining 0.5 →
    // total outer gap = 2 * cardGap.
    property real cardGap: Style.marginS * zoom
    property real gridOuterPadding: cardGap * 1.5

    // --- Workspace crop (in monitor logical pixels) ---
    // Hide N pixels from each side of the workspace preview to "zoom in" on a
    // specific region (e.g. trim a status bar from the top, or focus on the
    // center). Values are in logical/scaled pixels matching hyprctl coordinates.
    // Set all to 0 to show the full workspace.
    property real cropTop: cfg.cropTop ?? defaults.cropTop ?? 0
    property real cropBottom: cfg.cropBottom ?? defaults.cropBottom ?? 0
    property real cropLeft: cfg.cropLeft ?? defaults.cropLeft ?? 0
    property real cropRight: cfg.cropRight ?? defaults.cropRight ?? 0

    // Maximum columns shown in the grid — drives the panel width.
    property int maxColumns: 3
    // Horizontal panel chrome: outer ColumnLayout margins + the half-gap padding
    // each outermost cell adds. Keeps the visible card-to-edge distance equal
    // to the vertical edges.
    property real panelHorizontalChrome: Style.marginL * 2

    // Recommended dimensions adapted to the interface scale.
    // Width scales with the cards so they never overlap at higher zoom levels.
    // Total width = inner cells (cardWidth + cardGap each) + outer padding on
    // both sides + the panel's outer ColumnLayout margins.
    property real contentPreferredWidth: ((cardWidth + cardGap) * maxColumns) + (gridOuterPadding * 2) + panelHorizontalChrome
    // The outer Noctalia wrapper has slightly asymmetric padding (a bit
    // smaller on the bottom since the panel is bar-attached). Reserve a small
    // amount of extra bottom space inside our content so the visible bottom
    // gap below the grid matches the side gaps. Tune if it over/undershoots.
    property real extraBottomMargin: Style.marginL / 2
    // Height = column outer margins + header + spacing + grid content + extra bottom.
    property real panelVerticalChrome: (Style.marginL * 3) + (Style.fontSizeXL * Style.uiScaleRatio * 1.6) + extraBottomMargin
    property real contentPreferredHeight: Math.max(320 * Style.uiScaleRatio, (workspaceGrid.computedRows * workspaceGrid.cellHeight) + (gridOuterPadding * 2) + panelVerticalChrome)

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                topMargin: Style.marginL
                leftMargin: Style.marginL
                rightMargin: Style.marginL
                // Extra bottom margin compensates for the outer wrapper's smaller
                // bottom padding, so the visible bottom gap matches the sides.
                bottomMargin: Style.marginL + root.extraBottomMargin
            }
            spacing: Style.marginL

            // --- Header ---
            RowLayout {
                Layout.fillWidth: true
                NText {
                    text: pluginApi?.tr("panel.title") || "Workspace Overview"
                    pointSize: Style.fontSizeXL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
                NIconButton {
                    icon: "x"
                    onClicked: {
                        if (pluginApi) {
                            pluginApi.closePanel(pluginApi.panelOpenScreen)
                        }
                    }
                }
            }

            // --- Workspaces Area (Grid) ---
            // Layout.fillHeight is intentionally false here so the grid box
            // hugs its content. This makes the gap between the last row of
            // cards and the panel's bottom edge equal to the side gaps
            // (Style.marginL), instead of having extra slack distributed by
            // a vertically-centered grid.
            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: (workspaceGrid.computedRows * workspaceGrid.cellHeight) + (root.gridOuterPadding * 2)
                clip: true // Enable clipping to hide the overflow

                NGridView {
                    id: workspaceGrid
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    // Widen the grid and push its internal scrollbar beyond the clipped parent edge.
                    // Subtract gridOuterPadding so the right-side outer gap matches the left.
                    width: parent.width + (40 * Style.uiScaleRatio) - root.gridOuterPadding

                    // Outer padding via anchor margins only — don't ALSO set NGridView's
                    // own topMargin/leftMargin, or padding compounds and content gets
                    // pushed past the NBox bottom edge (clipped → last row cut off).
                    anchors.leftMargin: root.gridOuterPadding
                    anchors.topMargin: root.gridOuterPadding
                    anchors.bottomMargin: root.gridOuterPadding

                    // Use a deterministic cellWidth = card + cardGap so each cell
                    // contributes exactly cardGap/2 of internal padding on each side.
                    // Combined with gridOuterPadding (= 1.5 * cardGap) on the left and
                    // right, both visible side gaps equal 2 * cardGap and stay symmetric.
                    // (Computing cellWidth from parent.width would make it depend on
                    // the grid's widened width, producing asymmetric left/right padding.)
                    cellWidth: root.cardWidth + root.cardGap
                    cellHeight: root.cardHeight + root.cardGap

                    // The distribution is now handled by the dynamic cellWidth relative to the visible panel
                    property int columns: Math.max(1, Math.min(count, root.maxColumns))
                    property int computedRows: Math.max(1, Math.ceil(count / columns))

                    clip: true
                    
                    // Using the real Hyprland model provided by Quickshell
                    model: Hyprland.workspaces

                    // --- Workspace Component ---
                    delegate: DropArea {
                        width: workspaceGrid.cellWidth
                        height: workspaceGrid.cellHeight

                        // The "required property" tells QML: "I expect the model to send me a modelData"
                        required property var modelData 
                        
                        // Now you use it directly, without fear of being undefined
                        property int targetWorkspaceId: modelData.id

                        // Action when dropping the window in this workspace
                        onDropped: (drop) => {
                            if (drop.hasText && drop.text !== "") {
                                let windowData = JSON.parse(drop.text);
                                Logger.i("Workspace Overview", "Move window " + windowData.winId + " to workspace " + targetWorkspaceId);
                                
                                // Hyprland command via Quickshell
                                Hyprland.dispatch("movetoworkspacesilent " + targetWorkspaceId + ",address:" + windowData.winId);
                            }
                        }

                        NBox {
                            id: workspaceBg
                            width: root.cardWidth
                            height: root.cardHeight
                            anchors.centerIn: parent
                            
                            // Visual highlight if it is the active workspace or if it contains drag
                            readonly property bool isActiveWorkspace: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                            
                            // Using conditional color while still being an NBox for theme consistency
                            color: isActiveWorkspace ? Color.mPrimary : (parent.containsDrag ? Color.mSurfaceVariant : Color.mSurface)
                            border.color: isActiveWorkspace ? Color.mOnPrimary : Color.mOutline
                            border.width: parent.containsDrag ? 4 : 0
                            opacity: parent.containsDrag ? 0.8 : 1.0

                            // MouseArea to click on the workspace and switch to it
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (targetWorkspaceId !== undefined) {
                                        Hyprland.dispatch("workspace " + targetWorkspaceId);
                                        if (pluginApi) {
                                            pluginApi.closePanel(pluginApi.panelOpenScreen);
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    topMargin: root.cardTopMargin
                                    bottomMargin: root.cardBottomMargin
                                    leftMargin: root.cardSideGap
                                    rightMargin: root.cardSideGap
                                }
                                spacing: root.cardSpacingV

                                NText {
                                    text: modelData.name !== "" ? modelData.name : "Workspace " + modelData.id
                                    font.weight: Font.Bold
                                    color: workspaceBg.isActiveWorkspace ? Color.mOnPrimary : Color.mOnSurface
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: root.showWorkspaceName
                                }

                                // List of active windows (Titles)
                                // Reserve a FIXED slot equal to `maxTitles` rows so the mini-monitor
                                // always sits at the same vertical offset regardless of how many
                                // windows the workspace currently has (0, 1, or maxTitles).
                                Column {
                                    id: titlesColumn
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.titleListHeight
                                    Layout.minimumHeight: root.titleListHeight
                                    Layout.maximumHeight: root.titleListHeight
                                    spacing: root.titleRowSpacing
                                    clip: true
                                    visible: root.maxTitles > 0

                                    readonly property int totalTitles: modelData.toplevels ? (modelData.toplevels.count !== undefined ? modelData.toplevels.count : modelData.toplevels.length || 0) : 0
                                    readonly property int overflow: Math.max(0, totalTitles - root.maxTitles)

                                    Repeater {
                                        model: modelData.toplevels || null
                                        delegate: NText {
                                            required property var modelData
                                            required property int index
                                            visible: index < root.maxTitles
                                            height: visible ? implicitHeight : 0
                                            width: root.previewWidth
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "• " + (modelData.title || "App")
                                            pointSize: 8 * Style.uiScaleRatio
                                            elide: Text.ElideRight
                                            color: workspaceBg.isActiveWorkspace ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    NText {
                                        visible: titlesColumn.overflow > 0
                                        height: visible ? implicitHeight : 0
                                        width: root.previewWidth
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "+ " + titlesColumn.overflow + " more"
                                        pointSize: 8 * Style.uiScaleRatio
                                        elide: Text.ElideRight
                                        color: workspaceBg.isActiveWorkspace ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                // Mini-monitor background (Real wallpaper or solid color)
                                Rectangle {
                                    id: miniMonitor

                                    // Resolve the workspace's monitor up here so we can size the preview
                                    // to match the CROPPED aspect ratio. Without this, the rectangle is
                                    // locked at 16:9 and an off-ratio crop stretches the window thumbnails.
                                    property var wsMonitor: modelData.monitor || null
                                    property real monitorScale: wsMonitor && wsMonitor.scale > 0 ? wsMonitor.scale : 1.0
                                    property real rawMonitorX: wsMonitor ? wsMonitor.x : 0
                                    property real rawMonitorY: wsMonitor ? wsMonitor.y : 0
                                    property real rawMonitorW: (wsMonitor && wsMonitor.width > 0 ? wsMonitor.width : 1920) / monitorScale
                                    property real rawMonitorH: (wsMonitor && wsMonitor.height > 0 ? wsMonitor.height : 1080) / monitorScale

                                    // Cropped (visible) region of the monitor.
                                    property real monitorX: rawMonitorX + root.cropLeft
                                    property real monitorY: rawMonitorY + root.cropTop
                                    property real monitorW: Math.max(1, rawMonitorW - root.cropLeft - root.cropRight)
                                    property real monitorH: Math.max(1, rawMonitorH - root.cropTop - root.cropBottom)

                                    // Fit the cropped region inside the previewWidth × previewHeight
                                    // budget while preserving its aspect ratio (uniform scale → no
                                    // stretched windows). The card budget stays constant so cards in
                                    // the grid remain aligned; the preview just shrinks on one axis
                                    // when the crop isn't 16:9.
                                    property real cropAspect: monitorW / monitorH
                                    property real budgetAspect: root.previewWidth / root.previewHeight
                                    property real fitW: cropAspect >= budgetAspect ? root.previewWidth : root.previewHeight * cropAspect
                                    property real fitH: cropAspect >= budgetAspect ? root.previewWidth / cropAspect : root.previewHeight

                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                    Layout.preferredWidth: fitW
                                    Layout.preferredHeight: fitH
                                    color: Qt.rgba(0, 0, 0, 0.4)
                                    border.color: parent.parent.isActiveWorkspace ? Color.mOnPrimary : Color.mOutline
                                    border.width: 2 * Style.uiScaleRatio
                                    radius: root.roundedCorners ? Style.radiusS : 0
                                    // When rounded corners are off, plain `clip: true` is enough — the
                                    // axis-aligned bbox matches the rectangle's painted shape exactly,
                                    // so no MultiEffect is needed and no shader pass runs per frame.
                                    // When rounded corners are on, we disable native clipping and let
                                    // the MultiEffect mask below shape the children instead (otherwise
                                    // the square clip would create a visible "outline" inside the radius).
                                    clip: !root.roundedCorners

                                    // Uniform scale — same on both axes since the rect now matches
                                    // the cropped aspect ratio. Windows keep their proportions.
                                    property real scaleX: width / monitorW
                                    property real scaleY: height / monitorH

                                    // Rounded mask: shape used by MultiEffect to cut the wallpaper +
                                    // window thumbnails to the same rounded rect as the border.
                                    // `visible: false + layer.enabled: true` makes it a render source
                                    // without actually drawing it on screen.
                                    Rectangle {
                                        id: miniMonitorMask
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "black"
                                        visible: false
                                        // Only allocate the mask layer when we actually need it.
                                        layer.enabled: root.roundedCorners
                                    }

                                    // All maskable content lives inside this Item so the MultiEffect
                                    // can mask everything in one pass. Border stays on the outer
                                    // Rectangle (drawn on top — so it's not blurred by the effect).
                                    Item {
                                        id: miniMonitorContent
                                        anchors.fill: parent
                                        // Layer + MultiEffect only when rounded corners are enabled.
                                        // When disabled, this is a plain Item (zero shader cost) and
                                        // the outer Rectangle's `clip: true` handles square clipping.
                                        layer.enabled: root.roundedCorners
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: miniMonitorMask
                                            // Hard-edged mask — we want a clean rounded rect, not a feathered one.
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                        }

                                    // Wallpaper
                                    Image {
                                        anchors.fill: parent
                                        source: typeof WallpaperService !== "undefined" ? WallpaperService.getWallpaper(modelData.monitor.name) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: source != ""
                                        opacity: 0.8
                                    }

                                    Repeater {
                                        model: modelData.toplevels || null
                                        delegate: Rectangle {
                                            // Using 'required property var modelData' forces QML to get the modelData from the internal Repeater
                                            // escaping the scope shadowing generated by the external GridView.
                                            required property var modelData
                                            
                                            // Geometric information comes from the lastIpcObject associated with the window (inner modelData)
                                            property var ipcObj: modelData.lastIpcObject || null
                                            property real winX: ipcObj && ipcObj.at ? ipcObj.at[0] : 0
                                            property real winY: ipcObj && ipcObj.at ? ipcObj.at[1] : 0
                                            property real winW: ipcObj && ipcObj.size ? ipcObj.size[0] : 0
                                            property real winH: ipcObj && ipcObj.size ? ipcObj.size[1] : 0
                                            
                                            // Position relative to the monitor
                                            x: (winX - miniMonitor.monitorX) * miniMonitor.scaleX
                                            y: (winY - miniMonitor.monitorY) * miniMonitor.scaleY
                                            width: Math.max(2, winW * miniMonitor.scaleX)
                                            height: Math.max(2, winH * miniMonitor.scaleY)
                                            
                                            // Ignore unmapped (hidden) windows
                                            visible: modelData.mapped !== undefined ? modelData.mapped : (ipcObj !== null && ipcObj.mapped !== undefined ? ipcObj.mapped : true)
                                            
                                            color: Color.mPrimary
                                            border.color: Color.mBackground
                                            border.width: Math.max(1, 1 * Style.uiScaleRatio)
                                            radius: 2 * Style.uiScaleRatio
                                            clip: true
                                            
                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: modelData.wayland
                                                live: true
                                                paintCursor: true
                                                
                                                // Optimization: Only capture at the resolution we are displaying
                                                constraintSize: Qt.size(parent.width, parent.height)
                                            }
                                        }
                                    }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
