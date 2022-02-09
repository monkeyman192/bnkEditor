extends TabContainer


enum TABS {AUDIO, HIRC}


func change_tab(tab: String):
	# Set the current tab.
	# TODO: Decide whether to use a string, or import the enum and use it?
	match tab:
		"audio":
			self.current_tab = TABS.AUDIO
		"hirc":
			self.current_tab = TABS.HIRC
