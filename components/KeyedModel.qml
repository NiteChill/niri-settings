import QtQuick

// A ListModel kept in step with a plain JS array of flat objects (`values`), rows matched by `key`: rows
// are inserted, moved, removed and updated in place. A Repeater over the array itself rebuilds every row
// whenever the array is replaced: a Wi-Fi scan replaced it once per network found (30 networks = 900
// rows built, 1.7 s), and an app's volume slider was destroyed while being dragged. Delegates read the
// fields as roles: `required property var model`, then `model.name`.
ListModel {
    id: list

    property var values: []
    property string key: "id"

    onValuesChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        const vals = values || [];
        const keys = vals.map(v => v[key]);
        for (let i = count - 1; i >= 0; i--)
            if (keys.indexOf(get(i)[key]) < 0)
                remove(i);
        for (let i = 0; i < vals.length; i++) {
            let j = -1;
            for (let k = i; k < count; k++)
                if (get(k)[key] === keys[i]) {
                    j = k;
                    break;
                }
            if (j < 0) {
                insert(i, vals[i]);
                continue;
            }
            if (j !== i)
                move(j, i, 1);
            const row = get(i);
            for (const f in vals[i])
                if (row[f] !== vals[i][f])
                    setProperty(i, f, vals[i][f]);
        }
    }
}
