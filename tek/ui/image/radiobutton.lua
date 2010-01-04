-------------------------------------------------------------------------------
--
--	tek.ui.image.radiobutton
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	Version 2.2
--
-------------------------------------------------------------------------------

local ui = require "tek.ui"
local Image = ui.Image
module("tek.ui.image.radiobutton", tek.ui.class.image)

local coords =
{
	0x0000,0xffff,
	0x2aaa,0xd555,
	0xffff,0xffff,
	0xd555,0xd555,
	0xffff,0x0000,
	0xd555,0x2aaa,
	0x0000,0x0000,
	0x2aaa,0x2aaa,
	0x4800,0x4800,
	0xb800,0x4800,
	0xb800,0xb800,
	0x4800,0xb800
}

local points1 = { 7,8,1,2,3,4 }
local points2 = { 3,4,5,6,7,8 }
local points3 = { 9,10,12,11 }
local points4 = { 2,4,8,6 }

local primitives1 =
{
	{ 0x1000, 6, points1, "border-shine" },
	{ 0x1000, 6, points2, "border-shadow" },
	{ 0x1000, 4, points4, "background" },
}

local primitives2 =
{
	{ 0x1000, 6, points1, "border-shadow" },
	{ 0x1000, 6, points2, "border-shine" },
	{ 0x1000, 4, points4, "background" },
	{ 0x1000, 4, points3, "detail" },
}

function new(class, num)
	return Image.new(class, { coords, false, false, true,
		num == 2 and primitives2 or primitives1 })
end