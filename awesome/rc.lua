-- {{{ Libraries
local gears     = require("gears")
local awful     = require("awful")
awful.rules     = require("awful.rules")
require("awful.autofocus")
local vicious   = require("vicious")
local scratch   = require("scratch")
local naughty   = require("naughty")
local beautiful = require("beautiful")
local wibox     = require("wibox")
-- }}}

-- {{{ Error handling
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end

-- }}}

-- {{{ Variable definitions
local altkey = "Mod1"
local modkey = "Mod4"

local home   = os.getenv("HOME")
local exec   = awful.util.spawn
local sexec  = awful.util.spawn_with_shell

-- Beautiful theme
beautiful.init(home .. "/.config/awesome/zenburn/theme.lua")

-- Window management layouts
layouts = {
  awful.layout.suit.tile,        -- 1
  awful.layout.suit.tile.bottom, -- 2
  awful.layout.suit.fair,        -- 3
  awful.layout.suit.max,         -- 4
  awful.layout.suit.spiral,      -- 5
  awful.layout.suit.floating     -- 6
}
-- }}}


-- {{{ Tags
tags = {
  names  = { "term", "emacs", "firefox", "im/mail", "chrome", "git/deploy", "video", "other", "media" },
  layout = { layouts[3], layouts[2], layouts[1], layouts[3], layouts[6],
             layouts[5], layouts[4], layouts[6], layouts[6]
}}

for s = 1, screen.count() do
    tags[s] = awful.tag(tags.names, s, tags.layout)
    awful.tag.setproperty(tags[s][4], "mwfact", 0.13)
end
-- }}}
  
-- {{{ moc player

function hook_moc()
    moc_info = io.popen("mocp -i"):read("*all")
    moc_state = string.gsub(string.match(moc_info, "State: %a*"),"State: ","")
    if moc_state == "PLAY" or moc_state == "PAUSE" then
        moc_artist = string.gsub(string.match(moc_info, "Artist: %C*"), "Artist: ","")
        moc_title = string.gsub(string.match(moc_info, "SongTitle: %C*"), "SongTitle: ","")
        moc_curtime = string.gsub(string.match(moc_info, "CurrentTime: %d*:%d*"), "CurrentTime: ","")
        moc_totaltime = string.gsub(string.match(moc_info, "TotalTime: %d*:%d*"), "TotalTime: ","")
        if moc_artist == "" then 
            moc_artist = "unknown artist" 
        end
        if moc_title == "" then 
            moc_title = "unknown title" 
        end
        moc_string = " " .. moc_artist .. " - " .. moc_title .. "(" .. moc_curtime .. "/" .. moc_totaltime .. ")"
        if moc_state == "PAUSE" then 
            moc_string = " [[ " .. moc_string .. " ]]"
        end
    else
        moc_string = "-- MOC not playing --"
    end
    tb_moc:set_text(moc_string)
end

function pause_moc()
    moc_info = io.popen("mocp -i"):read("*all")
    moc_state = string.gsub(string.match(moc_info, "State: %a*"),"State: ","")
    if moc_state == "PLAY" then
        io.popen("mocp -P")
    elseif moc_state == "PAUSE" then
        io.popen("mocp -U")
    end
end

-- }}}

-- {{{ Wibox
--
-- {{{ Widgets configuration
--
-- {{{ Reusable separator
separator = wibox.widget.imagebox()
separator:set_image(beautiful.widget_sep)
-- }}}

-- {{{ CPU usage and temperature
cpuicon = wibox.widget.imagebox()
cpuicon:set_image(beautiful.widget_cpu)
-- Initialize widgets
cpugraph = awful.widget.graph()
cputemp1 = wibox.widget.textbox()
cputemp2 = wibox.widget.textbox()
gputemp  = wibox.widget.textbox()
-- Graph properties
cpugraph:set_width(40)
cpugraph:set_height(14)
cpugraph:set_background_color(beautiful.fg_off_widget)
cpugraph:set_color({ type = "linear", from = { 0, 0 }, to = { 10, 0 }, stops = { { 0, beautiful.fg_end_widget }, { 0.5, beautiful.fg_center_widget }, { 1, beautiful.fg_widget } }})
-- Register widgets
vicious.register(cpugraph, vicious.widgets.cpu,      "$1")
vicious.register(cputemp1, vicious.widgets.thermala, " $1C", 19, {"thinkpad_hwmon", "core"} )
vicious.register(cputemp2, vicious.widgets.thermalb, " $1C", 19, {"thinkpad_hwmon", "core"} )
vicious.register(gputemp,  vicious.widgets.nvsmi, " $1C", 19)
-- }}}

-- {{{ Battery state
baticon = wibox.widget.imagebox()
baticon:set_image(beautiful.widget_bat)
-- Initialize widget
batwidget = wibox.widget.textbox()
-- Register widget
vicious.register(batwidget, vicious.widgets.bat, "$1$2%", 61, "BAT0")
-- }}}

-- {{{ moc widget
--tb_moc = widget({ type = "textbox", name = "tb_moc", align = "right" })
tb_moc = wibox.widget.textbox()
tb_moc:buttons(awful.util.table.join(awful.button({ }, 1, function () pause_moc() end)))
-- }}}

-- {{{ Mcabber
jbwidget = wibox.widget.textbox()
function jbInfo()
    local f = io.popen("cat ~/.mcabber/mcabber.state | wc -l")
    local n = f:read("*all")
    f:close()
    if n == "0\n" then nn = "0" 
    else nn = '<span color="#FF0000">'.. n ..'</span>'
    end
    jbwidget:set_markup("/".. nn)
end
--awful.hooks.timer.register(2, function() jbInfo() end)
mcabber = timer({timeout = 2})
mcabber:connect_signal("timeout", function() jbInfo() end)
mcabber:start()
-- }}}

-- {{{ Memory usage
memicon = wibox.widget.imagebox()
memicon:set_image(beautiful.widget_mem)
-- Initialize widget
membar = awful.widget.progressbar()
-- Pogressbar properties
membar:set_vertical(true)
membar:set_ticks(true)
membar:set_height(12)
membar:set_width(8)
membar:set_ticks_size(2)
membar:set_background_color(beautiful.fg_off_widget)
membar:set_color({ type = "linear", from = { 0, 0 }, to = { 10, 0 }, stops = { { 0, beautiful.fg_widget }, { 0.5, beautiful.fg_center_widget }, { 1, beautiful.fg_end_widget } }})
-- Register widget
vicious.register(membar, vicious.widgets.mem, "$1", 13)
-- }}}

-- {{{ File system usage
fsicon = wibox.widget.imagebox()
fsicon:set_image(beautiful.widget_fs)
-- Initialize widgets
fs = {
  r = awful.widget.progressbar(), h = awful.widget.progressbar(),
  s = awful.widget.progressbar(), b = awful.widget.progressbar()
}
-- Progressbar properties
for _, w in pairs(fs) do
  w:set_vertical(true)
  w:set_ticks(true)
  w:set_height(14)
  w:set_width(5)
  w:set_ticks_size(2)
  w:set_border_color(beautiful.border_widget)
  w:set_background_color(beautiful.fg_off_widget)
  w:set_color({ type = "linear", from = { 0, 0 }, to = { 10, 0 }, stops = { { 0, beautiful.fg_widget }, { 0.5, beautiful.fg_center_widget }, { 1, beautiful.fg_end_widget } }})
end
-- Enable caching
vicious.cache(vicious.widgets.fs)
-- Register widgets
vicious.register(fs.r, vicious.widgets.fs, "${/ used_p}",            599)
-- }}}

-- {{{ Network usage
dnicon = wibox.widget.imagebox()
upicon = wibox.widget.imagebox()
dnicon:set_image(beautiful.widget_net)
upicon:set_image(beautiful.widget_netup)
-- Initialize widget
netwidget = wibox.widget.textbox()
-- Register widget
vicious.register(netwidget, vicious.widgets.net, '<span color="'
  .. beautiful.fg_netdn_widget ..'">${wlan0 down_kb}</span> <span color="'
  .. beautiful.fg_netup_widget ..'">${wlan0 up_kb}</span>', 3)
-- }}}

-- {{{ Mail subject
mailicon = wibox.widget.imagebox()
mailicon:set_image(beautiful.widget_mail)
-- Initialize widget
mailwidget = wibox.widget.textbox()
-- Register widget
vicious.register(mailwidget, vicious.widgets.mdir, "$1", 30, {home .. "/Mail/pomeo@pomeo.ru/INBOX", home .. "/Mail/me@sovechkin.com/Inbox"})
-- }}}

-- {{{ Weather
weathericon = wibox.widget.imagebox()
weathericon:set_image(beautiful.widget_temp)
-- Initialize widget
weatherwidget = wibox.widget.textbox()
-- Register widget
vicious.register(weatherwidget, vicious.widgets.weather, "${tempc}°C", 360, "UUWW")
-- Register buttons
weatherwidget:buttons(awful.util.table.join(
  awful.button({ }, 1, function ()
   local statf = io.popen('weather -i UUWW')
   local stat = statf:read("*all")
   statf :close()
   weatherinfo = {naughty.notify({ title = "Weather" , text = stat,timeout = 0 ,position   = "top_right" })}
  end),
  awful.button({ }, 3, function ()
   naughty.destroy(weatherinfo[1])
  end)
))
-- }}}

-- the current agenda popup
local org_agenda_pupup = nil

-- do some highlighting and show the popup
function show_org_agenda ()
   local fd = io.open("/tmp/org-agenda.txt", "r")
   if not fd then
      return
   end
   local text = fd:read("*a")
   fd:close()
   -- highlight week agenda line
   text = text:gsub("(Week%-agenda[ ]+%(W%d%d?%):)", "<span color='#00CC00'><b>%1</b></span>")
   -- highlight dates
   text = text:gsub("(%w+[ ]+%d%d? %w+ %d%d%d%d[^n]*)", "<span color='#CCCCCC'>%1</span>")
   -- highlight times
   text = text:gsub("(%d%d?:%d%d)", "<span color='#FFFF66'>%1</span>")
   -- highlight tags
   text = text:gsub("(:[^ ]+:)([ ]*n)", "<span color='#666'>%1%2</span>")
   -- highlight TODOs
   text = text:gsub("(TODO) ", "<span color='#FF0000'><b>%1</b></span> ")
   -- highlight categories
   text = text:gsub("([ ]+%w+:) ", "<span color='#33EEFF'>%1</span> ")
   org_agenda_pupup = naughty.notify(
      { text     = text,
        timeout  = 999999999,
        width    = 500,
        position = "top_right",
        screen   = mouse.screen })
end

-- dispose the popup
function dispose_org_agenda ()
   if org_agenda_pupup ~= nil then
      naughty.destroy(org_agenda_pupup)
      org_agenda_pupup = nil
   end
end

-- {{{ Org-mode agenda
orgicon = wibox.widget.imagebox()
orgicon:set_image(beautiful.widget_org)
-- Initialize widget
orgwidget = wibox.widget.textbox()
-- Configure widget
local orgmode = {
  files = { home.."/Dropbox/Org/tasks.org",
  },
  color = {
    past   = '<span color="'..beautiful.fg_urgent..'">',
    today  = '<span color="'..beautiful.fg_normal..'">',
    soon   = '<span color="'..beautiful.fg_widget..'">',
    future = '<span color="'..beautiful.fg_netup_widget..'">'
}} 
-- Register widget
vicious.register(orgwidget, vicious.widgets.org,
  orgmode.color.past..'$1</span>-'..orgmode.color.today .. '$2</span>-' ..
  orgmode.color.soon..'$3</span>-'..orgmode.color.future.. '$4</span>', 601,
  orgmode.files
)
orgwidget:connect_signal('mouse::enter', show_org_agenda)
orgwidget:connect_signal('mouse::leave', dispose_org_agenda)
-- Register buttons
orgwidget:buttons(awful.util.table.join(
  awful.button({ }, 1, function () exec("emacsclient --eval '(org-agenda-list)'") end),
  awful.button({ }, 3, function () exec("emacsclient --eval '(make-remember-frame)'") end)
))
-- }}}

-- {{{ Volume level
volicon = wibox.widget.imagebox()
volicon:set_image(beautiful.widget_vol)
-- Initialize widgets
volbar    = awful.widget.progressbar()
volwidget = wibox.widget.textbox()
-- Progressbar properties
volbar:set_vertical(true)
volbar:set_ticks(true)
volbar:set_height(12)
volbar:set_width(8)
volbar:set_ticks_size(2)
volbar:set_background_color(beautiful.fg_off_widget)
volbar:set_color({ type = "linear", from = { 0, 0 }, to = { 10, 0 }, stops = { { 0, beautiful.fg_widget }, { 0.5, beautiful.fg_center_widget }, { 1, beautiful.fg_end_widget } }})
-- Enable caching
vicious.cache(vicious.widgets.volume)
-- Register widgets
vicious.register(volbar,    vicious.widgets.volume,  "$1",  2, "Master")
vicious.register(volwidget, vicious.widgets.volume, " $1%", 2, "Master")
-- Register buttons
volbar:buttons(awful.util.table.join(
   awful.button({ }, 1, function () exec("pavucontrol") end),
   awful.button({ }, 4, function () exec("amixer -q set Master 2dB+", false) end),
   awful.button({ }, 5, function () exec("amixer -q set Master 2dB-", false) end)
))
-- Register assigned buttons
volwidget:buttons(volbar:buttons())
-- }}}

-- {{{ Date and time
dateicon = wibox.widget.imagebox()
dateicon:set_image(beautiful.widget_date)
-- Initialize widget
datewidget = wibox.widget.textbox()
-- Register widget
vicious.register(datewidget, vicious.widgets.date, "%b %d, %R", 61)
-- Register buttons
datewidget:buttons(awful.util.table.join(
  awful.button({ }, 1, function () exec("pylendar.py") end)
))
-- }}}

-- {{{ System tray
systray = wibox.widget.systray()
-- }}}

-- {{{ Wibox initialisation
mywibox     = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist   = {}
mytaglist.buttons = awful.util.table.join(
    awful.button({ },        1, awful.tag.viewonly),
    awful.button({ modkey }, 1, awful.client.movetotag),
    awful.button({ },        3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, awful.client.toggletag),
    awful.button({ },        4, awful.tag.viewnext),
    awful.button({ },        5, awful.tag.viewprev
))

for s = 1, screen.count() do
    -- Create a promptbox
    mypromptbox[s] = awful.widget.prompt()
    -- Create a layoutbox
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
        awful.button({ }, 1, function () awful.layout.inc(layouts,  1) end),
        awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
        awful.button({ }, 4, function () awful.layout.inc(layouts,  1) end),
        awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)
    ))

    -- Create the taglist
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)
    -- Create the wibox
    mywibox[s] = awful.wibox({      screen = s,
        fg = beautiful.fg_normal, height = 12,
        bg = beautiful.bg_normal, position = "top",
        border_color = beautiful.border_focus,
        border_width = beautiful.border_width
    })
    -- Widgets that are aligned to the left
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(mytaglist[s])
    left_layout:add(mylayoutbox[s])
    left_layout:add(separator)
    left_layout:add(mypromptbox[s])

    -- Widgets that are aligned to the right
    local right_layout = wibox.layout.fixed.horizontal()
    right_layout:add(tb_moc)
    right_layout:add(separator)
    right_layout:add(cpuicon)
    right_layout:add(cpugraph)
    right_layout:add(cputemp1)
    right_layout:add(cputemp2)
    right_layout:add(gputemp)
    right_layout:add(separator)
    right_layout:add(baticon)
    right_layout:add(batwidget)
    right_layout:add(separator)
    right_layout:add(memicon)
    right_layout:add(membar)
    right_layout:add(separator)
    right_layout:add(fsicon)
    right_layout:add(fs.r)
    right_layout:add(separator)
    right_layout:add(dnicon)
    right_layout:add(netwidget)
    right_layout:add(upicon)
    right_layout:add(separator)
    right_layout:add(mailicon)
    right_layout:add(mailwidget)
    right_layout:add(jbwidget)
    right_layout:add(separator)
    right_layout:add(orgicon)
    right_layout:add(orgwidget)
    right_layout:add(separator)
    right_layout:add(volicon)
    right_layout:add(volbar)
    right_layout:add(volwidget)
    right_layout:add(separator)
    right_layout:add(weathericon)
    right_layout:add(weatherwidget)
    right_layout:add(separator)
    right_layout:add(dateicon)
    right_layout:add(datewidget)
    right_layout:add(separator)
    right_layout:add(wibox.widget.systray())

    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
end
-- }}}


-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))

-- Client bindings
clientbuttons = awful.util.table.join(
    awful.button({ },        1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize)
)
-- }}}


-- {{{ Key bindings
--
-- {{{ Global keys
globalkeys = awful.util.table.join(
    -- {{{ Applications
    awful.key({ modkey }, "e", function () exec("emacsclient -n -c") end),
    awful.key({ modkey }, "w", function () exec("google-chrome") end),
    awful.key({ altkey }, "F1",  function () exec("urxvt") end),
    awful.key({ altkey }, "F12", function () scratch.drop("urxvt", "bottom") end),
    awful.key({ modkey }, "q", function () exec("emacsclient --eval '(make-remember-frame)'") end),
    -- }}}

    -- {{{ Multimedia keys
    awful.key({}, "#121", function () exec("amixer -q set Master toggle") end),
    awful.key({}, "#122", function () exec("amixer -q set Master 2dB-") end),
    awful.key({}, "#123", function () exec("amixer -q set Master 2dB+") end),
    -- }}}

    -- {{{ Prompt menus
    awful.key({ altkey }, "F2", function ()
	awful.util.spawn( "dmenu_run -nf '#888888' -nb '#222222' -sf '#ffffff' -sb '#285577'" )
    end),
    -- }}}

    -- {{{ Awesome controls
    awful.key({ modkey }, "b", function ()
        wibox[mouse.screen].visible = not wibox[mouse.screen].visible
    end),
    awful.key({ modkey, "Shift" }, "q", awesome.quit),
    awful.key({ modkey, "Shift" }, "r", function ()
        mypromptbox[mouse.screen].text = awful.util.escape(awful.util.restart())
    end),
    -- }}}

    -- {{{ Tag browsing
    awful.key({ altkey }, "n",   awful.tag.viewnext),
    awful.key({ altkey }, "p",   awful.tag.viewprev),
    awful.key({ altkey }, "Tab", awful.tag.history.restore),

    -- {{{ Layout manipulation
    awful.key({ modkey }, "l",          function () awful.tag.incmwfact( 0.05) end),
    awful.key({ modkey }, "h",          function () awful.tag.incmwfact(-0.05) end),
    awful.key({ modkey, "Shift" }, "l", function () awful.client.incwfact(-0.05) end),
    awful.key({ modkey, "Shift" }, "h", function () awful.client.incwfact( 0.05) end),
    awful.key({ modkey, "Shift" }, "space", function () awful.layout.inc(layouts, -1) end),
    awful.key({ modkey },          "space", function () awful.layout.inc(layouts,  1) end),
    -- }}}

    -- {{{ Focus controls
    awful.key({ modkey }, "p", function () awful.screen.focus_relative(1) end),
    awful.key({ modkey }, "s", function () scratch.pad.toggle() end),
    awful.key({ modkey }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey }, "j", function ()
        awful.client.focus.byidx(1)
        if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey }, "k", function ()
        awful.client.focus.byidx(-1)
        if client.focus then client.focus:raise() end
    end),
    awful.key({ modkey }, "Tab", function ()
        awful.client.focus.history.previous()
        if client.focus then client.focus:raise() end
    end),
    awful.key({ altkey }, "Escape", function ()
        awful.menu.menu_keys.down = { "Down", "Alt_L" }
        local cmenu = awful.menu.clients({width=230}, { keygrabber=true, coords={x=525, y=330} })
    end),
    awful.key({ modkey, "Shift" }, "j", function () awful.client.swap.byidx(1)  end),
    awful.key({ modkey, "Shift" }, "k", function () awful.client.swap.byidx(-1) end)
    -- }}}
)
-- }}}

-- {{{ Client manipulation
clientkeys = awful.util.table.join(
    awful.key({ modkey }, "c", function (c) c:kill() end),
    awful.key({ modkey }, "d", function (c) scratch.pad.set(c, 0.60, 0.60, true) end),
    awful.key({ modkey }, "f", function (c) c.fullscreen = not c.fullscreen end),
    awful.key({ modkey }, "m", function (c)
        c.maximized_horizontal = not c.maximized_horizontal
        c.maximized_vertical   = not c.maximized_vertical
    end),
    awful.key({ modkey }, "o",     awful.client.movetoscreen),
    awful.key({ modkey }, "Next",  function () awful.client.moveresize( 20,  20, -40, -40) end),
    awful.key({ modkey }, "Prior", function () awful.client.moveresize(-20, -20,  40,  40) end),
    awful.key({ modkey }, "Down",  function () awful.client.moveresize(  0,  20,   0,   0) end),
    awful.key({ modkey }, "Up",    function () awful.client.moveresize(  0, -20,   0,   0) end),
    awful.key({ modkey }, "Left",  function () awful.client.moveresize(-20,   0,   0,   0) end),
    awful.key({ modkey }, "Right", function () awful.client.moveresize( 20,   0,   0,   0) end),
    awful.key({ modkey, "Control"},"r", function (c) c:redraw() end),
    awful.key({ modkey, "Shift" }, "0", function (c) c.sticky = not c.sticky end),
    awful.key({ modkey, "Shift" }, "m", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey, "Shift" }, "c", function (c) exec("kill -CONT " .. c.pid) end),
    awful.key({ modkey, "Shift" }, "s", function (c) exec("kill -STOP " .. c.pid) end),
    awful.key({ modkey, "Shift" }, "t", function (c)
        awful.titlebar.toggle(c)
    end),
    awful.key({ modkey, "Shift" }, "f", function (c) if awful.client.floating.get(c)
        then awful.client.floating.delete(c);    awful.titlebar.hide(c)
        else awful.client.floating.set(c, true); awful.titlebar.show(c) end
    end)
)
-- }}}

-- {{{ Keyboard digits
local keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end
-- }}}

-- {{{ Tag controls
for i = 1, keynumber do
    globalkeys = awful.util.table.join( globalkeys,
        awful.key({ modkey }, "#" .. i + 9, function ()
            local screen = mouse.screen
            if tags[screen][i] then awful.tag.viewonly(tags[screen][i]) end
        end),
        awful.key({ modkey, "Control" }, "#" .. i + 9, function ()
            local screen = mouse.screen
            if tags[screen][i] then awful.tag.viewtoggle(tags[screen][i]) end
        end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9, function ()
            if client.focus and tags[client.focus.screen][i] then
                awful.client.movetotag(tags[client.focus.screen][i])
            end
        end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function ()
            if client.focus and tags[client.focus.screen][i] then
                awful.client.toggletag(tags[client.focus.screen][i])
            end
        end))
end
-- }}}

-- Set keys
root.keys(globalkeys)
-- }}}


-- {{{ Rules
awful.rules.rules = {
    { rule = { }, properties = {
      focus = true,      size_hints_honor = false,
      keys = clientkeys, buttons = clientbuttons,
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal }
    },
    { rule = { class = "Google-chrome", instance = "chrome" },
     properties = { tag = tags[screen.count()][5] }
    },
    { rule = { class = "Revelation", instance = "revelation" },
      properties = { tag = tags[screen.count()][9] }
    },
    { rule = { class = "Firefox" },
      properties = { tag = tags[screen.count()][3] }
    },
    { rule = { class = "Emacs", instance = "_Remember_" },
      properties = { floating = true }, callback = awful.titlebar.show
    },
    { rule = { class = "Xmessage", instance = "xmessage" },
      properties = { floating = true }, callback = awful.titlebar.show
    },
    { rule = { class = "npviewer.bin",    instance = "npviewer.bin" },
      properties = { floating = false }
    }
}
-- }}}


-- {{{ Signals
--
-- {{{ Manage signal handler
client.connect_signal("manage", function (c, startup)

    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function (c)
        if  awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    -- Client placement
    if not startup then
        awful.client.setslave(c)

        if  not c.size_hints.program_position
        and not c.size_hints.user_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)
-- }}}

-- {{{ Focus signal handlers
client.connect_signal("focus",   function (c) c.border_color = beautiful.border_focus  end)
client.connect_signal("unfocus", function (c) c.border_color = beautiful.border_normal end)
-- }}}

-- {{{ Arrange signal handler
for s = 1, screen.count() do screen[s]:add_signal("arrange", function ()
    local clients = awful.client.visible(s)
    local layout = awful.layout.getname(awful.layout.get(s))

    for _, c in pairs(clients) do -- Floaters are always on top
        if   awful.client.floating.get(c) or layout == "floating"
        then if not c.fullscreen then c.above       =  true  end
        else                          c.above       =  false end
    end
  end)
end
-- }}}
-- }}}

-- {{{ Moc widget timer

mytimermoc = timer({timeout = 1})
mytimermoc:connect_signal("timeout", function() hook_moc() end)
mytimermoc:start()

-- }}}

function run_once(prg)
  awful.util.spawn_with_shell("pgrep -u $USER -x " .. prg .. " || (" .. prg .. ")")
end

awful.util.spawn_with_shell(home .. "/.xinitrc")
awful.util.spawn_with_shell("gnome-keyring-daemon --start  --components=gpg,pkcs11,secrets,ssh")
awful.util.spawn_with_shell(home .. "/.dropbox-dist/dropboxd")
awful.util.spawn_with_shell("redshiftgui")
awful.util.spawn_with_shell("glippy")
awful.util.spawn_with_shell("blueman-applet")
awful.util.spawn_with_shell("wicd-gtk --tray")
awful.util.spawn_with_shell(home .. "/.conky_start_1.sh")
awful.util.spawn_with_shell(home .. "/.conky_start_2.sh")
awful.util.spawn_with_shell("rescuetime")
awful.util.spawn_with_shell("shutter --min_at_startup")
awful.util.spawn_with_shell("xcompmgr")
awful.util.spawn_with_shell("sudo tpb -d")
