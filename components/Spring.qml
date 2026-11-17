import QtQuick
import "../theme"

// The island's spring for things that travel: `Behavior on x { Spring {} }`. `s` picks the spring
// (Theme.springMove by default, Theme.springSoft for a calmer one). Follows the animation settings
// (Theme.spring): slower / faster with the animation speed; with reduced animation it jumps there
// (spring 0 + no velocity limit).
SpringAnimation {
    property var s: Theme.springMove
    spring: Theme.spring(s).spring
    damping: Theme.spring(s).damping
    velocity: Theme.reduceMotion ? 1e9 : 0
    epsilon: 0.25
}
