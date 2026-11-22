-- Evian Hub v1.0 | Lumber Tycoon 2
-- Single client script. Game actions depend on LT2 server behavior.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService") -- Local JSON only.
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then return end

local env = (getgenv and getgenv()) or _G
for _, key in ipairs({"EvianHubCleanup", "LT2MobileCleanup"}) do
    if type(env[key]) == "function" then
        local ok, err = pcall(env[key])
        if not ok then warn("[Evian Hub] Prior cleanup:", err) end
    end
end

local F, S, UI = {}, {alive = true, gameStatus = "Checking game…"}, {}
function F.errorText(err)
    local line = tostring(err):match("^[^\r\n]*") or "Unknown error"
    line = line:gsub("^.-:%d+:%s*", ""):gsub("https?://%S+", "[url]")
    line = line:gsub("[/\\][^%s:]+", "[path]"):gsub("[^%w%s%._:%-%[%]]", "?")
    return line:sub(1,72)
end
local connections, tweens = {}, setmetatable({}, {__mode = "k"})
local styles = setmetatable({}, {__mode = "k"})
local file = "EvianHub-v1-settings.json"
local categories = {
    {"Home", "home"}, {"Movement", "move"}, {"Building", "build"},
    {"Wood & Trees", "wood"}, {"Player", "player"}, {"Automation", "auto"},
    {"Visuals", "visual"}, {"Utilities", "utility"}, {"Customisation", "settings"},
}
local known = {}
for _, entry in ipairs(categories) do known[entry[1]] = true end
local defaults = {
    theme = 1, accent = 1, width = 790, height = 485,
    x = .5, y = .5, fx = 1, fy = .43, collapsed = false, animations = true,
    compact = false, status = true, health = true, speed = true, coords = false,
    selection = true, active = true, shortcut = "F8", category = "Home",
}
local ranges = {theme = {1, 2}, accent = {1, 3}, width = {440, 1080}, height = {300, 720},
    x = {0, 1}, y = {0, 1}, fx = {0, 1}, fy = {0, 1}}
local shortcuts = {"F8", "F9", "F10", "Off"}
local cfg = {}
local function valid(raw)
    local clean = {}
    for key, default in pairs(defaults) do
        local value, range = raw[key], ranges[key]
        if range then
            if type(value) == "number" and value == value and math.abs(value) < math.huge then
                value = math.clamp(value, range[1], range[2])
                if key == "theme" or key == "accent" then value = math.floor(value) end
            else value = default end
        elseif key == "category" then value = known[value] and value or default
        elseif key == "shortcut" then
            local allowed = false
            for _, name in ipairs(shortcuts) do if name == value then allowed = true end end
            if not allowed then value = default end
        elseif type(value) ~= type(default) then value = default end
        clean[key] = value
    end
    return clean
end

-- Settings and lifetime
S.storage = type(readfile) == "function" and type(writefile) == "function"
local raw = {}
if S.storage then
    local ok, contents = pcall(readfile, file)
    if ok and type(contents) == "string" and #contents <= 8192 then
        local decoded, parsed = pcall(function() return HttpService:JSONDecode(contents) end)
        if decoded and type(parsed) == "table" then raw = parsed
        else warn("[Evian Hub] Settings could not be read; using defaults.") end
    end
end
cfg = valid(raw)
function F.flush()
    if not S.dirty or not S.storage then return end
    S.dirty = false
    local ok, err = pcall(function() writefile(file, HttpService:JSONEncode(cfg)) end)
    if not ok then
        S.storage = false
        warn("[Evian Hub] Settings storage:", err)
        if F.storageLabel then F.storageLabel() end
        if S.alive and F.notify then F.notify("Settings are available for this session only.", true,
            {code = "S01", details = "Step: save settings\nCause: " .. F.errorText(err)}) end
    else
        S.saved = true
        if F.storageLabel then F.storageLabel() end
    end
end
function F.save()
    S.dirty = true
    if not S.storage or S.saveQueued then return end
    S.saveQueued = true
    task.delay(.65, function()
        S.saveQueued = false
        if S.alive then F.flush() end
    end)
end
function F.connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end
local function cleanup()
    if not S.alive then return end
    S.alive = false
    F.flush()
    if F.cleanupFeatures then
        local ok, err = pcall(F.cleanupFeatures)
        if not ok then warn("[Evian Hub] Feature cleanup:",err) end
    end
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if S.logConnection then S.logConnection:Disconnect() end
    for _, slots in pairs(tweens) do
        for _, tween in pairs(slots) do tween:Cancel() end
    end
    if UI.gui then UI.gui:Destroy() end
    if env.EvianHubCleanup == cleanup then env.EvianHubCleanup = nil end
end
env.EvianHubCleanup = cleanup

-- Theme and primitives shared by pages. All art is made from native GUI shapes.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local palettes = {
    {shell = rgb(23, 26, 32), side = rgb(27, 31, 38), body = rgb(31, 36, 44),
        card = rgb(38, 44, 54), control = rgb(47, 55, 67), line = rgb(59, 68, 82)},
    {shell = rgb(18, 23, 32), side = rgb(22, 29, 40), body = rgb(26, 35, 48),
        card = rgb(34, 45, 60), control = rgb(44, 57, 73), line = rgb(56, 73, 94)},
}
local accents = {rgb(109, 181, 255), rgb(137, 215, 255), rgb(138, 164, 255)}
function F.color(key)
    local accent = accents[cfg.accent]
    if key == "accent" then return accent end
    if key == "selected" then return palettes[cfg.theme].side:Lerp(accent, .14) end
    if key == "text" then return rgb(239, 244, 252) end
    if key == "muted" then return rgb(171, 184, 204) end
    if key == "error" then return rgb(255, 131, 141) end
    if key == "shadow" then return rgb(7, 10, 15) end
    return palettes[cfg.theme][key]
end
local function make(class, props, parent)
    local instance = Instance.new(class)
    if instance:IsA("GuiObject") then instance.BorderSizePixel = 0 end
    for key, value in pairs(props) do instance[key] = value end
    instance.Parent = parent
    return instance
end
function F.style(object, property, key)
    styles[object] = styles[object] or {}
    styles[object][property] = key
    object[property] = F.color(key)
end
function F.retheme()
    for object, props in pairs(styles) do
        if object.Parent then
            for property, key in pairs(props) do object[property] = F.color(key) end
        end
    end
    if F.paintNav then F.paintNav(false) end
    if F.refreshSettings then F.refreshSettings() end
end
local off, size = UDim2.fromOffset, UDim2.new
local function corner(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 9)}, object)
end
local function border(object, key)
    local line = make("UIStroke", {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1}, object)
    F.style(line, "Color", key or "line")
    return line
end
local function frame(parent, name, key, bounds, position)
    local object = make("Frame", {Name = name, Size = bounds or size(1,0,1,0),
        Position = position or off(0,0), BackgroundTransparency = key and 0 or 1}, parent)
    if key then F.style(object, "BackgroundColor3", key) end
    return object
end
local function label(parent, text, points, key, bounds, position, bold)
    local object = make("TextLabel", {Text = text, TextSize = points, BackgroundTransparency = 1,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, Size = bounds or size(1,0,1,0),
        Position = position or off(0,0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd}, parent)
    F.style(object, "TextColor3", key or "text")
    return object
end
function F.motion(object, slot, goals, seconds, forceOff)
    local slots = tweens[object] or {}
    tweens[object] = slots
    if slots[slot] then slots[slot]:Cancel(); slots[slot] = nil end
    if not cfg.animations or forceOff then
        for k, v in pairs(goals) do object[k] = v end
    else
        local tween = TweenService:Create(object, TweenInfo.new(seconds or .15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
        slots[slot] = tween
        tween:Play()
    end
end
local function button(parent, text, bounds, position, action, key)
    local b = make("TextButton", {Text = text, Size = bounds, Position = position or off(0,0),
        AutoButtonColor = false, Font = Enum.Font.GothamSemibold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd}, parent)
    corner(b, 7)
    F.style(b, "BackgroundColor3", key or "control")
    F.style(b, "TextColor3", "text")
    if action then
        local press = make("UIScale", {Scale = 1}, b)
        b.InputBegan:Connect(function(input)
            if F.pointer(input) then F.motion(press, "press", {Scale = .96}, .08) end
        end)
        b.InputEnded:Connect(function() F.motion(press, "press", {Scale = 1}, .1) end)
        b.Activated:Connect(function()
            F.motion(press, "press", {Scale = 1}, .1)
            local ok, err = xpcall(action, debug.traceback)
            if not ok then
                warn("[Evian Hub]", err)
                local control = b.Name ~= "TextButton" and b.Name or (b.Text ~= "" and b.Text or "button")
                F.notify("This control couldn't complete. Try again.", true,
                    {code = "U01", details = "Control: " .. F.errorText(control) .. "\nCause: " .. F.errorText(err)})
            end
        end)
    end
    return b
end
local function line(parent, x1, y1, x2, y2, width, key)
    local dx, dy = x2 - x1, y2 - y1
    local edge = frame(parent, "Stroke", key, off(math.sqrt(dx*dx + dy*dy), width), off((x1+x2)/2, (y1+y2)/2))
    edge.AnchorPoint = Vector2.new(.5, .5)
    edge.Rotation = math.deg(math.atan2(dy, dx))
    corner(edge, 1)
end
local function logo(parent, position)
    local emblem = frame(parent, "EH Monogram", "shell", off(36,36), position)
    corner(emblem, 9)
    local path = {{18,2},{32,10},{32,26},{18,34},{4,26},{4,10},{18,2}}
    for i = 1, #path-1 do
        line(emblem, path[i][1],path[i][2],path[i+1][1],path[i+1][2],1.3,"line")
    end
    line(emblem, 10,12,10,24,2,"text")
    line(emblem, 10,12,17,12,2,"text")
    line(emblem, 10,24,17,24,2,"text")
    line(emblem, 10,18,26,18,2,"accent")
    line(emblem, 17,14,17,22,2,"accent")
    line(emblem, 26,12,26,24,2,"accent")
    return emblem
end

-- One pointer owner at a time for touch and mouse, shared by sliders and drags.
function F.pointer(input)
    return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end
function F.capture(input, move, finish)
    if not F.pointer(input) or S.pointer then return false end
    S.pointer = {input = input, move = move, finish = finish}
    return true
end
F.connect(Input.InputChanged, function(input)
    local session = S.pointer
    if session and (input == session.input or (session.input.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement)) then session.move(input.Position) end
end)
F.connect(Input.InputEnded, function(input)
    local session = S.pointer
    if not session then return end
    if input == session.input or (input.UserInputType == Enum.UserInputType.MouseButton1
        and session.input.UserInputType == Enum.UserInputType.MouseButton1) then
        S.pointer = nil
        if session.finish then session.finish() end
    end
end)
F.connect(Input.WindowFocusReleased, function()
    local session = S.pointer
    S.pointer = nil
    if session and session.finish then session.finish() end
end)

-- Root and notifications
local playerGui = player:WaitForChild("PlayerGui", 15)
if not playerGui then cleanup(); warn("[Evian Hub] PlayerGui did not load."); return end
local stale = playerGui:FindFirstChild("EvianHub")
if stale then stale:Destroy() end
UI.gui = make("ScreenGui", {Name = "EvianHub", ResetOnSpawn = false, IgnoreGuiInset = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50}, playerGui)
UI.root = frame(UI.gui, "Safe Area")
UI.notifications = frame(UI.root, "Notifications", nil, size(.9,0,0,0), size(1,-12,0,10))
UI.notifications.AnchorPoint = Vector2.new(1,0)
UI.notifications.ZIndex = 20
UI.notifications.Active = false
make("UISizeConstraint", {MaxSize = Vector2.new(292, 260)}, UI.notifications)
make("UIListLayout", {Padding = UDim.new(0,7), SortOrder = Enum.SortOrder.LayoutOrder}, UI.notifications)
local toasts, toastErrors, toastSerial = {}, {}, 0
local loading
local function resizeNotifications()
    local height, count = 0, 0
    if loading and loading.Parent then height, count = 65, 1 end
    for _, card in ipairs(toasts) do
        if card.Parent then height, count = height + card.Size.Y.Offset, count + 1 end
    end
    UI.notifications.Size = size(.9,0,0,height + math.max(0,count-1)*7)
end
local function removeToast(card)
    for i, item in ipairs(toasts) do
        if item == card then table.remove(toasts, i); break end
    end
    toastErrors[card] = nil
    card:Destroy()
    resizeNotifications()
end
function F.notify(message, isError, diagnostic)
    if not S.alive then return end
    local signature = message .. (diagnostic and (diagnostic.code or "") or "")
    if S.lastMessage == signature and os.clock() - (S.lastNotice or 0) < 2 then return end
    S.lastMessage, S.lastNotice = signature, os.clock()
    if isError then
        S.lastError = {message = message, diagnostic = diagnostic}
        for i = #toasts, 1, -1 do if toastErrors[toasts[i]] then removeToast(toasts[i]) end end
    end
    if #toasts >= 2 then
        for _, item in ipairs(toasts) do if not toastErrors[item] then removeToast(item); break end end
    end
    toastSerial = toastSerial + 1
    local card = frame(UI.notifications, "Notification", "card", size(1,0,0,isError and 170 or 54))
    card.LayoutOrder = toastSerial
    corner(card, 9); border(card)
    local accent = isError and "error" or "accent"
    corner(frame(card, "Indicator", accent, off(3,isError and 150 or 34), off(8,10)), 2)
    local title = isError and ("ERROR " .. (diagnostic and diagnostic.code or "GENERAL")) or "EVIAN HUB"
    label(card, title, 10, accent, size(1,-56,0,16), off(18,6), true)
    local msg = label(card, message, 12, "text", size(1,-28,0,isError and 34 or 28), off(18,isError and 36 or 21))
    msg.TextWrapped = true
    msg.TextYAlignment = Enum.TextYAlignment.Top
    if isError then
        msg.TextTruncate = Enum.TextTruncate.None
        local detail = label(card, diagnostic and diagnostic.details or "See the game console for technical details.", 11, "muted", size(1,-28,0,93), off(18,70))
        detail.TextWrapped = true
        detail.TextYAlignment = Enum.TextYAlignment.Top
        detail.TextTruncate = Enum.TextTruncate.None
        local dismiss = button(card, "×", off(30,30), size(1,-35,0,4), function()
            removeToast(card)
            S.lastMessage = nil
        end)
        dismiss.Name = "Dismiss error"
        toastErrors[card] = true
    end
    toasts[#toasts+1] = card
    resizeNotifications()
    task.delay(3, function() if S.alive and card.Parent then removeToast(card) end end)
end
loading = frame(UI.notifications, "Loading", "card", size(1,0,0,65))
resizeNotifications()
corner(loading, 9); border(loading); logo(loading, off(12,13))
label(loading, "Evian Hub", 14, "text", size(1,-70,0,20), off(58,9), true)
local progress = label(loading, "Preparing interface…", 11, "muted", size(1,-70,0,17), off(58,29))
local rail = frame(loading, "Loading stages", "control", size(1,-72,0,3), off(58,52))
local fill = frame(rail, "Completed stages", "accent", size(.34,0,1,0))
task.wait()
if not S.alive then return end

-- Window, header, safe-area layout and navigation shell
UI.window = frame(UI.root, "Window")
UI.window.Visible = false
UI.group = make("CanvasGroup", {Size = size(1,0,1,0), Position = size(.5,0,.5,0),
    AnchorPoint = Vector2.new(.5,.5), BackgroundTransparency = 1}, UI.window)
UI.scale = make("UIScale", {Scale = 1}, UI.group)
local shell = frame(UI.group, "Shell", "shell", size(1,0,1,-4))
corner(shell, 11); border(shell)
shell.ZIndex = 2
local shadow = frame(UI.group, "Window depth", "shadow", size(1,0,1,-2), off(0,2))
shadow.BackgroundTransparency = .38
corner(shadow, 11)
local header = frame(shell, "Drag Header", nil, size(1,0,0,56))
header.Active = true
logo(header, off(12,10))
label(header, "Evian Hub", 19, "text", off(120,22), off(56,8), true)
local version = label(header, "v1.0", 10, "accent", off(42,18), off(165,10), true)
local playerLine = label(header, player.Name, 11, "muted", size(1,-159,0,17), off(56,32))
local gameLine = label(header, "", 11, "accent", off(180,22), size(1,-278,0,17))
gameLine.TextXAlignment = Enum.TextXAlignment.Right
local minimise = button(header, "−", off(36,36), size(1,-90,0,10), function() F.show(false) end, "side")
minimise.Name, minimise.TextSize = "Minimise", 18
local close = button(header, "×", off(36,36), size(1,-47,0,10), function() F.confirmClose() end, "side")
close.Name, close.TextSize = "Close Hub", 18
frame(shell, "Header divider", "line", size(1,0,0,1), off(0,55))
UI.sidebar = frame(shell, "Sidebar", "side", size(0,145,1,-66), off(8,56))
corner(UI.sidebar, 8)
UI.nav = make("ScrollingFrame", {Name = "Category list", Size = size(1,-8,1,-46), Position = off(4,4),
    BackgroundTransparency = 1, ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = off(0,0)}, UI.sidebar)
F.style(UI.nav, "ScrollBarImageColor3", "muted")
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,3)}, UI.nav)
local collapse = button(UI.sidebar, "‹  Collapse", size(1,-8,0,35), size(0,4,1,-38), function()
    if S.narrowScreen then
        S.mobileExpanded = not S.mobileExpanded
        F.layout()
    else
        cfg.collapsed = not cfg.collapsed
        F.layout()
        F.save()
    end
end)
collapse.Name = "Collapse sidebar"
UI.content = frame(shell, "Content", "body", size(1,-167,1,-103), off(159,56))
corner(UI.content, 8)

local search = make("TextBox", {Name = "Search", Position = off(10,8), Size = size(1,-57,0,32),
    PlaceholderText = "Search features and settings", Text = "", ClearTextOnFocus = false,
    Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, UI.content)
corner(search, 7); border(search); F.style(search, "BackgroundColor3", "side")
F.style(search, "TextColor3", "text"); F.style(search, "PlaceholderColor3", "muted")
make("UIPadding", {PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,8)}, search)
button(UI.content, "×", off(30,34), size(1,-39,0,8), function() search.Text = ""; search:ReleaseFocus() end).Name = "Clear search"
UI.pages = frame(UI.content, "Pages", nil, size(1,-20,1,-46), off(10,46))
UI.status = label(shell, "", 11, "muted", size(1,-52,0,27), size(0,16,1,-33))
UI.status.Name = "Status information"
UI.grip = button(shell, "◢", off(32,32), size(1,-36,1,-36), nil, "side")
UI.grip.Name = "Resize handle"
UI.float = button(UI.root, "", off(49,49), off(0,0), nil, "side")
UI.float.Name = "Open Evian Hub"
UI.float.ZIndex = 5
border(UI.float, "accent")
logo(UI.float, off(6,6))

function F.layout()
    local bounds = UI.root.AbsoluteSize
    if bounds.X < 120 or bounds.Y < 150 then return end
    local maxW, maxH = math.min(bounds.X-16, 1080), math.min(bounds.Y-16, 720)
    local w = math.floor(math.clamp(cfg.width, math.min(440,maxW), maxW))
    local h = math.floor(math.clamp(cfg.height, math.min(300,maxH), maxH))
    local x = 8 + (bounds.X-w-16)*cfg.x
    local y = 8 + (bounds.Y-h-16)*cfg.y
    S.width, S.height, S.x, S.y = w, h, x, y
    UI.window.Size, UI.window.Position = off(w,h), off(x,y)
    S.narrowScreen = w < 535
    local narrow = S.narrowScreen and not S.mobileExpanded or (not S.narrowScreen and cfg.collapsed)
    S.iconOnly = narrow
    local fullNav = S.mobileExpanded and w < 365
    local side = narrow and 49 or (fullNav and w-16 or (S.narrowScreen and 132 or 145))
    local bottom = cfg.status and 48 or 36
    UI.sidebar.Size = size(0,side,1,-66)
    UI.content.Position = off(side+14,56)
    UI.content.Size = size(1,-side-22,1,-56-bottom)
    UI.content.Visible = not fullNav
    UI.status.Visible = cfg.status and not fullNav
    UI.status.Position = size(0,side+16,1,-48)
    UI.status.Size = size(1,-side-60,0,40)
    collapse.Text = narrow and "›" or "‹  Collapse"
    playerLine.Text = w < 625 and (player.Name .. "  ·  " .. S.gameStatus) or player.Name
    gameLine.Visible = w >= 625
    gameLine.Text = S.gameStatus
    version.Visible = w >= 305
    local fx = math.max(0,bounds.X-65)
    local fy = math.max(0,bounds.Y-65)
    UI.float.Position = off(8 + fx*cfg.fx, 8 + fy*cfg.fy)
    if F.paintNav and S.lastNarrow ~= narrow then
        S.lastNarrow = narrow
        F.paintNav(false)
    end
    if F.refreshSettings then F.refreshSettings() end
end

header.InputBegan:Connect(function(input)
    if not F.pointer(input) or not S.x then return end
    local p, originX, originY = input.Position, S.x, S.y
    local headerRight = header.AbsolutePosition.X + header.AbsoluteSize.X
    if p.X >= headerRight-98 then return end
    F.capture(input, function(pos)
        local bounds = UI.root.AbsoluteSize
        cfg.x = math.clamp((originX + pos.X - p.X - 8) / math.max(1,bounds.X-S.width-16),0,1)
        cfg.y = math.clamp((originY + pos.Y - p.Y - 8) / math.max(1,bounds.Y-S.height-16),0,1)
        F.layout()
    end, F.save)
end)
UI.grip.InputBegan:Connect(function(input)
    if not S.width then return end
    local p, w, h, x, y = input.Position, S.width, S.height, S.x, S.y
    F.capture(input, function(pos)
        local bounds = UI.root.AbsoluteSize
        local maxW = math.min(1080,bounds.X-16)
        local maxH = math.min(720,bounds.Y-16)
        if maxW < 1 or maxH < 1 then return end
        cfg.width = math.floor(math.clamp(w+pos.X-p.X,math.min(440,maxW),maxW))
        cfg.height = math.floor(math.clamp(h+pos.Y-p.Y,math.min(300,maxH),maxH))
        cfg.x = math.clamp((x-8)/math.max(1,bounds.X-cfg.width-16),0,1)
        cfg.y = math.clamp((y-8)/math.max(1,bounds.Y-cfg.height-16),0,1)
        F.layout()
    end, F.save)
end)
UI.float.InputBegan:Connect(function(input)
    local p, fx, fy = input.Position, cfg.fx, cfg.fy
    local dragged = false
    F.capture(input, function(pos)
        local dx, dy = pos.X-p.X, pos.Y-p.Y
        if math.abs(dx)+math.abs(dy) > 7 then dragged = true; S.lastFloatDrag = os.clock() end
        if not dragged then return end
        local bounds = UI.root.AbsoluteSize
        cfg.fx = math.clamp(fx+dx/math.max(1,bounds.X-65),0,1)
        cfg.fy = math.clamp(fy+dy/math.max(1,bounds.Y-65),0,1)
        F.layout()
    end, function()
        if dragged then S.lastFloatDrag = os.clock(); F.save() end
    end)
end)
UI.float.Activated:Connect(function()
    if os.clock()-(S.lastFloatDrag or -1) > .25 then F.show(true) end
end)
function F.show(open)
    if not S.alive or open == S.open or S.closing then return end
    S.open = open
    S.transition = (S.transition or 0) + 1
    local transition = S.transition
    if open then
        UI.float.Visible = false
        UI.window.Visible = true
        UI.group.GroupTransparency = cfg.animations and 1 or 0
        UI.scale.Scale = cfg.animations and .985 or 1
    else
        search:ReleaseFocus()
        UI.float.Visible = true
        S.closeRequested = nil
    end
    F.motion(UI.group, "visibility", {GroupTransparency = open and 0 or 1}, .16)
    F.motion(UI.scale, "visibility", {Scale = open and 1 or .985}, .16)
    if not open then
        local function hide()
            if S.alive and S.transition == transition then UI.window.Visible = false end
        end
        if cfg.animations then task.delay(.17, hide) else hide() end
    end
end
function F.confirmClose()
    if not S.closeRequested or os.clock()-S.closeRequested > 4 then
        S.closeRequested = os.clock()
        F.notify("Tap × again to close Evian Hub. Use − to minimise.")
        return
    end
    F.show(false)
    S.closing = true
    UI.float.Visible = false
    if cfg.animations then task.delay(.18, cleanup) else cleanup() end
end
F.connect(Input.InputBegan, function(input, processed)
    if processed or Input:GetFocusedTextBox() or cfg.shortcut == "Off" then return end
    if input.KeyCode == Enum.KeyCode[cfg.shortcut] then F.show(not S.open) end
end)
F.connect(UI.root:GetPropertyChangedSignal("AbsoluteSize"), F.layout)

-- Page and control builders. Register a card title and its container for search.
local pages, nav, features, index = {}, {}, {pendingLogs = {}}, {}
local function page(name)
    local list = make("ScrollingFrame", {Name = name, Size = size(1,0,1,0), Visible = false,
        BackgroundTransparency = 1, ScrollBarThickness = 3, CanvasSize = off(0,0),
        ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y}, UI.pages)
    F.style(list, "ScrollBarImageColor3", "accent")
    make("UIPadding", {PaddingTop = UDim.new(0,2), PaddingBottom = UDim.new(0,11)}, list)
    local flow = make("UIListLayout", {Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder}, list)
    pages[name] = {list = list, flow = flow, order = 0}
    return list
end
local function row(category, name, height, key)
    local pageData = pages[category]
    pageData.order = pageData.order + 1
    local item = frame(pageData.list, name, key, size(1,-3,0,height))
    item.LayoutOrder = pageData.order
    if key then corner(item, 8); border(item) end
    return item
end
local function heading(category, text)
    label(row(category, text, 25), text, 16, "text", nil, nil, true)
end
local function textBlock(container, text, top, height)
    local textUI = label(container, text, 12, "muted", size(1,-24,0,height), off(12,top))
    textUI.TextWrapped, textUI.TextYAlignment = true, Enum.TextYAlignment.Top
    return textUI
end
local function register(category, name, target, terms)
    index[#index+1] = {category = category, name = name, target = target, terms = terms or ""}
end
local function card(category, title, description, height, terms)
    local item = row(category, title, height or 91, "card")
    label(item, title, 14, "text", size(1,-24,0,22), off(12,7), true)
    if description then textBlock(item, description, 33, (height or 91)-39) end
    register(category,title,item,terms)
    return item
end
local function movementSlider(title, key, minimum, maximum)
    local item = row("Movement",title,62,"card")
    label(item,title,13,"text",size(1,-85,0,24),off(11,3))
    local value = label(item,"",11,"accent",off(70,24),size(1,-81,0,3),true)
    value.TextXAlignment = Enum.TextXAlignment.Right
    local pick = frame(item,title .. " slider",nil,size(1,-28,0,29),off(14,29))
    pick.Active = true
    local rail = frame(pick,"Rail","control",size(1,0,0,4),off(0,12))
    corner(rail,2)
    local fill = frame(rail,"Progress","accent")
    corner(fill,2)
    local thumb = frame(pick,"Slider thumb","accent",off(14,14),off(0,14))
    thumb.AnchorPoint = Vector2.new(.5,.5); corner(thumb,7)
    local function draw(immediate)
        local current = features.movement[key]
        local ratio = (current-minimum)/(maximum-minimum)
        value.Text = tostring(current)
        F.motion(fill,"value",{Size = size(ratio,0,1,0)},.08,immediate)
        F.motion(thumb,"value",{Position = size(ratio,0,0,14)},.08,immediate)
    end
    local function update(position)
        if pick.AbsoluteSize.X <= 0 then return end
        local ratio = math.clamp((position.X-pick.AbsolutePosition.X)/pick.AbsoluteSize.X,0,1)
        features.movement[key] = math.floor((minimum+ratio*(maximum-minimum))*10+.5)/10
        draw(false)
    end
    pick.InputBegan:Connect(function(input)
        local list = pages.Movement.list
        if F.capture(input,update,function() list.ScrollingEnabled = true end) then
            list.ScrollingEnabled = false
            update(input.Position)
        end
    end)
    draw(true)
    register("Movement",title,item)
end

local iconPaths = {
    home = {{5,12,12,6},{12,6,19,12},{7,11,7,18},{7,18,17,18},{17,18,17,11}},
    move = {{6,17,18,7},{11,7,18,7},{18,7,18,14}},
    build = {{6,8,18,8},{6,16,18,16},{6,8,6,16},{18,8,18,16},{12,8,12,16},{6,12,18,12}},
    wood = {{12,4,5,15},{5,15,19,15},{19,15,12,4},{12,15,12,20}},
    player = {{9,6,15,6},{15,6,15,11},{15,11,9,11},{9,11,9,6},{5,18,9,14},{9,14,15,14},{15,14,19,18}},
    auto = {{7,14,7,7},{7,7,18,7},{15,4,18,7},{18,7,15,10},{17,10,17,17},{17,17,6,17},{9,14,6,17},{6,17,9,20}},
    visual = {{4,12,8,8},{8,8,16,8},{16,8,20,12},{20,12,16,16},{16,16,8,16},{8,16,4,12},{10,12,14,12}},
    utility = {{5,8,19,8},{5,12,19,12},{5,16,19,16},{10,6,10,10},{15,10,15,14},{8,14,8,18}},
    settings = {{7,6,17,6},{17,6,20,12},{20,12,17,18},{17,18,7,18},{7,18,4,12},{4,12,7,6},{10,12,14,12}},
}
for order, category in ipairs(categories) do
    local name, icon = category[1], category[2]
    page(name)
    local item = button(UI.nav, "", size(1,-2,0,34), nil, function() F.navigate(name) end, "side")
    item.Name, item.LayoutOrder = name, order
    local indicator = frame(item, "Selected indicator", "accent", off(2,20), off(2,7))
    corner(indicator, 1)
    local iconBox = frame(item, "Icon", nil, off(24,24), off(8,5))
    for _, edge in ipairs(iconPaths[icon]) do line(iconBox, edge[1],edge[2],edge[3],edge[4],1.35,"muted") end
    local title = label(item, name, 12, "muted", size(1,-36,1,0), off(33,0), true)
    nav[name] = {item = item, indicator = indicator, icon = iconBox, title = title}
end
local resultsPage = page("Search results")
function F.paintNav(animated)
    local narrow = S.iconOnly
    for name, node in pairs(nav) do
        local selected = name == cfg.category
        local key = selected and "accent" or "muted"
        node.title.Visible, node.indicator.Visible = not narrow, selected
        node.icon.Position = off(narrow and 7 or 8,5)
        F.motion(node.item, "nav", {BackgroundColor3 = F.color(selected and "selected" or "side")}, .14, not animated)
        F.motion(node.title, "nav", {TextColor3 = F.color(key)}, .14, not animated)
        for _, stroke in ipairs(node.icon:GetChildren()) do
            F.motion(stroke, "nav", {BackgroundColor3 = F.color(key)}, .14, not animated)
        end
    end
end

local function showPage(name)
    if S.visiblePage == name then return end
    if S.visiblePage then pages[S.visiblePage].list.Visible = false end
    S.visiblePage = name
    local list = pages[name].list
    list.Visible = true
    list.Position = off(cfg.animations and 5 or 0,0)
    F.motion(list, "page", {Position = off(0,0)}, .13)
end
function F.navigate(name, target)
    search:ReleaseFocus()
    if search.Text ~= "" then search.Text = "" end
    cfg.category = name
    if S.narrowScreen and S.mobileExpanded then S.mobileExpanded = false; F.layout() end
    showPage(name)
    F.paintNav(true)
    F.save()
    if target then
        local list = pages[name].list
        task.defer(function()
            if not S.alive or S.visiblePage ~= name or not target.Parent then return end
            local offsetY = target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
            local maxY = math.max(0,list.AbsoluteCanvasSize.Y-list.AbsoluteWindowSize.Y)
            list.CanvasPosition = Vector2.new(0,math.clamp(offsetY-4,0,maxY))
            local highlight = border(target, "accent")
            task.delay(.65, function() if S.alive then highlight:Destroy() end end)
        end)
    end
end
local searchRows = {}
function F.search()
    local query = search.Text:lower():sub(1,96):match("^%s*(.-)%s*$")
    if query == "" then showPage(cfg.category); return end
    for _, item in ipairs(searchRows) do item:Destroy() end
    searchRows = {}
    pages["Search results"].order = 0
    local matches = 0
    for _, item in ipairs(index) do
        local haystack = (item.category .. " " .. item.name .. " " .. item.terms):lower()
        local found = true
        for word in query:gmatch("%S+") do if not haystack:find(word,1,true) then found = false; break end end
        if found then
            matches = matches + 1
            local result = row("Search results", item.name, 53)
            searchRows[#searchRows+1] = result
            local jump = button(result, "", size(1,0,1,0), nil, function() F.navigate(item.category,item.target) end, "card")
            border(jump)
            label(jump, item.name, 13, "text", size(1,-24,0,21), off(12,5), true)
            label(jump, item.category, 11, "accent", size(1,-24,0,16), off(12,29))
        end
    end
    if matches == 0 then
        local empty = row("Search results", "No matches", 53, "card")
        searchRows[#searchRows+1] = empty
        textBlock(empty, "No matching features or settings.", 12, 31)
    end
    resultsPage.CanvasPosition = Vector2.new(0,0)
    showPage("Search results")
end
F.connect(search:GetPropertyChangedSignal("Text"), F.search)

-- Existing read-only game information and tree comparison.
local treeTypes = {{"Oak","Generic"},{"Cherry","Cherry"},{"Gold","GoldSwampy"},{"Cavecrawler","CaveCrawler"},
    {"Frost","Frost"},{"Lava","Volcano"},{"Elm","Oak"},{"Walnut","Walnut"},{"Birch","Birch"},
    {"Snowglow","SnowGlow"},{"Pine","GreenSwampy"},{"Koa","Koa"},{"Palm","Palm"},
    {"Spook","Spooky"},{"Sinister","SpookyNeon"},{"End Times","LoneCave"}}
features.treeIndex = 1
local function characterParts()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end
features.movement = {walk = 16, jump = 7.2, flySpeed = 50, flying = false, saved = setmetatable({}, {__mode = "k"})}
local function saveHumanoid(humanoid)
    local saved = features.movement.saved
    if not saved[humanoid] then
        saved[humanoid] = {walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight, usePower = humanoid.UseJumpPower}
    end
end
function F.stopFly()
    local movement = features.movement
    movement.flying = false
    if movement.velocity then movement.velocity:Destroy(); movement.velocity = nil end
    if movement.gyro then movement.gyro:Destroy(); movement.gyro = nil end
    if UI.flyButton then UI.flyButton.Text = "Flight: OFF" end
end
function F.toggleFly()
    local movement = features.movement
    if movement.flying then F.stopFly(); F.notify("Flight off."); return end
    local humanoid, root = characterParts()
    if not humanoid or not root then
        F.notify("Wait for your character to load.",true,{code = "M01", details = "Step: start flight\nHumanoid: " .. (humanoid and "ready" or "missing") .. " • Root: " .. (root and "ready" or "missing")})
        return
    end
    local ok, err = pcall(function()
        movement.velocity = make("BodyVelocity", {Name = "LT2FlyVelocity", MaxForce = Vector3.new(1e6,1e6,1e6), Velocity = Vector3.zero, P = 12500}, root)
        movement.gyro = make("BodyGyro", {Name = "LT2FlyGyro", MaxTorque = Vector3.new(0,1e6,0), P = 10000, CFrame = root.CFrame}, root)
    end)
    if not ok then
        F.stopFly(); warn("[Evian Hub] Flight:", err)
        F.notify("Flight could not start.",true,{code = "M02", details = "Step: create flight controls\nCause: " .. F.errorText(err)})
        return
    end
    movement.flying = true
    UI.flyButton.Text = "Flight: ON"
    F.notify("Flight on. Use the joystick and camera.")
end
local function updateMovement()
    local movement = features.movement
    local humanoid, root = characterParts()
    if humanoid then
        saveHumanoid(humanoid)
        if humanoid.WalkSpeed ~= movement.walk then humanoid.WalkSpeed = movement.walk end
        if humanoid.UseJumpPower then humanoid.UseJumpPower = false end
        if humanoid.JumpHeight ~= movement.jump then humanoid.JumpHeight = movement.jump end
    end
    if not movement.flying then return end
    if not humanoid or not root or not movement.velocity or movement.velocity.Parent ~= root
        or not movement.gyro or movement.gyro.Parent ~= root then F.stopFly(); return end
    local camera = workspace.CurrentCamera
    local direction = humanoid.MoveDirection
    if camera then
        local look = camera.CFrame.LookVector
        local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
        if right.Magnitude >= .001 then
            right = right.Unit
            local forward = Vector3.new(0,1,0):Cross(right)
            direction = look * direction:Dot(forward) + right * direction:Dot(right)
            if direction.Magnitude > 1 then direction = direction.Unit end
        end
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > .001 then movement.gyro.CFrame = CFrame.lookAt(root.Position,root.Position + flat) end
    end
    movement.velocity.Velocity = direction * movement.flySpeed
end
F.connect(player.CharacterAdded,function() F.stopFly(); features.movement.failed = false end)
function F.cleanupFeatures()
    if features.activity then features.activity.enabled, features.activity.records = false, {} end
    features.treeJob = (features.treeJob or 0)+1
    features.pendingCut = nil
    if features.restoreTree then
        local ok, err = pcall(features.restoreTree)
        if not ok then warn("[Evian Hub] Returning to start:",err) end
    end
    F.stopFly()
    for humanoid, values in pairs(features.movement.saved) do
        if humanoid.Parent then
            humanoid.WalkSpeed = values.walk
            humanoid.JumpHeight = values.jump
            humanoid.UseJumpPower = values.usePower
        end
    end
end
-- Observation only: replicated positions and physics can be delayed or incomplete.
features.activity = {enabled = false, records = {}, elapsed = 0}
function F.toggleActivity()
    local monitor = features.activity
    monitor.enabled = not monitor.enabled
    monitor.records, monitor.elapsed, monitor.lastNotice = {}, 0, nil
    UI.activityButton.Text = "Movement monitor: " .. (monitor.enabled and "ON" or "OFF")
    UI.activityReadout.Text = monitor.enabled and "Watching loaded players for unusual movement."
        or "Monitor off. Alerts are observations, not proof."
    F.notify(monitor.enabled and "Movement monitor on." or "Movement monitor off.")
    F.telemetry()
end
function F.sampleActivity()
    local monitor, now, present = features.activity, os.clock(), {}
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local function alert(target, state, reason)
        if state.lastAlert and now-state.lastAlert < 30 then return end
        state.lastAlert = now
        local name = tostring(target.Name):sub(1,24)
        UI.activityReadout.Text = name .. ": " .. reason .. ". This is not proof of cheating."
        if not monitor.lastNotice or now-monitor.lastNotice >= 5 then
            monitor.lastNotice = now
            F.notify("Unusual movement: " .. name .. ". See Player for details.")
        end
    end
    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= player then
            present[target] = true
            local character = target.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local stateOK, currentState = pcall(function() return humanoid and humanoid:GetState() end)
            local excludedState = stateOK and (currentState == Enum.HumanoidStateType.Climbing
                or currentState == Enum.HumanoidStateType.Swimming or currentState == Enum.HumanoidStateType.Seated)
            if not humanoid or humanoid.Health <= 0 or humanoid.Sit or excludedState or not root
                or not root:IsA("BasePart") or root.Anchored then
                monitor.records[target] = nil
            else
                local position, velocity = root.Position, root.AssemblyLinearVelocity
                local state = monitor.records[target]
                if not state or state.character ~= character or state.root ~= root then
                    state = {character=character,root=root,position=position,at=now,stable=0,speed=0,hover=0}
                    monitor.records[target] = state
                else
                    local delta, seconds = position-state.position, now-state.at
                    state.position, state.at = position, now
                    if seconds < .25 or seconds > 1.5 then
                        state.stable, state.speed, state.hover, state.lastJump = 0,0,0,nil
                    else
                        local horizontal = math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
                        local reportedSpeed = math.sqrt(velocity.X*velocity.X+velocity.Z*velocity.Z)
                        if horizontal/seconds > 70 and reportedSpeed > 55 then state.speed = state.speed+1
                        else state.speed = 0 end
                        if state.speed >= 4 then alert(target,state,"sustained fast movement") end
                        if delta.Magnitude >= 120 then
                            if state.stable >= 2 and state.lastJump and now-state.lastJump <= 12 then
                                alert(target,state,"repeated large position jumps")
                            end
                            state.lastJump, state.stable, state.hover = now,0,0
                        else
                            state.stable = state.stable+1
                            if math.abs(delta.Y) < 1.5 and math.abs(velocity.Y) < 3 then
                                local exclude = {character}
                                if player.Character then exclude[#exclude+1] = player.Character end
                                rayParams.FilterDescendantsInstances = exclude
                                local ground = workspace:Raycast(position,Vector3.new(0,-100,0),rayParams)
                                local surface = ground and ground.Instance
                                local stableGround = surface and (surface:IsA("Terrain")
                                    or (surface:IsA("BasePart") and surface.Anchored))
                                if stableGround and ground.Material ~= Enum.Material.Water and ground.Position
                                    and position.Y-ground.Position.Y > 18 then
                                    state.hover = state.hover+seconds
                                else state.hover = 0 end
                                if state.hover >= 8 then alert(target,state,"prolonged hovering") end
                            else state.hover = 0 end
                        end
                    end
                end
            end
        end
    end
    for target in pairs(monitor.records) do if not present[target] then monitor.records[target] = nil end end
end

local function findTree(treeClass)
    local best, bestWood, bestVolume
    for _, region in ipairs(workspace:GetChildren()) do
        if region.Name == "TreeRegion" then
            for _, candidate in ipairs(region:GetChildren()) do
                local class = candidate:FindFirstChild("TreeClass")
                local owner = candidate:FindFirstChild("Owner")
                local wood = candidate:FindFirstChild("WoodSection")
                if candidate:IsA("Model") and class and class:IsA("StringValue") and class.Value == treeClass
                    and wood and wood:IsA("BasePart") and candidate:FindFirstChild("CutEvent")
                    and (not owner or (owner:IsA("ObjectValue") and (owner.Value == nil or owner.Value == player))) then
                    local volume = 0
                    for _, part in ipairs(candidate:GetDescendants()) do
                        if part.Name == "WoodSection" and part:IsA("BasePart") then
                            local dim = part.Size
                            volume = volume + dim.X*dim.Y*dim.Z
                        end
                    end
                    if not bestVolume or volume > bestVolume then best,bestWood,bestVolume = candidate,wood,volume end
                end
            end
        end
    end
    return best,bestWood,bestVolume
end
local function coordinates(position)
    return string.format("%.0f, %.0f, %.0f",position.X,position.Y,position.Z)
end
local function remote(interaction, name)
    local object = interaction and interaction:FindFirstChild(name)
    return object and object:IsA("RemoteEvent") and object or nil
end
function F.treeDiagnostic(code, step, cause)
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local character = player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    local toolName = tool and tool:FindFirstChild("ToolName")
    local name = toolName and toolName:IsA("StringValue") and toolName.Value or (tool and tool.Name or "none")
    name = tostring(name):gsub("[^%w_%- ]", "?"):sub(1,24)
    local classes = ReplicatedStorage:FindFirstChild("AxeClasses")
    local axeClass = toolName and toolName:IsA("StringValue") and classes and classes:FindFirstChild("AxeClass_" .. toolName.Value)
    local function kind(object) return object and object.ClassName or "missing" end
    local tree = features.activeTree or treeTypes[features.treeIndex]
    local details = "Step: " .. step .. " • Tree: " .. tree[1]
        .. "\nAxe: " .. name .. " • Axe data: " .. kind(axeClass)
        .. "\nLogs: " .. kind(workspace:FindFirstChild("LogModels")) .. " • Interaction: " .. kind(interaction)
        .. "\nDrag: " .. kind(interaction and interaction:FindFirstChild("ClientIsDragging"))
        .. " • Cut: " .. kind(interaction and interaction:FindFirstChild("RemoteProxy"))
        .. " • Own: " .. kind(interaction and interaction:FindFirstChild("ClientRequestOwnership"))
    if cause then details = details .. "\nCause: " .. F.errorText(cause) end
    return {code = code, details = details}
end
function F.detect()
    if game.PlaceId == 13822889 then S.gameStatus = "Lumber Tycoon 2"
    else S.gameStatus = "Outside LT2" end
    local available = false
    if game.PlaceId == 13822889 then
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "TreeRegion" then available = true; break end
        end
    end
    features.trees = available
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    features.treeTransfer = game.PlaceId == 13822889 and remote(interaction,"ClientIsDragging") ~= nil
        and features.logFolder ~= nil
    features.treeCutting = features.treeTransfer and remote(interaction,"RemoteProxy") ~= nil
        and ReplicatedStorage:FindFirstChild("AxeClasses") ~= nil
    if UI.treeAvailability then
        UI.treeAvailability.Text = not available and "No LT2 tree regions loaded"
            or (features.treeCutting and "Loaded trees • Tree actions detected" or "Loaded trees • Some tree actions unavailable")
        UI.scan.Text = available and "Scan loaded trees" or "Scan unavailable"
    end
    if UI.overview then
        UI.overview.Text = available and "Tree comparison available • No automation running"
            or "Tree comparison awaiting LT2 regions • No automation running"
    end
end
function F.watchLogs()
    local folder = game.PlaceId == 13822889 and workspace:FindFirstChild("LogModels") or nil
    if folder == features.logFolder then return end
    if S.logConnection then S.logConnection:Disconnect(); S.logConnection = nil end
    features.logFolder, features.recentLog, features.pendingLogs = folder, nil, {}
    if not folder then F.detect(); return end
    S.logConnection = folder.ChildAdded:Connect(function(log)
        local _, root = characterParts()
        if not log:IsA("Model") or not root or not root:IsA("BasePart") then return end
        local queue = features.pendingLogs
        features.logSerial = (features.logSerial or 0)+1
        if #queue == 12 then table.remove(queue,1) end
        local cut = features.pendingCut
        queue[#queue+1] = {model = log, origin = root.Position, at = os.clock(), serial = features.logSerial,
            cut = cut and cut.started and cut or nil}
    end)
    F.detect()
end
local function checkLogs()
    local queue = features.pendingLogs
    for i = #queue,1,-1 do
        local entry = queue[i]
        local log = entry.model
        if log.Parent ~= features.logFolder or os.clock()-entry.at > 6 then
            table.remove(queue,i)
        else
            local owner = log:FindFirstChild("Owner")
            local species = log:FindFirstChild("TreeClass")
            local wood = log:FindFirstChild("WoodSection")
            if owner and owner:IsA("ObjectValue") and owner.Value and species and species:IsA("StringValue")
                and species.Value ~= "" and wood and wood:IsA("BasePart") then
                if owner.Value == player and (wood.Position-entry.origin).Magnitude <= 120
                    and (not features.recentLog or entry.serial > features.recentLog.serial) then
                    features.recentLog = {model = log, serial = entry.serial, species = species.Value, part = wood, owner = owner}
                end
                local cut = entry.cut
                if cut and features.pendingCut == cut and not cut.log and owner.Value == player
                    and species.Value == cut.species and (wood.Position-cut.position).Magnitude <= 120 then
                    cut.log = {model = log, part = wood, owner = owner}
                end
                table.remove(queue,i)
            end
        end
    end
end
F.detect()

heading("Home", "Overview")
local welcome = card("Home","Welcome, " .. player.Name,
    "Compare loaded trees, view live player information, and make Evian Hub your own.",86)
welcome.Name = "Welcome"
local quick = row("Home","Quick access",39)
button(quick,"Wood & Trees",size(.54,-4,1,0),nil,function() F.navigate("Wood & Trees") end,"selected")
button(quick,"Settings",size(.46,-4,1,0),size(.54,4,0,0),function() F.navigate("Customisation") end)
UI.overview = textBlock(card("Home","Feature overview",nil,84),"",33,43)

heading("Movement","Movement")
UI.motionReadout = textBlock(card("Movement","Current movement",nil,85,"walk speed jump health"),
    "Waiting for character…",33,44)
local flightRow = row("Movement","Flight",42)
UI.flyButton = button(flightRow,"Flight: OFF",size(1,0,1,0),nil,function() F.toggleFly() end,"selected")
register("Movement","Flight",flightRow,"fly movement")
movementSlider("Walk speed", "walk", 16, 100)
movementSlider("Fly speed", "flySpeed", 10, 150)
movementSlider("Jump height", "jump", 7.2, 60)
heading("Player","Player")
UI.playerReadout = textBlock(card("Player","Character status",nil,97,"health position coordinates"),
    "Waiting for character…",33,56)
local activityCard = card("Player","Suspicious movement",nil,132,"cheater hacker exploit speed teleport flight monitor")
textBlock(activityCard,"Watches loaded players. Unusual movement is not proof of cheating.",33,46)
UI.activityButton = button(activityCard,"Movement monitor: OFF",size(1,-24,0,35),off(12,87),function() F.toggleActivity() end,"selected")
UI.activityReadout = textBlock(card("Player","Latest activity",nil,91,"suspicious activity alerts"),
    "Monitor off. Alerts are observations, not proof.",33,50)
for _, name in ipairs({"Building","Automation","Visuals"}) do
    heading(name,name)
    card(name,"No features configured","Features for this category will appear when they are specified.",82)
end
heading("Utilities","Utilities")
local errorRow = row("Utilities","Latest error",42)
button(errorRow,"Show latest error",size(1,0,1,0),nil,function()
    if not S.lastError then F.notify("No error has been recorded."); return end
    S.lastMessage = nil
    F.notify(S.lastError.message,true,S.lastError.diagnostic)
end)
register("Utilities","Latest error",errorRow,"diagnostics screenshot error")

heading("Wood & Trees","Wood & Trees")
local treeCard = card("Wood & Trees","Largest loaded tree",nil,174,"scan size species wood volume")
UI.treeAvailability = label(treeCard,"",11,"accent",size(1,-24,0,17),off(12,32))
local previousTree = button(treeCard,"‹",off(38,35),off(12,56),function() F.changeTree(-1) end)
previousTree.Name = "Previous tree type"
UI.treeName = label(treeCard,"Oak",13,"text",size(1,-110,0,35),off(55,56),true)
UI.treeName.TextXAlignment = Enum.TextXAlignment.Center
button(treeCard,"›",off(38,35),size(1,-50,0,56),function() F.changeTree(1) end).Name = "Next tree type"
UI.scan = button(treeCard,"Scan loaded trees",size(1,-24,0,35),off(12,99),function() F.scan() end,"selected")
UI.treeResult = label(treeCard,"Results only include trees loaded on this device.",11,"muted",size(1,-24,0,32),off(12,134))
UI.treeResult.TextWrapped = true
local bringRow = row("Wood & Trees","Bring largest tree",42)
button(bringRow,"Bring largest tree",size(1,0,1,0),nil,function() F.startTree(true) end,"selected")
register("Wood & Trees","Bring largest tree",bringRow,"chop cut bring tree axe")
UI.logReadout = textBlock(card("Wood & Trees","Recent owned log",nil,84,"recent log location coordinates"),
    "Waiting for a nearby owned log to appear…",33,43)
local recentRow = row("Wood & Trees","Bring recent log",42)
button(recentRow,"Bring recent log",size(1,0,1,0),nil,function() F.startTree(false) end)
register("Wood & Trees","Bring recent log",recentRow,"bring tree recent log ownership")
function F.changeTree(delta)
    features.treeIndex = (features.treeIndex - 1 + delta) % #treeTypes + 1
    UI.treeName.Text = treeTypes[features.treeIndex][1]
    features.selected = nil
    UI.treeResult.Text = "Scan again for this tree type."
    F.telemetry()
end
function F.scan()
    if os.clock()-(features.lastScan or -1) < .35 then return end
    features.lastScan = os.clock()
    if not features.trees then
        F.notify("No LT2 tree regions are loaded on this device.",true,F.treeDiagnostic("T20","Scanning")); return
    end
    local selected = treeTypes[features.treeIndex]
    local model, wood, volume = findTree(selected[2])
    features.selected = model and {model = model, name = selected[1]} or nil
    if model then
        UI.treeResult.Text = string.format("%.0f studs³ estimated • %s", volume, coordinates(wood.Position))
        F.notify("Largest loaded " .. selected[1] .. " located.")
    else
        UI.treeResult.Text = "No eligible " .. selected[1] .. " trees loaded."
        F.notify(UI.treeResult.Text, true,F.treeDiagnostic("T21","Scanning"))
    end
    F.telemetry()
end
-- Read the equipped axe's own LT2 settings instead of inventing damage values.
local function axeStats(axe, species)
    local name = axe and axe:FindFirstChild("ToolName")
    local classes = ReplicatedStorage:FindFirstChild("AxeClasses")
    local module = name and name:IsA("StringValue") and classes and classes:FindFirstChild("AxeClass_" .. name.Value)
    if not name or not name:IsA("StringValue") then return nil,nil,nil,"ToolName missing or invalid" end
    if not classes then return nil,nil,nil,"AxeClasses missing" end
    if not module or not module:IsA("ModuleScript") then return nil,nil,nil,"Axe module missing or invalid" end
    local ok, stats = pcall(function()
        local definition = require(module)
        return definition.new()
    end)
    if not ok then return nil,nil,nil,"Axe module error: " .. F.errorText(stats) end
    if type(stats) ~= "table" then return nil,nil,nil,"Axe module returned invalid settings" end
    local special = type(stats.SpecialTrees) == "table" and stats.SpecialTrees[species]
    local damage = type(special) == "table" and special.Damage or stats.Damage
    local cooldown = type(special) == "table" and special.SwingCooldown or stats.SwingCooldown
    if type(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge
        or type(cooldown) ~= "number" or cooldown ~= cooldown or cooldown <= 0 or cooldown == math.huge then
        return nil,nil,nil,"Damage or swing cooldown invalid"
    end
    return damage, cooldown, math.max(.12,cooldown)
end
function F.startTree(automatic)
    local function report(code, message, step, cause)
        F.notify(message,true,F.treeDiagnostic(code,step,cause))
    end
    if features.treeBusy then report("T01","A tree request is already running.","Checking"); return end
    if game.PlaceId ~= 13822889 then report("T02","Tree actions are available in Lumber Tycoon 2.","Checking"); return end
    local character = player.Character
    local humanoid, root = characterParts()
    if not character or not humanoid or not root then report("T03","Wait for your character to load.","Character"); return end
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local ownership = remote(interaction,"ClientRequestOwnership")
    local drag = remote(interaction,"ClientIsDragging")
    local proxy = remote(interaction,"RemoteProxy")
    -- Refresh the log folder in case it replicated after the hub was opened.
    if not features.logFolder then F.watchLogs() end
    if not features.logFolder then report("T04","Tree action unavailable: LogModels is missing.","Checking"); return end
    if not interaction then report("T05","Tree action unavailable: Interaction is missing.","Checking"); return end
    if not drag then report("T06","Tree action unavailable: ClientIsDragging is missing or unsupported.","Checking"); return end
    if automatic and not proxy then report("T07","Tree action unavailable: RemoteProxy is missing or unsupported.","Checking"); return end
    features.treeBusy = true
    features.activeTree = treeTypes[features.treeIndex]
    features.treeJob = (features.treeJob or 0)+1
    local job = features.treeJob
    local original = root.CFrame
    local destination = original.Position + Vector3.new(0,3,0)
    local function restorePosition()
        if features.restoreTree ~= restorePosition then return end
        features.restoreTree = nil
        if root.Parent and player.Character == character then root.CFrame = original end
    end
    features.restoreTree = restorePosition
    local function active()
        return S.alive and features.treeJob == job and character == player.Character and root.Parent and humanoid.Health > 0
    end
    task.spawn(function()
        local step, failureCode, failureCause = "Checking", "T99", nil
        local function failure(code, message, cause)
            failureCode, failureCause = code, cause
            return message
        end
        local ok, message = xpcall(function()
            local log = features.recentLog
            if automatic then
                step = "Finding tree"
                local choice = features.activeTree
                local tree, wood = findTree(choice[2])
                if not tree then return failure("T08","No eligible " .. choice[1] .. " tree is loaded.") end
                step = "Checking axe"
                local axe = character:FindFirstChildOfClass("Tool")
                if not axe then return failure("T09","Equip an axe before bringing a tree.") end
                local damage, cooldown, interval, reason = axeStats(axe,choice[2])
                if not damage then return failure("T10","The equipped axe's LT2 settings are unavailable.",reason) end
                if not tree.Parent or not wood.Parent then return failure("T11","The selected tree is no longer available.") end
                F.stopFly()
                local cut = {species = choice[2], position = wood.Position}
                features.pendingCut = cut
                step = "Going to tree"
                root.CFrame = wood.CFrame + Vector3.new(4,2,2)
                F.notify("Cutting the largest loaded " .. choice[1] .. ".")
                task.wait(.3)
                local deadline = os.clock()+20
                local nextSwing = 0
                step = "Cutting"
                while active() and features.pendingCut == cut and not cut.log and os.clock() < deadline do
                    if axe.Parent ~= character then return failure("T12","The equipped axe became unavailable.") end
                    local owner = tree:FindFirstChild("Owner")
                    if owner and (not owner:IsA("ObjectValue") or (owner.Value and owner.Value ~= player)) then
                        return failure("T13","The selected tree is no longer available.","Tree ownership changed")
                    end
                    local event = tree.Parent and tree:FindFirstChild("CutEvent")
                    if event and os.clock() >= nextSwing then
                        cut.started = true
                        proxy:FireServer(event,{tool = axe, faceVector = Vector3.new(0,0,-1), height = .3,
                            sectionId = 1, hitPoints = damage, cooldown = cooldown, cuttingClass = "Axe"})
                        nextSwing = os.clock()+interval
                    end
                    task.wait(math.min(.1, math.max(.01, deadline-os.clock())))
                end
                log = cut.log
                if features.pendingCut == cut then features.pendingCut = nil end
                if not active() then return end
                if not log then return failure("T14","No matching log appeared; the cut may have been rejected.","Timed out after 20 seconds") end
            end
            step = "Checking log"
            if not log or log.model.Parent ~= features.logFolder or log.part.Parent ~= log.model
                or log.owner.Parent ~= log.model or log.owner.Value ~= player then
                return failure("T15",automatic and "The cut log is unavailable." or "Chop a nearby tree while the hub is open first.")
            end
            local function available()
                return active() and log.model.Parent == features.logFolder and log.part.Parent == log.model
                    and log.owner.Parent == log.model and log.owner.Value == player
            end
            F.stopFly()
            step = "Moving log"
            root.CFrame = log.part.CFrame + Vector3.new(4,2,2)
            if not available() then return failure("T16","The log became unavailable before moving.") end
            if ownership then
                ownership:FireServer(log.model)
                ownership:FireServer(log.part)
            end
            task.wait(.5)
            local moved = false
            for _ = 1,8 do
                if not available() then return failure("T17","The log or character became unavailable during the move.") end
                drag:FireServer(log.model)
                log.model:PivotTo(log.model:GetPivot() + (destination-log.part.Position))
                moved = true
                root.CFrame = original
                task.wait(.25)
            end
            if moved then return "Tree move requested. Check whether the server accepted it.", true end
        end, debug.traceback)
        features.pendingCut = nil
        local restored, restoreError = pcall(restorePosition)
        features.treeBusy = false
        if not S.alive then return end
        if not restored then
            warn("[Evian Hub] Returning to start:",restoreError)
            report("T18","Could not return to the starting spot.","Returning",restoreError)
        elseif not ok then
            warn("[Evian Hub] Tree action:",message)
            report("T99","The tree request failed.",step,message)
        elseif message then
            if message:find("move requested",1,true) then F.notify(message)
            else report(failureCode,message,step,failureCause) end
        end
        features.activeTree = nil
    end)
end
for _, signal in ipairs({workspace.ChildAdded,workspace.ChildRemoved}) do
    F.connect(signal,function(child)
        if child.Name == "TreeRegion" then F.detect()
        elseif child.Name == "LogModels" then F.watchLogs() end
    end)
end
local relevantInteraction = {Interaction = true, AxeClasses = true, ClientRequestOwnership = true,
    ClientIsDragging = true, RemoteProxy = true}
for _, signal in ipairs({ReplicatedStorage.DescendantAdded,ReplicatedStorage.DescendantRemoving}) do
    F.connect(signal,function(child)
        if relevantInteraction[child.Name] then task.defer(function() if S.alive then F.detect() end end) end
    end)
end
F.detect()
F.watchLogs()

-- Tree splitting and sawmill processing use LT2's replicated wood metadata.
-- The client only reports observed changes; server acceptance remains authoritative.
do
    local operation
    local panel = frame(UI.root,"Wood action prompt","card",size(1,-24,0,135),off(12,10))
    panel.Visible, panel.Active, panel.ZIndex = false, true, 10
    corner(panel,9); border(panel,"accent")
    make("UISizeConstraint",{MaxSize = Vector2.new(340,135)},panel)
    local title = label(panel,"",14,"accent",size(1,-24,0,21),off(12,8),true)
    local prompt = label(panel,"",12,"text",size(1,-24,0,50),off(12,32))
    prompt.TextWrapped, prompt.TextTruncate, prompt.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
    local confirm = button(panel,"Confirm",off(100,34),off(12,91),function()
        if operation and operation.stage == "confirm" then operation.confirmed = true end
    end,"selected")
    confirm.Name = "Confirm wood selection"
    local cancel = button(panel,"Cancel",off(90,34),off(120,91),function()
        if operation then operation.cancelled = true end
    end)
    cancel.Name = "Cancel wood action"
    local mills = {Sawmill=true,Sawmill2=true,Sawmill3=true,Sawmill4=true,Sawmill4L=true}

    local function setStage(op, stage, message)
        op.stage, op.acceptAt = stage, os.clock()+.3
        prompt.Text = message
        confirm.Visible = stage == "confirm"
    end
    local function clearHighlight(op)
        if op.highlight then op.highlight:Destroy(); op.highlight = nil end
    end
    local function woodSections(model)
        local sections, ids = {}, {}
        for _, part in ipairs(model:GetChildren()) do
            if part.Name == "WoodSection" and part:IsA("BasePart") then
                local id = part:FindFirstChild("ID")
                if not id or (not id:IsA("IntValue") and not id:IsA("NumberValue"))
                    or type(id.Value) ~= "number" or id.Value ~= id.Value or ids[id.Value] then return nil end
                ids[id.Value] = true
                sections[#sections+1] = {part=part,id=id.Value}
            end
        end
        table.sort(sections,function(a,b) return a.id < b.id end)
        return sections
    end
    local function treeModel(hit)
        local node, logs = hit, workspace:FindFirstChild("LogModels")
        while node and node ~= workspace do
            local parent = node.Parent
            local standing = parent and parent.Name == "TreeRegion" and parent.Parent == workspace
            if node:IsA("Model") and (standing or parent == logs) then
                local species, event = node:FindFirstChild("TreeClass"), node:FindFirstChild("CutEvent")
                local wood = node:FindFirstChild("WoodSection")
                if species and species:IsA("StringValue") and species.Value ~= "" and event and wood and wood:IsA("BasePart") then
                    return node, standing, species.Value
                end
                return
            end
            node = parent
        end
    end
    local function sawmillModel(hit)
        local node, models = hit, workspace:FindFirstChild("PlayerModels")
        while node and node ~= workspace do
            if node.Parent == models and node:IsA("Model") then
                local item, kind = node:FindFirstChild("ItemName"), node:FindFirstChild("Type")
                if not item or not item:IsA("StringValue") or not mills[item.Value]
                    or not kind or not kind:IsA("StringValue") or kind.Value ~= "Structure" then return end
                local inlet = node:FindFirstChild("Particles")
                if not inlet or not inlet:IsA("BasePart") then
                    local conveyor = node:FindFirstChild("Conveyor")
                    inlet = conveyor and conveyor:FindFirstChild("Conveyor")
                end
                if inlet and inlet:IsA("BasePart") then return node, inlet, item.Value end
                return
            end
            node = node.Parent
        end
    end
    local function finish(op, message, code, detail)
        if operation ~= op then return end
        clearHighlight(op)
        if op.logConnection then op.logConnection:Disconnect(); op.logConnection = nil end
        if op.outputConnection then op.outputConnection:Disconnect(); op.outputConnection = nil end
        if op.moved and op.original and op.root and op.root.Parent and player.Character == op.character then
            local ok, err = pcall(function() op.root.CFrame = op.original end)
            if not ok then warn("[Evian Hub] Wood action return:",err) end
        end
        operation = nil
        features.treeBusy = false
        panel.Visible = false
        if not S.alive then return end
        F.show(true)
        if message then
            local context = "Step: " .. op.step .. "\nTree: " .. (op.species or "not selected")
                .. " • Mill: " .. (op.millName or "not selected")
                .. "\n" .. (op.input and ("Input: " .. op.input) or ("Axe: " .. (op.axeName or "unknown")))
                .. "\nCause: " .. F.errorText(detail or "Check LT2 objects and try again.")
            F.notify(message,code ~= nil,code and {code=code,details=context} or nil)
        end
    end
    local function active(op)
        return S.alive and operation == op and not op.cancelled and player.Character == op.character
            and op.root.Parent and op.humanoid.Health > 0
    end
    local function waitSelection(op, stage, message)
        op.selected, op.confirmed = nil, false
        setStage(op,stage,message)
        local deadline = os.clock()+60
        while active(op) and os.clock() < deadline and not op.confirmed do task.wait(.1) end
        clearHighlight(op)
        if not active(op) then return nil,"cancelled" end
        if not op.confirmed then return nil,"Selection timed out." end
        return op.selected
    end
    local function choose(position, processed)
        local op = operation
        if processed or not op or S.open or Input:GetFocusedTextBox() or S.pointer
            or os.clock() < (op.acceptAt or 0) or (op.stage ~= "tree" and op.stage ~= "mill") then return end
        local camera = workspace.CurrentCamera
        if not camera then prompt.Text = "Camera unavailable. Wait for it to load or cancel."; return end
        local ray = camera:ViewportPointToRay(position.X,position.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = op.character and {op.character} or {}
        local result = workspace:Raycast(ray.Origin,ray.Direction*500,params)
        local hit = result and result.Instance
        local model, extra, name
        if op.stage == "tree" then
            model, extra, name = treeModel(hit)
        else
            model, extra, name = sawmillModel(hit)
        end
        if not model then
            prompt.Text = op.stage == "tree" and "Tap a standing tree or a cut tree with wood sections."
                or "Tap a placed sawmill with a recognised input."
            return
        end
        op.selected = {model=model,extra=extra,name=name}
        clearHighlight(op)
        op.highlight = make("Highlight",{Adornee=model,FillTransparency=.8,OutlineColor=F.color("accent")},model)
        setStage(op,"confirm","Selected " .. name .. ". Check the highlight, then tap Confirm or Cancel.")
    end
    local function safeChoose(position, processed)
        local ok, err = pcall(choose,position,processed)
        if not ok and operation then
            warn("[Evian Hub] Wood selection:",err)
            local op = operation
            finish(op,"Could not select that object.","W03","Cause: " .. F.errorText(err))
        end
    end
    F.connect(Input.TouchTapInWorld,safeChoose)
    F.connect(Input.InputBegan,function(input,processed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then safeChoose(input.Position,processed) end
    end)
    F.connect(player.CharacterAdded,function() if operation then operation.cancelled = true end end)
    local oldCleanup = F.cleanupFeatures
    function F.cleanupFeatures()
        if operation then operation.cancelled = true; finish(operation) end
        oldCleanup()
    end

    -- A new log must be near the targeted section and retain its section ID.
    -- This avoids taking an unrelated log produced by another cut nearby.
    local function cut(op, model, section, height)
        local event = model.Parent and model:FindFirstChild("CutEvent")
        if not event or section.part.Parent ~= model then return nil,"The selected section is no longer available." end
        local species = model:FindFirstChild("TreeClass")
        local axe = op.character:FindFirstChildOfClass("Tool")
        if not species or not species:IsA("StringValue") or not axe then return nil,"Equip an axe before cutting." end
        local damage, cooldown, interval, reason = axeStats(axe,species.Value)
        if not damage then return nil,"Axe data unavailable: " .. tostring(reason) end
        local position, candidates, seenAt, started = section.part.Position, {}, nil, false
        local connection = op.logs.ChildAdded:Connect(function(log)
            if started then candidates[#candidates+1] = log end
        end)
        op.logConnection = connection
        op.moved = true
        op.root.CFrame = section.part.CFrame + Vector3.new(4,2,2)
        task.wait(.3)
        local deadline, nextSwing = os.clock()+20, 0
        local found, ambiguous
        while active(op) and os.clock() < deadline do
            local match, matches = nil, 0
            for _, candidate in ipairs(candidates) do
                if candidate:IsA("Model") and candidate.Parent == op.logs then
                    local owner, class = candidate:FindFirstChild("Owner"), candidate:FindFirstChild("TreeClass")
                    local sections = woodSections(candidate)
                    if owner and owner:IsA("ObjectValue") and owner.Value == player and class
                        and class:IsA("StringValue") and class.Value == species.Value and sections then
                        for _, piece in ipairs(sections) do
                            if piece.id == section.id and (piece.part.Position-position).Magnitude <= 30 then
                                match, matches = candidate, matches+1; break
                            end
                        end
                    end
                end
            end
            if matches > 1 then ambiguous = true; break end
            if matches == 1 then
                if match ~= found then found, seenAt = match, os.clock() end
                if os.clock()-seenAt >= .5 then break end
            else found, seenAt = nil, nil end
            if axe.Parent ~= op.character then break end
            if not found and model.Parent and section.part.Parent == model and event.Parent and os.clock() >= nextSwing then
                started = true
                op.proxy:FireServer(event,{tool=axe,faceVector=Vector3.new(1,0,0),height=height,
                    sectionId=section.id,hitPoints=damage,cooldown=cooldown,cuttingClass="Axe"})
                nextSwing = os.clock()+interval
            end
            task.wait(.1)
        end
        connection:Disconnect(); op.logConnection = nil
        if not active(op) then return nil,"cancelled" end
        if ambiguous then return nil,"Several nearby logs matched the cut; selection is ambiguous." end
        if not found or not seenAt or os.clock()-seenAt < .5 then return nil,"No matching new log appeared within 20 seconds." end
        return found
    end
    local function dismember(op, selection)
        local initial = selection.model
        local sections = initial.Parent and woodSections(initial)
        if not sections or #sections == 0 then return nil,"Wood sections or their IDs are missing." end
        if selection.extra then
            op.step = "Cutting standing tree"
            local felled, reason = cut(op,initial,sections[1],.3)
            if not felled then return nil,reason end
            initial = felled
        end
        local queue, output, seen = {initial}, {}, {}
        while #queue > 0 do
            if not active(op) then return nil,"cancelled" end
            local model = table.remove(queue,1)
            if not model.Parent then return nil,"A selected log disappeared during splitting." end
            if seen[model] then return nil,"The server returned the same log twice." end
            seen[model] = true
            local pieces = woodSections(model)
            if not pieces or #pieces == 0 then return nil,"A log has no readable wood section IDs." end
            if #pieces == 1 then
                output[#output+1] = model
            else
                -- Cutting the base of a non-root section separates its branch.
                local target = pieces[2]
                op.step = "Separating section " .. tostring(target.id)
                prompt.Text = op.step .. "…"
                local branch, reason = cut(op,model,target,0)
                if not branch then return nil,reason end
                task.wait(.5)
                if not active(op) then return nil,"cancelled" end
                local remainder = model.Parent and woodSections(model)
                if not remainder or #remainder >= #pieces then
                    return nil,"A new log appeared, but the selected tree did not update."
                end
                for _, remaining in ipairs(remainder) do
                    if remaining.id == target.id then return nil,"The targeted section is still attached to the original tree." end
                end
                op.splits = (op.splits or 0)+1
                seen[model] = nil
                queue[#queue+1], queue[#queue+2] = model, branch
                if #queue + #output > 200 then return nil,"Tree has too many sections to process safely." end
            end
        end
        return output
    end
    local function feed(op, logs, mill)
        local model, inlet = mill.model, mill.extra
        local drag = remote(ReplicatedStorage:FindFirstChild("Interaction"),"ClientIsDragging")
        local ownership = remote(ReplicatedStorage:FindFirstChild("Interaction"),"ClientRequestOwnership")
        local models = workspace:FindFirstChild("PlayerModels")
        if not drag or not models then return nil,"Drag remote or PlayerModels is unavailable." end
        for i, log in ipairs(logs) do
            if not active(op) then return nil,"cancelled" end
            if not model.Parent or not inlet.Parent or not log.Parent then return nil,"The sawmill or a log disappeared." end
            local section = log:FindFirstChild("WoodSection")
            if not section or not section:IsA("BasePart") then return nil,"A log no longer has a wood section." end
            local candidates, started = {}, false
            op.outputConnection = models.ChildAdded:Connect(function(candidate)
                if started then candidates[#candidates+1] = candidate end
            end)
            local function outputSeen()
                for _, output in ipairs(candidates) do
                    local owner, wood = output:FindFirstChild("Owner"), output:FindFirstChild("WoodSection")
                    if output.Parent == models and output:FindFirstChild("RecentlyCut") and owner
                        and owner:IsA("ObjectValue") and owner.Value == player and wood and wood:IsA("BasePart")
                        and (wood.Position-inlet.Position).Magnitude <= 30 then return true end
                end
                return false
            end
            op.step = "Feeding log " .. i .. "/" .. #logs
            prompt.Text = op.step .. "…"
            op.moved = true
            op.root.CFrame = section.CFrame + Vector3.new(4,2,2)
            if ownership then ownership:FireServer(log); ownership:FireServer(section) end
            task.wait(.5)
            local observed = false
            local originalLength = section.Size.Y
            local waitSeconds = math.clamp(15 + originalLength * .5,20,45)
            local function changedLog()
                return section.Parent ~= log or section.Size.Y < originalLength-.05
            end
            local function turnedFrame(target, primary)
                local holder = model:FindFirstChild("Conveyor")
                local belt = holder and holder:FindFirstChild("Conveyor")
                local direction = inlet.CFrame.LookVector
                if belt and belt:IsA("BasePart") then
                    direction = belt.Size.X >= belt.Size.Z and belt.CFrame.RightVector or belt.CFrame.LookVector
                end
                local flat = Vector3.new(direction.X,0,direction.Z)
                if flat.Magnitude < .001 then
                    local right = inlet.CFrame.RightVector
                    flat = Vector3.new(right.X,0,right.Z)
                end
                if flat.Magnitude < .001 then flat = Vector3.new(0,0,-1) end
                flat = flat.Unit
                -- If the original orientation already uses that direction,
                -- try the other horizontal direction on the retry.
                if math.abs(primary.UpVector:Dot(flat)) > .98 then
                    flat = Vector3.new(-flat.Z,0,flat.X)
                end
                local vertical = Vector3.new(0,1,0)
                return CFrame.fromMatrix(target,vertical,flat,vertical:Cross(flat))
            end
            for attempt = 1,2 do
                if attempt == 2 then prompt.Text = "Turning log " .. i .. "/" .. #logs .. "…" end
                for _ = 1,attempt == 1 and 8 or 4 do
                    if not active(op) or not model.Parent or not inlet.Parent then break end
                    if outputSeen() then observed = true; break end
                    if not log.Parent or changedLog() then break end
                    started = true
                    drag:FireServer(log)
                    local target = inlet.Name == "Particles" and inlet.Position or inlet.Position + Vector3.new(0,1,0)
                    local targetFrame = inlet.CFrame
                    if inlet.Name ~= "Particles" then
                        targetFrame = targetFrame * (inlet.Size.X >= inlet.Size.Z
                            and CFrame.Angles(0,0,-math.pi/2) or CFrame.Angles(math.pi/2,0,0))
                    end
                    targetFrame = targetFrame + (target-inlet.Position)
                    local upright = math.abs(targetFrame.UpVector.Y) > .7
                    if upright then targetFrame = turnedFrame(target,targetFrame) end
                    if attempt == 2 then targetFrame = turnedFrame(target,targetFrame) end
                    op.input = inlet.Name .. " • " .. coordinates(target)
                        .. (attempt == 2 and " • turned" or (upright and " • horizontal" or ""))
                    log:PivotTo(targetFrame * section.CFrame:Inverse() * log:GetPivot())
                    op.root.CFrame = inlet.CFrame + Vector3.new(4,2,2)
                    task.wait(.25)
                end
                if observed or not active(op) or not model.Parent or not inlet.Parent
                    or not log.Parent or changedLog() or attempt == 2 then break end
                -- Give the mill time to start before trying a different angle.
                local retryAt = os.clock()+5
                while active(op) and model.Parent and inlet.Parent and log.Parent and not changedLog()
                    and os.clock() < retryAt do
                    if outputSeen() then observed = true; break end
                    task.wait(.1)
                end
                if observed or not active(op) or not model.Parent or not inlet.Parent
                    or not log.Parent or changedLog() then break end
            end
            local deadline = os.clock()+waitSeconds
            while active(op) and os.clock() < deadline do
                if not observed and outputSeen() then observed = true end
                if observed and not log.Parent then break end
                if not model.Parent or not inlet.Parent then break end
                task.wait(.1)
            end
            op.outputConnection:Disconnect(); op.outputConnection = nil
            if not active(op) then return nil,"cancelled" end
            if not model.Parent or not inlet.Parent then return nil,"The selected sawmill disappeared." end
            if not observed or log.Parent then
                local status = observed and "output seen but log still present"
                    or (log.Parent and "no output seen and log still present" or "log disappeared and no output seen")
                return nil,"Log " .. i .. " of " .. #logs .. ": " .. status .. "."
            end
        end
        return true
    end
    local function begin(mode)
        local function report(message,detail)
            F.notify(message,true,{code="W01",details="Step: starting wood action\n" .. detail})
        end
        if game.PlaceId ~= 13822889 then report("Open Lumber Tycoon 2 first.","Place: outside LT2"); return end
        if features.treeBusy or operation then report("A tree action is already running.","Wait for it to finish or cancel it."); return end
        local humanoid, root = characterParts()
        local interaction, logs = ReplicatedStorage:FindFirstChild("Interaction"), workspace:FindFirstChild("LogModels")
        local proxy = remote(interaction,"RemoteProxy")
        if not humanoid or not root then report("Wait for your character to load.","Humanoid or root missing"); return end
        if not logs or not proxy then report("Tree actions are unavailable.","LogModels or RemoteProxy missing"); return end
        if not player.Character:FindFirstChildOfClass("Tool") then report("Equip an axe first.","No tool equipped"); return end
        local equipped = player.Character:FindFirstChildOfClass("Tool")
        local axeName = equipped:FindFirstChild("ToolName")
        local op = {mode=mode,character=player.Character,humanoid=humanoid,root=root,original=root.CFrame,
            logs=logs,proxy=proxy,step="Selecting tree",axeName=axeName and axeName:IsA("StringValue") and axeName.Value or equipped.Name}
        operation, features.treeBusy = op, true
        title.Text = mode == "mill" and "Auto Sawmill" or "Dismember Tree"
        panel.Visible = true
        F.stopFly(); F.show(false)
        task.spawn(function()
            local ok, result, detail = xpcall(function()
                local selected, reason = waitSelection(op,"tree","Tap a tree or cut tree in the game, then confirm it.")
                if not selected then return nil,reason end
                if not selected.model.Parent then return nil,"The selected tree disappeared." end
                op.species = selected.name
                setStage(op,"working","Separating the selected tree…")
                local pieces; pieces, reason = dismember(op,selected)
                if not pieces then return nil,reason end
                if mode ~= "mill" then
                    if not op.splits then return "Selected tree already has one wood section." end
                    return "Separated " .. #pieces .. " log(s)."
                end
                op.step = "Selecting sawmill"
                local sawmill; sawmill, reason = waitSelection(op,"mill","Tap a placed sawmill in the game, then confirm it.")
                if not sawmill then return nil,reason end
                op.millName = sawmill.name
                setStage(op,"working","Feeding logs into the sawmill…")
                local done; done, reason = feed(op,pieces,sawmill)
                if not done then return nil,reason end
                return "Saw nearby output while feeding " .. #pieces .. " log(s). Check the results."
            end,debug.traceback)
            if not ok then
                warn("[Evian Hub] Wood action:",result)
                finish(op,"Wood action failed.","W99","Cause: " .. F.errorText(result))
            elseif not active(op) or detail == "cancelled" then finish(op,"Wood action cancelled.")
            elseif not result then finish(op,"Wood action could not finish.","W02",detail)
            else finish(op,result) end
        end)
    end
    local wood = "Wood & Trees"
    local split = card(wood,"Dismember Tree","Select a tree to separate its wood sections.",114,"split joints logs")
    button(split,"Select tree to dismember",size(1,-24,0,35),off(12,68),function() begin("split") end,"selected")
    local saw = card(wood,"Auto Sawmill","Select a tree, then select a sawmill to process its logs.",114,"sawmill split logs")
    button(saw,"Start Auto Sawmill",size(1,-24,0,35),off(12,68),function() begin("mill") end,"selected")
end

-- Customisation: preferences are data, controls only update their own setting.
local settings = "Customisation"
local renderSettings = {}
function F.refreshSettings()
    for _, update in ipairs(renderSettings) do update() end
end
local function switch(title, key, changed)
    local item = row(settings,title,43,"card")
    label(item,title,13,"text",size(1,-87,1,0),off(11,0))
    local toggle = button(item,"",off(53,26),size(1,-64,0,8),function()
        cfg[key] = not cfg[key]
        if changed then changed() end
        F.refreshSettings()
        F.save()
    end)
    local state = label(toggle,"",9,"text",off(22,26),off(0,0),true)
    state.TextXAlignment = Enum.TextXAlignment.Center
    local thumb = frame(toggle,"Thumb","text",off(16,16),off(4,5))
    corner(thumb,8)
    local last
    renderSettings[#renderSettings+1] = function()
        if last ~= cfg[key] then
            local enabled = cfg[key]
            state.Text = enabled and "ON" or "OFF"
            state.Position = off(enabled and 5 or 25,0)
            F.motion(toggle,"toggle",{BackgroundColor3 = F.color(enabled and "selected" or "control")},.12,last == nil)
            last = enabled
        else
            toggle.BackgroundColor3 = F.color(cfg[key] and "selected" or "control")
        end
        local target = off(cfg[key] and 33 or 4,5)
        if thumb.Position ~= target or (tweens[thumb] and tweens[thumb].toggle) then
            -- Repeated viewport updates should not restart an in-flight switch.
            if S.switchGoals == nil then S.switchGoals = {} end
            if S.switchGoals[thumb] ~= cfg[key] then
                S.switchGoals[thumb] = cfg[key]
                F.motion(thumb,"toggle",{Position = target},.13)
            end
        end
    end
    register(settings,title,item)
end
local function option(title,key,values,after)
    local item = row(settings,title,43,"card")
    label(item,title,13,"text",size(.53,-14,1,0),off(11,0))
    local b = button(item,"",size(.47,-10,0,30),size(.53,0,0,6),function()
        if type(cfg[key]) == "number" then cfg[key] = cfg[key] % #values + 1
        else
            local current = 1
            for i, text in ipairs(values) do if cfg[key] == text then current = i; break end end
            cfg[key] = values[current % #values + 1]
        end
        if after then after() end
        F.refreshSettings(); F.save()
    end)
    b.Name = title .. " choice"
    renderSettings[#renderSettings+1] = function() b.Text = values[cfg[key]] or cfg[key] end
    register(settings,title,item)
end
local function slider(title,key,lo,hi,asPercent)
    local item = row(settings,title,62,"card")
    label(item,title,13,"text",size(1,-90,0,24),off(11,3))
    local value = label(item,"",11,"accent",off(73,24),size(1,-84,0,3),true)
    value.TextXAlignment = Enum.TextXAlignment.Right
    local pick = frame(item,title .. " slider",nil,size(1,-28,0,29),off(14,29))
    pick.Active = true
    local guide = frame(pick,"Rail","control",size(1,0,0,4),off(0,12))
    corner(guide,2)
    local progressBar = frame(guide,"Progress","accent")
    corner(progressBar,2)
    local dot = frame(pick,"Slider thumb","accent",off(14,14),off(0,14))
    dot.AnchorPoint = Vector2.new(.5,.5); corner(dot,7)
    local function actualValue()
        if key == "width" then return S.width or cfg[key] end
        if key == "height" then return S.height or cfg[key] end
        return cfg[key]
    end
    local function limits()
        if key == "width" or key == "height" then
            local extent = (key == "width" and UI.root.AbsoluteSize.X or UI.root.AbsoluteSize.Y)-16
            local upper = math.min(hi,math.max(1,extent))
            return math.min(lo,upper),upper
        end
        return lo,hi
    end
    local lastFraction
    local function refresh()
        local actual = actualValue()
        local low, high = limits()
        local ratio = math.clamp((actual-low)/math.max(.0001,high-low),0,1)
        value.Text = asPercent and string.format("%.0f%%", actual*100) or string.format("%.0f px",actual)
        if lastFraction ~= ratio then
            F.motion(progressBar,"value",{Size = size(ratio,0,1,0)},.08,lastFraction == nil)
            F.motion(dot,"value",{Position = size(ratio,0,0,14)},.08,lastFraction == nil)
            lastFraction = ratio
        end
    end
    local function update(position)
        if pick.AbsoluteSize.X <= 0 then return end
        local ratio = math.clamp((position.X-pick.AbsolutePosition.X)/pick.AbsoluteSize.X,0,1)
        local low, high = limits()
        local n = low + ratio*(high-low)
        cfg[key] = asPercent and math.floor(n*100+.5)/100 or math.floor(n+.5)
        -- Keep saved dimensions within the desktop bounds even when the device is smaller.
        if key == "width" or key == "height" then cfg[key] = math.max(lo,cfg[key]) end
        F.layout()
    end
    pick.InputBegan:Connect(function(input)
        local list = pages[settings].list
        if F.capture(input,update,function() list.ScrollingEnabled = true; F.save() end) then
            list.ScrollingEnabled = false
            update(input.Position)
        end
    end)
    renderSettings[#renderSettings+1] = refresh
    register(settings,title,item)
end

heading(settings,"Appearance")
option("Window theme","theme",{"Graphite","Midnight"},F.retheme)
option("Accent colour","accent",{"Azure","Ice Blue","Periwinkle"},F.retheme)
switch("Use animations","animations")
switch("Compact spacing","compact",function()
    for _, node in pairs(pages) do node.flow.Padding = UDim.new(0,cfg.compact and 4 or 6) end
end)
heading(settings,"Window and access")
slider("Menu width","width",440,1080)
slider("Menu height","height",300,720)
switch("Collapse wide sidebar","collapsed",F.layout)
slider("Floating button X","fx",0,1,true)
slider("Floating button Y","fy",0,1,true)
option("Menu shortcut","shortcut",shortcuts)
heading(settings,"Status information")
switch("Show status bar","status",F.layout)
switch("Show player health","health")
switch("Show movement speed","speed")
switch("Show coordinates","coords")
switch("Show selected tree","selection")
switch("Show active features","active")
heading(settings,"Storage")
UI.persistence = textBlock(card(settings,"Settings storage",nil,78),"",33,39)
function F.storageLabel()
    UI.persistence.Text = S.storage and (S.saved and "Saved on this device." or "Local storage detected. Changes are saved automatically.")
        or "Session only • local settings storage unavailable."
end
local reset = row(settings,"Reset to defaults",42)
button(reset,"Reset to defaults",size(1,0,1,0),nil,function()
    cfg = valid({})
    S.mobileExpanded = false
    search.Text = ""
    for _, node in pairs(pages) do
        node.list.CanvasPosition = Vector2.new(0,0)
        node.flow.Padding = UDim.new(0,8)
    end
    F.retheme()
    F.layout()
    F.navigate("Home")
    F.telemetry()
    F.notify("Default settings restored.")
end)
register(settings,"Reset to defaults",reset,"clear preferences")

-- Status is sampled only while the window is open; no game properties are changed.
function F.telemetry()
    local humanoid, root = characterParts()
    local velocity = root and root:IsA("BasePart") and root.AssemblyLinearVelocity or nil
    local speed = velocity and math.sqrt(velocity.X*velocity.X+velocity.Z*velocity.Z) or nil
    if S.visiblePage == "Movement" then
        UI.motionReadout.Text = humanoid and string.format("Walk speed setting: %.1f studs/s\nHorizontal speed: %s",humanoid.WalkSpeed,
            speed and string.format("%.1f studs/s",speed) or "unavailable") or "Waiting for character…"
    elseif S.visiblePage == "Player" then
        UI.playerReadout.Text = humanoid and string.format("Health: %.0f / %.0f\nLocation: %s", humanoid.Health,humanoid.MaxHealth,
            velocity and coordinates(root.Position) or "unavailable") or "Waiting for character…"
    elseif S.visiblePage == "Wood & Trees" then
        local log = features.recentLog
        UI.logReadout.Text = log and log.model.Parent == features.logFolder and log.part.Parent == log.model
            and log.owner.Parent == log.model and log.owner.Value == player
            and (log.species .. " log • " .. coordinates(log.part.Position))
            or (features.logFolder and "No recent nearby owned log detected." or "LT2 log data is unavailable.")
    end
    local activeFeatures = {}
    if features.movement.flying then activeFeatures[#activeFeatures+1] = "Flight" end
    if features.activity.enabled then activeFeatures[#activeFeatures+1] = "Movement monitor" end
    if features.treeBusy then activeFeatures[#activeFeatures+1] = "Tree request" end
    local summary = #activeFeatures > 0 and table.concat(activeFeatures, ", ") or "No automation running"
    UI.overview.Text = (features.trees and "Tree comparison available • " or "Tree comparison awaiting LT2 regions • ") .. summary
    if not cfg.status then return end
    local fields = {}
    if cfg.health and humanoid then fields[#fields+1] = string.format("HP %.0f / %.0f",humanoid.Health,humanoid.MaxHealth) end
    if cfg.speed and speed then fields[#fields+1] = string.format("%.1f studs/s",speed) end
    if cfg.coords and velocity then fields[#fields+1] = coordinates(root.Position) end
    if cfg.selection and features.selected and features.selected.model.Parent then fields[#fields+1] = features.selected.name .. " selected" end
    if cfg.active then
        fields[#fields+1] = summary
    end
    UI.status.Text = table.concat(fields,"   ·   ")
end
UI.status.TextWrapped = true
local elapsed = 0
F.connect(RunService.Heartbeat,function(dt)
    if not features.movement.failed then
        local ok, err = pcall(updateMovement)
        if not ok then
            features.movement.failed = true
            F.stopFly()
            warn("[Evian Hub] Movement:",err)
            F.notify("Movement controls are unavailable.",true,{code = "M03", details = "Step: update movement\nCause: " .. F.errorText(err)})
        end
    end
    local activity = features.activity
    if activity.enabled then
        activity.elapsed = activity.elapsed + dt
        if activity.elapsed >= .5 then
            activity.elapsed = 0
            local ok, err = pcall(F.sampleActivity)
            if not ok then
                activity.enabled, activity.records = false, {}
                UI.activityButton.Text = "Movement monitor: OFF"
                UI.activityReadout.Text = "Monitor stopped. Check the latest error."
                warn("[Evian Hub] Movement monitor:",err)
                F.notify("Movement monitor stopped.",true,{code="P01",details="Step: check players\nCause: " .. F.errorText(err)})
            end
        end
    end
    if not S.open and #features.pendingLogs == 0 then return end
    elapsed = elapsed + dt
    if elapsed >= .25 then
        elapsed = 0
        if #features.pendingLogs > 0 then checkLogs() end
        if S.open then F.telemetry() end
    end
end)

progress.Text = "Applying preferences…"
fill.Size = size(.7,0,1,0)
F.storageLabel()
for _, node in pairs(pages) do node.flow.Padding = UDim.new(0,cfg.compact and 4 or 6) end
F.layout()
showPage(cfg.category)
F.paintNav(false)
F.refreshSettings()
F.telemetry()
F.show(true)
progress.Text = "Ready"
fill.Size = size(1,0,1,0)
task.delay(.55,function() if S.alive then loading:Destroy(); resizeNotifications() end end)
