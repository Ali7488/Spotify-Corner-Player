.pragma library

// Preset IDs deliberately match the Windows WPF release.
// Settings are persisted by KDE KConfig, never by a shell command.
var themes = {
    Burgundy: {
        name: "Burgundy Rose",
        background: "#1B0C15", surface: "#341323", button: "#392031",
        hover: "#643049", pressed: "#8D294B", border: "#874461",
        text: "#FFF3F6", muted: "#DFB1C1", primary: "#800020",
        accent: "#D45D87", accentHover: "#F2B4CA", onAccent: "#1B0C15",
        vinylBorder: "#B56B8A", vinylTop: "#382035",
        vinylBottom: "#0E0910", vinylGroove: "#502D42",
        vinylLabel: "#800020", vinylLabelBorder: "#CE7497", vinylCenter: "#170C15"
    },
    Forest: {
        name: "Emerald Forest + Coral",
        background: "#0B201B", surface: "#163128", button: "#203B30",
        hover: "#294A3B", pressed: "#335647", border: "#4A816F",
        text: "#F4FEFB", muted: "#B5DBCE", primary: "#146B50",
        accent: "#FA9888", accentHover: "#FFC0B0", onAccent: "#0B201B",
        vinylBorder: "#72AE9A", vinylTop: "#355F51",
        vinylBottom: "#0B1613", vinylGroove: "#3E685A",
        vinylLabel: "#146B50", vinylLabelBorder: "#FA9888", vinylCenter: "#0B201B"
    },
    Sapphire: {
        name: "Midnight Sapphire",
        background: "#0B1426", surface: "#142133", button: "#213044",
        hover: "#314763", pressed: "#2C558B", border: "#466185",
        text: "#F4F8FE", muted: "#B2C5DE", primary: "#234C8A",
        accent: "#76A2DC", accentHover: "#ACD3FF", onAccent: "#0B1426",
        vinylBorder: "#6D8BB3", vinylTop: "#31435B",
        vinylBottom: "#090C10", vinylGroove: "#2D3A4B",
        vinylLabel: "#234C8A", vinylLabelBorder: "#76A2DC", vinylCenter: "#0B1426"
    },
    Amethyst: {
        name: "Royal Amethyst + Gold",
        background: "#1A1129", surface: "#251631", button: "#352541",
        hover: "#59416B", pressed: "#65408A", border: "#694B80",
        text: "#FAF4FE", muted: "#D6BAEC", primary: "#7043AB",
        accent: "#E4BD75", accentHover: "#F2D49C", onAccent: "#1A1129",
        vinylBorder: "#AF87CE", vinylTop: "#4B3262",
        vinylBottom: "#0D0A0F", vinylGroove: "#583B6F",
        vinylLabel: "#7043AB", vinylLabelBorder: "#E4BD75", vinylCenter: "#1A1129"
    },
    Obsidian: {
        name: "Obsidian Gold + Purple",
        background: "#17191C", surface: "#2B261C", button: "#3B352A",
        hover: "#564E3E", pressed: "#726245", border: "#756A56",
        text: "#FCFAF6", muted: "#D2CBBE", primary: "#88652F",
        accent: "#B898F1", accentHover: "#D7BBFF", onAccent: "#17191C",
        vinylBorder: "#A1957F", vinylTop: "#50493C",
        vinylBottom: "#0E0D0B", vinylGroove: "#605849",
        vinylLabel: "#88652F", vinylLabelBorder: "#B898F1", vinylCenter: "#17191C"
    }
};

function get(id) {
    return themes[id] || themes.Forest;
}

function label(id) {
    return get(id).name;
}
