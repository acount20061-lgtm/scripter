-- Чекаємо повного завантаження
repeat task.wait() until game:IsLoaded()

local autoLoadFile = "YBA_AutoLoad.txt"
local shouldAutoLoad = false

-- Відновлюємо папку, якщо ти її видалив
pcall(function()
    if makefolder and not isfolder("UAKillerHub") then
        makefolder("UAKillerHub")
    end
end)

-- Перевіряємо наш незалежний файл автозавантаження
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
   LoadingSubtitle = "by acount20061-lgtm",
   ConfigurationSaving = { 
       Enabled = true, 
       FolderName = "UAKillerHub", 
       FileName = "YBA_Config" 
   }
})

local MainTab = Window:CreateTab("Головна", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362534)

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
           Rayfield:Notify({
               Title = "Успіх",
               Content = "Конфіг завантажено!",
               Duration = 3,
               Image = 4483362458,
           })
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

_G.ItemFarm = false
_G.ItemESP = false
_G.StepDistance = 25  
_G.StepDelay = 0.04   

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
        if (pos - bannedPos).Magnitude < 3 then 
            return true
        end
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

local function antiKickMove(targetCFrame)
    local char = game.Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local startPos = hrp.Position
    local endPos = targetCFrame.Position
    local distance = (startPos - endPos).Magnitude
    local steps = math.floor(distance / _G.StepDistance)
    
    if steps > 0 then
        for i = 1, steps do
            if not _G.ItemFarm then break end
            local alpha = i / steps
            local nextPos = startPos:Lerp(endPos, alpha)
            
            hrp.CFrame = CFrame.new(nextPos)
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
            task.wait(_G.StepDelay)
        end
    end
    
    if _G.ItemFarm then
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    end
end

FarmTab:CreateSlider({
   Name = "Дистанція кроку (Step Distance)",
   Range = {5, 35}, 
   Increment = 1,
   CurrentValue = 25,
   Flag = "StepDist_Slider", 
   Callback = function(Value)
       _G.StepDistance = Value
   end,
})

FarmTab:CreateSlider({
   Name = "Затримка кроку (Step Delay)",
   Range = {0.01, 0.2},
   Increment = 0.01,
   CurrentValue = 0.04,
   Flag = "StepDelay_Slider", 
   Callback = function(Value)
       _G.StepDelay = Value
   end,
})

FarmTab:CreateToggle({
   Name = "Увімкнути Глобальний ESP (Вся карта)",
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
                   task.wait(0.1) 
                   local char = game.Players.LocalPlayer.Character
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
                       local targetCFrame = targetItem.part.CFrame * CFrame.new(0, 0.5, 0)
                       local targetPos = targetItem.part.Position
                       
                       antiKickMove(targetCFrame)
                       task.wait(0.12)
                       
                       targetItem.prompt.RequiresLineOfSight = false
                       fireproximityprompt(targetItem.prompt)
                       task.wait(0.3) 
                       
                       if targetItem.prompt and targetItem.prompt:IsDescendantOf(workspace) then
                           table.insert(bannedCoordinates, targetPos) 
                           
                           if espObjects[targetItem.part] then
                               espObjects[targetItem.part]:Destroy()
                               espObjects[targetItem.part] = nil
                           end
                       end
                   else
                       task.wait(0.5) 
                   end
               end
           end)
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

-- Перевіряємо, чи існує сам файл конфігу Rayfield перед завантаженням
if shouldAutoLoad then
    pcall(function()
        -- Назва файлу, яку створює Rayfield
        local configPath = "UAKillerHub/YBA_Config.json" 
        -- Якщо файл існує (в тебе експлойт підтримує isfile), тоді завантажуємо
        if (isfile and isfile(configPath)) or not isfile then
            Rayfield:LoadConfiguration()
        else
            -- Якщо файлу нема, вимикаємо автозавантаження, щоб не було проблем наступного разу
            if writefile then writefile(autoLoadFile, "false") end
        end
    end)
end
