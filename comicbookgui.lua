ComicBookGui = ComicBookGui or class(RaidGuiBase)
ComicBookGui.PAGE_WIDTH = 992
ComicBookGui.PAGE_HEIGHT = 768
ComicBookGui.TOTAL_PAGE_COUNT = 14
ComicBookGui.PAGING_NO_PAGE_COLOR_CIRCLE = tweak_data.gui.colors.raid_dark_grey
ComicBookGui.PAGING_NO_PAGE_COLOR_ARROW = tweak_data.gui.colors.raid_dark_grey
ComicBookGui.PAGING_NORMAL_PAGE_COLOR_CIRCLE = tweak_data.gui.colors.raid_dirty_white
ComicBookGui.PAGING_NORMAL_PAGE_COLOR_ARROW = tweak_data.gui.colors.raid_dirty_white
ComicBookGui.NORMAL_PAGE_HOVER_COLOR_CIRCLE = tweak_data.gui.colors.raid_red
ComicBookGui.NORMAL_PAGE_HOVER_COLOR_ARROW = tweak_data.gui.colors.raid_dirty_white
ComicBookGui.BULLET_PANEL_HEIGHT = 32
ComicBookGui.BULLET_WIDTH = 16
ComicBookGui.BULLET_HEIGHT = 16
ComicBookGui.BULLET_PADDING = 2
ComicBookGui.ANIMATION_DURATION = 0.25
ComicBookGui.PAGE_NAME = "ui/comic_book/raid_comic_"
ComicBookGui.MAX_ZOOM = 1.7
ComicBookGui.MIN_ZOOM = 1
ComicBookGui.MIN_MAX_ZOOM_DIFFERENCE = ComicBookGui.MAX_ZOOM - ComicBookGui.MIN_ZOOM
ComicBookGui.HIDE_UI_THRESHOLD = 1.1
ComicBookGui.SCROLL_WHEEL_STEP = 0.1
ComicBookGui.PAGE_MOVE_STEP = 1
ComicBookGui.ZOOM_DURATION = 0.5

function ComicBookGui:init(ws, fullscreen_ws, node, component_name)
	ComicBookGui.super.init(self, ws, fullscreen_ws, node, component_name)
	self._node.components.raid_menu_header:set_screen_name("menu_comic_book_screen_name")
	self:_update_page()
	self:_update_arrows()
end

function ComicBookGui:_set_initial_data()
	self._zoom = 1
	self._dragging = false
	self._current_page = 1
	self._bullets_normal = {}
	self._bullets_active = {}
end

function ComicBookGui:close()
	ComicBookGui.super.close(self)
end

-- Helper function. Returns true if current page is first
function ComicBookGui:_on_first_page()
	return self._current_page == 1
end

-- Helper function. Returns true if current page is last
function ComicBookGui:_on_last_page()
	return self._current_page == ComicBookGui.TOTAL_PAGE_COUNT
end

-- Helper function. Returns true if current page is first or last
function ComicBookGui:_on_first_or_last_page()
	return self:_on_first_page() or self:_on_last_page()
end

-- Changes the current page to the specified page,
-- and updates the UI accordingly
function ComicBookGui:_change_page(page)
	-- Don't do anything if the page is already selected or the page number is invalid
    if (self._current_page == page or page < 1 or page > ComicBookGui.TOTAL_PAGE_COUNT) then return end

	managers.menu_component:post_event("paper_shuffle_menu")

    self:_stop_animation(self._current_page, self._previous_page)
	
    self._previous_page = self._current_page
    self._current_page = page

	self._comic_book_image:set_image(ComicBookGui.PAGE_NAME .. string.format("%03d", self._current_page))
	self._zoom = 1

    self:_update_arrows()
	self:_update_page()

    self._bullet_panel:animate(callback(self, self, "_animate_bullets", {
		current_page = self._current_page,
		previous_page = self._previous_page
	}))
end

function ComicBookGui:get_zoom()
	return self._zoom
end

function ComicBookGui:set_zoom(zoom)
	if (zoom > ComicBookGui.MAX_ZOOM) then
		self._zoom = ComicBookGui.MAX_ZOOM
	elseif (zoom < ComicBookGui.MIN_ZOOM) then
		self._zoom = ComicBookGui.MIN_ZOOM
	else
		self._zoom = zoom
	end
	self:_update_page()
end

-- Handles updating the comic book page size and position, as well as the UI visibility
function ComicBookGui:_update_page()
	self:_update_comic_book_size()
	self:_check_image_position()
	self:_update_ui_visibility()
end

-- Updates the left and right arrow visibility based on the current page and zoom level
function ComicBookGui:_update_ui_visibility()
	if (self._zoom >= ComicBookGui.HIDE_UI_THRESHOLD) then
		self:hide_ui()
	else
		self:show_ui()
	end
end

-- Updates the comic book image size based on the current zoom level
function ComicBookGui:_update_comic_book_size()
    if self:_on_first_or_last_page() then
        self._comic_book_image:set_w(ComicBookGui.PAGE_WIDTH / 2 * self._zoom)
    else
        self._comic_book_image:set_w(ComicBookGui.PAGE_WIDTH * self._zoom)
    end
    self._comic_book_image:set_h(ComicBookGui.PAGE_HEIGHT * self._zoom)
    self._comic_book_image:set_center_x(self._root_panel:center_x())
end

-- Hides UI elements so they won't be visible when zooming in
function ComicBookGui:hide_ui()
	self._bullet_panel:set_visible(false)
    self._left_arrow:set_visible(false)
    self._right_arrow:set_visible(false)
end
-- Shows UI elements so they will be visible when zooming out
function ComicBookGui:show_ui()
	self._bullet_panel:set_visible(true)
    self._left_arrow:set_visible(true)
    self._right_arrow:set_visible(true)
end

-- Scroll wheel callbacks
function ComicBookGui:mouse_pressed(o, button, x, y)
    if button == Idstring("mouse wheel up") then
		self:mouse_scroll_up(o, button, x, y)
	elseif button == Idstring("mouse wheel down") then
		self:mouse_scroll_down(o, button, x, y)
    end

	return self._root_panel:mouse_pressed(o, button, x, y)
end

-- Callback for the page itself, so dragging can only be started if user clicked on the page
function ComicBookGui:_on_comic_book_clicked(button)
	if button == Idstring("0") then
		self._dragging = true
	end
end

-- Checks if the comic book page is in a valid position
-- i.e. not outside the visible area
function ComicBookGui:_check_image_position()
	-- preventing page from going too far up
	if (self._comic_book_image:top() > 0) then
		self._comic_book_image:set_top(0)
	elseif (self._comic_book_image:bottom() < self._comic_book_panel:h()) then -- preventing page from going too far down
		self._comic_book_image:set_bottom(self._comic_book_panel:h())
	end
end

-- Used for handling dragging the comic book page
function ComicBookGui:mouse_moved(o, x, y)
	if self._dragging then
		local mouse_x, mouse_y = managers.mouse_pointer:modified_mouse_pos()
		if not self._last_y then
			self._last_y = mouse_y
		end
		local delta_y = mouse_y - self._last_y
		self._last_y = mouse_y
		self._comic_book_image:set_y(self._comic_book_image:y() + delta_y)
		self:_check_image_position()
	end

	return self._root_panel:mouse_moved(o, x, y)
end

-- Used for handling dropping the comic book page after you dragged it around
function ComicBookGui:mouse_released(o, button, x, y)
	if button == Idstring("0") and self._dragging then
		self._dragging = false
		self._last_y = nil
		return true
	end

	return self._root_panel:mouse_released(o, button, x, y)
end

function ComicBookGui:_move_page_up()
	self._comic_book_image:set_y(self._comic_book_image:y() + ComicBookGui.PAGE_MOVE_STEP)
	self:_check_image_position()
end

function ComicBookGui:_move_page_down()
	self._comic_book_image:set_y(self._comic_book_image:y() - ComicBookGui.PAGE_MOVE_STEP)
	self:_check_image_position()
end

-- This function is called when the user presses the up arrow key
-- it sucks because there's a hardcoded timer between registering key presses
function ComicBookGui:move_up()
	self:_move_page_up()
	return true
end

function ComicBookGui:move_down()
	self:_move_page_down()
	return true
end

function ComicBookGui:mouse_scroll_up()
    self:set_zoom(self:get_zoom() + ComicBookGui.SCROLL_WHEEL_STEP)
end

function ComicBookGui:mouse_scroll_down()
    self:set_zoom(self:get_zoom() - ComicBookGui.SCROLL_WHEEL_STEP)
end

function ComicBookGui:_layout()
	self:_disable_dof()

	-- Left arrow initialization
	self._left_arrow = self._root_panel:panel({
		visible = true,
		y = 0,
		x = 0,
		w = tweak_data.gui.icons.players_icon_outline.texture_rect[3],
		h = tweak_data.gui.icons.players_icon_outline.texture_rect[4]
	})
	self._left_arrow_circle = self._left_arrow:image_button({
		visible = true,
		y = 0,
		x = 0,
		texture = tweak_data.gui.icons.players_icon_outline.texture,
		texture_rect = tweak_data.gui.icons.players_icon_outline.texture_rect,
		color = ComicBookGui.PAGING_NORMAL_PAGE_COLOR_CIRCLE,
		highlight_color = ComicBookGui.NORMAL_PAGE_HOVER_COLOR_CIRCLE,
		disabled_color = ComicBookGui.PAGING_NO_PAGE_COLOR_CIRCLE,
		on_click_callback = callback(self, self, "_on_left_arrow_clicked")
	})
	self._left_arrow_arrow = self._left_arrow:bitmap({
		visible = true,
		y = 7,
		x = 7,
		texture = tweak_data.gui.icons.ico_page_turn_left.texture,
		texture_rect = tweak_data.gui.icons.ico_page_turn_left.texture_rect,
		color = ComicBookGui.PAGING_NORMAL_PAGE_COLOR_ARROW
	})
	self._left_arrow:set_center_x(176)
	self._left_arrow:set_center_y(464)

	-- Right arrow initialization
	self._right_arrow = self._root_panel:panel({
		visible = true,
		y = 0,
		x = 0,
		w = tweak_data.gui.icons.players_icon_outline.texture_rect[3],
		h = tweak_data.gui.icons.players_icon_outline.texture_rect[4]
	})
	self._right_arrow_circle = self._right_arrow:image_button({
		visible = true,
		y = 0,
		x = 0,
		texture = tweak_data.gui.icons.players_icon_outline.texture,
		texture_rect = tweak_data.gui.icons.players_icon_outline.texture_rect,
		color = ComicBookGui.PAGING_NORMAL_PAGE_COLOR_CIRCLE,
		highlight_color = ComicBookGui.NORMAL_PAGE_HOVER_COLOR_CIRCLE,
		disabled_color = ComicBookGui.PAGING_NO_PAGE_COLOR_CIRCLE,
		on_click_callback = callback(self, self, "_on_right_arrow_clicked")
	})
	self._right_arrow_arrow = self._right_arrow:bitmap({
		visible = true,
		y = 7,
		x = 7,
		texture = tweak_data.gui.icons.ico_page_turn_right.texture,
		texture_rect = tweak_data.gui.icons.ico_page_turn_right.texture_rect,
		color = ComicBookGui.PAGING_NORMAL_PAGE_COLOR_ARROW
	})
	self._right_arrow:set_center_x(1552)
	self._right_arrow:set_center_y(464)

    -- We need to create a new panel for the comic book image so we can crop comic book page image easily
    self._comic_book_panel = self._root_panel:panel({
		visible = true,
		y = 96,
		x = 0,
		w = self._root_panel:w(),
		h = ComicBookGui.PAGE_HEIGHT
	})
	self._comic_book_image = self._comic_book_panel:image({
		texture = "ui/comic_book/raid_comic_001",
		visible = true,
		y = 0,
		x = 0,
		w = ComicBookGui.PAGE_WIDTH,
		h = ComicBookGui.PAGE_HEIGHT,
		on_mouse_pressed_callback = callback(self, self, "_on_comic_book_clicked")
	})

	-- Bullet panel initialization
	self._bullet_panel = self._root_panel:panel({
		h = 32,
		x = 0,
		y = self._root_panel:h() - ComicBookGui.BULLET_PANEL_HEIGHT * 2,
		w = self._root_panel:w()
	})
	for i = 1, ComicBookGui.TOTAL_PAGE_COUNT do
		table.insert(self._bullets_normal, self._bullet_panel:image_button({
			x = (i - 1) * (ComicBookGui.BULLET_WIDTH + ComicBookGui.BULLET_PADDING),
			y = ComicBookGui.BULLET_HEIGHT / 2,
			w = ComicBookGui.BULLET_WIDTH,
			h = ComicBookGui.BULLET_HEIGHT,
			texture = tweak_data.gui.icons.bullet_empty.texture,
			texture_rect = tweak_data.gui.icons.bullet_empty.texture_rect,
            color = ComicBookGui.PAGING_NORMAL_PAGE_COLOR_ARROW,
            highlight_color = ComicBookGui.NORMAL_PAGE_HOVER_COLOR_CIRCLE,    
            on_click_callback = callback(self, self, "_change_page", i)
		}))
		table.insert(self._bullets_active, self._bullet_panel:bitmap({
			h = 0,
			w = 0,
			x = (i - 1) * (ComicBookGui.BULLET_WIDTH + ComicBookGui.BULLET_PADDING),
			y = ComicBookGui.BULLET_HEIGHT / 2,
			texture = tweak_data.gui.icons.bullet_active.texture,
			texture_rect = tweak_data.gui.icons.bullet_active.texture_rect
		}))
	end
	self._bullet_panel:set_w(ComicBookGui.TOTAL_PAGE_COUNT * (ComicBookGui.BULLET_WIDTH + ComicBookGui.BULLET_PADDING))
	self._bullet_panel:set_center_x(self._root_panel:w() / 2)
	-- activating first bullet
	self._bullets_active[1]:set_w(ComicBookGui.BULLET_WIDTH)
	self._bullets_active[1]:set_h(ComicBookGui.BULLET_HEIGHT)

	self:bind_controller_inputs()
end

function ComicBookGui:_page_left()
	self:_change_page(self._current_page - 1)
end

function ComicBookGui:_page_right()
	self:_change_page(self._current_page + 1)
end

-- Updates arrow colors
function ComicBookGui:_update_arrows()
	-- Reseting left/right arrow colors and no_highlight param
	self._left_arrow_circle:set_enabled(not self:_on_first_page())
	self._right_arrow_circle:set_enabled(not self:_on_last_page())
	if (self:_on_first_page()) then
		self._left_arrow_arrow:set_color(ComicBookGui.PAGING_NO_PAGE_COLOR_ARROW)
	else
		self._left_arrow_arrow:set_color(ComicBookGui.PAGING_NORMAL_PAGE_COLOR_ARROW)
	end

	if (self:_on_last_page()) then
		self._right_arrow_arrow:set_color(ComicBookGui.PAGING_NO_PAGE_COLOR_ARROW)
	else
		self._right_arrow_arrow:set_color(ComicBookGui.PAGING_NORMAL_PAGE_COLOR_ARROW)
	end
end

-- Animates bullets, so previous bullet shrinks and current bullet instantly appears
function ComicBookGui:_animate_bullets(params)
	local current_page = params.current_page
	local previous_page = params.previous_page

	self._bullets_active[previous_page]:set_w(0)
	self._bullets_active[previous_page]:set_h(0)
	self._bullets_active[current_page]:set_w(ComicBookGui.BULLET_WIDTH)
	self._bullets_active[current_page]:set_h(ComicBookGui.BULLET_HEIGHT)
	self._bullets_active[current_page]:set_center_x(self._bullets_normal[current_page]:center_x())
	self._bullets_active[current_page]:set_center_y(self._bullets_normal[current_page]:center_y())

	local t = 0
	local animation_duration = ComicBookGui.ANIMATION_DURATION

	while t < animation_duration do
		local dt = coroutine.yield()
		t = t + dt

		local current_active_width = (animation_duration - t) / animation_duration * ComicBookGui.BULLET_WIDTH
		local current_active_height = (animation_duration - t) / animation_duration * ComicBookGui.BULLET_HEIGHT

		self._bullets_active[previous_page]:set_w(current_active_width)
		self._bullets_active[previous_page]:set_h(current_active_height)
		self._bullets_active[previous_page]:set_center_x(self._bullets_normal[previous_page]:center_x())
		self._bullets_active[previous_page]:set_center_y(self._bullets_normal[previous_page]:center_y())
	end
end

-- Zoom in animation for use with keyboard and controller
function ComicBookGui:_animate_zoom_in()
	local t = 0
	local animation_duration = ComicBookGui.ZOOM_DURATION
	self.animation_running = true
	while t < animation_duration do
		local dt = coroutine.yield()
		t = t + dt
		local completion = t / animation_duration
		-- Square-ing completion to make the animation more smooth
		local squared_completion = math.pow(completion, 2)
		local current_zoom = ComicBookGui.MIN_ZOOM + squared_completion * ComicBookGui.MIN_MAX_ZOOM_DIFFERENCE
		self:set_zoom(current_zoom)
	end
	self.animation_running = false
end

-- Zoom out animation for use with keyboard and controller
function ComicBookGui:_animate_zoom_out()
	local t = 0
	local animation_duration = ComicBookGui.ZOOM_DURATION
	self.animation_running = true
	while t < animation_duration do
		local dt = coroutine.yield()
		t = t + dt
		-- Inverting the completion to make the animation go backwards
		local completion = 1 - (t / animation_duration)
		-- Square-ing completion to make the animation more smooth
		local squared_completion = math.pow(completion, 2)
		local current_zoom = ComicBookGui.MIN_ZOOM + squared_completion * ComicBookGui.MIN_MAX_ZOOM_DIFFERENCE
		self:set_zoom(current_zoom)
	end
	self.animation_running = false
end

-- Stops animations and sets bullet sizes to 0
function ComicBookGui:_stop_animation(current_page, previous_page)
	if previous_page then
		self._bullets_active[previous_page]:set_w(0)
		self._bullets_active[previous_page]:set_h(0)
	end

	if current_page then
		self._bullets_active[current_page]:set_w(0)
		self._bullets_active[current_page]:set_h(0)
	end

	self._bullet_panel:stop()
end

-- Handling pressing the left arrow key
function ComicBookGui:move_left()
	self:_page_left()
	return self._root_panel:move_left()
end

-- Handling pressing the right arrow key
function ComicBookGui:move_right()
	self:_page_right()
	return self._root_panel:move_right()
end

-- Callback for left arrow button
function ComicBookGui:_on_left_arrow_clicked()
	self:_page_left()
end

-- Callback for right arrow button
function ComicBookGui:_on_right_arrow_clicked()
	self:_page_right()
end

-- Callback for zoom button
function ComicBookGui:_on_zoom()
	if (self.animation_running == true) then
		return
	end
	if (self._zoom < ComicBookGui.MAX_ZOOM) then
		self._comic_book_panel:stop()
		self._comic_book_panel:animate(callback(self, self, "_animate_zoom_in"))
	else
		self._comic_book_panel:stop()
		self._comic_book_panel:animate(callback(self, self, "_animate_zoom_out"))
	end
end

function ComicBookGui:bind_controller_inputs()
	local bindings = {
		{
			key = Idstring("menu_controller_shoulder_left"),
			callback = callback(self, self, "_on_left_arrow_clicked")
		},
		{
			key = Idstring("menu_controller_shoulder_right"),
			callback = callback(self, self, "_on_right_arrow_clicked")
		},
		{
			key = Idstring("menu_controller_face_top"),
			callback = callback(self, self, "_on_zoom")
		}
	}

	self:set_controller_bindings(bindings, true)

	local legend = {
		controller = {
			"menu_legend_back",
			"menu_legend_comic_book_left",
			"menu_legend_comic_book_right",
			"menu_legend_zoom"
		},
		keyboard = {
			{
				key = "footer_back",
				callback = callback(self, self, "_on_legend_pc_back", nil)
			}
		}
	}

	self:set_legend(legend)
end
