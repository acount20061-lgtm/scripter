repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

_G.AutoSell = false
_G.AutoBuy = false
_G.ItemFarm = false
_G.ItemESP = false
_G.FlySpeed = 150
_G.PickupDistance = 3.5
_G.AntiAFK = false
_G.StandaloneNoClip = false
_G.AutoRespawn = true

_G.SelectedItems = {
    ["Ancient Scroll"] = false,
    ["Blue Candy"] = false,
    ["Caesar's Headband"] = false,
    ["Christmas Present"] = false,
    ["Clackers"] = false,
    ["Diamond"] = false,
    ["Dio's Diary"] = false,
    ["Gold Coin"] = false,
    ["Gold Umbrella"] = false,
    ["Green Candy"] = false,
    ["Lucky Arrow"] = false,
    ["Lucky Stone Mask"] = false,
    ["Mysterious Arrow"] = false,
    ["Pure Rokakaka"] = false,
    ["Quinton's Glove"] = false,
    ["Red Candy"] = false,
    ["Rib Cage of The Saint's Corpse"] = false,
    ["Rokakaka"] = false,
    ["Steel Ball"] = false,
    ["Stone Mask"] = false,
    ["Yellow Candy"] = false,
    ["Zepellin's Headband"] = false,
    ["Zeppeli's Hat"] = false,
}

local bannedCoordinates = {}
local espObjects = {}
local itemCache = {}
local lastCacheRefresh = 0
local CACHE_REFRESH_INTERVAL = 1.25
local BAN_TTL = 45

local farmThreadActive = false
local farmStatusText = "Waiting..."

local flightState
local noclipConnection
local antiAfkConnection

local function setFarmStatus(text)
    farmStatusText = text
end

local function isInvalidItemPart(obj)
    if not obj then return true end
    local current = obj
    while current and current ~= workspace do
        if current:IsA("Backpack") then return true end
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then return true end
        current = current.Parent
    end
    return false
end

local function cleanupBannedCoordinates()
    local now = tick()
    for i = #bannedCoordinates, 1, -1 do
        if now - bannedCoordinates[i].time > BAN_TTL then table.remove(bannedCoordinates, i) end
    end
end

local function isCoordinateBanned(pos)
    cleanupBannedCoordinates()
    for _, entry in ipairs(bannedCoordinates) do
        if (pos - entry.pos).Magnitude < 3 then return true end
    end
    return false
end

local function banCoordinate(pos)
    table.insert(bannedCoordinates, { pos = pos, time = tick() })
end

local function resolveItemFromPrompt(desc)
    if not desc or not desc:IsA("ProximityPrompt") or not desc.Parent then return nil end
    local parent = desc.Parent
    local model = parent:IsA("Model") and parent or parent.Parent
    local itemName = ""
    if _G.SelectedItems[parent.Name] ~= nil then
        itemName = parent.Name
    elseif model and _G.SelectedItems[model.Name] ~= nil then
        itemName = model.Name
    elseif desc.ObjectText and _G.SelectedItems[desc.ObjectText] ~= nil then
        itemName = desc.ObjectText
    end
    if itemName == "" then return nil end
    local targetPart = parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart") or (model and model:FindFirstChildWhichIsA("BasePart"))
    if not targetPart or targetPart.Transparency >= 1 then return nil end
    if isCoordinateBanned(targetPart.Position) or isInvalidItemPart(targetPart) then return nil end
    if not desc.Enabled then return nil end
    return { prompt = desc, part = targetPart, parent = parent, name = itemName, position = targetPart.Position }
end

local function anyItemSelected()
    for _, selected in pairs(_G.SelectedItems) do if selected then return true end end
    return false
end

local function shouldFarmItem(itemName)
    if not anyItemSelected() then return true end
    return _G.SelectedItems[itemName] == true
end

local function refreshItemCache()
    local now = tick()
    if now - lastCacheRefresh < CACHE_REFRESH_INTERVAL then return itemCache end
    lastCacheRefresh = now
    table.clear(itemCache)
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local item = resolveItemFromPrompt(desc)
            if item and shouldFarmItem(item.name) then table.insert(itemCache, item) end
        end
    end
    return itemCache
end

local function getNearestItem(hrp)
    local nearest
    local shortest = math.huge
    for _, item in ipairs(refreshItemCache()) do
        if item.prompt:IsDescendantOf(workspace) and not isInvalidItemPart(item.parent) then
            local dist = (hrp.Position - item.position).Magnitude
            if dist < shortest then shortest = dist; nearest = item end
        end
    end
    return nearest, shortest
end

local function applyESP(part, name)
    if espObjects[part] then return end
    if not part or part.Transparency == 1 or isCoordinateBanned(part.Position) or isInvalidItemPart(part) then return end
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "YBA_Item_ESP"
    bgui.AlwaysOnTop = true
    bgui.Size = UDim2.new(0, 140, 0, 32)
    bgui.Adornee = part
    local text = Instance.new("TextLabel")
    text.Parent = bgui
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Text = name
    text.TextColor3 = Color3.fromRGB(0, 255, 255)
    text.TextSize = 14
    text.Font = Enum.Font.GothamBold
    text.TextStrokeTransparency = 0
    bgui.Parent = part
    espObjects[part] = bgui
end

local function clearESP()
    for part, gui in pairs(espObjects) do
        if gui then gui:Destroy() end
        espObjects[part] = nil
    end
    table.clear(espObjects)
end

local function getCharacter()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function zeroHrpVelocity(hrp)
    if not hrp then return end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

local function cleanupFlight()
    if not flightState then return end
    if flightState.tween then flightState.tween:Cancel() end
    if flightState.heartbeatConn then flightState.heartbeatConn:Disconnect() end
    if flightState.cframeValue then flightState.cframeValue:Destroy() end
    flightState = nil
end

local function stopFlight()
    cleanupFlight()
    if noclipConnection and not _G.StandaloneNoClip and not _G.ItemFarm then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

local function ensureNoClip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if not _G.ItemFarm and not _G.StandaloneNoClip then return end
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part ~= hrp then part.CanCollide = false end
        end
    end)
end

local function moveToItemAndPickup(item)
    if not item or not item.part or not item.part:IsDescendantOf(workspace) then return false end
    if not item.prompt or not item.prompt:IsDescendantOf(workspace) then return false end
    if isInvalidItemPart(item.parent) then return false end
    local char, hrp, hum = getCharacter()
    if not hrp or not hum then return false end
    cleanupFlight()
    ensureNoClip()
    local targetCFrame = CFrame.new(item.part.Position + Vector3.new(0, 1.2, 0))
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    local tweenTime = math.max(distance / _G.FlySpeed, 0.05)
    local cframeValue = Instance.new("CFrameValue")
    cframeValue.Name = "YBA_VirtualCFrame"
    cframeValue.Value = hrp.CFrame
    cframeValue.Parent = player
    local tween = TweenService:Create(cframeValue, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), { Value = targetCFrame })
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent then return end
        local currentHrp = char:FindFirstChild("HumanoidRootPart")
        if not currentHrp or not cframeValue.Parent then return end
        currentHrp.CFrame = cframeValue.Value
        zeroHrpVelocity(currentHrp)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part ~= currentHrp then part.CanCollide = false end
        end
    end)
    flightState = { cframeValue = cframeValue, tween = tween, heartbeatConn = heartbeatConn }
    local function shouldContinue()
        return _G.ItemFarm and item.part:IsDescendantOf(workspace) and not isInvalidItemPart(item.part) and item.prompt:IsDescendantOf(workspace)
    end
    tween:Play()
    local finished = false
    tween.Completed:Once(function() finished = true end)
    while not finished do
        if not shouldContinue() then cleanupFlight() return false end
        if not hrp or not hrp.Parent then cleanupFlight() return false end
        RunService.Heartbeat:Wait()
    end
    if not shouldContinue() then cleanupFlight() return false end
    targetCFrame = CFrame.new(item.part.Position + Vector3.new(0, 1.2, 0))
    cframeValue.Value = targetCFrame
    local currentHrp = char:FindFirstChild("HumanoidRootPart")
    if currentHrp then
        currentHrp.CFrame = targetCFrame
        currentHrp.AssemblyLinearVelocity = Vector3.zero
        currentHrp.AssemblyAngularVelocity = Vector3.zero
    end
    task.wait(0.05)
    if shouldContinue() then
        item.prompt.RequiresLineOfSight = false
        item.prompt.HoldDuration = 0
        fireproximityprompt(item.prompt, 0)
    end
    local pickedUp = not item.prompt:IsDescendantOf(workspace) or isInvalidItemPart(item.parent)
    cleanupFlight()
    return pickedUp
end

local function tryRespawn()
    if not _G.AutoRespawn then return end
    local _, _, hum = getCharacter()
    if hum and hum.Health <= 0 then
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remotes then
            local loadCharacter = remotes:FindFirstChild("LoadCharacter")
            if loadCharacter then loadCharacter:FireServer() end
        end
    end
end

local lastRemoteFireTime = 0
local REMOTE_DEBOUNCE_DELAY = 0.8

local function safeFireRemote(remote, ...)
    local now = tick()
    local timeSinceLastFire = now - lastRemoteFireTime
    if timeSinceLastFire < REMOTE_DEBOUNCE_DELAY then
        local waitTime = REMOTE_DEBOUNCE_DELAY - timeSinceLastFire
        task.wait(waitTime)
    end
    remote:FireServer(...)
    lastRemoteFireTime = tick()
end

local sellQueue = {}
local isSelling = false

local function processSellQueue()
    if isSelling then return end
    isSelling = true
    while #sellQueue > 0 do
        if not _G.AutoSell then break end
        local item = table.remove(sellQueue, 1)
        local backpack = player:FindFirstChild("Backpack")
        if item and backpack and item.Parent == backpack and item:IsA("Tool") and item.Name ~= "Lucky Arrow" then
            local char, _, hum = getCharacter()
            local remote = char and char:FindFirstChild("RemoteEvent")
            if remote and hum then
                hum:EquipTool(item)
                task.wait(0.45)
                safeFireRemote(remote, "EndDialogue", { Option = "Option1", Dialogue = "Dialogue5", NPC = "Merchant" })
                task.wait(0.35)
            end
        end
    end
    isSelling = false
end

local function queueItemForSale(item)
    if not _G.AutoSell then return end
    if not item or not item:IsA("Tool") or item.Name == "Lucky Arrow" then return end
    table.insert(sellQueue, item)
    task.spawn(processSellQueue)
end

local function setupBackpackListener(backpack)
    for _, item in ipairs(backpack:GetChildren()) do queueItemForSale(item) end
    backpack.ChildAdded:Connect(function(item)
        task.wait(0.35)
        queueItemForSale(item)
    end)
end

player.ChildAdded:Connect(function(child)
    if child.Name == "Backpack" then setupBackpackListener(child) end
end)
if player:FindFirstChild("Backpack") then setupBackpackListener(player.Backpack) end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UAKillerHub_GUI"
screenGui.Parent = player:PlayerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 450)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
titleLabel.Text = "UA Killer Hub | YBA"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 50)
statusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
statusLabel.Text = "Status: Waiting..."
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

local function createToggle(name, y, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 35)
    frame.Position = UDim2.new(0, 10, 0, y)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.Parent = mainFrame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.25, 0, 0, 25)
    button.Position = UDim2.new(0.7, 5, 0, 5)
    button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    button.Text = "OFF"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.Parent = frame
    button.MouseButton1Click:Connect(function()
        local currentState = button.Text == "ON"
        local newState = not currentState
        button.Text = newState and "ON" or "OFF"
        button.BackgroundColor3 = newState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(100, 100, 100)
        callback(newState)
    end)
    return button
end

local function createSlider(name, y, min, max, current, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.Position = UDim2.new(0, 10, 0, y)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.Parent = mainFrame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. current
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, 0, 0, 25)
    slider.Position = UDim2.new(0, 0, 0, 25)
    slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    slider.Text = ""
    slider.Parent = frame
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((current - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fill.Parent = slider
    slider.MouseButton1Down:Connect(function()
        local input = slider.MouseEnter:Wait()
        while input.UserInputState == Enum.UserInputState.Begin do
            local mousePos = input.MousePosition
            local sliderPos = slider.AbsolutePosition
            local sliderSize = slider.AbsoluteSize
            local percent = math.clamp((mousePos.X - sliderPos.X) / sliderSize.X, 0, 1)
            local value = math.floor(min + percent * (max - min))
            fill.Size = UDim2.new(percent, 0, 1, 0)
            label.Text = name .. ": " .. value
            callback(value)
            input = slider.MouseEnter:Wait()
        end
    end)
    return slider
end

local yOffset = 85
createToggle("Auto Farm", yOffset, function(value)
    _G.ItemFarm = value
    if not value then
        farmThreadActive = false
        setFarmStatus("Stopped")
        stopFlight()
        return
    end
    if farmThreadActive then return end
    farmThreadActive = true
    task.spawn(function()
        setFarmStatus("Searching items...")
        while _G.ItemFarm and farmThreadActive do
            tryRespawn()
            local _, hrp = getCharacter()
            if not hrp then
                setFarmStatus("Waiting for character...")
                task.wait(0.5)
                continue
            end
            local targetItem = getNearestItem(hrp)
            if not targetItem then
                setFarmStatus("No items found")
                task.wait(0.35)
                continue
            end
            setFarmStatus("Flying to: " .. targetItem.name)
            if moveToItemAndPickup(targetItem) then
                banCoordinate(targetItem.position)
                if espObjects[targetItem.part] then
                    espObjects[targetItem.part]:Destroy()
                    espObjects[targetItem.part] = nil
                end
                lastCacheRefresh = 0
            end
            task.wait(0.08)
        end
        farmThreadActive = false
        setFarmStatus("Stopped")
        stopFlight()
    end)
end)

yOffset = yOffset + 45
createToggle("ESP", yOffset, function(value) _G.ItemESP = value end)

yOffset = yOffset + 45
createToggle("Auto Sell", yOffset, function(value)
    _G.AutoSell = value
    if value then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do queueItemForSale(item) end
        end
    else
        table.clear(sellQueue)
    end
end)

yOffset = yOffset + 45
createToggle("Auto Buy (Lucky Arrow)", yOffset, function(value)
    _G.AutoBuy = value
    if value then
        task.spawn(function()
            while _G.AutoBuy do
                local char = player.Character
                local remote = char and char:FindFirstChild("RemoteEvent")
                if remote then safeFireRemote(remote, "PurchaseShopItem", { ItemName = "1x Lucky Arrow" }) end
                task.wait(2.5 + math.random() * 1.5)
            end
        end)
    end
end)

yOffset = yOffset + 45
createToggle("Anti-AFK", yOffset, function(value)
    _G.AntiAFK = value
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    if value then
        antiAfkConnection = player.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

yOffset = yOffset + 45
createToggle("NoClip", yOffset, function(value)
    _G.StandaloneNoClip = value
    if value then
        ensureNoClip()
    elseif not _G.ItemFarm and noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end)

yOffset = yOffset + 45
createToggle("Auto Respawn", yOffset, function(value) _G.AutoRespawn = value end)

yOffset = yOffset + 50
createSlider("Fly Speed", yOffset, 50, 350, 150, function(value) _G.FlySpeed = value end)

yOffset = yOffset + 55
createSlider("Pickup Distance", yOffset, 2, 8, 3.5, function(value) _G.PickupDistance = value end)

task.spawn(function()
    while task.wait(0.35) do statusLabel.Text = "Status: " .. farmStatusText end
end)

task.spawn(function()
    while true do
        task.wait(0.8)
        if _G.ItemESP then
            for _, item in ipairs(refreshItemCache()) do applyESP(item.part, item.name) end
        else
            clearESP()
        end
    end
end)
