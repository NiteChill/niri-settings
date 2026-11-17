pragma Singleton
import QtQuick
import Quickshell

// A small KDL reader / writer, enough for niri's config.
// A node: { name, args: [values], props: { key: value }, children: [nodes] or null }.
// Values: strings, numbers, true / false / null (KDL 1 and 2 spellings). Comments (//, /* */ nested,
// /- slashdash) are dropped when reading; the app only writes its own file, so nothing is lost.
Singleton {
    id: kdl

    function parse(text) {
        const s = text || "";
        let i = 0;
        const n = s.length;
        const err = msg => {
            throw new Error("KDL: " + msg + " at line " + (s.slice(0, i).split("\n").length));
        };
        function skipBlock() {
            let depth = 0;
            do {
                if (s.startsWith("/*", i)) {
                    depth++;
                    i += 2;
                } else if (s.startsWith("*/", i)) {
                    depth--;
                    i += 2;
                } else if (i >= n) {
                    err("unclosed comment");
                } else {
                    i++;
                }
            } while (depth > 0);
        }
        // spaces, comments, escaped newlines; newlines too when `lines`
        function ws(lines) {
            for (;;) {
                const c = s[i];
                if (c === " " || c === "\t" || c === "\r" || c === "﻿")
                    i++;
                else if (c === "\\") {
                    i++;
                    while (s[i] === " " || s[i] === "\t")
                        i++;
                    if (s.startsWith("//", i))
                        while (i < n && s[i] !== "\n")
                            i++;
                    if (s[i] === "\r")
                        i++;
                    if (s[i] === "\n")
                        i++;
                } else if (lines && c === "\n")
                    i++;
                else if (s.startsWith("//", i))
                    while (i < n && s[i] !== "\n")
                        i++;
                else if (s.startsWith("/*", i))
                    skipBlock();
                else
                    return;
            }
        }
        const identEnd = /[\s\\\/(){}<>;\[\]=,"]/;
        function ident() {
            const st = i;
            while (i < n && !identEnd.test(s[i]))
                i++;
            if (i === st)
                err("expected a name");
            return s.slice(st, i);
        }
        function str() {
            // raw: r"..." r#"..."# (KDL 1) or #"..."# (KDL 2)
            if (s[i] === "r" || s[i] === "#") {
                if (s[i] === "r")
                    i++;
                let hashes = 0;
                while (s[i] === "#") {
                    hashes++;
                    i++;
                }
                if (s[i] !== "\"")
                    err("bad raw string");
                i++;
                const end = "\"" + "#".repeat(hashes);
                const e = s.indexOf(end, i);
                if (e < 0)
                    err("unclosed string");
                const v = s.slice(i, e);
                i = e + end.length;
                return v;
            }
            i++;
            let v = "";
            while (i < n && s[i] !== "\"") {
                if (s[i] === "\\") {
                    i++;
                    const c = s[i++];
                    if (c === "n") v += "\n";
                    else if (c === "t") v += "\t";
                    else if (c === "r") v += "\r";
                    else if (c === "u") {
                        const e = s.indexOf("}", i);
                        v += String.fromCodePoint(parseInt(s.slice(i + 1, e), 16));
                        i = e + 1;
                    } else v += c;
                } else {
                    v += s[i++];
                }
            }
            if (s[i] !== "\"")
                err("unclosed string");
            i++;
            return v;
        }
        function value() {
            const c = s[i];
            if (c === "\"" || (c === "r" && (s[i + 1] === "\"" || s[i + 1] === "#")) || (c === "#" && (s[i + 1] === "\"" || s[i + 1] === "#")))
                return str();
            const word = ident();
            if (word === "true" || word === "#true") return true;
            if (word === "false" || word === "#false") return false;
            if (word === "null" || word === "#null") return null;
            const clean = word.replace(/_/g, "");
            if (/^[+-]?0x[0-9a-f]+$/i.test(clean)) return parseInt(clean, 16);
            if (/^[+-]?0o[0-7]+$/i.test(clean)) return parseInt(clean.replace(/0o/i, ""), 8);
            if (/^[+-]?0b[01]+$/i.test(clean)) return parseInt(clean.replace(/0b/i, ""), 2);
            if (/^[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?$/i.test(clean)) return Number(clean);
            return word; // a bare identifier as a value (KDL 2)
        }
        function nodes(top) {
            const out = [];
            for (;;) {
                ws(true);
                while (s[i] === ";") {
                    i++;
                    ws(true);
                }
                if (i >= n) {
                    if (!top) err("missing }");
                    return out;
                }
                if (s[i] === "}") {
                    if (top) err("unexpected }");
                    i++;
                    return out;
                }
                let skip = false;
                if (s.startsWith("/-", i)) {
                    skip = true;
                    i += 2;
                    ws(true);
                }
                const node = one();
                if (!skip)
                    out.push(node);
            }
        }
        function one() {
            if (s[i] === "(") { // type annotation: ignored
                i = s.indexOf(")", i) + 1;
            }
            const name = s[i] === "\"" || s[i] === "r" && s[i + 1] === "\"" ? str() : ident();
            const node = { "name": name, "args": [], "props": {}, "children": null };
            for (;;) {
                ws(false);
                const c = s[i];
                if (i >= n || c === "\n" || c === ";" || c === "}") {
                    if (c === ";") i++;
                    return node;
                }
                let skip = false;
                if (s.startsWith("/-", i)) {
                    skip = true;
                    i += 2;
                    ws(false);
                }
                if (s[i] === "{") {
                    i++;
                    const kids = nodes(false);
                    if (!skip)
                        node.children = kids;
                    continue;
                }
                if (s[i] === "(")
                    i = s.indexOf(")", i) + 1;
                // a property is name=value; anything else is an argument
                const start = i;
                let key = null;
                if (s[i] !== "\"" ) {
                    const m = /^[^\s\\\/(){}<>;\[\]=,"]+=/.exec(s.slice(i, i + 200));
                    if (m) {
                        key = m[0].slice(0, -1);
                        i += m[0].length;
                    }
                } else {
                    const save = i;
                    const k = str();
                    if (s[i] === "=") {
                        key = k;
                        i++;
                    } else {
                        i = save;
                    }
                }
                const v = value();
                if (skip)
                    continue;
                if (key !== null)
                    node.props[key] = v;
                else
                    node.args.push(v);
            }
        }
        return nodes(true);
    }

    // niri reads a number's type from how it's written, and JS has one number type. Most of niri's
    // numbers take either form, some only a whole number (blur passes, cursor size, key repeat, output
    // position), and these only a decimal: `proportion 1` was rejected (the "Full" window width).
    // Checked against `niri validate` (26.04) for every number the app writes.
    readonly property var decimalNodes: ["proportion", "opacity"]
    function quote(v, decimal) {
        if (v === true) return "true";
        if (v === false) return "false";
        if (v === null || v === undefined) return "null";
        if (typeof v === "number") {
            const s = String(Math.round(v * 1e6) / 1e6);
            return decimal && /^-?\d+$/.test(s) ? s + ".0" : s;
        }
        return "\"" + String(v).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\"";
    }
    function nameOf(name) {
        return /^[A-Za-z_+\-][^\s\\\/(){}<>;\[\]=,"]*$/.test(name) && !/^[+-]?\d/.test(name) ? name : quote(name);
    }
    // nodes -> text, 4-space indents
    function write(list, depth) {
        const pad = "    ".repeat(depth || 0);
        let out = "";
        for (const node of list) {
            let line = pad + nameOf(node.name);
            const decimal = decimalNodes.indexOf(node.name) >= 0;
            for (const a of node.args)
                line += " " + quote(a, decimal);
            for (const k in node.props)
                line += " " + nameOf(k) + "=" + quote(node.props[k]);
            if (node.children !== null && node.children !== undefined) {
                if (node.children.length === 0) {
                    line += " {}";
                } else {
                    line += " {\n" + write(node.children, (depth || 0) + 1) + pad + "}";
                }
            }
            out += line + "\n";
        }
        return out;
    }
    function node(name, args, props, children) {
        return { "name": name, "args": args || [], "props": props || {}, "children": children === undefined ? null : children };
    }
    function clone(v) {
        return JSON.parse(JSON.stringify(v));
    }
}
