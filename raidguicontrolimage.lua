function RaidGUIControlImage:on_mouse_pressed(button)
	if self._on_mouse_pressed_callback then
		self._on_mouse_pressed_callback(button)

		return true
	end

	return false
end