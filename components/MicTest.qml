import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Hear your microphone: Record (up to `maxSeconds`, or Stop), then Play it back. The level (`peak`, from
// the page's PwNodePeakMonitor) is sampled every 100 ms while recording and drawn as the recording's
// waveform, which lights up as it plays. pw-record / pw-play, to a file in the session's runtime folder
// that's deleted with this. `mode`: "" | "recording" | "ready" | "playing" (for the row's explanation).
Row {
    id: test

    property real peak: 0
    property bool available: true
    readonly property int maxSeconds: 5
    property string mode: ""
    property var wave: []          // 0-1 levels (square-rooted, like the page's dots)
    property real elapsed: 0       // seconds into the recording or the playback
    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/settings-mic-test.wav"

    function record() {
        player.running = false;
        wave = [];
        elapsed = 0;
        mode = "recording";
        recorder.running = true;
    }
    function stopRecording() {
        // SIGINT: pw-record finishes the file properly
        if (recorder.running)
            recorder.signal(2);
    }
    function play() {
        elapsed = 0;
        mode = "playing";
        player.running = true;
    }
    function stopPlaying() {
        player.running = false;
        mode = "ready";
    }
    Component.onDestruction: Quickshell.execDetached(["rm", "-f", test.file])

    Process {
        id: recorder
        command: ["pw-record", test.file]
        onExited: test.mode = test.wave.length > 2 ? "ready" : ""
    }
    Process {
        id: player
        command: ["pw-play", test.file]
        onExited: if (test.mode === "playing") test.mode = "ready"
    }
    Timer {
        interval: 100
        repeat: true
        running: test.mode === "recording" || test.mode === "playing"
        onTriggered: {
            test.elapsed += 0.1;
            if (test.mode === "recording") {
                test.wave = test.wave.concat([Math.min(1, Math.sqrt(test.peak))]);
                if (test.elapsed >= test.maxSeconds)
                    test.stopRecording();
            }
        }
    }

    spacing: Theme.spacing * 3

    Button {
        id: recordButton
        anchors.verticalCenter: parent.verticalCenter
        size: "sm"
        variant: test.mode === "recording" ? "danger" : "secondary"
        iconName: test.mode === "recording" ? "stop-fill" : "mic-fill"
        text: test.mode === "recording" ? "Stop" : test.mode === "" ? "Record" : "Record again"
        enabled: test.available
        onClicked: test.mode === "recording" ? test.stopRecording() : test.record()
    }
    Button {
        id: playButton
        visible: test.mode === "ready" || test.mode === "playing"
        anchors.verticalCenter: parent.verticalCenter
        size: "sm"
        variant: "secondary"
        iconName: test.mode === "playing" ? "stop-fill" : "play_arrow-fill"
        text: test.mode === "playing" ? "Stop" : "Play"
        onClicked: test.mode === "playing" ? test.stopPlaying() : test.play()
    }
    // the recording's waveform: one bar per 100 ms, lit up to where playback is
    Item {
        id: waveBox
        anchors.verticalCenter: parent.verticalCenter
        width: test.width - recordButton.width - (playButton.visible ? playButton.width + test.spacing : 0) - test.spacing
        height: 32
        readonly property int slots: test.maxSeconds * 10
        readonly property real barWidth: Math.max(2, (width - (slots - 1) * 2) / slots)
        Repeater {
            model: test.wave.length
            Rectangle {
                required property int index
                x: index * (waveBox.barWidth + 2)
                width: waveBox.barWidth
                height: Math.max(3, waveBox.height * test.wave[index])
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: test.mode === "recording" ? Theme.c.danger : test.mode === "playing" && index / 10 <= test.elapsed ? Theme.c.accent : Theme.alpha(Theme.c.foreground, 0.25)
            }
        }
    }
}
