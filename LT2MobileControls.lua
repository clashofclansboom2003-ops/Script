-- Lumber Tycoon 2 mobile controls. Run as a client script in Delta.
-- Tree and log interactions use LT2 remotes and depend on server behavior.
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
local flySpeed = 50
local walkSpeed = 16
local jumpHeight = 7.2
local flyVelocity, flyGyro
local savedHumanoids = {}
local treeBusy = false
local treeJob = 0
local treeReturn
local viewportConnection
local logConnection
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
    if treeReturn then pcall(treeReturn) end
    stopFly()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
    if logConnection then logConnection:Disconnect(); logConnection = nil end
    for humanoid, values in pairs(savedHumanoids) do
        if humanoid.Parent then
            humanoid.WalkSpeed = values.walk
            humanoid.JumpHeight = values.jump
            humanoid.UseJumpPower = values.usePower
        end
    end
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
local colors = {
    background = Color3.fromRGB(10, 15, 23),
    panel = Color3.fromRGB(20, 30, 44),
    card = Color3.fromRGB(17, 26, 39),
    border = Color3.fromRGB(44, 67, 91),
    accent = Color3.fromRGB(105, 195, 255),
    primary = Color3.fromRGB(29, 101, 170),
    text = Color3.fromRGB(239, 247, 255),
    muted = Color3.fromRGB(151, 174, 195),
}
local function outline(object, color)
    make("UIStroke", {Color = color or colors.border, Thickness = 1, Transparency = .15}, object)
end
gui = make("ScreenGui", {Name = "LT2MobileControls", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local open = make("TextButton", {Name = "Open", Size = UDim2.fromOffset(98, 38), Position = UDim2.new(1, -110, 0, 12), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 12, Text = "LT2  •  TOOLS", Visible = false}, gui)
round(open, 10); outline(open)
local panel = make("Frame", {Name = "Panel", Size = UDim2.fromOffset(320, 480), Position = UDim2.new(1, -330, 0, 10), BackgroundColor3 = colors.background, BorderSizePixel = 0}, gui)
round(panel, 14); outline(panel)
local scale = make("UIScale", {Scale = 1}, panel)
local function resize()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    if viewport.X <= 20 or viewport.Y <= 20 then return end
    local availableWidth, availableHeight = viewport.X - 20, viewport.Y - 20
    scale.Scale = math.min(1, availableWidth / 320, availableHeight / 260)
    panel.Size = UDim2.fromOffset(320, math.min(480, availableHeight / scale.Scale))
    panel.Position = UDim2.new(1, -10 - 320 * scale.Scale, 0, 10)
end
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
    local camera = workspace.CurrentCamera
    if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize()
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
watchCamera()
local logo = make("TextLabel", {Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(14, 13), BackgroundColor3 = colors.primary, Text = "LT", TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 13}, panel)
round(logo, 9)
make("TextLabel", {Size = UDim2.fromOffset(150, 20), Position = UDim2.fromOffset(57, 10), BackgroundTransparency = 1, Text = "LUMBER TOOLS", TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, panel)
make("TextLabel", {Size = UDim2.fromOffset(150, 16), Position = UDim2.fromOffset(57, 31), BackgroundTransparency = 1, Text = "MOBILE CONTROL PANEL", TextColor3 = colors.muted, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left}, panel)
local hide = make("TextButton", {Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -84, 0, 13), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 17, Text = "−"}, panel)
round(hide, 9)
local close = make("TextButton", {Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -44, 0, 13), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 16, Text = "×"}, panel)
round(close, 9)
connect(hide.Activated, function() panel.Visible = false; open.Visible = true end)
connect(open.Activated, function() panel.Visible = true; open.Visible = false end)
connect(close.Activated, cleanup)
local content = make("ScrollingFrame", {Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -28, 1, -127), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = colors.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, panel)
make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, content)
make("UIPadding", {PaddingBottom = UDim.new(0, 8)}, content)
local statusBox = make("Frame", {Position = UDim2.new(0, 14, 1, -54), Size = UDim2.new(1, -28, 0, 42), BackgroundColor3 = colors.card, BorderSizePixel = 0}, panel)
round(statusBox, 9); outline(statusBox)
local statusDot = make("Frame", {Position = UDim2.fromOffset(11, 17), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = colors.accent, BorderSizePixel = 0}, statusBox)
round(statusDot, 4)
local status = make("TextLabel", {Position = UDim2.fromOffset(25, 3), Size = UDim2.new(1, -32, 1, -6), BackgroundTransparency = 1, Text = "Ready", TextColor3 = colors.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham, TextSize = 11}, statusBox)
local function tell(message) if running then status.Text = message end end
local order = 0
local function row(height)
    order = order + 1
    return make("Frame", {LayoutOrder = order, Size = UDim2.new(1, -6, 0, height), BackgroundTransparency = 1}, content)
end
local function button(parent, text, position, size, callback)
    local b = make("TextButton", {Position = position or UDim2.new(), Size = size or UDim2.new(1, 0, 1, 0), BackgroundColor3 = colors.panel, TextColor3 = colors.text, Font = Enum.Font.GothamSemibold, TextSize = 12, Text = text, AutoButtonColor = true, BorderSizePixel = 0}, parent)
    round(b, 9); outline(b)
    if callback then connect(b.Activated, callback) end
    return b
end
local function section(text)
    local r = row(24)
    local marker = make("Frame", {Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(3, 12), BackgroundColor3 = colors.accent, BorderSizePixel = 0}, r)
    round(marker, 2)
    make("TextLabel", {Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = colors.accent, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, r)
end
local function slider(label, min, max, initial, callback)
    local r = row(66)
    r.BackgroundTransparency = 0
    r.BackgroundColor3 = colors.card
    round(r, 10); outline(r)
    make("TextLabel", {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -85, 0, 22), BackgroundTransparency = 1, Text = label, TextColor3 = colors.text, Font = Enum.Font.GothamSemibold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, r)
    local valueLabel = make("TextLabel", {Position = UDim2.new(1, -68, 0, 5), Size = UDim2.fromOffset(56, 24), BackgroundColor3 = colors.panel, TextColor3 = colors.accent, Font = Enum.Font.GothamBold, TextSize = 11}, r)
    round(valueLabel, 7)
    local track = make("Frame", {Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 24), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true}, r)
    local rail = make("Frame", {Position = UDim2.new(0, 0, .5, -3), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = colors.border, BorderSizePixel = 0}, track)
    round(rail, 3)
    local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.accent, BorderSizePixel = 0}, rail)
    round(fill, 3)
    local knob = make("Frame", {AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0, .5), BackgroundColor3 = colors.text, BorderSizePixel = 0, Active = true}, track)
    round(knob, 9); outline(knob, colors.accent)
    local activeInput
    local function set(value)
        value = math.floor(math.clamp(value, min, max) * 10 + .5) / 10
        local fraction = (value - min) / (max - min)
        valueLabel.Text = tostring(value)
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
local flyRow = row(42)
local flyButton
flyButton = button(flyRow, "FLY: OFF", nil, nil, function()
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
    tell("Use the joystick and aim the camera to fly.")
end)
-- MoveDirection is horizontal and camera-relative. Restore the camera's pitch
-- to the forward component while keeping sideways movement level.
local function flightDirection(moveDirection, cameraCFrame)
    local look = cameraCFrame.LookVector
    local right = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
    if right.Magnitude < 0.001 then return moveDirection end
    right = right.Unit
    local flatForward = Vector3.new(0, 1, 0):Cross(right)
    local forwardAmount = moveDirection:Dot(flatForward)
    local sidewaysAmount = moveDirection:Dot(right)
    local direction = look * forwardAmount + right * sidewaysAmount
    if direction.Magnitude > 1 then return direction.Unit end
    return direction
end
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
        local cameraNow = workspace.CurrentCamera
        local direction = cameraNow and flightDirection(humanoid.MoveDirection, cameraNow.CFrame) or humanoid.MoveDirection
        flyVelocity.Velocity = direction * flySpeed
        if cameraNow then
            local look = cameraNow.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.001 then flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flat) end
        end
    end
end)
connect(player.CharacterAdded, function() stopFly(); flyButton.Text = "FLY: OFF" end)
section("BRING TREE")
-- Only logs that appear after the tools start can be identified as recent.
local recentLog, logFolder, pendingCut
local logSequence, recentSequence = 0, 0
local treeTypes = {{"Oak", "Generic"}, {"Cherry", "Cherry"}, {"Gold", "GoldSwampy"}, {"Cavecrawler", "CaveCrawler"}, {"Frost", "Frost"}, {"Lava", "Volcano"}, {"Elm", "Oak"}, {"Walnut", "Walnut"}, {"Birch", "Birch"}, {"Snowglow", "SnowGlow"}, {"Pine", "GreenSwampy"}, {"Koa", "Koa"}, {"Palm", "Palm"}, {"Spook", "Spooky"}, {"Sinister", "SpookyNeon"}, {"End Times", "LoneCave"}}
local treeIndex = 1
local treeRow = row(42)
local treeLabel = button(treeRow, "TREE: Oak", UDim2.new(0, 0, 0, 0), UDim2.new(.55, -4, 1, 0), nil)
local function changeTree(delta)
    treeIndex = (treeIndex - 1 + delta) % #treeTypes + 1
    treeLabel.Text = "TREE: " .. treeTypes[treeIndex][1]
end
button(treeRow, "‹", UDim2.new(.55, 0, 0, 0), UDim2.new(.15, -4, 1, 0), function() changeTree(-1) end)
button(treeRow, "NEXT ›", UDim2.new(.70, 0, 0, 0), UDim2.new(.30, 0, 1, 0), function() changeTree(1) end)
local axeDamage = {Beesaxe=1.4, AxeAmber=3.39, ManyAxe=10.2, BasicHatchet=.2, Axe1=.55, Axe2=.93, AxeAlphaTesters=1.5, Rukiryaxe=1.68, Axe3=1.45, AxeBetaTesters=1.45, FireAxe=.6, SilverAxe=1.6, EndTimesAxe=1.58, AxeChicken=.9, AxeTwitter=1.65, CandyCornAxe=1.75}

local function watchLogs(folder)
    if logConnection then logConnection:Disconnect(); logConnection = nil end
    logFolder = folder
    recentLog = nil
    if not folder then return end
    logConnection = folder.ChildAdded:Connect(function(log)
        local _, _, root = characterParts()
        if not root or not log:IsA("Model") then return end
        local chopPosition = root.Position
        logSequence = logSequence + 1
        local sequence = logSequence
        local cut = pendingCut and pendingCut.started and pendingCut or nil
        task.spawn(function()
            local deadline = os.clock() + 6
            while running and logFolder == folder and log.Parent == folder and os.clock() < deadline do
                local owner = log:FindFirstChild("Owner")
                local class = log:FindFirstChild("TreeClass")
                local wood = log:FindFirstChild("WoodSection")
                if owner and owner:IsA("ObjectValue") and owner.Value ~= nil and class and class:IsA("StringValue") and class.Value ~= "" and wood and wood:IsA("BasePart") then
                    if owner.Value == player and (wood.Position - chopPosition).Magnitude <= 120 and sequence > recentSequence then
                        recentSequence = sequence
                        recentLog = log
                    end
                    if cut and pendingCut == cut and not cut.log and sequence > cut.afterSequence
                        and owner.Value == player and class.Value == cut.treeClass
                        and (wood.Position - cut.position).Magnitude <= 120 then
                        cut.log = log
                    end
                    return
                end
                task.wait(.1)
            end
        end)
    end)
end
connect(workspace.ChildAdded, function(child)
    if child.Name == "LogModels" then watchLogs(child) end
end)
connect(workspace.ChildRemoved, function(child)
    if child == logFolder then watchLogs(nil) end
end)
watchLogs(workspace:FindFirstChild("LogModels"))

-- Sum wood section volumes to compare trees without counting their leaves.
-- Only trees currently replicated to this client can be inspected.
local function findTree(treeClass)
    local largestTree, largestWood, largestVolume
    for _, region in ipairs(workspace:GetChildren()) do
        if region.Name == "TreeRegion" then
            for _, candidate in ipairs(region:GetChildren()) do
                local class = candidate:FindFirstChild("TreeClass")
                local owner = candidate:FindFirstChild("Owner")
                local wood = candidate:FindFirstChild("WoodSection")
                if candidate:IsA("Model") and class and class:IsA("StringValue") and class.Value == treeClass
                    and candidate:FindFirstChild("CutEvent") and wood and wood:IsA("BasePart")
                    and (not owner or (owner:IsA("ObjectValue") and (owner.Value == nil or owner.Value == player))) then
                    local volume = 0
                    for _, part in ipairs(candidate:GetDescendants()) do
                        if part.Name == "WoodSection" and part:IsA("BasePart") then
                            local size = part.Size
                            volume = volume + size.X * size.Y * size.Z
                        end
                    end
                    if not largestVolume or volume > largestVolume then
                        largestTree, largestWood, largestVolume = candidate, wood, volume
                    end
                end
            end
        end
    end
    return largestTree, largestWood
end

local function bringTree(automatic)
    if treeBusy then tell("A tree request is already running."); return end
    local character, humanoid, root = characterParts()
    if not character or not humanoid or not root then tell("Wait for your character to load."); return end
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local drag = interaction and interaction:FindFirstChild("ClientIsDragging")
    local ownership = interaction and interaction:FindFirstChild("ClientRequestOwnership")
    local proxy = interaction and interaction:FindFirstChild("RemoteProxy")
    if not drag or not drag:IsA("RemoteEvent") then tell("Tree transfer is unavailable: drag remote missing."); return end
    if ownership and not ownership:IsA("RemoteEvent") then ownership = nil end
    if automatic and (not proxy or not proxy:IsA("RemoteEvent") or not logFolder) then
        tell("Tree cutting is unavailable in this server."); return
    end

    treeBusy = true
    treeJob = treeJob + 1
    local job = treeJob
    local original = root.CFrame
    local destination = original.Position + Vector3.new(0, 3, 0)
    local movedLog = false
    local function restorePosition()
        if treeReturn ~= restorePosition then return end
        treeReturn = nil
        if root.Parent and player.Character == character then root.CFrame = original end
    end
    treeReturn = restorePosition
    local function active()
        return running and treeJob == job and player.Character == character and root.Parent
    end
    local success, result = pcall(function()
        local log = recentLog
        if automatic then
            local treeType = treeTypes[treeIndex]
            local tree, treeWood = findTree(treeType[2])
            if not tree then return "No " .. treeType[1] .. " tree loaded. Move closer and try again." end
            local axe = character:FindFirstChildOfClass("Tool")
            if not axe then return "Equip a supported axe, then press BRING ONE TREE again." end
            local name = axe:FindFirstChild("ToolName")
            local axeName = name and name:IsA("StringValue") and name.Value
            local damage = axeName and axeDamage[axeName]
            if not damage then return "The equipped tool must be a supported axe." end
            if treeType[2] == "Volcano" and axeName == "FireAxe" then damage = 6.35 end
            if treeType[2] == "LoneCave" and axeName == "EndTimesAxe" then damage = 10000000 end
            if not tree.Parent or not treeWood.Parent then return "The selected tree is no longer available." end
            stopFly(); flyButton.Text = "FLY: OFF"
            local cut = {treeClass = treeType[2], position = treeWood.Position, afterSequence = logSequence}
            pendingCut = cut
            root.CFrame = treeWood.CFrame + Vector3.new(4, 2, 2)
            tell("Cutting " .. treeType[1] .. "...")
            task.wait(.3)
            local deadline = os.clock() + 20
            while active() and pendingCut == cut and not cut.log and os.clock() < deadline do
                if axe.Parent ~= character then return "The equipped axe became unavailable." end
                local cutEvent = tree.Parent and tree:FindFirstChild("CutEvent")
                if cutEvent then
                    cut.started = true
                    proxy:FireServer(cutEvent, {tool = axe, faceVector = Vector3.new(0, 0, -1), height = .3, sectionId = 1, hitPoints = damage, cooldown = .1, cuttingClass = "Axe"})
                end
                task.wait(.12)
            end
            log = cut.log
            if pendingCut == cut then pendingCut = nil end
            if not active() then return end
            if not log then return "No matching log appeared. The server may have rejected the cut." end
        end
        local owner = log and log:FindFirstChild("Owner")
        local wood = log and log:FindFirstChild("WoodSection")
        if not log or log.Parent ~= logFolder or not owner or not owner:IsA("ObjectValue") or owner.Value ~= player or not wood or not wood:IsA("BasePart") then
            return automatic and "The cut log became unavailable." or "Chop a tree nearby while these tools are open, then try again."
        end
        stopFly(); flyButton.Text = "FLY: OFF"
        local function canContinue()
            return active() and log.Parent == logFolder and owner.Parent == log and owner.Value == player and wood.Parent == log
        end
        tell("Moving the log back...")
        root.CFrame = wood.CFrame + Vector3.new(4, 2, 2)
        for _ = 1, 10 do
            if not canContinue() then return "The log or character became unavailable before the move." end
            if ownership then ownership:FireServer(log); ownership:FireServer(wood) end
            drag:FireServer(log)
            task.wait(.1)
        end
        for _ = 1, 20 do
            if not canContinue() then return "The log or character became unavailable during the move." end
            if ownership then ownership:FireServer(log); ownership:FireServer(wood) end
            drag:FireServer(log)
            log:PivotTo(log:GetPivot() + (destination - wood.Position))
            movedLog = true
            root.CFrame = original
            task.wait(.1)
        end
        return "Tree move requested. Check whether the server accepted it."
    end)
    pendingCut = nil
    restorePosition()
    treeBusy = false
    if not running then return end
    if not success then tell("Tree request failed: " .. tostring(result))
    elseif result then tell(result)
    elseif movedLog then tell("Tree move requested. Check whether the server accepted it.") end
end
local function startTreeRequest(automatic)
    task.spawn(function()
        local ok, err = pcall(bringTree, automatic)
        if not ok then
            pendingCut = nil
            if treeReturn then pcall(treeReturn) end
            treeBusy = false
            tell("Tree request failed: " .. tostring(err))
        end
    end)
end
local bringRow = row(42)
local bringButton = button(bringRow, "BRING ONE TREE", nil, nil, function() startTreeRequest(true) end)
bringButton.BackgroundColor3 = colors.primary
local recentRow = row(42)
button(recentRow, "BRING RECENT TREE", nil, nil, function() startTreeRequest(false) end)
