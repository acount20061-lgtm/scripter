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

-- Логування (просто через print)
local function Log(message)
    print(message)
end

-- Автопідбирання
local function PickupItems()
    if not firetouchinterest then
        Log("firetouchinterest не знайдено! Автопідбирання не працюватиме")
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
                        if obj.Name:lower():find("sell") then
                            obj:FireServer()
                            lastSold = tick()
                            Log("Продано предметів через RemoteEvent: " .. obj.Name)
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

-- Автозапуск фарму
Log("Фарм запущено автоматично!")
StartThread(PickupItems)
StartThread(SellItems)

-- Просте текстове меню
while true do
    print("\n===== AutoFarm Menu =====")
    print("1. Автопідбирання: " .. (Settings.AutoPickup and "✅" or "❌"))
    print("2. Автопродаж: " .. (Settings.AutoSell and "✅" or "❌"))
    print("3. Anti-AFK: " .. (Settings.AntiAFK and "✅" or "❌"))
    print("4. Радіус підбирання: " .. Settings.PickupRange)
    print("5. Затримка продажу: " .. Settings.SellCooldown .. " сек")
    print("6. Почати/перезапустити фарм")
    print("7. Вийти")
    local input = tostring(io.read())

    if input == "1" then
        Settings.AutoPickup = not Settings.AutoPickup
        Log("Автопідбирання: " .. (Settings.AutoPickup and "увімкнено" or "вимкнено"))
    elseif input == "2" then
        Settings.AutoSell = not Settings.AutoSell
        Log("Автопродаж: " .. (Settings.AutoSell and "увімкнено" or "вимкнено"))
    elseif input == "3" then
        Settings.AntiAFK = not Settings.AntiAFK
        Log("Anti-AFK: " .. (Settings.AntiAFK and "увімкнено" or "вимкнено"))
    elseif input == "4" then
        print("Введіть новий радіус підбирання (поточний: " .. Settings.PickupRange .. "):")
        local num = tonumber(io.read())
        if num and num > 0 then
            Settings.PickupRange = num
            Log("Радіус підбирання змінено на: " .. Settings.PickupRange)
        end
    elseif input == "5" then
        print("Введіть нову затримку продажу (поточний: " .. Settings.SellCooldown .. " сек):")
        local num = tonumber(io.read())
        if num and num > 0 then
            Settings.SellCooldown = num
            Log("Затримка продажу змінена на: " .. Settings.SellCooldown .. " сек")
        end
    elseif input == "6" then
        StopAllThreads()
        StartThread(PickupItems)
        StartThread(SellItems)
        Log("Фарм перезапущено!")
    elseif input == "7" then
        StopAllThreads()
        Log("Скрипт зупинено")
        break
    end
end
