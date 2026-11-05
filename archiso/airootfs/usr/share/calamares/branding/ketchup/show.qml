import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation
    function nextSlide() { presentation.goToNextSlide(); }
    Timer { id: advance; interval: 6000; running: presentation.activatedInCalamares; repeat: true; onTriggered: nextSlide() }

    function slide(title, body) { }

    Slide {
        Rectangle { anchors.fill: parent; color: "#14090a" }
        Image { id: logo; source: "logo.png"; width: parent.width * 0.5; fillMode: Image.PreserveAspectFit; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.12 }
        Text { anchors.top: logo.bottom; anchors.topMargin: 30; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * 0.8
               horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: "#f3e6dc"; font.pixelSize: 22
               text: "Welcome to Ketchup.\nFast, slim and smooth: the linux-zen kernel, tuned for your desktop." }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#14090a" }
        Text { anchors.centerIn: parent; width: parent.width * 0.8; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
               color: "#f3e6dc"; font.pixelSize: 22
               text: "Built-in Distrobox and Podman\nrun any other distro's apps in a container, with no dual boot." }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#14090a" }
        Text { anchors.centerIn: parent; width: parent.width * 0.8; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
               color: "#f3e6dc"; font.pixelSize: 22
               text: "You choose where apps live.\nRun ketchup-apps-location to put Flatpak apps and containers on any drive." }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#14090a" }
        Text { anchors.centerIn: parent; width: parent.width * 0.8; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
               color: "#f3e6dc"; font.pixelSize: 22
               text: "Make it yours.\nRun ketchup-logo any time to swap in your own logo." }
    }

    function onActivate() { }
    function onLeave() { }
}
