package routes

Section :: struct {
	title: string,
	path:  cstring,
}

// Sections are stored in group order so an index into SECTIONS is also
// an index into the gallery's parallel views array. GROUPS below slices
// into this flat list by (start, count) ranges rather than carrying
// nested slices — simpler layout, no pointer soup.
SECTIONS :: [?]Section {
	// Widgets
	{"Buttons", "/buttons"},
	{"Inputs", "/inputs"},
	{"Text areas", "/textareas"},
	{"Dropdowns", "/dropdowns"},
	{"Checkboxes", "/checkboxes"},
	{"Toggles", "/toggles"},
	{"Sliders", "/sliders"},
	{"Progress", "/progress"},
	{"Tooltips", "/tooltips"},
	{"Modals", "/modals"},
	{"Radios", "/radios"},
	{"Segmented", "/segmented"},
	{"Tabs", "/tabs"},
	{"Badges", "/badges"},
	{"Avatars", "/avatars"},
	// System
	{"Typography", "/typography"},
	{"Composition", "/composition"},
	{"Setup", "/setup"},
}

Section_Group :: struct {
	title: string,
	start: int, // first index in SECTIONS belonging to this group
	count: int, // number of sections in the group
}

GROUPS :: [?]Section_Group {
	{"WIDGETS", 0, 15},
	{"SYSTEM", 15, 3},
}

index :: proc(path: string) -> (int, bool) {
	for section, i in SECTIONS {
		if path == string(section.path) {return i, true}
	}
	return 0, false
}
