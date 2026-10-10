extends RefCounted

static var selected_level := 0
static var selected_boss := false

static func menu_requested() -> bool:
	return OS.get_cmdline_user_args().has("--debug-menu")


static func final_boss_requested() -> bool:
	var query := ""
	if OS.has_feature("web"):
		query = str(JavaScriptBridge.eval("window.location.search", true))
	return matches(OS.get_cmdline_user_args(), query)

static func matches(args: PackedStringArray, query: String) -> bool:
	if args.has("--debug-final-boss"):
		return true
	for entry in query.trim_prefix("?").split("&", false):
		var pair := entry.split("=", true, 1)
		if pair.size() == 2 and pair[0].uri_decode() == "debug" and pair[1].uri_decode() == "final-boss":
			return true
	return false
