-------------------------------------------------------------------------------
--
--	tek.ui.class.popitem
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		[[#tek.ui.class.element : Element]] /
--		[[#tek.ui.class.area : Area]] /
--		[[#tek.ui.class.frame : Frame]] /
--		[[#tek.ui.class.gadget : Gadget]] /
--		[[#tek.ui.class.text : Text]] /
--		PopItem ${subclasses(PopItem)}
--
--		This class provides an anchorage for popups. This also works
--		recursively, i.e. elements of the PopItem class may contain other
--		PopItems as their children. The most notable child class of the
--		PopItem is the [[#tek.ui.class.menuitem : MenuItem]].
--
--	ATTRIBUTES::
--		- {{Children [I]}} (table)
--			Array of child objects - will be connected to the application
--			while the popup is open.
--		- {{Shortcut [IG]}} (string)
--			Keyboard shortcut for the object; unlike
--			[[#tek.ui.class.gadget : Gadget]].KeyCode, this shortcut is
--			also enabled while the object is invisible. By convention, only
--			combinations with a qualifier should be used here, e.g.
--			{{"Alt+C"}}, {{"Shift+Ctrl+Q"}}. Qualifiers are separated by
--			{{"+"}} and must precede the key. Valid qualifiers are:
--				- {{"Alt"}}, {{"LAlt"}}, {{"RAlt"}}
--				- {{"Shift"}}, {{"LShift"}}, {{"RShift"}}
--				- {{"Ctrl"}}, {{"LCtrl"}}, {{"RCtrl"}}
--				- {{"IgnoreCase"}} - pseudo-qualifier; ignores the Shift key
--				- {{"IgnoreAltShift"}} - pseudo-qualifier, ignores the Shift
--				and Alt keys
--			
--			Alias names for keys are
--				- {{"F1"}} ... {{"F12"}} (function keys),
--				- {{"Left"}}, {{"Right"}}, {{"Up"}}, {{"Down"}} (cursor keys)
--				- {{"BckSpc"}}, {{"Tab"}}, {{"Esc"}}, {{"Insert"}},
--				{{"Overwrite"}}, {{"PageUp"}}, {{"PageDown"}}, {{"Pos1"}}, 
--				{{"End"}}, {{"Print"}}, {{"Scroll"}}, and {{"Pause"}}}}.
--
--	OVERRIDES::
--		- Element:cleanup()
--		- Element:getAttr()
--		- Object.init()
--		- Gadget:onPress()
--		- Area:passMsg()
--		- Element:setup()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"

local ui = require "tek.ui"
local CheckMark = ui.require("checkmark", 7)
local PopupWindow = ui.require("popupwindow", 4)
local Text = ui.require("text", 24)

local floor = math.floor
local ipairs = ipairs
local max = math.max
local unpack = unpack

module("tek.ui.class.popitem", tek.ui.class.text)
_VERSION = "PopItem 15.0"

-------------------------------------------------------------------------------
--	Constants and class data:
-------------------------------------------------------------------------------

local DEF_POPUPFADEINDELAY = 6
local DEF_POPUPFADEOUTDELAY = 10

local NOTIFY_SUBMENU = { ui.NOTIFY_SELF, "submenu", ui.NOTIFY_VALUE }
local NOTIFY_ONSELECT = { ui.NOTIFY_SELF, "selectPopup" }
local NOTIFY_ONUNSELECT = { ui.NOTIFY_SELF, "unselectPopup" }

local NOTIFY_PRESSED = { ui.NOTIFY_SELF, "onPress", ui.NOTIFY_VALUE }
local NOTIFY_ACTIVE = { ui.NOTIFY_SELF, "onActivate", ui.NOTIFY_VALUE }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

local PopItem = _M

function PopItem.init(self)
	self.Image = self.Image or false
	self.ImageRect = self.ImageRect or false
	self.PopupBase = false
	self.PopupWindow = false
	self.DelayedBeginPopup = false
	self.DelayedEndPopup = false
	if self.KeyCode == nil then
		self.KeyCode = true
	end
	self.ShiftX = false
	self.ShiftY = false
	if self.Children then
		self.Mode = "toggle"
		self.FocusNotification = { self, "unselectPopup" }
	else
		self.Children = false
		self.Mode = "button"
	end
	self.Shortcut = self.Shortcut or false
	return Text.init(self)
end

-------------------------------------------------------------------------------
--	connect: overrides
-------------------------------------------------------------------------------

function PopItem:connect(parent)
	if not self.PopupBase then
		-- this is a root item of a popup tree:
		self:addStyleClass("popup-root")
	end
	return Text.connect(self, parent)
end

-------------------------------------------------------------------------------
--	setup: overrides
-------------------------------------------------------------------------------

function PopItem:setup(app, window)
	Text.setup(self, app, window)
	if window:getClass() ~= PopupWindow then
		self:connectPopItems(app, window)
	end
end

-------------------------------------------------------------------------------
--	cleanup: overrides
-------------------------------------------------------------------------------

function PopItem:cleanup()
	local app, window = self.Application, self.Window
	if self.Window:getClass() ~= PopupWindow then
		self:disconnectPopItems(self.Window)
	end
	Text.cleanup(self)
	-- restore application and window, as they are needed in
	-- popitems' notification handlers even when they are not visible:
	self.Application, self.Window = app, window
end

-------------------------------------------------------------------------------
--	hide: overrides
-------------------------------------------------------------------------------

function PopItem:hide()
	self:unselectPopup()
	Text.hide(self)
end

-------------------------------------------------------------------------------
--	askMinMax: overrides
-------------------------------------------------------------------------------

function PopItem:askMinMax(m1, m2, m3, m4)
	local n1, n2, n3, n4 = Text.askMinMax(self, m1, m2, m3, m4)
	if self.Image then
		local p1, p2, p3, p4 = self:getPadding()
		local m = self.Margin
		local iw = n1 - m1 - p3 - p1 - m[3] - m[1] + 1
		local ih = n2 - m2 - p4 - p2 - m[4] - m[2] + 1
		iw, ih = self.Application.Display:fitMinAspect(iw, ih, 1, 1, 0)
		n1 = n1 + iw
		n3 = n3 + ih
	end
	return n1, n2, n3, n4
end

-------------------------------------------------------------------------------
--	layout: overrides
-------------------------------------------------------------------------------

function PopItem:layout(x0, y0, x1, y1, markdamage)
	if Text.layout(self, x0, y0, x1, y1, markdamage) then
		if self.Image then
			local r = self.Rect
			local p1, p2, p3, p4 = self:getPadding()
			local iw = r[3] - r[1] - p3 - p1 + 1
			local ih = r[4] - r[2] - p4 - p2 + 1
			iw, ih = self.Application.Display:fitMinAspect(iw, ih, 1, 1, 0)
			-- use half the padding that was granted for the right edge:
			local x = r[3] - floor(p3 / 2) - iw
			local y = r[2] + p2
			local i = self.ImageRect
			i[1], i[2], i[3], i[4] = x, y, x + iw - 1, y + ih - 1
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	draw: overrides
-------------------------------------------------------------------------------

function PopItem:draw()
	self.ShiftX, self.ShiftY = self.Drawable:getShift()
	if Text.draw(self) then
		local i = self.Image
		if i then
			local d = self.Drawable
			local r = self.Rect
			local ir = self.ImageRect
			local x0, y0, x1, y1 = unpack(ir)
			i:draw(d, x0, y0, x1, y1, d.Pens[self.FGPen])
		end
		return true
	end
end

-------------------------------------------------------------------------------
--	calcPopup:
-------------------------------------------------------------------------------

function PopItem:calcPopup()
	local x, y = self.Drawable:getXY()
	local w
	local r = self.Rect
	local sx, sy = self.ShiftX, self.ShiftY
	if self.PopupBase then
		x =	x + r[3] + sx
		y = y + r[2] + sy
	else
		x =	x + r[1] + sx
		y = y + r[4] + sy
		w = r[3] - r[1] + 1
	end
	return x, y, w
end

-------------------------------------------------------------------------------
--	beginPopup:
-------------------------------------------------------------------------------

function PopItem:beginPopup()

	local winx, winy, winw, winh = self:calcPopup()

	if self.Window.ActivePopup then
		db.info("Killed active popup")
		self.Window.ActivePopup:endPopup()
	end

	-- prepare children for being used in a popup window:
	for _, c in ipairs(self.Children) do
		c:init()
		if c:instanceOf(PopItem) then
			c.PopupBase = self.PopupBase or self
		end
	end

	self.PopupWindow = PopupWindow:new
	{
		-- window in which the popup cascade is rooted:
		PopupRootWindow = self.Window.PopupRootWindow or self.Window,
		-- item in which this popup window is rooted:
		PopupBase = self.PopupBase or self,
		Children = self.Children,
		Orientation = "vertical",
		Left = winx,
		Top = winy,
		Width = winw,
		Height = winh,
		MaxWidth = winw,
		MaxHeight = winh,
	}

	local app = self.Application

	-- connect children recursively:
	app.connect(self.PopupWindow)

	self.Window.ActivePopup = self

	app:addMember(self.PopupWindow)

	self.PopupWindow:setValue("Status", "show")

	self.Window:addNotify("Status", "hide", self.FocusNotification)
	self.Window:addNotify("WindowFocus", ui.NOTIFY_ALWAYS,
		self.FocusNotification)

end

-------------------------------------------------------------------------------
--	endPopup:
-------------------------------------------------------------------------------

function PopItem:endPopup()
	self:setValue("Selected", false, false)
	self:setValue("Focus", false)
	self:setState()
	self.Window:remNotify("WindowFocus", ui.NOTIFY_ALWAYS,
		self.FocusNotification)
	self.Window:remNotify("Status", "hide", self.FocusNotification)
	self.PopupWindow:setValue("Status", "hide")
	self.Application:remMember(self.PopupWindow)
	self.Window.ActivePopup = false
	self.PopupWindow = false
end

-------------------------------------------------------------------------------
--	unselectPopup:
-------------------------------------------------------------------------------

function PopItem:unselectPopup()
	if self.PopupWindow then
		self:endPopup()
		self.Window:setActiveElement()
	end
end

function PopItem:passMsg(msg)
	if msg[2] == ui.MSG_MOUSEBUTTON then
		if msg[3] == 1 then -- leftdown:
			if self.PopupWindow and self.Window.ActiveElement ~= self and
				not self.PopupBase and self.Window.HoverElement == self then
				self:endPopup()
				-- swallow event, don't let ourselves get reactivated:
				return false
			end
		elseif msg[3] == 2 then -- leftup:
			if self.PopupWindow and self.Window.HoverElement ~= self and
				not self.Disabled then
				self:endPopup()
			end
		end
	end
	return Text.passMsg(self, msg)
end


function PopItem:submenu(val)
	-- check if not the baseitem:
	if self.PopupBase then
		self.Window.DelayedBeginPopup = false
		if val == true then
			if not self.PopupWindow then
				db.trace("Begin beginPopup delay")
				self.Window.BeginPopupTicks = DEF_POPUPFADEINDELAY
				self.Window.DelayedBeginPopup = self
			elseif self.Window.DelayedEndPopup == self then
				self.Window.DelayedEndPopup = false
			end
		elseif val == false and self.PopupWindow then
			db.trace("Begin endPopup delay")
			self.Window.BeginPopupTicks = DEF_POPUPFADEOUTDELAY
			self.Window.DelayedEndPopup = self
		end
	end
end

-------------------------------------------------------------------------------
--	selectPopup:
-------------------------------------------------------------------------------

function PopItem:selectPopup()
	if self.Children then
		if not self.PopupWindow then
			self:beginPopup()
		end
		if self.PopupBase then
			self.Selected = false
			self.Flags:set(ui.FL_REDRAW)
		end
	end
end

-------------------------------------------------------------------------------
--	onPress:
-------------------------------------------------------------------------------

function PopItem:onPress(pressed)
	if not pressed and self.PopupBase then
		-- unselect base item, causing the tree to collapse:
		self.PopupBase:setValue("Selected", false)
	end
end

-------------------------------------------------------------------------------
--	connectPopItems:
-------------------------------------------------------------------------------

function PopItem:connectPopItems(app, window)
	local addhandlers
	if self:instanceOf(PopItem) then
		db.info("adding %s", self:getClassName())
		local c = self:getChildren(true)
		if c then
			self:addNotify("Hilite", ui.NOTIFY_ALWAYS, NOTIFY_SUBMENU)
			self:addNotify("Selected", true, NOTIFY_ONSELECT)
			self:addNotify("Selected", false, NOTIFY_ONUNSELECT)
			for i = 1, #c do
				c[i]:addStyleClass("popup-child")
				PopItem.connectPopItems(c[i], app, window)
			end
		else
			if self.Shortcut then
				window:addKeyShortcut("IgnoreCase+" .. self.Shortcut, self)
			end
			addhandlers = true
		end
	end
	if addhandlers or self:instanceOf(CheckMark) then
		-- TODO: why not connect()?
		self.Application = app
		self.Window = window
		self:addNotify("Active", ui.NOTIFY_ALWAYS, NOTIFY_ACTIVE)
		self:addNotify("Pressed", ui.NOTIFY_ALWAYS, NOTIFY_PRESSED)
	end
end

-------------------------------------------------------------------------------
--	disconnectPopItems:
-------------------------------------------------------------------------------

function PopItem:disconnectPopItems(window)
	local remhandlers
	if self:instanceOf(PopItem) then
		db.info("removing popitem %s", self:getClassName())
		local c = self:getChildren(true)
		if c then
			for i = 1, #c do
				PopItem.disconnectPopItems(c[i], window)
			end
			self:remNotify("Selected", false, NOTIFY_ONUNSELECT)
			self:remNotify("Selected", true, NOTIFY_ONSELECT)
			self:remNotify("Hilite", ui.NOTIFY_ALWAYS, NOTIFY_SUBMENU)
		else
			if self.Shortcut then
				window:remKeyShortcut(self.Shortcut, self)
			end
			remhandlers = true
		end
	end
	if remhandlers or self:instanceOf(CheckMark) then
		self:remNotify("Pressed", ui.NOTIFY_ALWAYS, NOTIFY_PRESSED)
		self:remNotify("Active", ui.NOTIFY_ALWAYS, NOTIFY_ACTIVE)
		-- TODO: why not disconnect()?
	end
end

-------------------------------------------------------------------------------
--	getAttr: overrides
-------------------------------------------------------------------------------

local getattrs =
{
	["menuitem-size"] = function(self)
		-- Do we have a text record for a shortcut? If so, return its size
		if self.TextRecords[2] then
			return self:getTextSize()	
		end
	end,
}

function PopItem:getAttr(attr, ...)
	return (getattrs[attr] or Text.getAttr)(self, attr, ...)
end

-------------------------------------------------------------------------------
--	getChildren: overrides
-------------------------------------------------------------------------------

function PopItem:getChildren(init)
	return init and self.Children
end
