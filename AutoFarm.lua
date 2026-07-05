-- Чекаємо повного завантаження
repeat task.wait() until game:IsLoaded()

local player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local autoLoadFile = "YBA_AutoLoad.txt"
local shouldAutoLoad = false

-- Відновлюємо папку
pcall(function()
    if makefolder and not isfolder("UAKillerHub") then
        makefolder("UAKillerHub")
    end
end)

-- Перевіряємо автозавантаження
pcall(function()
    if isfile and isfile(autoLoadFile) then
        shouldAutoLoad = (readfile(autoLoadFile) == "true")
    else
        if writefile then writefile(autoLoadFile, "false") end
    end
end)

-- Безпечне завантаження Rayfield
local RayfieldSuccess, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not RayfieldSuccess then return end

local Window = Rayfield:CreateWindow({
   Name = "UA Killer Hub | YBA",
   LoadingTitle = "Завантаження...",
   LoadingSubtitle = "by acount20061-lgtm | FAST Tween Bypass",
   ConfigurationSaving = { 
       Enabled = true, 
       FolderName = "UAKillerHub", 
       FileName = "YBA_Config" 
   }
})

local MainTab = Window:CreateTab("Головна", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362534)
local ShopTab = Window:CreateTab("Магазин", 4483362458)

-- ====================
-- Вкладка ГОЛОВНА
-- ====================
MainTab:CreateSection("Налаштування конфігу")

MainTab:CreateToggle({
   Name = "Автозавантаження конфігу при старті",
   CurrentValue = shouldAutoLoad,
   Callback = function(Value)
       pcall(function()
           if writefile then
               writefile(autoLoadFile, tostring(Value))
           end
       end)
   end,
})

MainTab:CreateButton({
   Name = "Завантажити конфіг вручну",
   Callback = function()
       pcall(function()
           Rayfield:LoadConfiguration()
       end)
   end,
})

MainTab:CreateSection("Характеристики")

local JP_Value = 50
task.spawn(function()
    while task.wait(0.1) do
        local p = game.Players.LocalPlayer
        if p and p.Character and p.Character:FindFirstChild("Humanoid") then
            p.Character.Humanoid.JumpPower = JP_Value
        end
    end
end)

MainTab:CreateSlider({
   Name = "Висота стрибка (JumpPower)",
   Range = {50, 200},
   Increment = 1,
   CurrentValue = 50,
   Flag = "JumpPower_Slider", 
   Callback = function(Value)
       JP_Value = Value
   end,
})

-- ====================
-- Вкладка МАГАЗИН
-- ====================
_G.AutoSell = false
_G.AutoBuy = false

local sellQueue = {}
local isSelling = false

local function processSellQueue()
    if isSelling then return end
    isSelling = true
    
    while #sellQueue > 0 do
        if not _G.AutoSell then break end
        
        local item = table.remove(sellQueue, 1)
        if item and item.Parent == player.Backpack and item:IsA("Tool") and item.Name ~= "Lucky Arrow" then
            local character = player.Character
            local remote = character and character:FindFirstChild("RemoteEvent")
            local hum = character and character:FindFirstChild("Humanoid")
            
            if remote and hum then
                hum:EquipTool(item)
                task.wait(0.4) 
                
                remote:FireServer("EndDialogue", {
                    ["Option"] = "Option1", 
                    ["Dialogue"] = "Dialogue5", 
                    ["NPC"] = "Merchant"
                })
                
                task.wait(0.3) 
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
        task.wait(0.3) 
        queueItemForSale(item)
    end)
end

player.ChildAdded:Connect(function(child)
    if child.Name == "Backpack" then setupBackpackListener(child) end
end)

if player:FindFirstChild("Backpack") then
    setupBackpackListener(player.Backpack)
end

ShopTab:CreateToggle({
   Name = "Автопродаж (Крім Lucky Arrow)",
   CurrentValue = false,
   Flag = "AutoSell_Toggle",
   Callback = function(Value)
       _G.AutoSell = Value
       if Value then
           local backpack = player:FindFirstChild("Backpack")
           if backpack then
               for _, item in ipairs(backpack:GetChildren()) do
                   queueItemForSale(item)
               end
           end
       else
           sellQueue = {} 
       end
   end,
})

ShopTab:CreateToggle({
   Name = "Автокупівля (Lucky Arrow)",
   CurrentValue = false,
   Flag = "AutoBuy_Toggle",
   Callback = function(Value)
       _G.AutoBuy = Value
       if Value then
           task.spawn(function()
               while _G.AutoBuy do
                   local char = player.Character
                   local remote = char and char:FindFirstChild("RemoteEvent")
                   if remote then
                       remote:FireServer("PurchaseShopItem", {["ItemName"] = "1x Lucky Arrow"})
                   end
                   task.wait(2.5 + math.random() * 1.5) 
               end
           end)
       end
   end,
})

-- ====================
-- Вкладка АВТОФАРМ (МАКСИМАЛЬНА ШВИДКІСТЬ)
-- ====================
_G.ItemFarm = false
_G.ItemESP = false
_G.TweenSpeed = 175 -- ШВИДКІСТЬ ЯК НА ВІДЕО

local bannedCoordinates = {} 
local espObjects = {}

_G.SelectedItems = {
    ["Ancient Scroll"] = false, ["Blue Candy"] = false, ["Caesar's Headband"] = false,
    ["Christmas Present"] = false, ["Clackers"] = false, ["Diamond"] = false,
    ["Dio's Diary"] = false, ["Gold Coin"] = false, ["Gold Umbrella"] = false,
    ["Green Candy"] = false, ["Lucky Arrow"] = false, ["Lucky Stone Mask"] = false,
    ["Mysterious Arrow"] = false, ["Pure Rokakaka"] = false, ["Quinton's Glove"] = false,
    ["Red Candy"] = false, ["Rib Cage of The Saint's Corpse"] = false, ["Rokakaka"] = false,
    ["Steel Ball"] = false, ["Stone Mask"] = false, ["Yellow Candy"] = false,
    ["Zepellin's Headband"] = false, ["Zeppeli's Hat"] = false
}

local function isCoordinateBanned(pos)
    for _, bannedPos in ipairs(bannedCoordinates) do
        if (pos - bannedPos).Magnitude < 3 then return true end
    end
    return false
end

local function applyESP(part, name)
    if espObjects[part] then return end
    if not part or part.Transparency == 1 or isCoordinateBanned(part.Position) then return end

    local bgui = Instance.new("BillboardGui")
    bgui.Name = "YBA_Item_ESP"
    bgui.AlwaysOnTop = true
    bgui.Size = UDim2.new(0, 120, 0, 30)
    bgui.Adornee = part

    local text = Instance.new("TextLabel")
    text.Parent = bgui
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Text = name
    text.TextColor3 = Color3.fromRGB(0, 255, 255) 
    text.TextSize = 14
    text.Font = Enum.Font.SourceSansBold
    text.TextStrokeTransparency = 0 

    bgui.Parent = part
    espObjects[part] = bgui
end

task.spawn(function()
    while true do
        task.wait(0.7)
        if _G.ItemESP then
            for _, desc in pairs(workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Parent then
                    local parent = desc.Parent
                    local model = parent:IsA("Model") and parent or parent.Parent
                    
                    local itemName = ""
                    if _G.SelectedItems[parent.Name] ~= nil then itemName = parent.Name
                    elseif model and _G.SelectedItems[model.Name] ~= nil then itemName = model.Name
                    elseif desc.ObjectText and _G.SelectedItems[desc.ObjectText] ~= nil then itemName = desc.ObjectText end

                    if itemName ~= "" then
                        local targetPart = parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart") or (model and model:FindFirstChildWhichIsA("BasePart"))
                        if targetPart and targetPart.Transparency < 1 and not isCoordinateBanned(targetPart.Position) then
                            applyESP(targetPart, itemName)
                        end
                    end
                end
            end
        else
            for part, gui in pairs(espObjects) do
                if gui then gui:Destroy() end
            end
            table.clear(espObjects)
        end
    end
end)

local noclipConnection
local currentTween
local currentBV

local function stopMovement()
    if currentTween then currentTween:Cancel(); currentTween = nil end
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    if currentBV then currentBV:Destroy(); currentBV = nil end
end

local function antiKickTweenMove(targetCFrame)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    stopMovement() 

    -- Створюємо нульову гравітацію, щоб летіти рівно
    currentBV = Instance.new("BodyVelocity")
    currentBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    currentBV.Velocity = Vector3.new(0, 0, 0)
    currentBV.Parent = hrp

    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local distance = (startPos - endPos).Magnitude
    
    -- Розрахунок часу для МАКСИМАЛЬНОЇ швидкості
    local timeToTravel = distance / _G.TweenSpeed
    -- Запобіжник: якщо предмет дуже близько, летимо не менше 0.1 секунди, щоб не телепортувало миттєво (це кік)
    if timeToTravel < 0.1 then timeToTravel = 0.1 end
    
    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    noclipConnection = RunService.Stepped:Connect(function()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then 
                    part.CanCollide = false 
                end
            end
        end
    end)
    
    currentTween:Play()
    currentTween.Completed:Wait() 
    
    stopMovement() 
    task.wait(0.1) -- Менша затримка після прильоту
end

FarmTab:CreateLabel("Швидкість як на відео: 150-200")

FarmTab:CreateSlider({
   Name = "Швидкість польоту (Tween Speed)",
   Range = {50, 350}, 
   Increment = 5,
   CurrentValue = 175, 
   Flag = "TweenSpeed_Slider", 
   Callback = function(Value)
       _G.TweenSpeed = Value
   end,
})

FarmTab:CreateToggle({
   Name = "Увімкнути Глобальний ESP",
   CurrentValue = false,
   Flag = "ESP_Toggle", 
   Callback = function(Value)
       _G.ItemESP = Value
   end,
})

FarmTab:CreateToggle({
   Name = "Увімкнути Автофарм",
   CurrentValue = false,
   Flag = "ItemFarmToggle",
   Callback = function(Value)
       _G.ItemFarm = Value
       if Value then
           task.spawn(function()
               while _G.ItemFarm do
                   task.wait(0.05) -- Зменшив затримку циклу для більшої динаміки
                   local char = player.Character
                   local hrp = char and char:FindFirstChild("HumanoidRootPart")
                   if not hrp then task.wait(0.5) continue end
                   
                   local anySelected = false
                   for _, isSelected in pairs(_G.SelectedItems) do
                       if isSelected then anySelected = true; break end
                   end
                   
                   local targetItem = nil
                   local shortestDistance = math.huge
                   
                   for _, desc in pairs(workspace:GetDescendants()) do
                       if not _G.ItemFarm then break end
                       
                       if desc:IsA("ProximityPrompt") and desc.Parent then
                           local parent = desc.Parent
                           local model = parent:IsA("Model") and parent or parent.Parent
                           
                           if model and model:IsA("Model") and (model:FindFirstChildOfClass("Humanoid") or parent:FindFirstChildOfClass("Humanoid")) then
                               continue
                           end
                           
                           local itemName = ""
                           if _G.SelectedItems[parent.Name] ~= nil then itemName = parent.Name
                           elseif model and _G.SelectedItems[model.Name] ~= nil then itemName = model.Name
                           elseif desc.ObjectText and _G.SelectedItems[desc.ObjectText] ~= nil then itemName = desc.ObjectText end
                           
                           if itemName ~= "" then
                               local shouldPickup = not anySelected or _G.SelectedItems[itemName]
                               
                               if shouldPickup then
                                   local targetPart = parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart") or (model and model:FindFirstChildWhichIsA("BasePart"))
                                   
                                   if targetPart and targetPart.Transparency < 1 and not isCoordinateBanned(targetPart.Position) then
                                       local dist = (hrp.Position - targetPart.Position).Magnitude
                                       if dist < shortestDistance then
                                            shortestDistance = dist
                                            targetItem = {prompt = desc, part = targetPart, parent = parent}
                                       end
                                   end
                               end
                           end
                       end
                   end
                   
                   if targetItem then
                       local targetCFrame = targetItem.part.CFrame * CFrame.new(0, 2.5, 0)
                       local targetPos = targetItem.part.Position
                       
                       antiKickTweenMove(targetCFrame)
                       
                       if not _G.ItemFarm then break end 
                       
                       targetItem.prompt.RequiresLineOfSight = false
                       fireproximityprompt(targetItem.prompt)
                       task.wait(0.2) -- Зменшив затримку після підбирання
                       
                       if targetItem.prompt and targetItem.prompt:IsDescendantOf(workspace) then
                           table.insert(bannedCoordinates, targetPos) 
                           
                           if espObjects[targetItem.part] then
                               espObjects[targetItem.part]:Destroy()
                               espObjects[targetItem.part] = nil
                           end
                       end
                   else
                       task.wait(0.2) 
                   end
               end
               stopMovement() 
           end)
       else
           stopMovement()
       end
   end,
})

FarmTab:CreateLabel("Фільтр предметів:")

local sortedItems = {}
for k, _ in pairs(_G.SelectedItems) do table.insert(sortedItems, k) end
table.sort(sortedItems)

for _, itemName in ipairs(sortedItems) do
   FarmTab:CreateToggle({
       Name = itemName,
       CurrentValue = false,
       Flag = "Filter_" .. itemName, 
       Callback = function(Value)
           _G.SelectedItems[itemName] = Value
       end,
   })
end

if shouldAutoLoad then
    pcall(function()
        local configPath = "UAKillerHub/YBA_Config.json" 
        if (isfile and isfile(configPath)) or not isfile then
            Rayfield:LoadConfiguration()
        else
            if writefile then writefile(autoLoadFile, "false") end
        end
    end)
end
