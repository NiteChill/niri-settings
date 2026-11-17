import QtQuick
import "../theme"
import "../components"

// Every component in its variants and states, to review the look (a development page).
Column {
    id: page
    spacing: Theme.spacing * 6

    component Section: Card {
        width: page.width
    }
    component Line: Flow {
        width: parent.width
        spacing: Theme.spacing * 3
    }

    Section {
        title: "Button"
        description: "Primary, secondary, tertiary, outline, ghost, danger, danger soft. Sizes, icons, pending, disabled."
        Line {
            Button { text: "Primary" }
            Button { text: "Secondary"; variant: "secondary" }
            Button { text: "Tertiary"; variant: "tertiary" }
            Button { text: "Outline"; variant: "outline" }
            Button { text: "Ghost"; variant: "ghost" }
            Button { text: "Danger"; variant: "danger" }
            Button { text: "Danger soft"; variant: "danger-soft" }
        }
        Line {
            Button { text: "Small"; size: "sm" }
            Button { text: "Medium" }
            Button { text: "Large"; size: "lg" }
            Button { text: "Add device"; iconName: "add"; variant: "secondary" }
            Button { text: "Next"; endIconName: "chevron_right"; variant: "tertiary" }
            Button { iconName: "settings-fill"; variant: "tertiary" }
            Button { iconName: "close"; variant: "ghost" }
            Button { text: "Saving"; pending: true }
            Button { text: "Disabled"; enabled: false }
        }
    }

    Section {
        title: "Text field"
        description: "Label, placeholder, description, error, icon, clear, password, unit."
        Line {
            TextField { label: "Computer name"; placeholder: "my-laptop"; description: "Shown to other devices on the network." }
            TextField { label: "Email"; text: "not-an-email"; errorMessage: "Enter a valid email address." }
        }
        Line {
            SearchField { placeholder: "Search apps"; text: "fire" }
            TextField { label: "Wi-Fi password"; password: true; text: "hunter22"; iconName: "lock-fill" }
            TextField { label: "Disabled"; text: "Can't change this"; enabled: false }
        }
    }

    Section {
        title: "Number field"
        Line {
            NumberField { onValueModified: v => value = v; label: "Gaps"; value: 12; to: 64; suffix: "px" }
            NumberField { onValueModified: v => value = v; label: "Scale"; value: 1.25; from: 0.5; to: 3; step: 0.05; decimals: 2; suffix: "×" }
            NumberField { onValueModified: v => value = v; label: "Invalid"; value: 0; errorMessage: "Must be above 0" }
        }
    }

    Section {
        title: "Slider"
        Slider { width: parent.width; label: "Volume"; value: 64; to: 100; suffix: " %" }
        Slider { width: parent.width; label: "Steps"; value: 3; to: 10; stepSize: 1; showSteps: true }
        Slider {
            width: parent.width
            from: -1; to: 1; stepSize: 0.1; value: 0.3
            marks: [{ "value": -1, "label": "Slow" }, { "value": 0, "label": "Default" }, { "value": 1, "label": "Fast" }]
        }
    }

    Section {
        title: "Switch, checkbox, radio"
        Line {
            spacing: Theme.spacing * 8
            Column {
                spacing: Theme.spacing * 3
                Switch { checked: true }
                Switch { text: "Bluetooth" }
                Switch { text: "Wi-Fi"; description: "Connected to Home"; checked: true }
                Switch { text: "Disabled"; enabled: false; checked: true }
            }
            Column {
                spacing: Theme.spacing * 3
                Checkbox { text: "Show battery percentage"; checked: true }
                Checkbox { text: "Remember recent files" }
                Checkbox { text: "Some apps"; checkState: Qt.PartiallyChecked; tristate: true }
                Checkbox { text: "I accept"; invalid: true; description: "Required to continue" }
                Checkbox { text: "Disabled"; enabled: false; checked: true }
            }
            RadioGroup {
                onActivated: v => value = v
                label: "Lid close"
                value: "suspend"
                options: [
                    { "value": "suspend", "label": "Suspend" },
                    { "value": "nothing", "label": "Do nothing", "description": "Keeps running with the lid closed" },
                    { "value": "off", "label": "Turn off the screen" }
                ]
            }
        }
    }

    Section {
        title: "Select and tabs"
        Line {
            Select {
                label: "Power mode"
                onActivated: v => value = v
                value: "balanced"
                options: [
                    { "value": "saver", "label": "Power saver", "icon": "bolt-fill" },
                    { "value": "balanced", "label": "Balanced" },
                    { "value": "performance", "label": "Performance" }
                ]
            }
            Select { onActivated: v => value = v; label: "Empty"; options: [{ "value": 1, "label": "One" }, { "value": 2, "label": "Two" }] }
        }
        Line {
            Tabs {
                onActivated: v => value = v
                value: "dark"
                options: [{ "value": "light", "label": "Light", "icon": "light_mode-fill" }, { "value": "dark", "label": "Dark", "icon": "dark_mode-fill" }]
            }
            Tabs {
                onActivated: v => value = v
                value: "week"
                options: [{ "value": "day", "label": "Day" }, { "value": "week", "label": "Week" }, { "value": "month", "label": "Month" }, { "value": "year", "label": "Year" }]
            }
        }
    }

    Section {
        title: "Chip, keys, tooltip, spinner"
        Line {
            Chip { text: "Default" }
            Chip { text: "Connected"; tone: "accent"; variant: "soft" }
            Chip { text: "Charging"; tone: "success"; variant: "soft"; iconName: "bolt-fill" }
            Chip { text: "Warning"; tone: "warning"; variant: "soft" }
            Chip { text: "Failed"; tone: "danger"; variant: "soft" }
            Chip { text: "New"; tone: "accent"; variant: "primary" }
            Chip { text: "Advanced"; size: "sm" }
        }
        Line {
            Kbd { keys: ["Super", "Shift", "E"] }
            Kbd { keys: ["Alt", "Tab"] }
            Kbd { keys: ["Ctrl", "Enter"] }
            Button {
                text: "Hover me"
                variant: "outline"
                size: "sm"
                Tooltip { text: "Tooltips explain a control in a few words"; shown: parent.hovered }
            }
            Spinner {}
            Spinner { size: "sm"; color: Theme.c.accent }
        }
    }

    Section {
        title: "Cards"
        description: "Surface, secondary, tertiary."
        Row {
            spacing: Theme.spacing * 3
            Card { width: 200; variant: "secondary"; title: "Secondary"; description: "A step lighter" }
            Card { width: 200; variant: "tertiary"; title: "Tertiary"; description: "Another step" }
        }
    }

    Item { width: 1; height: Theme.spacing * 4 }
}
