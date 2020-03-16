/*
 * Copyright (C) 2020
 *      Jean-Luc Barriere <jlbarriere68@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQml.Models 2.3
import Osmin 1.0
import "./components"
import "../toolbox.js" as ToolBox

MapPage {
    id: favoritesPage

    states: [
        State {
            name: "default"
        },
        State {
            name: "selection"
            PropertyChanges { target: favoritesPage; pageTitle: qsTr("Select a Place"); }
        }
    ]

    state: "default"

    pageTitle: qsTr("Favorite Places")
    pageFlickable: favoritesView

    signal selectPOI(var poi)

    onPopped: {
        // a slot could be connected to signal, waiting a selection
        // trigger the signal for null
        if (state === "selection")
            selectPOI(null);
    }

    MapListView {
        id: favoritesView
        contentHeight: contentHeight
        anchors.fill: parent
        anchors.bottomMargin: mapPreview.height

        model: SortFilterModel {
            model: FavoritesModel
            sort.property: "label"
            sort.order: Qt.AscendingOrder
            sortCaseSensitivity: Qt.CaseInsensitive
            //filter.property: "normalized"
            //filter.pattern: new RegExp(Utils.normalizedInputString(filter.displayText), "i")
            //filterCaseSensitivity: Qt.CaseInsensitive
        }

        delegate: SimpleListItem {
            id: favoriteItem
            height: units.gu(8)
            color: "transparent"

            column: Column {
                Row {
                    POIIcon {
                      id: poi
                      anchors.verticalCenter: parent.verticalCenter
                      poiType: type
                      color: styleMap.view.foregroundColor
                      width: units.gu(6)
                      height: units.gu(6)
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - poi.width
                        Label {
                            width: parent.width
                            color: styleMap.view.primaryColor
                            font.pointSize: units.fs("medium")
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            text: label
                        }
                        Label {
                            font.pointSize: units.fs("x-small")
                            color: styleMap.view.secondaryColor
                            text: Converter.readableCoordinatesGeocaching(lat, lon)
                        }
                    }
                }
            }

            highlighted: parent.pressed || index === favoritesView.currentIndex

            onPressAndHold: {
                if (favoritesPage.state === "default") {
                    mapPage.navigateTo(lat, lon, label);
                    stackView.pop();
                }
            }

            onClicked: {
                forceActiveFocus();
                favoritesView.currentIndex = index;
                selectedPOI = { "lat": lat, "lon": lon, "label": label, "type": type };
            }

            menuItems: [
                MenuItem {
                    visible: favoritesPage.state === "default"
                    height: (visible ? implicitHeight : 0)
                    text: qsTr("Go there")
                    font.pointSize: units.fs("medium")
                    onTriggered: {
                        mapPage.navigateTo(lat, lon, label);
                        stackView.pop();
                    }
                },
                MenuItem {
                    text: qsTr("Rename")
                    font.pointSize: units.fs("medium")
                    onTriggered: {
                        dialogEdit.model = model;
                        dialogEdit.open();
                        ToolBox.connectOnce(dialogEdit.editRequested, updateModel);
                    }
                    function updateModel(model) {
                        createFavorite(model.lat, model.lon, model.label);
                        removeFavorite(model.id);
                    }
                },
                MenuItem {
                    text: qsTr("Delete")
                    font.pointSize: units.fs("medium")
                    onTriggered: removeFavorite(model.id);
                }
            ]

            menuVisible: true
        }
    }

    property var selectedPOI: null

    Loader {
        id: mapPreview
         // active the preview on selection
        active: selectedPOI !== null
        height: active ? parent.height / 2 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        asynchronous: true
        sourceComponent: Item {
            id: preview
            anchors.fill: parent
            property alias map: map
            Map {
                id: map
                showCurrentPosition: true
                anchors.fill: parent

                onTap: {
                    // on tap change the location
                    preview.mark.selected = false;  // not the selected location
                    preview.mark.lat = lat;
                    preview.mark.lon = lon;
                    preview.mark.label = Converter.readableCoordinatesGeocaching(lat, lon);
                    preview.mark.type = "";
                    locationInfoModel.setLocation(lat, lon);
                    showCoordinates(lat, lon);
                    addPositionMark(0, lat, lon);
                }
            }

            property int isFavoriteMark: 0
            property QtObject mark: QtObject {
                property bool selected: false   // is the selected location
                property double lat: 0.0        // latitude
                property double lon: 0.0        // longitude
                property string label: ""       // label
                property string type: ""        // type
            }

            LocationInfoModel{
                id: locationInfoModel
                onReadyChange: {
                    if (ready && rowCount() > 0) {
                        var str = "";
                        var mi = index(0, 0)
                        str = data(mi, LocationInfoModel.LabelRole);
                        if (str === "")
                            str = data(mi, LocationInfoModel.AddressRole);
                        if (str === "")
                            str = data(mi, LocationInfoModel.PoiRole);
                        if (str !== "")
                            preview.mark.label = str;
                        preview.mark.type = data(mi, LocationInfoModel.TypeRole);
                    }
                }
            }

            MapIcon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: units.gu(1)
                source: "qrc:/images/close.svg"
                color: "black"
                backgroundColor: "white"
                borderPadding: units.gu(1.5)
                opacity: 0.7
                height: units.gu(6)
                onClicked: {
                    selectedPOI = null; // deactivate the preview
                }
            }
            MapIcon {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: units.gu(1)
                source: favoritesPage.state === "default" ? "qrc:/images/trip/navigator.svg"
                                                      : "qrc:/images/trip/pin.svg"
                color: "black"
                backgroundColor: "white"
                borderPadding: units.gu(1.0)
                opacity: 0.7
                label.text: favoritesPage.state === "default" ? qsTr("Go") : qsTr("Accept")
                label.font.pointSize: units.fs("medium")
                label.color: "black"
                height: units.gu(6)
                onClicked: {
                    if (favoritesPage.state === "default") {
                        mapPage.navigateTo(preview.mark.lat, preview.mark.lon, preview.mark.label);
                    } else {
                        selectPOI({ "lat": preview.mark.lat, "lon": preview.mark.lon, "label": preview.mark.label, "type": preview.mark.type });
                    }
                    stackView.pop();
                }
            }
        }

        onStatusChanged: {
            if (active && status === Loader.Ready) {
                console.log("Activate map preview");
                favoritesPage.selectedPOIChanged.connect(showSelectedLocation);
                showSelectedLocation();
            } else if (!active) {
                console.log("Deactivate map preview");
                favoritesPage.selectedPOIChanged.disconnect(showSelectedLocation);
            }
        }

        function showSelectedLocation() {
            console.log("Show selected location on map preview");
            item.map.showCoordinatesInstantly(selectedPOI.lat, selectedPOI.lon);
            item.map.addPositionMark(0, selectedPOI.lat, selectedPOI.lon);
            item.map.removeAllOverlayObjects();
            // setup mark
            item.mark.selected = true;
            item.mark.lat = selectedPOI.lat;
            item.mark.lon = selectedPOI.lon;
            item.mark.type = selectedPOI.type;
            if (selectedPOI.label !== "")
                item.mark.label = selectedPOI.label;
            else
                item.mark.label = Converter.readableCoordinatesGeocaching(selectedPOI.lat, selectedPOI.lon);
            //console.log("Selected location: \"" + item.mark.label + "\", " + item.mark.type);
        }

        Behavior on height {
            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad;
                onStopped: {
                    console.log("Animate is stopped");
                    favoritesView.positionViewAtIndex(favoritesView.currentIndex, ListView.Contain);
                }
            }
        }
    }

    DialogBase {
        id: dialogEdit
        title: qsTr("Rename")

        property var model: null

        signal editRequested(var model)
        onAccepted: {
            model.label = inputLabel.text;
            editRequested(model);
        }

        footer: Row {
            leftPadding: units.gu(1)
            rightPadding: units.gu(1)
            bottomPadding: units.gu(1)
            spacing: units.gu(1)
            layoutDirection: Qt.RightToLeft

            Button {
                flat: true
                text: qsTr("Ok")
                onClicked: {
                    dialogEdit.accept();
                }
            }
        }

        TextField {
            id: inputLabel
            font.pointSize: units.fs("medium")
            placeholderText: qsTr("Enter the label")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly
            EnterKey.type: Qt.EnterKeyDone
        }

        onOpened: {
            inputLabel.text = model.label;
        }
    }
}