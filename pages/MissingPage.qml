import QtQuick
import "../theme"
import "../services"
import "../components"

// A page that can't work on this computer because something it needs isn't installed (App's `needs`,
// Deps): just the banner offering it. Once it's installed, App loads the real page in its place.
Column {
    id: missing
    spacing: Theme.spacing * 8

    // the page shown (App's entry: id, label, needs), set by App's Loader
    property var page: null

    Missing {
        width: parent.width
        needs: missing.page ? missing.page.needs || [] : []
        what: missing.page ? missing.page.label : ""
    }
}
