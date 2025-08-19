-- Налаштування
local Settings = {
    AutoPickup = true,
    AutoSell = true,
    AntiAFK = true,
    PickupRange = 30,
    SellCooldown = 5
}

-- Система управління потоками
local RunningThreads = {}
local ShouldStop = false

-- Кольори для консолі
local Colors = {
    Red = Color3.fromRGB(255, 85, 85),
    Green = Color3.fromRGB(85, 255, 85),
    Yellow = Color3.fromRGB(255, 255, 85),
    White = Color3.fromRGB(255, 255, 255)
}

-- Безпечне очищення консолі
local function SafeConsoleClear()
    pcall(rconsoleclear)
end

-- Функція для логування
local function Log(message, color)
    if rconsoleprint then
        rconsoleprint("@@")
        rconsoleprint(tostring(color or Colors.White))
        rconsoleprint("@@")
        rconsoleprint(message .. "\n")
        rconsoleprint("@@WHITE@@")
    else
        print(message)
    end
end

-- Збереження налаштувань
local function SaveSettings()
    if not isfolder("Delta_AutoFarm") then
        makefolder("Delta_AutoFarm")
    end
    writefile("Delta_AutoFarm/settings.txt", game:GetService("HttpService"):JSONEncode(Settings))
end

-- Завантаження налаштувань
if isfile("Delta_AutoFarm/settings.txt") then
    Settings = game:GetService("HttpService"):JSONDecode(readfile("Delta_AutoFarm/settings.txt"))
end

-- Функція зупинки потоків
local function StopAllThreads()
    ShouldStop = true
    task.wait(0.1)
    RunningThreads = {}
    ShouldStop = false
end

-- Функція запуску потоку
local function StartThread(func)
    local co = coroutine.create(func)
    table.insert(RunningThreads, co)
    coroutine.resume(co)
    return co
end

-- Автопідбирання
local function PickupItems()
    if not firetouchinterest then
        Log("firetouchinterest не знайдено! Автопідбирання не працюватиме", Colors.Red)
        return
    end

    while task.wait(0.5) and not ShouldStop do
        if Settings.AutoPickup then
            local character = game.Players.LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                for _, item in ipairs(workspace:GetChildren()) do
                    if item:IsA("BasePart") and item.Name:find("Drop") then
                        local distance = (rootPart.Position - item.Position).Magnitude
                        if distance <= Settings.PickupRange then
                            firetouchinterest(rootPart, item, 0)
                            task.wait(0.1)
                            firetouchinterest(rootPart, item, 1)
                        end
                    end
                end
            end
        end
    end
end

-- Автопродаж
local function SellItems()
    local lastSold = 0
    while task.wait(1) and not ShouldStop do
        if Settings.AutoSell and tick() - lastSold >= Settings.SellCooldown then
            pcall(function()
                for _, obj in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        Log("Знайдено RemoteEvent: "..obj.Name, Colors.Yellow)
                        if obj.Name:lower():find("sell") then
                            obj:FireServer()
                            lastSold = tick()
                            Log("[" .. os.date("%H:%M:%S") .. "] Продано предметів через: " .. obj.Name, Colors.Green)
                            break
                        end
                    end
                end
            end)
        end
    end
end

-- Anti-AFK система
local VirtualUser = game:GetService("VirtualUser")
game.Players.LocalPlayer.Idled:Connect(function()
    if Settings.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Функція для відображення меню
local function ShowMenu()
    SafeConsoleClear()
    Log("===== AutoFarm Menu =====", Colors.Yellow)
    Log("1. Автопідбирання: " .. (Settings.AutoPickup and "✅" or "❌"))
    Log("2. Автопродаж: " .. (Settings.AutoSell and "✅" or "❌"))
    Log("3. Anti-AFK: " .. (Settings.AntiAFK and "✅" or "❌"))
    Log("4.Радіус підбирання: " .. Settings.PickupRange)
    Log("5. Затримка продажу: " .. Settings.SellCooldown .. " сек")
    Log("6. Почати/перезапустити фарм")
    Log("7. Вийти")
end

-- Обробка числового вводу
local function GetNumberInput(prompt, currentValue)
    Log(prompt, Colors.Yellow)
    local input = rconsoleinput()
    input = input and input:gsub("[\n\r]", "") or ""
    local number = tonumber(input)
    return number and number > 0 and number or currentValue
end

-- Головний цикл меню
local function MainLoop()
    if not rconsoleprint then
        print("rconsole не підтримується у вашому експлойтері. Меню працювати не буде.")
        return
    end

    Log("Anti-AFK: " .. (Settings.AntiAFK and "увімкнено" or "вимкнено"), 
        Settings.AntiAFK and Colors.Green or Colors.Red)
    
    -- Автозапуск фарму при старті
    StartThread(PickupItems)
    StartThread(SellItems)
    Log("Фарм запущено автоматично!", Colors.Green)
    
    while true do
        ShowMenu()
        local input = rconsoleinput()
        if input then
            input = input:gsub("[\n\r]", "")
            
            if input == "1" then
                Settings.AutoPickup = not Settings.AutoPickup
                Log("Автопідбирання: " .. (Settings.AutoPickup and "увімкнено" or "вимкнено"), 
                    Settings.AutoPickup and Colors.Green or Colors.Red)
            elseif input == "2" then
                Settings.AutoSell = not Settings.AutoSell
                Log("Автопродаж: " .. (Settings.AutoSell and "увімкнено" or "вимкнено"), 
                    Settings.AutoSell and Colors.Green or Colors.Red)
            elseif input == "3" then
                Settings.AntiAFK = not Settings.AntiAFK
                Log("Anti-AFK: " .. (Settings.AntiAFK and "увімкнено" or "вимкнено"), 
                    Settings.AntiAFK and Colors.Green or Colors.Red)
            elseif input == "4" then
                Settings.PickupRange = GetNumberInput(
                    "Введіть новий радіус підбирання (поточний: " .. Settings.PickupRange .. "):",
                    Settings.PickupRange)
                Log("Радіус підбирання змінено на: " .. Settings.PickupRange, Colors.Green)
            elseif input == "5" then
                Settings.SellCooldown = GetNumberInput(
                    "Введіть нову затримку продажу (поточний: " .. Settings.SellCooldown .. " сек):",
                    Settings.SellCooldown)
                Log("Затримка продажу змінена на: " .. Settings.SellCooldown .. " сек", Colors.Green)
            elseif input == "6" then
                StopAllThreads()
                StartThread(PickupItems)
                StartThread(SellItems)
                Log("Фарм перезапущено!", Colors.Green)
            elseif input == "7" then
                StopAllThreads()
                Log("Скрипт зупинено", Colors.Red)
                break
            end
            
            SaveSettings()
        end
    end
end

-- Запуск головного меню в безпечному pcall
pcall(function()
    MainLoop()
end)
