import QtQuick 2.15

Rectangle {
    id: root
    color: "#070708"
    width: 1920
    height: 1080

    // Gekozen gebruiker (laatste login, anders de eerste in de lijst)
    function pickUser() {
        if (userModel.lastUser && userModel.lastUser.length > 0)
            return userModel.lastUser;
        if (userModel.count > 0)
            return userModel.data(userModel.index(0, 0), Qt.UserRole + 1) || "";
        return "";
    }
    property string userName: pickUser()

    Image {
        anchors.fill: parent
        source: "assets/bg.png"
        fillMode: Image.PreserveAspectCrop
    }

    // ---- Klok ----
    Column {
        anchors.top: parent.top
        anchors.topMargin: 54
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#f4f4f6"; font.pixelSize: 44; font.weight: Font.Light
            text: Qt.formatTime(new Date(), "HH:mm")
        }
        Text {
            id: dateT
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#8a8a95"; font.pixelSize: 15
            text: Qt.formatDate(new Date(), "dddd d MMMM")
        }
    }
    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: {
            clock.text = Qt.formatTime(new Date(), "HH:mm");
            dateT.text = Qt.formatDate(new Date(), "dddd d MMMM");
        }
    }

    // ---- Animatie-stage ----
    Item {
        id: stage
        width: 440; height: 440
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -46

        Image { anchors.fill: parent; source: "assets/track.png"; smooth: true }

        Image {
            anchors.fill: parent; source: "assets/circletext.png"; smooth: true
            RotationAnimator on rotation {
                from: 360; to: 0; duration: 46000; loops: Animation.Infinite
            }
        }
        Image {
            anchors.fill: parent; source: "assets/spinner.png"; smooth: true
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 9000; loops: Animation.Infinite
            }
        }
        Image {
            id: bear
            source: "assets/bear.png"
            anchors.centerIn: parent
            width: parent.width * 0.46
            height: width * (sourceSize.height / sourceSize.width)
            smooth: true
            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.04; duration: 3000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.04; to: 1.0; duration: 3000; easing.type: Easing.InOutSine }
            }
        }
    }

    // ---- Merk ----
    Column {
        id: brand
        anchors.top: stage.bottom; anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#f4f4f6"; font.pixelSize: 30; font.weight: Font.DemiBold
            font.letterSpacing: 4; text: "BearlyOS"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#8a8a95"; font.pixelSize: 12; font.letterSpacing: 3; text: "BEARLY · IT"
        }
    }

    // ---- Login ----
    Column {
        anchors.top: brand.bottom; anchors.topMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#8a8a95"; font.pixelSize: 14
            text: root.userName.length > 0 ? root.userName : "gebruiker"
        }

        Rectangle {
            id: field
            width: 290; height: 46; radius: 23
            color: "#14ffffff"; border.color: "#24ffffff"; border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            TextInput {
                id: pw
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.right: goBtn.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                color: "#f4f4f6"; font.pixelSize: 15
                clip: true; focus: true; selectByMouse: true
                onAccepted: root.doLogin()
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "Wachtwoord"; color: "#8a8a95"; font.pixelSize: 15
                visible: pw.text.length === 0 && !pw.activeFocus
            }
            Rectangle {
                id: goBtn
                width: 34; height: 34; radius: 17; color: "#F4A63B"
                anchors.right: parent.right; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "→"; color: "#161009"; font.pixelSize: 17; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: root.doLogin() }
            }
        }

        Text {
            id: msg
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#e88a83"; font.pixelSize: 12; text: ""
        }
    }

    function doLogin() {
        msg.text = "";
        var u = root.userName.length > 0 ? root.userName : "";
        sddm.login(u, pw.text, sessionModel.lastIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            msg.text = "Verkeerd wachtwoord";
            pw.text = "";
            pw.forceActiveFocus();
        }
    }

    Component.onCompleted: pw.forceActiveFocus()
}
