import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Controls 1.5
import QtQuick.Layouts 1.3
import com.kajeka 1.0

import ".."
import "TransformConfig.js" as TransformConfig
import "../../../../shared/ui/qml/Constants.js" as Constants
import "../../../../shared/ui/qml/Utils.js" as Utils

import "../Controls"

Window
{
    id: root

    title: qsTr("Add Transform")
    modality: Qt.ApplicationModal
    flags: Qt.Window|Qt.Dialog
    width: 900
    height: 350
    minimumWidth: 900
    minimumHeight: 350

    property var document
    property string transformExpression
    property var defaultVisualisations

    property var _transform: undefined
    property int _numParameters: _transform !== undefined ? _transform.parameterNames.length : 0
    property int _numAttributeParameters: _transform !== undefined ? _transform.attributeParameterNames.length : 0
    property int _numDeclaredAttributes: _transform !== undefined ? Object.keys(_transform.declaredAttributes).length : 0

    Preferences
    {
        section: "misc"
        property alias transformSortOrder: transformsList.ascendingSortOrder
        property alias transformSortBy: transformsList.sortRoleName
        property alias transformAttributeSortOrder: lhsAttributeList.ascendingSortOrder
        property alias transformAttributeSortBy: lhsAttributeList.sortRoleName
    }

    ColumnLayout
    {
        id: layout

        anchors.fill: parent
        anchors.margins: Constants.margin

        RowLayout
        {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TreeBox
            {
                id: transformsList
                Layout.preferredWidth: 192
                Layout.fillHeight: true

                showSections: sortRoleName !== "display"
                sortRoleName: "type"

                onSelectedValueChanged:
                {
                    if(selectedValue !== undefined)
                    {
                        parametersRepeater.model = [];
                        parameters._values = {};

                        attributeParametersRepeater.model = [];
                        attributeParameters._attributeNames = {};

                        visualisationsRepeater.model = [];
                        visualisations._visualisations = {};

                        root._transform = document.transform(selectedValue);
                        lhsAttributeList.model = document.availableAttributes(root._transform.elementType);
                        valueRadioButton.checked = true;
                        rhsAttributeList.model = undefined;

                        if(_transform.parameterNames !== undefined)
                            parametersRepeater.model = _transform.parameterNames;

                        if(_transform.attributeParameterNames !== undefined)
                            attributeParametersRepeater.model = _transform.attributeParameterNames;

                        if(_transform.declaredAttributes !== undefined)
                            visualisationsRepeater.model = Object.keys(_transform.declaredAttributes);
                    }

                    description.update();
                    updateTransformExpression();
                }

                onDoubleClicked:
                {
                    if(document.graphTransformIsValid(transformExpression))
                        root.accept();
                }

                TransformListSortMenu { transformsList: transformsList }
            }

            Label
            {
                visible: !scrollView.visible
                Layout.fillWidth: visible
                Layout.fillHeight: visible

                horizontalAlignment: Qt.AlignCenter
                verticalAlignment: Qt.AlignVCenter
                font.pixelSize: 16
                font.italic: true

                text: _transform !== undefined && _numParameters === 0 && _numAttributeParameters === 0 ?
                          qsTr("No Parameters Required") : qsTr("Select A Transform")
            }

            ScrollView
            {
                id: scrollView

                frameVisible: (parameters.enabled || attributeParameters.enabled ||
                               visualisations.enabled) && scrollView.__verticalScrollBar.visible

                visible: parameters.enabled || attributeParameters.enabled || visualisations.enabled ||
                         condition.enabled

                Layout.fillWidth: visible
                Layout.fillHeight: visible

                horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
                verticalScrollBarPolicy: Qt.ScrollBarAsNeeded

                RowLayout
                {
                    width: scrollView.viewport.width

                    ColumnLayout
                    {
                        Layout.fillWidth: true
                        Layout.margins: scrollView.frameVisible ? Constants.margin : 0
                        spacing: 20

                        RowLayout
                        {
                            id: condition
                            enabled: _transform !== undefined && _transform.requiresCondition
                            visible: enabled

                            Layout.fillWidth: visible
                            Layout.minimumHeight:
                            {
                                var conditionHeight = scrollView.viewport.height;

                                if(parameters.enabled || visualisations.enabled)
                                    conditionHeight *= 0.5;

                                return Math.max(conditionHeight, 128);
                            }

                            Label
                            {
                                Layout.topMargin: Constants.margin
                                Layout.alignment: Qt.AlignTop
                                text: qsTr("where")
                            }

                            TreeBox
                            {
                                id: lhsAttributeList
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                showSections: sortRoleName !== "display"
                                sortRoleName: "userDefined"

                                onSelectedValueChanged:
                                {
                                    if(selectedValue !== undefined)
                                    {
                                        opList.updateModel(document.attribute(selectedValue).ops);

                                        var parameterData = document.findTransformParameter(transformsList.selectedValue,
                                                                                            lhsAttributeList.selectedValue);
                                        rhs.configure(parameterData);
                                    }
                                    else
                                    {
                                        opList.updateModel();
                                        valueParameter.reset();
                                    }

                                    description.update();
                                    updateTransformExpression();
                                }

                                AttributeListSortMenu { attributeList: lhsAttributeList }
                            }

                            ListBox
                            {
                                id: opList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 150

                                onSelectedValueChanged: { updateTransformExpression(); }

                                Component { id: modelComponent; ListModel {} }

                                function updateModel(ops)
                                {
                                    if(ops === undefined)
                                    {
                                        opList.model = undefined;
                                        return;
                                    }

                                    var newModel = modelComponent.createObject();

                                    for(var i = 0; i < ops.length; i++)
                                    {
                                        var item =
                                        {
                                            display: TransformConfig.sanitiseOp(ops[i]),
                                            value: ops[i],
                                            unary: document.opIsUnary(ops[i])
                                        };

                                        newModel.append(item);
                                    }

                                    opList.model = newModel;
                                }
                            }

                            GridLayout
                            {
                                id: rhs

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                enabled: opList.selectedValue !== undefined &&
                                         !opList.selectedValue.unary

                                columns: 2
                                ExclusiveGroup { id: rhsGroup }

                                RadioButton
                                {
                                    id: valueRadioButton
                                    Layout.alignment: Qt.AlignTop

                                    checked: true
                                    exclusiveGroup: rhsGroup
                                }

                                TransformParameter
                                {
                                    id: valueParameter
                                    Layout.fillWidth: true

                                    enabled: valueRadioButton.checked
                                    updateValueImmediately: true
                                    direction: Qt.Vertical
                                    fillWidth: true
                                    onValueChanged: { updateTransformExpression(); }
                                }

                                RadioButton
                                {
                                    id: attributeRadioButton
                                    Layout.alignment: Qt.AlignTop

                                    exclusiveGroup: rhsGroup
                                }

                                TreeBox
                                {
                                    id: rhsAttributeList
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    showSections: lhsAttributeList.showSections
                                    sortRoleName: lhsAttributeList.sortRoleName

                                    enabled: attributeRadioButton.checked
                                    onSelectedValueChanged: { updateTransformExpression(); }

                                    AttributeListSortMenu { attributeList: rhsAttributeList }
                                }

                                function configure(parameterData)
                                {
                                    valueParameter.configure(parameterData);

                                    if(parameterData.valueType !== undefined)
                                    {
                                        rhsAttributeList.model = document.availableAttributes(
                                                    root._transform.elementType, parameterData.valueType);
                                    }
                                    else
                                        rhsAttributeList.model = undefined;
                                }

                                function value()
                                {
                                    if(valueRadioButton.checked)
                                        return valueParameter.value;
                                    else if(attributeRadioButton.checked)
                                        return "$\"" + rhsAttributeList.selectedValue + "\"";

                                    return "";
                                }
                            }
                        }

                        ColumnLayout
                        {
                            id: attributeParameters
                            enabled: _transform !== undefined && _numAttributeParameters > 0
                            visible: enabled

                            Layout.fillWidth: visible
                            spacing: 20

                            property var _attributeNames

                            Repeater
                            {
                                id: attributeParametersRepeater

                                delegate: Component
                                {
                                    RowLayout
                                    {
                                        property var parameterData: _transform.attributeParameters[modelData]

                                        ColumnLayout
                                        {
                                            id: attributeParameterRowLayout
                                            Layout.fillWidth: true

                                            Label
                                            {
                                                Layout.alignment: Qt.AlignTop
                                                font.italic: true
                                                font.bold: true
                                                text: modelData
                                            }

                                            Text
                                            {
                                                Layout.fillWidth: true
                                                text: parameterData.description
                                                textFormat: Text.StyledText
                                                wrapMode: Text.Wrap
                                                elide: Text.ElideRight
                                                onLinkActivated: Qt.openUrlExternally(link);
                                            }

                                            Item { Layout.fillHeight: true }
                                        }

                                        TreeBox
                                        {
                                            id: attributeParameterAttributeList
                                            Layout.fillHeight: true
                                            Layout.alignment: Qt.AlignTop
                                            Layout.preferredHeight: 110
                                            Layout.preferredWidth: 250

                                            showSections: sortRoleName !== "display"
                                            sortRoleName: "userDefined"

                                            onSelectedValueChanged:
                                            {
                                                if(selectedValue !== undefined)
                                                    attributeParameters._attributeNames[modelData] = selectedValue;

                                                updateTransformExpression();
                                            }

                                            AttributeListSortMenu { attributeList: attributeParameterAttributeList }
                                        }

                                        Component.onCompleted:
                                        {
                                            attributeParameterAttributeList.model =
                                                document.availableAttributes(parameterData.elementType, parameterData.valueType);
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout
                        {
                            id: parameters
                            enabled: _transform !== undefined && _numParameters > 0
                            visible: enabled

                            Layout.fillWidth: visible
                            spacing: 20

                            property var _values

                            Repeater
                            {
                                id: parametersRepeater

                                delegate: Component
                                {
                                    RowLayout
                                    {
                                        property var parameterData: _transform.parameters[modelData]

                                        ColumnLayout
                                        {
                                            Layout.fillWidth: true

                                            Label
                                            {
                                                Layout.alignment: Qt.AlignTop
                                                font.italic: true
                                                font.bold: true
                                                text: modelData
                                            }

                                            Text
                                            {
                                                Layout.fillWidth: true
                                                text: parameterData.description
                                                textFormat: Text.StyledText
                                                wrapMode: Text.Wrap
                                                elide: Text.ElideRight
                                                onLinkActivated: Qt.openUrlExternally(link);
                                            }

                                            Item { Layout.fillHeight: true }
                                        }

                                        Item
                                        {
                                            id: controlPlaceholder
                                            Layout.fillHeight: true

                                            implicitWidth: childrenRect.width
                                            implicitHeight: childrenRect.height
                                        }

                                        Component.onCompleted:
                                        {
                                            var transformParameter = TransformConfig.createTransformParameter(document,
                                                controlPlaceholder, parameterData, updateTransformExpression);
                                            transformParameter.direction = Qt.Vertical;
                                            parameters._values[modelData] = transformParameter;
                                        }
                                    }
                                }
                            }

                            function updateValues()
                            {
                                for(var parameterName in _values)
                                    _values[parameterName].updateValue();
                            }

                            function valueOf(parameterName)
                            {
                                if(_values === undefined)
                                    return "\"\"";

                                var transformParameter = _values[parameterName];

                                if(transformParameter === undefined)
                                    return "\"\"";

                                return transformParameter.value;
                            }
                        }

                        ColumnLayout
                        {
                            id: visualisations
                            enabled: _transform !== undefined && _numDeclaredAttributes > 0
                            visible: enabled

                            Layout.fillWidth: visible
                            spacing: 20

                            property var _visualisations

                            Label
                            {
                                Layout.alignment: Qt.AlignTop
                                font.italic: true
                                font.bold: true
                                text: qsTr("Visualisations")
                            }

                            Repeater
                            {
                                id: visualisationsRepeater

                                delegate: Component
                                {
                                    ColumnLayout
                                    {
                                        property var declaredAttribute: _transform !== undefined ?
                                                                            _transform.declaredAttributes[modelData] : undefined

                                        RowLayout
                                        {
                                            Layout.fillWidth: true

                                            Label
                                            {
                                                text: modelData
                                            }

                                            ComboBox
                                            {
                                                id: visualisationsComboBox
                                                editable: false
                                                onCurrentIndexChanged:
                                                {
                                                    var value = currentText;
                                                    if(value === "None")
                                                        value = "";

                                                    visualisations._visualisations[modelData] = value;
                                                }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }

                                        Component.onCompleted:
                                        {
                                            var visualisationChannelNames = document.availableVisualisationChannelNames(declaredAttribute.valueType);
                                            visualisationsComboBox.model = ["None"].concat(visualisationChannelNames);
                                            visualisationsComboBox.currentIndex = visualisationsComboBox.model.indexOf(declaredAttribute.defaultVisualisation);
                                            visualisations._visualisations[modelData] = declaredAttribute.defaultVisualisation;
                                        }
                                    }
                                }
                            }

                            function selectedVisualisation(attributeName)
                            {
                                if(_visualisations === undefined)
                                    return "";

                                var visualisationChannelName = _visualisations[attributeName];

                                if(visualisationChannelName === undefined)
                                    return "";

                                return visualisationChannelName;
                            }
                        }
                    }
                }
            }
        }

        RowLayout
        {
            Layout.fillHeight: true
            Layout.preferredHeight: 64

            Text
            {
                id: description
                Layout.fillWidth: true

                textFormat: Text.StyledText
                wrapMode: Text.WordWrap

                onLinkActivated: Qt.openUrlExternally(link);

                function update()
                {
                    text = "";

                    if(_transform !== undefined)
                    {
                        text += _transform.description;

                        if(lhsAttributeList.selectedValue !== undefined)
                        {
                            var parameterData = document.findTransformParameter(transformsList.selectedValue,
                                                                                lhsAttributeList.selectedValue);

                            if(parameterData.description !== undefined)
                                text += "<br><br>" + parameterData.description;
                        }
                    }
                }
            }

            Button
            {
                Layout.alignment: Qt.AlignBottom
                text: qsTr("OK")
                enabled: { return document.graphTransformIsValid(transformExpression); }
                onClicked: { root.accept(); }
            }

            Button
            {
                Layout.alignment: Qt.AlignBottom
                text: qsTr("Cancel")
                onClicked: { root.reject(); }
            }
        }

        Keys.onPressed:
        {
            event.accepted = true;
            switch(event.key)
            {
            case Qt.Key_Escape:
            case Qt.Key_Back:
                reject();
                break;

            case Qt.Key_Enter:
            case Qt.Key_Return:
                accept();
                break;

            default:
                event.accepted = false;
            }
        }
    }

    function accept()
    {
        accepted();
        root.close();
    }

    function reject()
    {
        rejected();
        root.close();
    }

    signal accepted()
    signal rejected()

    function updateTransformExpression()
    {
        parameters.updateValues();

        var expression = "";

        if(transformsList.selectedValue !== undefined)
        {
            expression += "\"" + transformsList.selectedValue + "\"";

            if(_numAttributeParameters > 0)
            {
                expression += " using";

                for(var attributeName in attributeParameters._attributeNames)
                    expression += " $\"" + attributeParameters._attributeNames[attributeName] + "\"";
            }

            if(_numParameters > 0)
            {
                expression += " with";

                for(var index in _transform.parameterNames)
                {
                    var parameterName = _transform.parameterNames[index];
                    expression += " \"" + parameterName + "\" = " + parameters.valueOf(parameterName);
                }
            }

            if(lhsAttributeList.selectedValue !== undefined)
            {
                expression += " where $\"" + lhsAttributeList.selectedValue + "\"";

                if(opList.selectedValue !== undefined)
                {
                    expression += " " + opList.selectedValue.value;
                    var rhsValue = rhs.value();

                    if(!opList.selectedValue.unary && rhsValue.length > 0)
                        expression += " " + rhsValue;
                }
            }
        }

        transformExpression = expression;
    }

    function updateDefaultVisualisations()
    {
        defaultVisualisations = [];

        Object.keys(_transform.declaredAttributes).forEach(function(attributeName)
        {
            var channelName = visualisations.selectedVisualisation(attributeName);

            if(channelName.length > 0)
            {
                var expression = "\"" + attributeName + "\" \"" + channelName + "\"";

                var valueType = _transform.declaredAttributes[attributeName].valueType;
                var parameters = document.visualisationDefaultParameters(valueType,
                                                                         channelName);

                if(Object.keys(parameters).length !== 0)
                    expression += " with ";

                for(var key in parameters)
                    expression += " " + key + " = " + parameters[key];

                defaultVisualisations.push(expression);
            }
        });
    }

    onAccepted:
    {
        updateTransformExpression();
        updateDefaultVisualisations();

        document.update([transformExpression], defaultVisualisations);
    }

    onVisibleChanged:
    {
        transformExpression.text = "";
        defaultVisualisations = [];
        transformsList.model = document.availableTransforms();

        parametersRepeater.model = undefined;
        parameters._values = {};

        attributeParametersRepeater.model = undefined;
        attributeParameters._attributeNames = {};

        lhsAttributeList.model = rhsAttributeList.model = undefined;
        opList.model = undefined;

        _transform = undefined;
    }
}
