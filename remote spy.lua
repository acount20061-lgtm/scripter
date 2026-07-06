-- Safe Remote Spy для емулятора
local SG = Instance.new("ScreenGui")
SG.Name = "SafeSpy"
SG.Parent = game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 400, 0, 200)
Main.Position = UDim2.new(0.5, -200, 0.5, -100)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.Active = true
Main.Draggable = true
Main.Parent = SG

local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1, -10, 1, -10)
List.Position = UDim2.new(0, 5, 0, 5)
List.BackgroundTransparency = 1
List.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Parent = List

local function log(method, remote, ...)
    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, 0, 0, 30)
    msg.Text = method .. " | " .. tostring(remote)
    msg.TextColor3 = Color3.new(1, 1, 1)
    msg.BackgroundTransparency = 0.5
    msg.Parent = List
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if checkcaller() then return oldNamecall(self, ...) end
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        task.spawn(log, method, self, ...)
    end
    return oldNamecall(self, ...)
end)
