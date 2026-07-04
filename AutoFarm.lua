local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- Налаштування збереження конфігу
local Window = Rayfield:CreateWindow({
    Name = "UA Killer Hub | YBA Final",
    LoadingTitle = "Завантаження конфігів...",
    LoadingSubtitle = "by acount20061-lgtm",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UAKillerHub", -- Папка в workspace твого експлойту
        FileName = "YBA_SaveData"
    }
})

local MainTab = Window:CreateTab("Головна", 4483362458)
local FarmTab = Window:CreateTab("Автофарм", 4483362534)

-- Змінні
_G.ItemFarm = false
_G.StepDistance = 25  
_G.StepDelay = 0.04   
local JP_Value = 50
local bannedCoordinates = {}
local lastPickedCFrame = nil 

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

-- Гак на висоту стрибка
task.spawn(function()
    while task.wait(0.5) do
        if Player.Character and Player.Character:FindFirstChild("Humanoid") then
            Player.Character.Humanoid.JumpPower = JP_Value
        end
    end
end)

MainTab:CreateSlider({
    Name = "Висота стрибка (JumpPower)",
    Range = {50, 200},
    Increment = 1,
    CurrentValue = 50,
    Flag = "JumpPowerSlider", -- Прапорець для автозбереження
    Callback = function(Value)
        JP_Value = Value
    end,
})

-- Безпечний рух (Bypass)
local function antiKickMove(targetCFrame)
    local char = Player.Character
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
    Name = "Дистанція кроку (Швидкість)",
    Range = {5, 40},
    Increment = 1,
    CurrentValue = 25,
    Flag = "StepDistanceSave", -- Прапорець
    Callback = function(Value)
        _G.StepDistance = Value
    end,
})

FarmTab:CreateToggle({
    Name = "Увімкнути Автофарм",
    CurrentValue = false,
    Flag = "ItemFarmToggle", -- Прапорець
    Callback = function(Value)
        _G.ItemFarm = Value
        if Value then
            task.spawn(function()
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then lastPickedCFrame = hrp.CFrame end 
                
                while _G.ItemFarm do
                    task.wait(0.5) -- Оптимізована затримка
                    char = Player.Character
                    hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then continue end
                    
                    local targetItem = nil
                    local shortestDistance = math.huge
                    
                    for _, desc in pairs(Workspace:GetDescendants()) do
                        if not _G.ItemFarm then break end
                        
                        if desc:IsA("ProximityPrompt") and desc.Parent then
                            local parent = desc.Parent
                            local itemName = parent.Name
                            
                            -- Перевірка чи обраний предмет
                            if _G.SelectedItems[itemName] or (desc.ObjectText and _G.SelectedItems[desc.ObjectText]) then
                                local targetPart = parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart")
                                
                                if targetPart and targetPart.Transparency < 1 then
                                    local dist = (hrp.Position - targetPart.Position).Magnitude
                                    if dist < shortestDistance then
                                        shortestDistance = dist
                                        targetItem = {prompt = desc, part = targetPart}
                                    end
                                end
                            end
                        end
                    end
                    
                    if targetItem then
                        local targetCFrame = targetItem.part.CFrame * CFrame.new(0, 0.5, 0)
                        antiKickMove(targetCFrame)
                        task.wait(0.2)
                        
                        targetItem.prompt.RequiresLineOfSight = false
                        fireproximityprompt(targetItem.prompt)
                        task.wait(0.5) 
                        
                        if targetItem.prompt and targetItem.prompt.Parent then
                            -- Якщо не зібрався, відходимо щоб не зловити бан
                            if lastPickedCFrame then antiKickMove(lastPickedCFrame) end
                        else
                            lastPickedCFrame = targetCFrame
                        end
                    else
                        -- Якщо предметів немає, повертаємось на безпечну точку
                        if lastPickedCFrame and (hrp.Position - lastPickedCFrame.Position).Magnitude > 10 then
                            antiKickMove(lastPickedCFrame)
                        end
                    end
                end
            end)
        end
    end,
})

FarmTab:CreateLabel("Фільтр предметів:")

-- Створення тоглів для кожного предмета з прапорцями для збереження
local sortedItems = {}
for k, _ in pairs(_G.SelectedItems) do table.insert(sortedItems, k) end
table.sort(sortedItems)

for _, itemName in ipairs(sortedItems) do
    FarmTab:CreateToggle({
        Name = itemName,
        CurrentValue = false,
        Flag = "ItemSave_" .. itemName, -- Динамічний прапорець для автозбереження кожного предмета
        Callback = function(Value)
            _G.SelectedItems[itemName] = Value
        end,
    })
end

-- ВАЖЛИВО: Завантаження конфігу після створення всіх UI елементів
Rayfield:LoadConfiguration()
