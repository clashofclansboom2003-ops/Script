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
local flySpeed = 50
local walkSpeed = 16
local jumpHeight = 7.2
local flyVelocity, flyGyro
local savedHumanoids = {}
local treeBusy = false
local treeJob = 0
local createdTools = {}
local selectedStructure
local selectingStructure = false
local selectionHighlight
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
    if selectionHighlight then selectionHighlight:Destroy() end
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
local selectRow = row(36)
button(selectRow, "SELECT PLACED STRUCTURE", nil, nil, function()
    selectedStructure = nil
    if selectionHighlight then selectionHighlight:Destroy(); selectionHighlight = nil end
    selectingStructure = true
    tell("Tap a placed structure that you own.")
end)
connect(UserInputService.InputBegan, function(input, processed)
    if not selectingStructure or processed then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    selectingStructure = false
    local cameraNow = workspace.CurrentCamera
    local models = workspace:FindFirstChild("PlayerModels")
    if not cameraNow or not models then tell("Placed structures are unavailable."); return end
    local ray = cameraNow:ScreenPointToRay(input.Position.X, input.Position.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = player.Character and {player.Character} or {}
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    local model = hit and hit.Instance
    while model and model.Parent ~= models do model = model.Parent end
    local owner = model and model:FindFirstChild("Owner")
    local kind = model and model:FindFirstChild("Type")
    if not model or not model:IsA("Model") or not owner or owner.Value ~= player or not kind or kind.Value ~= "Structure" or not model.PrimaryPart then
        selectedStructure = nil
        if selectionHighlight then selectionHighlight:Destroy(); selectionHighlight = nil end
        tell("Tap one of your own placed structures.")
        return
    end
    selectedStructure = model
    if selectionHighlight then selectionHighlight:Destroy() end
    selectionHighlight = make("Highlight", {Adornee = model, FillTransparency = .7, OutlineColor = colors.accent, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, model)
    local item = model:FindFirstChild("ItemName")
    tell("Selected " .. (item and tostring(item.Value) or "structure") .. ".")
end)
local rotateRow = row(36)
button(rotateRow, "ROTATE SELECTED 90°", nil, nil, function()
    local model = selectedStructure
    local owner = model and model:FindFirstChild("Owner")
    local kind = model and model:FindFirstChild("Type")
    if not model or not model.Parent or not model.PrimaryPart or not owner or owner.Value ~= player or not kind or kind.Value ~= "Structure" then
        tell("Select one of your placed structures first.")
        return
    end
    local placement = ReplicatedStorage:FindFirstChild("PlaceStructure")
    local remote = placement and placement:FindFirstChild("ClientPlacedStructure")
    if not remote or not remote:IsA("RemoteEvent") then tell("Structure placement remote unavailable."); return end
    local rotated = model.PrimaryPart.CFrame * CFrame.Angles(0, math.rad(90), 0)
    remote:FireServer(nil, rotated, player, nil, model, true)
    selectedStructure = nil
    if selectionHighlight then selectionHighlight:Destroy(); selectionHighlight = nil end
    tell("Rotation requested. Select the structure again to rotate it further.")
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
    local ownership = interaction and interaction:FindFirstChild("ClientRequestOwnership")
    local logs = workspace:FindFirstChild("LogModels")
    if not proxy or not drag or not ownership or not logs then tell("Tree remotes are unavailable in this server."); return end
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
    local movedLog = false
    local connection = logs.ChildAdded:Connect(function(log)
        task.spawn(function()
            local deadline = os.clock() + 6
            while running and treeJob == job and log.Parent == logs and not foundLog and os.clock() < deadline do
                local owner = log:FindFirstChild("Owner")
                local class = log:FindFirstChild("TreeClass")
                local wood = log:FindFirstChild("WoodSection")
                if owner and class and wood and owner.Value == player and class.Value == treeClass then
                    foundLog = log
                    return
                end
                task.wait(.1)
            end
        end)
    end)
    tell("Cutting " .. treeTypes[treeIndex][1] .. "; returning when finished.")
    local success, err = pcall(function()
        root.CFrame = sectionPart.CFrame + Vector3.new(4, 2, 2)
        local damage = axeDamage[axeName]
        if treeClass == "Volcano" and axeName == "FireAxe" then damage = 6.35 end
        if treeClass == "LoneCave" and axeName == "EndTimesAxe" then damage = 10000000 end
        local deadline = os.clock() + 20
        while running and treeJob == job and character == player.Character and not foundLog and os.clock() < deadline do
            local cutEvent = tree.Parent and tree:FindFirstChild("CutEvent")
            if cutEvent then
                proxy:FireServer(cutEvent, {tool = axe, faceVector = Vector3.new(0, 0, -1), height = .3, sectionId = 1, hitPoints = damage, cooldown = .1, cuttingClass = "Axe"})
            end
            task.wait(.12)
        end
        if foundLog and foundLog.Parent and running and treeJob == job and character == player.Character then
            local wood = foundLog:FindFirstChild("WoodSection")
            if not wood or not wood:IsA("BasePart") then error("Cut log has no wood section") end
            -- Request physics ownership before moving the new log; keep the player
            -- near the tree until the server has had time to process the request.
            for _ = 1, 10 do
                if not foundLog.Parent or not running or treeJob ~= job or character ~= player.Character then break end
                ownership:FireServer(foundLog)
                ownership:FireServer(wood)
                drag:FireServer(foundLog)
                task.wait(.1)
            end
            local destination = (original * CFrame.new(0, 3, -6)).Position
            for _ = 1, 20 do
                if not foundLog.Parent or not running or treeJob ~= job or character ~= player.Character then break end
                ownership:FireServer(foundLog)
                drag:FireServer(foundLog)
                foundLog:MoveTo(destination)
                movedLog = true
                task.wait(.1)
            end
        end
    end)
    connection:Disconnect()
    if root.Parent and player.Character == character then root.CFrame = original end
    treeBusy = false
    if not running then return end
    if not success then tell("Tree request failed: " .. tostring(err))
    elseif movedLog then tell("Tree move requested. Check whether the server accepted it.")
    elseif foundLog then tell("The log disappeared before it could be moved.")
    else tell("No log appeared within 20 seconds. The server may have rejected the cut.") end
end
local bringRow = row(36)
button(bringRow, "BRING ONE TREE", nil, nil, function() task.spawn(bringTree) end)
