-- UA Killer Hub | YBA — покращена версія
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local autoLoadFile = "YBA_AutoLoad.txt"
local shouldAutoLoad = false

pcall(function()
    if makefolder and not isfolder("UAKillerHub") then
        makefolder("UAKillerHub")
    end
end)

pcall(function()
    if isfile and isfile(autoLoadFile) then
        shouldAutoLoad = (readfile(autoLoadFile) == "true")
    elseif writefile then
        writefile(autoLoadFile, "false")
    end
end)

local RayfieldSuccess, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not RayfieldSuccess then return end

-- ====================
-- ГЛОБАЛЬНІ НАЛАШТУВАННЯ
-- ====================
_G.AutoSell = false
_G.AutoBuy = false
_G.ItemFarm = false
_G.ItemESP = false
_G.FlySpeed = 150
_G.HoverHeight = 2.5
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
local farmStatusText = "Очікування..."
local itemsCollected = 0

local currentAlignPos
local currentAlignOri
local currentAttachment
local noclipConnection
local antiAfkConnection

-- ====================
-- ДОПОМІЖНІ ФУНКЦІЇ
-- ====================
local function setFarmStatus(text)
    farmStatusText = text
end

local function isHeldByPlayer(obj)
    if not obj then return true end
    local current = obj
    while current and current ~= workspace do
        if current:IsA("Backpack") then
            return true
        end
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
            local hum = current:FindFirstChildOfClass("Humanoid")
            if hum and Players:GetPlayerFromCharacter(current) then
                return true
            end
        end
        if current:IsA("Tool") and current.Parent and current.Parent:IsA("Model") then
            local owner = Players:GetPlayerFromCharacter(current.Parent)
            if owner then return true end
        end
        current = current.Parent
    end
    return false
end

local function cleanupBannedCoordinates()
    local now = tick()
    for i = #bannedCoordinates, 1, -1 do
        if now - bannedCoordinates[i].time > BAN_TTL then
            table.remove(bannedCoordinates, i)
        end
    end
end

local function isCoordinateBanned(pos)
    cleanupBannedCoordinates()
    for _, entry in ipairs(bannedCoordinates) do
        if (pos - entry.pos).Magnitude < 3 then
            return true
        end
    end
    return false
end

local function banCoordinate(pos)
    table.insert(bannedCoordinates, { pos = pos, time = tick() })
end

local function resolveItemFromPrompt(desc)
    if not desc or not desc:IsA("ProximityPrompt") or not desc.Parent then
        return nil
    end

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

    if itemName == "" then
        return nil
    end

    local targetPart = parent:IsA("BasePart") and parent
        or parent:FindFirstChildWhichIsA("BasePart")
        or (model and model:FindFirstChildWhichIsA("BasePart"))

    if not targetPart or targetPart.Transparency >= 1 then
        return nil
    end
    if isCoordinateBanned(targetPart.Position) or isHeldByPlayer(targetPart) then
        return nil
    end
    if not desc.Enabled then
        return nil
    end

    return {
        prompt = desc,
        part = targetPart,
        parent = parent,
        name = itemName,
        position = targetPart.Position,
    }
end

local function anyItemSelected()
    for _, selected in pairs(_G.SelectedItems) do
        if selected then return true end
    end
    return false
end

local function shouldFarmItem(itemName)
    if not anyItemSelected() then
        return true
    end
    return _G.SelectedItems[itemName] == true
end

local function refreshItemCache()
    local now = tick()
    if now - lastCacheRefresh < CACHE_REFRESH_INTERVAL then
        return itemCache
    end

    lastCacheRefresh = now
    table.clear(itemCache)

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local item = resolveItemFromPrompt(desc)
            if item and shouldFarmItem(item.name) then
                table.insert(itemCache, item)
            end
        end
    end

    return itemCache
end

local function getNearestItem(hrp)
    local nearest
    local shortest = math.huge

    for _, item in ipairs(refreshItemCache()) do
        if item.prompt:IsDescendantOf(workspace) and not isHeldByPlayer(item.parent) then
            local dist = (hrp.Position - item.position).Magnitude
            if dist < shortest then
                shortest = dist
                nearest = item
            end
        end
    end

    return nearest, shortest
end

local function applyESP(part, name)
    if espObjects[part] then return end
    if not part or part.Transparency == 1 or isCoordinateBanned(part.Position) or isHeldByPlayer(part) then
        return
    end

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

local function stopFlight()
    if currentAlignPos then currentAlignPos:Destroy(); currentAlignPos = nil end
    if currentAlignOri then currentAlignOri:Destroy(); currentAlignOri = nil end
    if currentAttachment then currentAttachment:Destroy(); currentAttachment = nil end

    if noclipConnection and not _G.StandaloneNoClip then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    local _, hrp = getCharacter()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function ensureNoClip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if not _G.ItemFarm and not _G.StandaloneNoClip then return end
        local char = player.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function smoothFlyTo(targetPart)
    local char, hrp = getCharacter()
    if not hrp or not targetPart then return false end

    stopFlight()
    ensureNoClip()

    currentAttachment = Instance.new("Attachment")
    currentAttachment.Parent = hrp

    currentAlignPos = Instance.new("AlignPosition")
    currentAlignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    currentAlignPos.Attachment0 = currentAttachment
    currentAlignPos.MaxForce = math.huge
    currentAlignPos.Responsiveness = 120
    currentAlignPos.RigidityEnabled = false
    currentAlignPos.Parent = hrp

    currentAlignOri = Instance.new("AlignOrientation")
    currentAlignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    currentAlignOri.Attachment0 = currentAttachment
    currentAlignOri.MaxTorque = math.huge
    currentAlignOri.Responsiveness = 120
    currentAlignOri.RigidityEnabled = false
    currentAlignOri.Parent = hrp

    local lastPos = hrp.Position
    local stuckTimer = 0

    while _G.ItemFarm and targetPart:IsDescendantOf(workspace) and not isHeldByPlayer(targetPart) do
        char, hrp = getCharacter()
        if not hrp then break end

        local targetPos = targetPart.Position + Vector3.new(0, _G.HoverHeight, 0)
        local dist = (hrp.Position - targetPos).Magnitude

        currentAlignPos.MaxVelocity = _G.FlySpeed
        currentAlignPos.Position = targetPos
        currentAlignOri.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))

        if dist <= _G.PickupDistance then
            return true
        end

        local moved = (hrp.Position - lastPos).Magnitude
        if moved < 0.35 then
            stuckTimer += RunService.Heartbeat:Wait()
            if stuckTimer > 1.75 then
                hrp.CFrame = CFrame.new(hrp.Position + (targetPos - hrp.Position).Unit * 8, targetPos)
                stuckTimer = 0
            end
        else
            stuckTimer = 0
        end

        lastPos = hrp.Position
        RunService.Heartbeat:Wait()
    end

    stopFlight()
    return false
end

local function tryPickupItem(item)
    if not item or not item.prompt or not item.prompt:IsDescendantOf(workspace) then
        return false
    end
    if isHeldByPlayer(item.parent) then
        return false
    end

    item.prompt.RequiresLineOfSight = false
    item.prompt.HoldDuration = 0

    for _ = 1, 3 do
        if not item.prompt:IsDescendantOf(workspace) then break end
        fireproximityprompt(item.prompt, 0)
        task.wait(0.15)
        if not item.prompt:IsDescendantOf(workspace) or isHeldByPlayer(item.parent) then
            return true
        end
    end

    return not item.prompt:IsDescendantOf(workspace)
end

local function tryRespawn()
    if not _G.AutoRespawn then return end
    local _, _, hum = getCharacter()
    if hum and hum.Health <= 0 then
        pcall(function()
            local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            remote = remote and remote:FindFirstChild("LoadCharacter")
            if remote then remote:FireServer() end
        end)
    end
end

-- ====================
-- UI
-- ====================
local Window = Rayfield:CreateWindow({
    Name = "UA Killer Hub | YBA",
    LoadingTitle = "Завантаження...",
    LoadingSubtitle = "by acount20061-lgtm | PERFECT FLY BYPASS+",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UAKillerHub",
        FileName = "YBA_Config",
    },
})

local MainTab = Window:CreateTab("Головна", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362534)
local ShopTab = Window:CreateTab("Магазин", 4483362458)
local MiscTab = Window:CreateTab("Інше", 4483362458)

-- ====================
-- ГОЛОВНА
-- ====================
MainTab:CreateSection("Налаштування конфігу")

MainTab:CreateToggle({
    Name = "Автозавантаження конфігу при старті",
    CurrentValue = shouldAutoLoad,
    Callback = function(value)
        pcall(function()
            if writefile then writefile(autoLoadFile, tostring(value)) end
        end)
    end,
})

MainTab:CreateButton({
    Name = "Завантажити конфіг вручну",
    Callback = function()
        pcall(function() Rayfield:LoadConfiguration() end)
    end,
})

MainTab:CreateSection("Характеристики")

local JP_Value = 50
local function applyJumpPower()
    local _, _, hum = getCharacter()
    if hum then hum.JumpPower = JP_Value end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyJumpPower()
end)

task.spawn(function()
    while task.wait(0.15) do
        applyJumpPower()
    end
end)

MainTab:CreateSlider({
    Name = "Висота стрибка (JumpPower)",
    Range = { 50, 200 },
    Increment = 1,
    CurrentValue = 50,
    Flag = "JumpPower_Slider",
    Callback = function(value) JP_Value = value end,
})

-- ====================
-- МАГАЗИН
-- ====================
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
                remote:FireServer("EndDialogue", {
                    Option = "Option1",
                    Dialogue = "Dialogue5",
                    NPC = "Merchant",
                })
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
    for _, item in ipairs(backpack:GetChildren()) do
        queueItemForSale(item)
    end
    backpack.ChildAdded:Connect(function(item)
        task.wait(0.35)
        queueItemForSale(item)
    end)
end

player.ChildAdded:Connect(function(child)
    if child.Name == "Backpack" then setupBackpackListener(child) end
end)
if player:FindFirstChild("Backpack") then setupBackpackListener(player.Backpack) end

ShopTab:CreateToggle({
    Name = "Автопродаж (крім Lucky Arrow)",
    CurrentValue = false,
    Flag = "AutoSell_Toggle",
    Callback = function(value)
        _G.AutoSell = value
        if value then
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    queueItemForSale(item)
                end
            end
        else
            table.clear(sellQueue)
        end
    end,
})

ShopTab:CreateToggle({
    Name = "Автокупівля (Lucky Arrow)",
    CurrentValue = false,
    Flag = "AutoBuy_Toggle",
    Callback = function(value)
        _G.AutoBuy = value
        if value then
            task.spawn(function()
                while _G.AutoBuy do
                    local char = player.Character
                    local remote = char and char:FindFirstChild("RemoteEvent")
                    if remote then
                        remote:FireServer("PurchaseShopItem", { ItemName = "1x Lucky Arrow" })
                    end
                    task.wait(2.5 + math.random() * 1.5)
                end
            end)
        end
    end,
})

-- ====================
-- АВТОФАРМ
-- ====================
local statusLabel = FarmTab:CreateLabel("Статус: Очікування... | Зібрано: 0")

task.spawn(function()
    while task.wait(0.35) do
        pcall(function()
            statusLabel:Set("Статус: " .. farmStatusText .. " | Зібрано: " .. itemsCollected)
        end)
    end
end)

FarmTab:CreateSlider({
    Name = "Швидкість польоту",
    Range = { 50, 350 },
    Increment = 5,
    CurrentValue = 150,
    Flag = "FlySpeed_Slider",
    Callback = function(value) _G.FlySpeed = value end,
})

FarmTab:CreateSlider({
    Name = "Висота над предметом",
    Range = { 1, 8 },
    Increment = 0.5,
    CurrentValue = 2.5,
    Flag = "HoverHeight_Slider",
    Callback = function(value) _G.HoverHeight = value end,
})

FarmTab:CreateSlider({
    Name = "Дистанція підбору",
    Range = { 2, 8 },
    Increment = 0.5,
    CurrentValue = 3.5,
    Flag = "PickupDistance_Slider",
    Callback = function(value) _G.PickupDistance = value end,
})

FarmTab:CreateToggle({
    Name = "Увімкнути ESP",
    CurrentValue = false,
    Flag = "ESP_Toggle",
    Callback = function(value) _G.ItemESP = value end,
})

FarmTab:CreateToggle({
    Name = "Увімкнути автофарм",
    CurrentValue = false,
    Flag = "ItemFarmToggle",
    Callback = function(value)
        _G.ItemFarm = value
        if not value then
            farmThreadActive = false
            setFarmStatus("Зупинено")
            stopFlight()
            return
        end

        if farmThreadActive then return end
        farmThreadActive = true

        task.spawn(function()
            setFarmStatus("Пошук предметів...")
            while _G.ItemFarm and farmThreadActive do
                tryRespawn()

                local _, hrp = getCharacter()
                if not hrp then
                    setFarmStatus("Очікування персонажа...")
                    task.wait(0.5)
                    continue
                end

                local targetItem = getNearestItem(hrp)
                if not targetItem then
                    setFarmStatus("Предметів не знайдено")
                    task.wait(0.35)
                    continue
                end

                setFarmStatus("Лечу до: " .. targetItem.name)
                local arrived = smoothFlyTo(targetItem.part)
                if not _G.ItemFarm then break end

                if arrived and targetItem.prompt:IsDescendantOf(workspace) then
                    setFarmStatus("Підбираю: " .. targetItem.name)
                    if tryPickupItem(targetItem) then
                        itemsCollected += 1
                        banCoordinate(targetItem.position)
                        if espObjects[targetItem.part] then
                            espObjects[targetItem.part]:Destroy()
                            espObjects[targetItem.part] = nil
                        end
                        lastCacheRefresh = 0
                    end
                end

                task.wait(0.08)
            end

            farmThreadActive = false
            setFarmStatus("Зупинено")
            stopFlight()
        end)
    end,
})

FarmTab:CreateSection("Фільтр предметів")

FarmTab:CreateButton({
    Name = "Увімкнути всі предмети",
    Callback = function()
        for name in pairs(_G.SelectedItems) do
            _G.SelectedItems[name] = true
        end
        lastCacheRefresh = 0
    end,
})

FarmTab:CreateButton({
    Name = "Вимкнути всі предмети",
    Callback = function()
        for name in pairs(_G.SelectedItems) do
            _G.SelectedItems[name] = false
        end
        lastCacheRefresh = 0
    end,
})

local sortedItems = {}
for name in pairs(_G.SelectedItems) do
    table.insert(sortedItems, name)
end
table.sort(sortedItems)

for _, itemName in ipairs(sortedItems) do
    FarmTab:CreateToggle({
        Name = itemName,
        CurrentValue = false,
        Flag = "Filter_" .. itemName,
        Callback = function(value)
            _G.SelectedItems[itemName] = value
            lastCacheRefresh = 0
        end,
    })
end

-- ESP цикл (використовує кеш)
task.spawn(function()
    while true do
        task.wait(0.8)
        if _G.ItemESP then
            for _, item in ipairs(refreshItemCache()) do
                applyESP(item.part, item.name)
            end
        else
            clearESP()
        end
    end
end)

-- ====================
-- ІНШЕ
-- ====================
MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAFK_Toggle",
    Callback = function(value)
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
    end,
})

MiscTab:CreateToggle({
    Name = "NoClip (окремо від фарму)",
    CurrentValue = false,
    Flag = "StandaloneNoClip_Toggle",
    Callback = function(value)
        _G.StandaloneNoClip = value
        if value then
            ensureNoClip()
        elseif not _G.ItemFarm and noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end,
})

MiscTab:CreateToggle({
    Name = "Авто-респawn при смерті",
    CurrentValue = true,
    Flag = "AutoRespawn_Toggle",
    Callback = function(value)
        _G.AutoRespawn = value
    end,
})

MiscTab:CreateButton({
    Name = "Очистити заблоковані координати",
    Callback = function()
        table.clear(bannedCoordinates)
        lastCacheRefresh = 0
        Rayfield:Notify({
            Title = "UA Killer Hub",
            Content = "Чорний список координат очищено",
            Duration = 3,
        })
    end,
})

MiscTab:CreateButton({
    Name = "Скинути лічильник зібраних предметів",
    Callback = function()
        itemsCollected = 0
    end,
})

if shouldAutoLoad then
    pcall(function()
        local configPath = "UAKillerHub/YBA_Config.json"
        if (isfile and isfile(configPath)) or not isfile then
            Rayfield:LoadConfiguration()
        elseif writefile then
            writefile(autoLoadFile, "false")
        end
    end)
end

Rayfield:Notify({
    Title = "UA Killer Hub",
    Content = "Скрипт завантажено. Покращений політ, кеш предметів, Anti-AFK.",
    Duration = 4,
})
