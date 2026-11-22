-- Lumber Tycoon 2 mobile controls. Run as a client script in Delta.
-- Log and structure interactions use LT2 remotes and depend on server behavior.
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
local selectedStructure
local selectingStructure = false
local selectionMode = "structure"
local selectionHighlight
local viewportConnection
local logConnection
local hotbarTools, hotbarConnections = {}, {}
local activeBtool
local btoolsEnabled = false
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
    for _, connection in ipairs(hotbarConnections) do connection:Disconnect() end
    for _, tool in ipairs(hotbarTools) do tool:Destroy() end
    for humanoid, values in pairs(savedHumanoids) do
        if humanoid.Parent then
            humanoid.WalkSpeed = values.walk
            humanoid.JumpHeight = values.jump
            humanoid.UseJumpPower = values.usePower
        end
    end
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
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
    local camera = workspace.CurrentCamera
    if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize()
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
watchCamera()
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
-- Touch-friendly building controls operate on models owned by the player.
local moveSelected, deleteSelected, rotateSelected
local function beginSelection(mode)
    selectedStructure = nil
    if selectionHighlight then selectionHighlight:Destroy(); selectionHighlight = nil end
    selectingStructure = true
    selectionMode = mode
    tell(mode == "structure" and "Tap a placed structure that you own." or "Tap an object or log that you own.")
end
local bRow = row(36)
button(bRow, "BTOOLS: SELECT OBJECT", nil, nil, function() beginSelection("object") end)
local selectRow = row(36)
button(selectRow, "SELECT PLACED STRUCTURE", nil, nil, function() beginSelection("structure") end)
connect(UserInputService.InputBegan, function(input, processed)
    if (not selectingStructure and not activeBtool) or processed then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local toolAction = not selectingStructure and activeBtool or nil
    local mode = toolAction == "rotate" and "structure" or (toolAction and "object" or selectionMode)
    local cameraNow = workspace.CurrentCamera
    local models = workspace:FindFirstChild("PlayerModels")
    local logs = workspace:FindFirstChild("LogModels")
    if not cameraNow or (mode == "structure" and not models) or (not models and not logs) then
        tell("Placed objects are unavailable."); return
    end
    local ray = cameraNow:ScreenPointToRay(input.Position.X, input.Position.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = player.Character and {player.Character} or {}
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    local model = hit and hit.Instance
    while model and model ~= workspace and model.Parent ~= models and (not logs or model.Parent ~= logs) do model = model.Parent end
    local owner = model and model:FindFirstChild("Owner")
    local kind = model and model:FindFirstChild("Type")
    local inOwnedFolder = model and (model.Parent == models or (logs and model.Parent == logs))
    local structure = model and model:IsA("Model") and model.Parent == models and kind and kind.Value == "Structure" and model.PrimaryPart
    if not inOwnedFolder or not model:IsA("Model") or not owner or owner.Value ~= player or (mode == "structure" and not structure) then
        tell(mode == "structure" and "Tap one of your own placed structures." or "Tap one of your own objects or logs.")
        return
    end
    selectingStructure = false
    selectedStructure = model
    if selectionHighlight then selectionHighlight:Destroy(); selectionHighlight = nil end
    selectionHighlight = make("Highlight", {Adornee = model, FillTransparency = .7, OutlineColor = colors.accent, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, model)
    local item = model:FindFirstChild("ItemName") or model:FindFirstChild("TreeClass")
    tell("Selected " .. (item and tostring(item.Value) or "object") .. ".")
    if toolAction == "move" then moveSelected()
    elseif toolAction == "delete" then deleteSelected()
    elseif toolAction == "rotate" then rotateSelected() end
end)
local function selectedOwnedObject()
    local model = selectedStructure
    local owner = model and model:FindFirstChild("Owner")
    if not model or not model.Parent or not owner or owner.Value ~= player then return nil end
    return model
end
moveSelected = function()
    local model = selectedOwnedObject()
    local _, _, root = characterParts()
    if not model or not root then tell("Select your object first."); return end
    local kind = model:FindFirstChild("Type")
    if kind and kind.Value == "Structure" then
        local placement = ReplicatedStorage:FindFirstChild("PlaceStructure")
        local remote = placement and placement:FindFirstChild("ClientPlacedStructure")
        if not model.PrimaryPart or not remote or not remote:IsA("RemoteEvent") then tell("Structure move is unavailable."); return end
        local target = (root.CFrame * CFrame.new(0, 0, -6)).Position
        local current = model.PrimaryPart.CFrame
        remote:FireServer(nil, current - current.Position + target, player, nil, model, true)
        tell("Structure move requested. Check whether the server accepted it.")
        return
    end
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local ownership = interaction and interaction:FindFirstChild("ClientRequestOwnership")
    local drag = interaction and interaction:FindFirstChild("ClientIsDragging")
    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not ownership or not ownership:IsA("RemoteEvent") or not drag or not drag:IsA("RemoteEvent") or not part then
        tell("Object move is unavailable."); return
    end
    local destination = (root.CFrame * CFrame.new(0, 3, -6)).Position
    tell("Moving selected object...")
    task.spawn(function()
        local moved = false
        local ok, err = pcall(function()
            for _ = 1, 20 do
                if not running or not model.Parent or not part:IsDescendantOf(model) or not selectedOwnedObject() or selectedStructure ~= model then break end
                ownership:FireServer(model)
                ownership:FireServer(part)
                drag:FireServer(model)
                model:PivotTo(model:GetPivot() + (destination - part.Position))
                moved = true
                task.wait(.1)
            end
        end)
        if not ok then tell("Object move failed: " .. tostring(err))
        elseif moved then tell("Object move requested. Check whether the server accepted it.")
        else tell("Object move cancelled.") end
    end)
end
deleteSelected = function()
    local model = selectedOwnedObject()
    if not model then tell("Select your object first."); return end
    local interaction = ReplicatedStorage:FindFirstChild("Interaction")
    local remote = interaction and interaction:FindFirstChild("DestroyStructure")
    if not remote or not remote:IsA("RemoteEvent") then tell("Object deletion is unavailable."); return end
    local ok, err = pcall(function()
        local ownership = interaction:FindFirstChild("ClientRequestOwnership")
        local drag = interaction:FindFirstChild("ClientIsDragging")
        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        if ownership and part then ownership:FireServer(part) end
        if drag then drag:FireServer(model) end
        remote:FireServer(model)
    end)
    if not ok then tell("Delete failed: " .. tostring(err)); return end
    selectedStructure = nil
    if selectionHighlight then selectionHighlight:Destroy(); selectionHighlight = nil end
    tell("Delete requested. Check whether the server accepted it.")
end
rotateSelected = function()
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
end
local toolRow = row(36)
button(toolRow, "MOVE TO ME", UDim2.new(0, 0, 0, 0), UDim2.new(.5, -4, 1, 0), moveSelected)
button(toolRow, "DELETE", UDim2.new(.5, 4, 0, 0), UDim2.new(.5, -4, 1, 0), deleteSelected)
local rotateRow = row(36)
button(rotateRow, "ROTATE SELECTED 90°", nil, nil, rotateSelected)
local function createHotbarTools(backpack)
    activeBtool = nil
    for _, connection in ipairs(hotbarConnections) do connection:Disconnect() end
    for _, tool in ipairs(hotbarTools) do tool:Destroy() end
    hotbarConnections, hotbarTools = {}, {}
    local definitions = {
        {name = "LT2 Move", action = "move", tip = "Tap your object to move it to you"},
        {name = "LT2 Delete", action = "delete", tip = "Tap your object to request deletion"},
        {name = "LT2 Rotate", action = "rotate", tip = "Tap your structure to rotate it"},
    }
    for _, definition in ipairs(definitions) do
        local tool = make("Tool", {Name = definition.name, ToolTip = definition.tip, RequiresHandle = false, CanBeDropped = false}, backpack)
        table.insert(hotbarTools, tool)
        table.insert(hotbarConnections, tool.Equipped:Connect(function()
            activeBtool = definition.action
            selectingStructure = false
            tell(definition.tip .. ".")
        end))
        table.insert(hotbarConnections, tool.Unequipped:Connect(function()
            if activeBtool == definition.action then activeBtool = nil end
        end))
    end
end
local function giveHotbarTools()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then tell("Wait for your backpack to load."); return end
    if btoolsEnabled and #hotbarTools == 3 then
        local allPresent = true
        for _, tool in ipairs(hotbarTools) do
            if tool.Parent ~= backpack and tool.Parent ~= player.Character then allPresent = false; break end
        end
        if allPresent then tell("BTOOLS are already in your hotbar or backpack."); return end
    end
    createHotbarTools(backpack)
    btoolsEnabled = true
    tell("BTOOLS added. Equip one, then tap your object.")
end
local hotbarRow = row(36)
button(hotbarRow, "ADD BTOOLS TO HOTBAR", nil, nil, giveHotbarTools)
connect(player.CharacterAdded, function(character)
    if not btoolsEnabled then return end
    task.spawn(function()
        local backpack = player:WaitForChild("Backpack", 10)
        if running and player.Character == character and backpack then createHotbarTools(backpack) end
    end)
end)
section("BRING TREE")
-- Only logs that appear after the tools start can be identified as recent.
local recentLog, logFolder, pendingCut
local logSequence, recentSequence = 0, 0
local treeTypes = {{"Oak", "Generic"}, {"Cherry", "Cherry"}, {"Gold", "GoldSwampy"}, {"Cavecrawler", "CaveCrawler"}, {"Frost", "Frost"}, {"Lava", "Volcano"}, {"Elm", "Oak"}, {"Walnut", "Walnut"}, {"Birch", "Birch"}, {"Snowglow", "SnowGlow"}, {"Pine", "GreenSwampy"}, {"Koa", "Koa"}, {"Palm", "Palm"}, {"Spook", "Spooky"}, {"Sinister", "SpookyNeon"}, {"End Times", "LoneCave"}}
local treeIndex = 1
local treeRow = row(36)
local treeLabel = button(treeRow, "TREE: Oak", UDim2.new(0, 0, 0, 0), UDim2.new(.7, -4, 1, 0), nil)
button(treeRow, "NEXT ›", UDim2.new(.7, 4, 0, 0), UDim2.new(.3, -4, 1, 0), function()
    treeIndex = treeIndex % #treeTypes + 1
    treeLabel.Text = "TREE: " .. treeTypes[treeIndex][1]
end)
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

local function findTree(treeClass)
    for _, region in ipairs(workspace:GetChildren()) do
        if region.Name == "TreeRegion" then
            for _, candidate in ipairs(region:GetChildren()) do
                local class = candidate:FindFirstChild("TreeClass")
                local owner = candidate:FindFirstChild("Owner")
                local wood = candidate:FindFirstChild("WoodSection")
                if candidate:IsA("Model") and class and class:IsA("StringValue") and class.Value == treeClass
                    and candidate:FindFirstChild("CutEvent") and wood and wood:IsA("BasePart")
                    and (not owner or (owner:IsA("ObjectValue") and (owner.Value == nil or owner.Value == player))) then
                    return candidate, wood
                end
            end
        end
    end
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
local bringRow = row(36)
button(bringRow, "BRING ONE TREE", nil, nil, function() startTreeRequest(true) end)
local recentRow = row(36)
button(recentRow, "BRING RECENT TREE", nil, nil, function() startTreeRequest(false) end)
