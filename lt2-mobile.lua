-- Lumber Tycoon 2 mobile controls. Run as a client script in Delta.
-- Tree and structure interactions use LT2 remotes and depend on server behavior.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
if type(env.LT2MobileCleanup) == "function" then
    pcall(env.LT2MobileCleanup)
end

local connections = {}
local running = true
local flying = false
local flyVertical = 0
local flySpeed = 50
local walkSpeed = 16
local jumpHeight = 7.2
local flyVelocity, flyGyro
local savedHumanoids = {}
local treeBusy = false
local treeJob = 0
local createdTools = {}
local gui
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
local function characterParts()
    local character = player.Character
    return character, character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end
local function stopFly()
    flying = false
    flyVertical = 0
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
end
local function saveHumanoid(humanoid)
    if humanoid and not savedHumanoids[humanoid] then
        savedHumanoids[humanoid] = {walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight, usePower = humanoid.UseJumpPower}
    end
end
local function cleanup()
    if not running then return end
    running = false
    treeJob = treeJob + 1
    stopFly()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for humanoid, values in pairs(savedHumanoids) do
        if humanoid.Parent then
            humanoid.WalkSpeed = values.walk
            humanoid.JumpHeight = values.jump
            humanoid.UseJumpPower = values.usePower
        end
    end
    for _, tool in ipairs(createdTools) do if tool.Parent then tool:Destroy() end end
    if gui then gui:Destroy() end
    if env.LT2MobileCleanup == cleanup then env.LT2MobileCleanup = nil end
end
env.LT2MobileCleanup = cleanup

local function make(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end
local colors = {background = Color3.fromRGB(24, 31, 29), panel = Color3.fromRGB(37, 47, 42), accent = Color3.fromRGB(108, 186, 116), text = Color3.fromRGB(245, 248, 242), muted = Color3.fromRGB(177, 191, 179)}
gui = make("ScreenGui", {Name = "LT2MobileControls", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local open = make("TextButton", {Name = "Open", Size = UDim2.fromOffset(84, 34), Position = UDim2.new(1, -96, 0, 12), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 13, Text = "LT2 TOOLS", Visible = false}, gui)
round(open)
local panel = make("Frame", {Name = "Panel", Size = UDim2.fromOffset(310, 430), Position = UDim2.new(1, -320, 0, 10), BackgroundColor3 = colors.background, BorderSizePixel = 0}, gui)
round(panel, 10)
local scale = make("UIScale", {Scale = 1}, panel)
local function resize()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.min(1, math.max(0.55, (viewport.Y - 25) / 430), math.max(0.55, (viewport.X - 20) / 310))
    panel.Position = UDim2.new(1, -10 - 310 * scale.Scale, 0, 10)
end
resize()
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), resize)
local camera = workspace.CurrentCamera
if camera then connect(camera:GetPropertyChangedSignal("ViewportSize"), resize) end
local header = make("TextLabel", {Size = UDim2.new(1, -88, 0, 42), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1, Text = "LUMBER  /  TOOLS", TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left}, panel)
local hide = make("TextButton", {Size = UDim2.fromOffset(36, 30), Position = UDim2.new(1, -78, 0, 6), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 17, Text = "−"}, panel)
round(hide)
local close = make("TextButton", {Size = UDim2.fromOffset(32, 30), Position = UDim2.new(1, -38, 0, 6), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 16, Text = "×"}, panel)
round(close)
connect(hide.Activated, function() panel.Visible = false; open.Visible = true end)
connect(open.Activated, function() panel.Visible = true; open.Visible = false end)
connect(close.Activated, cleanup)
local content = make("ScrollingFrame", {Position = UDim2.fromOffset(10, 43), Size = UDim2.new(1, -20, 1, -92), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = colors.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, panel)
local layout = make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, content)
make("UIPadding", {PaddingBottom = UDim.new(0, 8)}, content)
local status = make("TextLabel", {Position = UDim2.new(0, 12, 1, -43), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1, Text = "Ready", TextColor3 = colors.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 11}, panel)
local function tell(message) if running then status.Text = message end end
local order = 0
local function row(height)
    order = order + 1
    return make("Frame", {LayoutOrder = order, Size = UDim2.new(1, -6, 0, height), BackgroundTransparency = 1}, content)
end
local function button(parent, text, position, size, callback)
    local b = make("TextButton", {Position = position or UDim2.new(), Size = size or UDim2.new(1, 0, 1, 0), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamSemibold, TextSize = 12, Text = text, AutoButtonColor = true}, parent)
    round(b, 6)
    if callback then connect(b.Activated, callback) end
    return b
end
local function section(text)
    local r = row(20)
    make("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = colors.accent, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, r)
end
local function slider(label, min, max, initial, callback)
    local r = row(52)
    local title = make("TextLabel", {Size = UDim2.new(1, 0, 0, 21), BackgroundTransparency = 1, TextColor3 = colors.text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, r)
    local track = make("Frame", {Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = Color3.fromRGB(66, 79, 70), BorderSizePixel = 0, Active = true}, r)
    round(track, 4)
    local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.accent, BorderSizePixel = 0}, track)
    round(fill, 4)
    local knob = make("Frame", {AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0, .5), BackgroundColor3 = colors.text, BorderSizePixel = 0, Active = true}, track)
    round(knob, 10)
    local activeInput
    local function set(value)
        value = math.floor(math.clamp(value, min, max) * 10 + .5) / 10
        local fraction = (value - min) / (max - min)
        title.Text = label .. "  " .. tostring(value)
        fill.Size = UDim2.fromScale(fraction, 1)
        knob.Position = UDim2.fromScale(fraction, .5)
        callback(value)
    end
    local function update(input)
        if track.AbsoluteSize.X > 0 then
            set(min + math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (max - min))
        end
    end
    local function begin(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            activeInput = input
            update(input)
        end
    end
    connect(track.InputBegan, begin)
    connect(knob.InputBegan, begin)
    connect(UserInputService.InputChanged, function(input)
        if activeInput and (input == activeInput or (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then update(input) end
    end)
    connect(UserInputService.InputEnded, function(input) if input == activeInput then activeInput = nil end end)
    set(initial)
end
section("MOVEMENT")
slider("Walk speed", 16, 100, 16, function(value) walkSpeed = value end)
slider("Fly speed", 10, 150, 50, function(value) flySpeed = value end)
slider("Jump height", 7.2, 60, 7.2, function(value) jumpHeight = value end)
local flyRow = row(36)
local flyButton
flyButton = button(flyRow, "FLY: OFF", UDim2.new(0, 0, 0, 0), UDim2.new(.46, -3, 1, 0), function()
    if flying then
        stopFly()
        flyButton.Text = "FLY: OFF"
        tell("Flight off.")
        return
    end
    local _, humanoid, root = characterParts()
    if not humanoid or not root then tell("Wait for your character to load."); return end
    flyVelocity = make("BodyVelocity", {Name = "LT2FlyVelocity", MaxForce = Vector3.new(1e6, 1e6, 1e6), Velocity = Vector3.zero, P = 12500}, root)
    flyGyro = make("BodyGyro", {Name = "LT2FlyGyro", MaxTorque = Vector3.new(0, 1e6, 0), P = 10000, CFrame = root.CFrame}, root)
    flying = true
    flyButton.Text = "FLY: ON"
    tell("Use the joystick to fly; hold UP or DOWN for height.")
end)
local up = button(flyRow, "UP", UDim2.new(.46, 3, 0, 0), UDim2.new(.27, -6, 1, 0))
local down = button(flyRow, "DOWN", UDim2.new(.73, 0, 0, 0), UDim2.new(.27, 0, 1, 0))
local function holdButton(b, direction)
    local active
    connect(b.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then active = input; flyVertical = direction end
    end)
    connect(UserInputService.InputEnded, function(input) if input == active then active = nil; if flyVertical == direction then flyVertical = 0 end end end)
end
holdButton(up, 1)
holdButton(down, -1)
connect(RunService.Heartbeat, function()
    local _, humanoid, root = characterParts()
    if humanoid then
        saveHumanoid(humanoid)
        humanoid.WalkSpeed = walkSpeed
        humanoid.UseJumpPower = false
        humanoid.JumpHeight = jumpHeight
    end
    if flying then
        if not root or not humanoid or not flyVelocity or flyVelocity.Parent ~= root then
            stopFly(); flyButton.Text = "FLY: OFF"; return
        end
        local direction = humanoid.MoveDirection + Vector3.new(0, flyVertical, 0)
        if direction.Magnitude > 1 then direction = direction.Unit end
        flyVelocity.Velocity = direction * flySpeed
        local cameraNow = workspace.CurrentCamera
        if cameraNow then
            local look = cameraNow.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.001 then flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flat) end
        end
    end
end)
connect(player.CharacterAdded, function() stopFly(); flyButton.Text = "FLY: OFF" end)
section("BUILDING")
local bRow = row(36)
button(bRow, "GET BTOOLS", nil, nil, function()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then tell("Backpack unavailable."); return end
    for _, tool in ipairs(createdTools) do
        if tool.Parent then tell("BTools have already been added."); return end
    end
    createdTools = {}
    local ok = pcall(function()
        for _, binType in ipairs({Enum.BinType.Clone, Enum.BinType.Grab, Enum.BinType.Hammer}) do
            local tool = Instance.new("HopperBin")
            tool.BinType = binType
            tool.Parent = backpack
            table.insert(createdTools, tool)
        end
    end)
    if not ok then
        for _, tool in ipairs(createdTools) do if tool.Parent then tool:Destroy() end end
        createdTools = {}
    end
    tell(ok and "BTools added. Server changes may not replicate." or "BTools are unavailable in this client.")
end)
local rotateRow = row(36)
button(rotateRow, "ROTATE HELD STRUCTURE", nil, nil, function()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local dragGui = playerGui and playerGui:FindFirstChild("StructureDraggingGUI")
    local rotate = dragGui and dragGui:FindFirstChild("Rotate", true)
    local rotateButton = rotate and (rotate:IsA("GuiButton") and rotate or rotate:FindFirstChildWhichIsA("GuiButton", true))
    if not dragGui or not rotateButton or not rotateButton.Visible or (dragGui:IsA("ScreenGui") and not dragGui.Enabled) then
        tell("Start moving a structure in the game first.")
        return
    end
    if type(firesignal) == "function" then
        local ok = pcall(firesignal, rotateButton.MouseButton1Click)
        tell(ok and "Rotation control triggered." or "Could not trigger the rotation control.")
    elseif type(getconnections) == "function" then
        local ok, listeners = pcall(getconnections, rotateButton.MouseButton1Click)
        if not ok or #listeners == 0 then tell("Rotation control has no accessible listeners."); return end
        local fired = false
        for _, listener in ipairs(listeners) do
            if type(listener.Fire) == "function" then
                local firedOk = pcall(function() listener:Fire() end)
                fired = fired or firedOk
            end
        end
        tell(fired and "Rotation control triggered." or "Could not trigger the rotation control.")
    else
        tell("Delta does not expose a supported rotation signal here.")
    end
end)
section("BRING TREE")
local treeTypes = {{"Oak", "Generic"}, {"Cherry", "Cherry"}, {"Gold", "GoldSwampy"}, {"Cavecrawler", "CaveCrawler"}, {"Frost", "Frost"}, {"Lava", "Volcano"}, {"Elm", "Oak"}, {"Walnut", "Walnut"}, {"Birch", "Birch"}, {"Snowglow", "SnowGlow"}, {"Pine", "GreenSwampy"}, {"Koa", "Koa"}, {"Palm", "Palm"}, {"Spook", "Spooky"}, {"Sinister", "SpookyNeon"}, {"End Times", "LoneCave"}}
local treeIndex = 1
local treeRow = row(36)
local treeLabel = button(treeRow, "TREE: Oak", UDim2.new(0, 0, 0, 0), UDim2.new(.7, -4, 1, 0), function() end)
button(treeRow, "NEXT ›", UDim2.new(.7, 4, 0, 0), UDim2.new(.3, -4, 1, 0), function()
    treeIndex = treeIndex % #treeTypes + 1
    treeLabel.Text = "TREE: " .. treeTypes[treeIndex][1]
end)
local axeDamage = {Beesaxe=1.4, AxeAmber=3.39, ManyAxe=10.2, BasicHatchet=.2, Axe1=.55, Axe2=.93, AxeAlphaTesters=1.5, Rukiryaxe=1.68, Axe3=1.45, AxeBetaTesters=1.45, FireAxe=.6, SilverAxe=1.6, EndTimesAxe=1.58, AxeChicken=.9, AxeTwitter=1.65, CandyCornAxe=1.75}
local function findAxe(character)
    for _, container in ipairs({character, player:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                local name = tool:FindFirstChild("ToolName")
                if tool:IsA("Tool") and name and axeDamage[name.Value] then return tool, name.Value end
            end
        end
    end
end
local function bringTree()
    if treeBusy then tell("A tree request is already running."); return end
    local character, humanoid, root = characterParts()
    if not character or not humanoid or not root then tell("Wait for your character to load."); return end
    local axe, axeName = findAxe(character)
    if not axe then tell("Equip or carry a supported axe first."); return end
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local proxy = interaction and interaction:FindFirstChild("RemoteProxy")
    local drag = interaction and interaction:FindFirstChild("ClientIsDragging")
    local logs = workspace:FindFirstChild("LogModels")
    if not proxy or not drag or not logs then tell("Tree remotes are unavailable in this server."); return end
    local treeClass = treeTypes[treeIndex][2]
    local tree, sectionPart
    for _, region in ipairs(workspace:GetChildren()) do
        if region.Name == "TreeRegion" then
            for _, candidate in ipairs(region:GetChildren()) do
                local class = candidate:FindFirstChild("TreeClass")
                local owner = candidate:FindFirstChild("Owner")
                local wood = candidate:FindFirstChild("WoodSection")
                if candidate:IsA("Model") and class and class.Value == treeClass and candidate:FindFirstChild("CutEvent") and wood and wood:IsA("BasePart") and (not owner or owner.Value == nil or owner.Value == player) then
                    tree, sectionPart = candidate, wood; break
                end
            end
        end
        if tree then break end
    end
    if not tree then tell("No available " .. treeTypes[treeIndex][1] .. " tree found."); return end
    treeBusy = true
    treeJob = treeJob + 1
    local job = treeJob
    stopFly(); flyButton.Text = "FLY: OFF"
    local original = root.CFrame
    local foundLog
    local connection = logs.ChildAdded:Connect(function(log)
        task.spawn(function()
            local owner = log:WaitForChild("Owner", 3)
            local class = log:WaitForChild("TreeClass", 3)
            if running and treeJob == job and owner and class and owner.Value == player and class.Value == treeClass then foundLog = log end
        end)
    end)
    tell("Cutting " .. treeTypes[treeIndex][1] .. "; returning when finished.")
    local success, err = pcall(function()
        root.CFrame = sectionPart.CFrame + Vector3.new(4, 2, 2)
        local damage = axeDamage[axeName]
        if treeClass == "Volcano" and axeName == "FireAxe" then damage = 6.35 end
        if treeClass == "LoneCave" and axeName == "EndTimesAxe" then damage = 10000000 end
        local deadline = os.clock() + 20
        while running and treeJob == job and character == player.Character and tree.Parent and not foundLog and os.clock() < deadline do
            proxy:FireServer(tree.CutEvent, {tool = axe, faceVector = Vector3.new(0, 0, -1), height = .3, sectionId = 1, hitPoints = damage, cooldown = .1, cuttingClass = "Axe"})
            task.wait(.12)
        end
        if foundLog and foundLog.Parent and running and treeJob == job then
            for _ = 1, 7 do
                if not foundLog.Parent then break end
                foundLog:MoveTo((original * CFrame.new(0, 3, -6)).Position)
                drag:FireServer(foundLog)
                task.wait(.08)
            end
        end
    end)
    connection:Disconnect()
    if root.Parent and player.Character == character then root.CFrame = original end
    treeBusy = false
    if not running then return end
    if not success then tell("Tree request failed: " .. tostring(err))
    elseif foundLog then tell("Tree move requested. Check whether the server accepted it.")
    else tell("No log appeared within 20 seconds. The server may have rejected the cut.") end
end
local bringRow = row(36)
button(bringRow, "BRING ONE TREE", nil, nil, function() task.spawn(bringTree) end)
