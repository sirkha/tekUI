-------------------------------------------------------------------------------
--
--	tek.class.object
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		[[#ClassOverview]] :
--		[[#tek.class : Class]] / 
--		Object ${subclasses(Object)}
--
--		This class implements notifications.
--
--	ATTRIBUTES::
--		- {{Notifications [I]}} (table)
--			Initial set of notifications. Static initialization of
--			notifications has this form:
--
--					Notifications =
--					{
--					  ["attribute-name1"] =
--					  {
--					    [value1] =
--					    {
--					      action1,
--					      action2,
--					      ...
--					    }
--					    [value2] = ...
--					  },
--					  ["attribute-name2"] = ...
--					}
--
--			Refer to Object:addNotify() for possible placeholders
--			and a description of the action data structure.
--
--	IMPLEMENTS::
--		- Object:addNotify() - Adds a notification to an object
--		- Object.init() - (Re-)initializes an object
--		- Object:remNotify() - Removes a notification from an object
--		- Object:setValue() - Sets an attribute, triggering notifications
--
--	OVERRIDES::
--		- Class.new()
--
-------------------------------------------------------------------------------

local Class = require "tek.class"
local db = require "tek.lib.debug"

local assert = assert
local error = error
local insert = table.insert
local ipairs = ipairs
local remove = table.remove
local select = select
local type = type
local unpack = unpack

module("tek.class.object", tek.class)
_VERSION = "Object 10.0"
local Object = _M

-------------------------------------------------------------------------------
--	Placeholders:
-------------------------------------------------------------------------------

-- denotes that any value causes an object to be notified:
NOTIFY_ALWAYS = { }
-- denotes insertion of the object itself:
NOTIFY_SELF = function(a, n, i) insert(a, a[-1]) return 1 end
-- denotes insertion of the value that triggered the notification:
NOTIFY_VALUE = function(a, n, i) insert(a, a[0]) return 1 end
-- denotes insertion of the value of the attribute prior to setting it:
NOTIFY_OLDVALUE = function(a, n, i) insert(a, a[-2]) return 1 end
-- denotes insertion of logical negation of the value:
NOTIFY_TOGGLE = function(a, n, i) insert(a, not a[0]) return 1 end
-- denotes insertion of the value, using the next argument as format string:
NOTIFY_FORMAT = function(a, n, i) insert(a, n[i+1]:format(a[0])) return 2 end
-- denotes insertion of a function value:
NOTIFY_FUNCTION = function(a, n, i) insert(a, n[i+1]) return 2 end

-------------------------------------------------------------------------------
--	Class implementation:
-------------------------------------------------------------------------------

function Object.new(class, self)
	return Class.new(class, class.init(self or { }))
end

-------------------------------------------------------------------------------
--	object = Object.init(object): This function is called during Object.new()
--	before passing control to {{superclass.new()}}. By convention, {{new()}}
--	is used to claim resources (e.g. to create tables), whereas the {{init()}}
--	function is used to initialize them with defaults.
-------------------------------------------------------------------------------

function Object.init(self)
	self.Notifications = self.Notifications or { }
	return self
end

-------------------------------------------------------------------------------
--	Object:setValue(key, value[, notify]): Sets an {{object}}'s {{key}} to
--	the specified {{value}}, and, if {{notify}} is not '''false''', triggers
--	notifications that were previously registered with the object. If
--	{{value}} is '''nil''', the key's present value is reset. To enforce a
--	notification regardless of its value, set {{notify}} to '''true'''.
--	For details on registering notifications, see Object:addNotify().
-------------------------------------------------------------------------------

local function doNotify(self, n, key, oldval)
	if n then
		if not n[0] then
			n[0] = true
			for _, n in ipairs(n) do
				local a = { [-2] = oldval, [-1] = self, [0] = self[key] }
				local i, v = 1
				while i <= #n do
					v = n[i]
					if type(v) == "function" then
						i = i + v(a, n, i)
					else
						insert(a, v)
						i = i + 1
					end
				end
				if a[1] then
					local func = remove(a, 2)
					if type(func) == "string" then
						func = a[1][func]
					end
					if func then
						func(unpack(a))
					end
				end
			end
			n[0] = false
		-- else
		--	db.warn("dropping cyclic notification")
		end
	end
end

function Object:setValue(key, val, notify)
	local oldval = self[key]
	if val == nil then
		val = oldval
	end
	local n = self.Notifications[key]
	if n and notify ~= false then
		if val ~= oldval or notify then
			self[key] = val
			doNotify(self, n[NOTIFY_ALWAYS], key, oldval)
			doNotify(self, n[val], key, oldval)
		end
	else
		self[key] = val
	end
end

-------------------------------------------------------------------------------
--	Object:addNotify(attr, val, dest[, pos]):
--	Adds a notification to an object. {{attr}} is the name of an attribute to
--	react on setting its value. {{val}} is the value that triggers the
--	notification. The placeholder {{ui.NOTIFY_ALWAYS}} can be used for
--	reacting on any change of the value.
--	{{dest}} is a table describing the action to take when the notification
--	occurs; it has the general form:
--			{ object, method, arg1, ... }
--	{{object}} denotes the target of the notification, i.e. the {{self}}
--	that will be passed to the {{method}} as its first argument.
--	{{ui.NOTIFY_SELF}} is a placeholder for the object causing the
--	notification (see below for the additional placeholders {{ui.NOTIFY_ID}},
--	{{ui.NOTIFY_WINDOW}}, and {{ui.NOTIFY_APPLICATION}}). {{method}} can be
--	either a string denoting the name of a function in the addressed object,
--	or {{ui.NOTIFY_FUNCTION}} followed by a function value. The following
--	placeholders are supported in the [[Object][#tek.ui.class.object]] class:
--		* {{ui.NOTIFY_SELF}} - the object causing the notification
--		* {{ui.NOTIFY_VALUE}} - the value causing the notification
--		* {{ui.NOTIFY_TOGGLE}} - the logical negation of the value
--		* {{ui.NOTIFY_OLDVALUE}} - the attributes's value prior to setting it
--		* {{ui.NOTIFY_FORMAT}} - taking the next argument as a format string
--		for formatting the value
--		* {{ui.NOTIFY_FUNCTION}} - to pass a function in the next argument
--	The following additional placeholders are supported if the notification is
--	triggered in a child of the [[Element][#tek.ui.class.element]] class:
--		* {{ui.NOTIFY_ID}} - to address the [[Element][#tek.ui.class.element]]
--		with the Id given in the next argument
--		* {{ui.NOTIFY_WINDOW}} - to address the
--		[[Window][#tek.ui.class.window]] the object is connected to
--		* {{ui.NOTIFY_APPLICATION}} - to address the
--		[[Application][#tek.ui.class.application]] the object is connected to
--		* {{ui.NOTIFY_COROUTINE}} - like {{ui.NOTIFY_FUNCTION}}, but the
--		function will be launched as a coroutine by the
--		[[Application][#tek.ui.class.application]]. See also
--		Application:addCoroutine() for further details.
--	In any case, the {{method}} will be invoked as follows:
--			method(object, arg1, ...)
--	The optional {{pos}} argument allows for insertion at the specified
--	position in the list of notifications. By default, notifications are
--	added at the end. The only reasonable value for {{pos}} is probably {{1}}.
--
--	If the destination object or addressed method cannot be determined,
--	nothing else besides setting the attribute will happen.
--
--	Notifications should be removed using Object:remNotify() when they are
--	no longer needed, to reduce overhead and memory use.
------------------------------------------------------------------------------

function Object:addNotify(attr, val, dest, pos)
	if dest then
		local n = self.Notifications
		n[attr] = n[attr] or { }
		n[attr][val] = n[attr][val] or { }
		if pos then
			insert(n[attr][val], pos, dest)
		else
			insert(n[attr][val], dest)
		end
	else
		error("No notify destination given")
	end
end

-------------------------------------------------------------------------------
--	success = Object:remNotify(attr, val, dest):
--	Removes a notification from an object and returns '''true''' if it
--	was found and removed successfully. You must specify the exact set of
--	arguments as for Object:addNotify() to identify a notification.
-------------------------------------------------------------------------------

function Object:remNotify(attr, val, dest)
	local n = self.Notifications
	if n[attr] and n[attr][val] then
		for i, v in ipairs(n[attr][val]) do
			if v == dest then
				remove(n[attr][val], i)
				-- if #n[attr][val] == 0 then
				--	n[attr][val] = nil
				-- end
				return
			end
		end
	end
	db.error("Notification not found : %s[%s]", attr, val)
	return false
end
