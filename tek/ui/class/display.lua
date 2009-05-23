-------------------------------------------------------------------------------
--
--	tek.ui.class.display
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	LINEAGE::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] /
--		[[#tek.class.object : Object]] /
--		Display
--
--	OVERVIEW::
--		This class manages a display.
--
--	ATTRIBUTES::
--		- {{AspectX [IG]}} (number)
--			- X component of the display's aspect ratio
--		- {{AspectY [IG]}} (number)
--			- Y component of the display's aspect ratio
--
--	IMPLEMENTS::
--		- Display:closeFont() - Closes font
--		- Display:colorToRGB() - Converts a symbolic color name to RGB
--		- Display.createPixMap() - Creates a pixmap from picture file data
--		- Display:getFontAttrs() - Gets font attributes
--		- Display:getPaletteEntry() - Gets an entry from the symbolic palette
--		- Display.getPixmap() - Gets a a pixmap from the cache
--		- Display:getTime() - Gets system time
--		- Display.loadPixmap() - Loads a pixmap from the file system
--		- Display:openFont() - Opens a named font
--		- Display:openVisual() - Opens a visual
--		- Display:sleep() - Sleeps for a period of time
--
--	STYLE PROPERTIES::
--		- {{font}}
--		- {{font-fixed}}
--		- {{font-huge}}
--		- {{font-large}}
--		- {{font-menu}}
--		- {{font-small}}
--		- {{rgb-active}}
--		- {{rgb-active-detail}}
--		- {{rgb-background}}
--		- {{rgb-border-focus}}
--		- {{rgb-border-legend}}
--		- {{rgb-border-rim}}
--		- {{rgb-border-shadow}}
--		- {{rgb-border-shine}}
--		- {{rgb-cursor}}
--		- {{rgb-cursor-detail}}
--		- {{rgb-dark}}
--		- {{rgb-detail}}
--		- {{rgb-disabled}}
--		- {{rgb-disabled-detail}}
--		- {{rgb-disabled-detail2}}
--		- {{rgb-fill}}
--		- {{rgb-focus}}
--		- {{rgb-focus-detail}}
--		- {{rgb-group}}
--		- {{rgb-half-shadow}}
--		- {{rgb-half-shine}}
--		- {{rgb-hover}}
--		- {{rgb-hover-detail}}
--		- {{rgb-list}}
--		- {{rgb-list-active}}
--		- {{rgb-list-active-detail}}
--		- {{rgb-list-detail}}
--		- {{rgb-list2}}
--		- {{rgb-menu}}
--		- {{rgb-menu-active}}
--		- {{rgb-menu-active-detail}}
--		- {{rgb-menu-detail}}
--		- {{rgb-outline}}
--		- {{rgb-shadow}}
--		- {{rgb-shine}}
--		- {{rgb-user1}}
--		- {{rgb-user2}}
--		- {{rgb-user3}}
--		- {{rgb-user4}}
--
--	OVERRIDES::
--		- Class.new()
--
-------------------------------------------------------------------------------

local db = require "tek.lib.debug"
local ui = require "tek.ui"
local floor = math.floor
local open = io.open
local pairs = pairs
local tonumber = tonumber
local unpack = unpack
local Element = require "tek.ui.class.element"
local Visual = require "tek.lib.visual"

module("tek.ui.class.display", tek.ui.class.element)
_VERSION = "Display 19.0"

local Display = _M

-------------------------------------------------------------------------------
--	Class data and constants:
-------------------------------------------------------------------------------

local DEF_RGB_BACK       = "#d2d2d2"
local DEF_RGB_DETAIL     = "#000"
local DEF_RGB_SHINE      = "#fff"
local DEF_RGB_FILL       = "#6e82a0"
local DEF_RGB_SHADOW     = "#777"
local DEF_RGB_HALFSHADOW = "#bebebe"
local DEF_RGB_HALFSHINE  = "#e1e1e1"
local DEF_RGB_CURSOR     = "#c85014"

-- local DEF_RGB_BLACK      = "#000"
-- local DEF_RGB_RED        = "#f00"
-- local DEF_RGB_LIME       = "#0f0"
-- local DEF_RGB_YELLOW     = "#ff0"
-- local DEF_RGB_BLUE       = "#00f"
-- local DEF_RGB_FUCHSIA    = "#f0f"
-- local DEF_RGB_AQUA       = "#0ff"
-- local DEF_RGB_WHITE      = "#fff"
-- local DEF_RGB_GRAY       = "#808080"
-- local DEF_RGB_MAROON     = "#800000"
-- local DEF_RGB_GREEN      = "#008000"
-- local DEF_RGB_OLIVE      = "#808000"
-- local DEF_RGB_NAVY       = "#000080"
-- local DEF_RGB_PURPLE     = "#800080"
-- local DEF_RGB_TEAL       = "#008080"
-- local DEF_RGB_SILVER     = "#c0c0c0"
-- local DEF_RGB_ORANGE     = "#ffa500"

local DEF_MAINFONT  = "sans-serif,helvetica,arial,Vera:14"
local DEF_SMALLFONT = "sans-serif,helvetica,arial,Vera:12"
local DEF_MENUFONT  = "sans-serif,helvetica,arial,Vera:14"
local DEF_FIXEDFONT = "monospace,fixed,courier new,VeraMono:14"
local DEF_LARGEFONT = "sans-serif,helvetica,arial,Vera:18"
local DEF_HUGEFONT  = "sans-serif,utopia,arial,Vera:24"

local ColorDefaults =
{
	{ "background", DEF_RGB_BACK },
	{ "dark", DEF_RGB_DETAIL },
	{ "outline", DEF_RGB_SHINE },
	{ "fill", DEF_RGB_FILL },
	{ "active", DEF_RGB_HALFSHADOW },
	{ "focus", DEF_RGB_BACK },
	{ "hover", DEF_RGB_HALFSHINE },
	{ "disabled", DEF_RGB_BACK },
	{ "detail", DEF_RGB_DETAIL },
	{ "active-detail", DEF_RGB_DETAIL },
	{ "focus-detail", DEF_RGB_DETAIL },
	{ "hover-detail", DEF_RGB_DETAIL },
	{ "disabled-detail", DEF_RGB_SHADOW },
	{ "disabled-detail2", DEF_RGB_HALFSHINE },
	{ "border-shine", DEF_RGB_HALFSHINE },
	{ "border-shadow", DEF_RGB_SHADOW },
	{ "border-rim", DEF_RGB_DETAIL },
	{ "border-focus", DEF_RGB_CURSOR },
	{ "border-legend", DEF_RGB_DETAIL },
	{ "menu", DEF_RGB_BACK },
	{ "menu-detail", DEF_RGB_DETAIL },
	{ "menu-active", DEF_RGB_FILL },
	{ "menu-active-detail", DEF_RGB_SHINE },
	{ "list", DEF_RGB_BACK },
	{ "list2", DEF_RGB_HALFSHINE },
	{ "list-detail", DEF_RGB_DETAIL },
	{ "list-active", DEF_RGB_FILL },
	{ "list-active-detail", DEF_RGB_SHINE },
	{ "cursor", DEF_RGB_CURSOR },
	{ "cursor-detail", DEF_RGB_SHINE },
	{ "group", DEF_RGB_HALFSHADOW },
	{ "shadow", DEF_RGB_SHADOW },
	{ "shine", DEF_RGB_SHINE },
	{ "half-shadow", DEF_RGB_HALFSHADOW },
	{ "half-shine", DEF_RGB_HALFSHINE },
	{ "user1", DEF_RGB_DETAIL },
	{ "user2", DEF_RGB_DETAIL },
	{ "user3", DEF_RGB_DETAIL },
	{ "user4", DEF_RGB_DETAIL },
}

local FontDefaults =
{
	-- cache name : propname : default
	["ui-fixed"] = { "font-fixed", DEF_FIXEDFONT },
	["ui-huge"] = { "font-huge", DEF_HUGEFONT },
	["ui-large"] = { "font-large", DEF_LARGEFONT },
	["ui-main"] = { "font", DEF_MAINFONT },
	["ui-menu"] = { "font-menu", DEF_MENUFONT },
	["ui-small"] = { "font-small", DEF_SMALLFONT },
}
FontDefaults[""] = FontDefaults["ui-main"]

local PixmapCache = { }

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Display.new(class, self)
	self = self or { }
	self.AspectX = self.AspectX or 1
	self.AspectY = self.AspectY or 1
	self.RGBTab = { }
	self.PenTab = { }
	self.ColorNames = { }
	self.FontTab = self.FontTab or { }
	self.FontCache = { }
	return Element.new(class, self)
end

-------------------------------------------------------------------------------
--	image, width, height, transparency = Display.createPixmap(picture):
--	Creates a pixmap object from data in a picture file format. Currently
--	only the PPM file format is recognized.
-------------------------------------------------------------------------------

Display.createPixmap = Visual.createpixmap

-------------------------------------------------------------------------------
--	image, width, height, transparency = Display.loadPixmap(filename): Creates
--	a pixmap object from an image file in the file system. Currently only the
--	PPM file format is recognized.
-------------------------------------------------------------------------------

function Display.loadPixmap(fname)
	local f = open(fname, "rb")
	if f then
		local img, w, h, trans = createPixmap(f:read("*a"))
		f:close()
		if img then
			return img, w, h, trans
		end
	end
	db.warn("loading '%s' failed", fname)
	return false
end

-------------------------------------------------------------------------------
--	image, width, height, transparency = Display.getPixmap(fname): Gets a
--	pixmap object, either by loading it from the filesystem or by retrieving
--	it from the cache.
-------------------------------------------------------------------------------

function Display.getPixmap(fname)
	if PixmapCache[fname] then
		db.info("got cache copy for '%s'", fname)
		return unpack(PixmapCache[fname])
	end
	local pm, w, h, trans = loadPixmap(fname)
	if pm then
		PixmapCache[fname] = { pm, w, h, trans }
	end
	return pm, w, h, trans
end

-------------------------------------------------------------------------------
--	w, h = fitMinAspect(w, h, iw, ih[, evenodd]) - Fit to size, considering
--	the display's aspect ratio. If the optional {{evenodd}} is {{0}}, even
--	numbers are returned, if it is {{1}}, odd numbers are returned.
-------------------------------------------------------------------------------

function Display:fitMinAspect(w, h, iw, ih, round)
	local ax, ay = self.AspectX, self.AspectY
	if w * ih * ay / (ax * iw) > h then
		w = h * ax * iw / (ay * ih)
	else
		h = w * ih * ay / (ax * iw)
	end
	if round then
		return floor(w / 2) * 2 + round, floor(h / 2) * 2 + round
	end
	return floor(w), floor(h)
end

-------------------------------------------------------------------------------
--	r, g, b = colorToRGB(colspec[, defcolspec]): Converts a color
--	specification to RGB. If {{colspec}} is not a valid color, the optional
--	{{defcolspec}} can be used as a fallback. Valid color specifications are
--	{{#rrggbb}} (each color component is noted in 8 bit hexadecimal) and
--	{{#rgb}} (each color component is noted in 4 bit hexadecimal).
-------------------------------------------------------------------------------

function Display:colorToRGB(col, def)
	for i = 1, 2 do
		local r, g, b = col:match("%#(%x%x)(%x%x)(%x%x)")
		if r then
			r, g, b = tonumber("0x" .. r), tonumber("0x" .. g),
				tonumber("0x" .. b)
			return r, g, b
		end
		r, g, b = col:match("%#(%x)(%x)(%x)")
		if r then
			r, g, b = tonumber("0x" .. r), tonumber("0x" .. g),
				tonumber("0x" .. b)
			r = r * 16 + r
			g = g * 16 + g
			b = b * 16 + b
			return r, g, b
		end
		col = def
		if not col then
			return
		end
		-- retry with default color
	end
end

-------------------------------------------------------------------------------
--	name, r, g, b = getPaletteEntry(index): Gets the {{name}} and red, green,
--	blue components of a color of the given {{index}} in the Display's
--	symbolic color palette.
-------------------------------------------------------------------------------

function Display:getPaletteEntry(i)
	local color = ColorDefaults[i]
	if color then
		local name, defrgb = color[1], color[2]
		local rgb = self.RGBTab[i] or defrgb
		return name, self:colorToRGB(rgb, defrgb)
	end
end

-------------------------------------------------------------------------------
--	getProperties: overrides
-------------------------------------------------------------------------------

function Display:getProperties(p, pclass)
	for i = 1, #ColorDefaults do
		local color = ColorDefaults[i]
		self.RGBTab[i] = self.RGBTab[i] or
			self:getProperty(p, pclass, "rgb-" .. color[1])
	end
	local ft = self.FontTab
	for cfname, font in pairs(FontDefaults) do
		ft[cfname] = ft[cfname] or self:getProperty(p, pclass, font[1])
	end
	Element.getProperties(self, p, pclass)
end

-------------------------------------------------------------------------------
--	font = openFont(fontname): Opens the named font. For a discussion
--	of the {{fontname}} format, see [[#tek.ui.class.text : Text]].
-------------------------------------------------------------------------------

function Display:openFont(fname)
	local fname = fname or ""
	if not self.FontCache[fname] then
		local name, size = fname:match("^([^:]*):?(%d*)$")
		local deff = self.FontTab[name] or
			FontDefaults[name] and FontDefaults[name][2]
		if deff then
			local nname, nsize = deff:match("^([^:]*):?(%d*)$")
			if size == "" then
				size = nsize
			end
			name = nname
		end
		size = tonumber(size)
		for name in name:gmatch("%s*([^,]*)%s*,?") do
			if name == "" then
				name = FontDefaults[""][2]:match("^([^:,]*),?[^:]*:?(%d*)$")
			end
			db.info("Open font: '%s' -> '%s:%d'", fname, name, size or -1)
			local font = Visual.openfont(name, size)
			if font then
				local r = { font, font:getattrs { }, fname, name }
				self.FontCache[fname] = r
				self.FontCache[font] = r
				return font
			end
		end
		return
	end
	return self.FontCache[fname][1]
end

-------------------------------------------------------------------------------
--	closeFont(font): Closes the specified font, and always returns '''false'''.
-------------------------------------------------------------------------------

function Display:closeFont(display, font)
	return false
end

-------------------------------------------------------------------------------
--	h, up, ut = getFontAttrs(font): Returns the font attributes height,
--	underline position and underline thickness.
-------------------------------------------------------------------------------

function Display:getFontAttrs(font)
	local a = self.FontCache[font][2]
	return a.Height, a.UlPosition, a.UlThickness
end

-------------------------------------------------------------------------------
--	wait:
-------------------------------------------------------------------------------

function Display:wait()
	return Visual.wait()
end

-------------------------------------------------------------------------------
--	getMsg:
-------------------------------------------------------------------------------

function Display:getMsg(...)
	return Visual.getmsg(...)
end

-------------------------------------------------------------------------------
--	sleep:
-------------------------------------------------------------------------------

function Display.sleep(...)
	return Visual.sleep(...)
end

-------------------------------------------------------------------------------
--	Display:getTime(): Gets the system time.
-------------------------------------------------------------------------------

function Display:getTime(...)
	return Visual.gettime(...)
end

-------------------------------------------------------------------------------
--	openVisual:
-------------------------------------------------------------------------------

function Display:openVisual(...)
	return Visual.open(...)
end
