-- Ультра-мінімальний шпигун
local SG = Instance.new("ScreenGui")
SG.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(0, 300, 0, 300)
List.Parent = SG

local function log(method, remote)
    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, 0, 0, 20)
    msg.Position = UDim2.new(0, 0, 0, #List:GetChildren() * 20)
    -- Не чіпаємо сам об'єкт remote, просто пишемо тип виклику
    msg.Text = "Виклик методу: " .. tostring(method)
    msg.Parent = List
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if checkcaller() then return oldNamecall(self, ...) end
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        task.spawn(log, method, self)
    end
    return oldNamecall(self, ...)
end)
