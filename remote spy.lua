--[[
    Remote Spy (Aggressive)
    Dual-hooks __namecall + FireServer/InvokeServer via hookfunction.
    Requires: hookmetamethod, hookfunction, checkcaller, getnamecallmethod, setclipboard
]]

-- Optional manual ignore list (DISABLED by default — not used by hooks)
-- Set USE_IGNORE_LIST = true and add exact remote names if you want to suppress specific spam
local USE_IGNORE_LIST = false
local IgnoreList = {
    -- "ExactRemoteNameOnly",
}

-- Services
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Exploit safety wrappers
local newcclosure = newcclosure or function(fn) return fn end
local clonefunction = clonefunction or function(fn) return fn end

-- Utilities
local function isIgnored(remoteName: string): boolean
    if not USE_IGNORE_LIST then
        return false
    end
    for _, ignored in ipairs(IgnoreList) do
        if remoteName == ignored then
            return true
        end
    end
    return false
end

local function getRemoteIdentity(remote: any): (string, string, string)
    if typeof(remote) == "Instance" then
        local name = "Unknown"
        local path = "Unknown"
        local codePath = "nil"

        pcall(function()
            name = remote.Name
        end)
        pcall(function()
            path = remote:GetFullName()
            codePath = "game." .. path
        end)

        return name, path, codePath
    end

    local label = typeof(remote) .. ":" .. tostring(remote)
    return label, label, tostring(remote)
end

local function instanceToCodePath(instance: Instance): string
    local ok, fullName = pcall(function()
        return instance:GetFullName()
    end)
    if ok then
        return "game." .. fullName
    end
    return tostring(instance)
end

local function serializeForCode(value: any, depth: number?): string
    depth = depth or 0
    if depth > 4 then
        return "nil --[[ max depth ]]"
    end

    local valueType = typeof(value)

    if valueType == "string" then
        return string.format("%q", value)
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "nil" then
        return "nil"
    elseif valueType == "Instance" then
        return instanceToCodePath(value)
    elseif valueType == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", value.X, value.Y, value.Z)
    elseif valueType == "Vector2" then
        return string.format("Vector2.new(%s, %s)", value.X, value.Y)
    elseif valueType == "CFrame" then
        local components = { value:GetComponents() }
        return string.format(
            "CFrame.new(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
            table.unpack(components)
        )
    elseif valueType == "Color3" then
        return string.format(
            "Color3.fromRGB(%d, %d, %d)",
            math.floor(value.R * 255 + 0.5),
            math.floor(value.G * 255 + 0.5),
            math.floor(value.B * 255 + 0.5)
        )
    elseif valueType == "UDim2" then
        return string.format(
            "UDim2.new(%s, %s, %s, %s)",
            value.X.Scale, value.X.Offset,
            value.Y.Scale, value.Y.Offset
        )
    elseif valueType == "UDim" then
        return string.format("UDim.new(%s, %s)", value.Scale, value.Offset)
    elseif valueType == "EnumItem" then
        return tostring(value)
    elseif valueType == "BrickColor" then
        return string.format("BrickColor.new(%q)", tostring(value))
    elseif valueType == "table" then
        local parts = {}
        local isArray = true
        local maxIndex = 0

        for key in pairs(value) do
            if typeof(key) ~= "number" or key % 1 ~= 0 or key < 1 then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, key)
        end

        if isArray then
            for i = 1, maxIndex do
                table.insert(parts, serializeForCode(value[i], depth + 1))
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end

        for key, entry in pairs(value) do
            local keyCode
            if typeof(key) == "string" then
                keyCode = string.format("[%q]", key)
            elseif typeof(key) == "number" then
                keyCode = "[" .. tostring(key) .. "]"
            else
                keyCode = "[" .. serializeForCode(key, depth + 1) .. "]"
            end
            table.insert(parts, keyCode .. " = " .. serializeForCode(entry, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return string.format("%q", tostring(value))
    end
end

local function formatArgDisplay(value: any, index: number): string
    local valueType = typeof(value)
    local displayValue

    if valueType == "Instance" then
        local ok, fullName = pcall(function()
            return value:GetFullName()
        end)
        displayValue = ok and fullName or tostring(value)
    elseif valueType == "table" then
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(value)
        end)
        displayValue = ok and encoded or "<table>"
    else
        displayValue = tostring(value)
    end

    if #displayValue > 200 then
        displayValue = displayValue:sub(1, 200) .. "..."
    end

    return string.format("[%d] %s: %s", index, valueType, displayValue)
end

local function formatArgs(...)
    local packed = table.pack(...)
    local displayLines = {}
    local codeParts = {}

    for i = 1, packed.n do
        local arg = packed[i]
        table.insert(displayLines, formatArgDisplay(arg, i))
        table.insert(codeParts, serializeForCode(arg))
    end

    local displayText = #displayLines > 0 and table.concat(displayLines, "\n") or "(no arguments)"
    local codeText = table.concat(codeParts, ", ")

    return displayText, codeText
end

-- UI Theme
local Theme = {
    Background = Color3.fromRGB(22, 22, 28),
    Surface = Color3.fromRGB(30, 30, 38),
    SurfaceHover = Color3.fromRGB(38, 38, 48),
    TitleBar = Color3.fromRGB(16, 16, 20),
    Border = Color3.fromRGB(55, 55, 70),
    Text = Color3.fromRGB(230, 230, 240),
    TextMuted = Color3.fromRGB(140, 140, 160),
    TextDim = Color3.fromRGB(100, 100, 120),
    FireServer = Color3.fromRGB(90, 170, 255),
    InvokeServer = Color3.fromRGB(190, 130, 255),
    Accent = Color3.fromRGB(55, 140, 95),
    AccentHover = Color3.fromRGB(65, 165, 110),
    Scrollbar = Color3.fromRGB(70, 70, 88),
    Input = Color3.fromRGB(36, 36, 46),
}

local function applyCorner(parent: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end

local function applyStroke(parent: Instance, color: Color3, thickness: number?)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

-- Build UI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RemoteSpy"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(520, 420)
Main.Position = UDim2.new(0.5, -260, 0.5, -210)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
applyCorner(Main, 10)
applyStroke(Main, Theme.Border, 1)

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Theme.TitleBar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleBarFill = Instance.new("Frame")
TitleBarFill.Size = UDim2.new(1, 0, 0, 12)
TitleBarFill.Position = UDim2.new(0, 0, 1, -12)
TitleBarFill.BackgroundColor3 = Theme.TitleBar
TitleBarFill.BorderSizePixel = 0
TitleBarFill.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.fromOffset(14, 0)
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "Remote Spy"
TitleLabel.TextColor3 = Theme.Text
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local LogCountLabel = Instance.new("TextLabel")
LogCountLabel.Name = "LogCount"
LogCountLabel.BackgroundTransparency = 1
LogCountLabel.Position = UDim2.new(1, -78, 0, 0)
LogCountLabel.Size = UDim2.fromOffset(44, 34)
LogCountLabel.Font = Enum.Font.Gotham
LogCountLabel.Text = "0"
LogCountLabel.TextColor3 = Theme.TextDim
LogCountLabel.TextSize = 12
LogCountLabel.TextXAlignment = Enum.TextXAlignment.Right
LogCountLabel.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -34, 0, 0)
CloseButton.Size = UDim2.fromOffset(34, 34)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "×"
CloseButton.TextColor3 = Theme.TextMuted
CloseButton.TextSize = 20
CloseButton.Parent = TitleBar

CloseButton.MouseEnter:Connect(function()
    CloseButton.TextColor3 = Color3.fromRGB(255, 90, 90)
end)
CloseButton.MouseLeave:Connect(function()
    CloseButton.TextColor3 = Theme.TextMuted
end)
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.BackgroundColor3 = Theme.Input
SearchBox.BorderSizePixel = 0
SearchBox.Position = UDim2.fromOffset(12, 44)
SearchBox.Size = UDim2.new(1, -24, 0, 30)
SearchBox.ClearTextOnFocus = false
SearchBox.Font = Enum.Font.Gotham
SearchBox.PlaceholderColor3 = Theme.TextDim
SearchBox.PlaceholderText = "Search remotes by name or path..."
SearchBox.Text = ""
SearchBox.TextColor3 = Theme.Text
SearchBox.TextSize = 13
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.Parent = Main
applyCorner(SearchBox, 6)

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 10)
SearchPadding.PaddingRight = UDim.new(0, 10)
SearchPadding.Parent = SearchBox

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "Logs"
ScrollFrame.BackgroundColor3 = Theme.Surface
ScrollFrame.BorderSizePixel = 0
ScrollFrame.Position = UDim2.fromOffset(12, 82)
ScrollFrame.Size = UDim2.new(1, -24, 1, -94)
ScrollFrame.ScrollBarThickness = 5
ScrollFrame.ScrollBarImageColor3 = Theme.Scrollbar
ScrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.Parent = Main
applyCorner(ScrollFrame, 8)

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ScrollFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 8)
ListPadding.PaddingBottom = UDim.new(0, 8)
ListPadding.PaddingLeft = UDim.new(0, 8)
ListPadding.PaddingRight = UDim.new(0, 8)
ListPadding.Parent = ScrollFrame

local dragging = false
local dragInput
local dragStart
local startPos

local function updateDrag(input: InputObject)
    local delta = input.Position - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

TitleBar.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

-- Log State
local logs = {}
local searchFilter = ""
local logCounter = 0
local MAX_LOGS = 250

local function matchesFilter(remoteName: string, remotePath: string): boolean
    if searchFilter == "" then
        return true
    end
    return remoteName:lower():find(searchFilter, 1, true) ~= nil
        or remotePath:lower():find(searchFilter, 1, true) ~= nil
end

local function refreshFilter()
    for _, log in ipairs(logs) do
        log.Frame.Visible = matchesFilter(log.RemoteName, log.RemotePath)
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchFilter = SearchBox.Text:lower()
    refreshFilter()
end)

local function trimOldLogs()
    while #logs > MAX_LOGS do
        local oldest = table.remove(logs)
        if oldest and oldest.Frame then
            oldest.Frame:Destroy()
        end
    end
    LogCountLabel.Text = tostring(#logs)
end

local function createLogEntry(remote: any, method: string, ...)
    local remoteName, remotePath, codePath = getRemoteIdentity(remote)
    local argsDisplay, argsCode = formatArgs(...)
    local codeLine = string.format("%s:%s(%s)", codePath, method, argsCode)
    local methodColor = method == "FireServer" and Theme.FireServer or Theme.InvokeServer

    logCounter += 1

    local Entry = Instance.new("Frame")
    Entry.Name = "Log_" .. logCounter
    Entry.BackgroundColor3 = Theme.SurfaceHover
    Entry.BorderSizePixel = 0
    Entry.Size = UDim2.new(1, -4, 0, 0)
    Entry.AutomaticSize = Enum.AutomaticSize.Y
    Entry.LayoutOrder = -logCounter
    Entry.Parent = ScrollFrame
    applyCorner(Entry, 6)

    local EntryLayout = Instance.new("UIListLayout")
    EntryLayout.Padding = UDim.new(0, 5)
    EntryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    EntryLayout.Parent = Entry

    local EntryPadding = Instance.new("UIPadding")
    EntryPadding.PaddingTop = UDim.new(0, 8)
    EntryPadding.PaddingBottom = UDim.new(0, 8)
    EntryPadding.PaddingLeft = UDim.new(0, 10)
    EntryPadding.PaddingRight = UDim.new(0, 10)
    EntryPadding.Parent = Entry

    local Header = Instance.new("Frame")
    Header.BackgroundTransparency = 1
    Header.LayoutOrder = 1
    Header.Size = UDim2.new(1, 0, 0, 22)
    Header.Parent = Entry

    local MethodBadge = Instance.new("TextLabel")
    MethodBadge.BackgroundColor3 = methodColor
    MethodBadge.BackgroundTransparency = 0.85
    MethodBadge.Position = UDim2.fromOffset(0, 2)
    MethodBadge.Size = UDim2.fromOffset(method == "FireServer" and 68 or 84, 18)
    MethodBadge.Font = Enum.Font.GothamBold
    MethodBadge.Text = method
    MethodBadge.TextColor3 = methodColor
    MethodBadge.TextSize = 10
    MethodBadge.Parent = Header
    applyCorner(MethodBadge, 4)

    local NameLabel = Instance.new("TextLabel")
    NameLabel.BackgroundTransparency = 1
    NameLabel.Position = UDim2.fromOffset(method == "FireServer" and 74 or 90, 0)
    NameLabel.Size = UDim2.new(1, -170, 1, 0)
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Text = remoteName
    NameLabel.TextColor3 = Theme.Text
    NameLabel.TextSize = 12
    NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Parent = Header

    local CopyButton = Instance.new("TextButton")
    CopyButton.BackgroundColor3 = Theme.Accent
    CopyButton.BorderSizePixel = 0
    CopyButton.Position = UDim2.new(1, -82, 0, 0)
    CopyButton.Size = UDim2.fromOffset(82, 22)
    CopyButton.Font = Enum.Font.GothamBold
    CopyButton.Text = "Copy Code"
    CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyButton.TextSize = 11
    CopyButton.Parent = Header
    applyCorner(CopyButton, 5)

    CopyButton.MouseEnter:Connect(function()
        CopyButton.BackgroundColor3 = Theme.AccentHover
    end)
    CopyButton.MouseLeave:Connect(function()
        CopyButton.BackgroundColor3 = Theme.Accent
    end)
    CopyButton.MouseButton1Click:Connect(function()
        setclipboard(codeLine)
        CopyButton.Text = "Copied!"
        task.delay(1.2, function()
            if CopyButton.Parent then
                CopyButton.Text = "Copy Code"
            end
        end)
    end)

    local PathLabel = Instance.new("TextLabel")
    PathLabel.BackgroundTransparency = 1
    PathLabel.LayoutOrder = 2
    PathLabel.Size = UDim2.new(1, 0, 0, 0)
    PathLabel.AutomaticSize = Enum.AutomaticSize.Y
    PathLabel.Font = Enum.Font.Gotham
    PathLabel.Text = remotePath
    PathLabel.TextColor3 = Theme.TextMuted
    PathLabel.TextSize = 11
    PathLabel.TextWrapped = true
    PathLabel.TextXAlignment = Enum.TextXAlignment.Left
    PathLabel.Parent = Entry

    local ArgsLabel = Instance.new("TextLabel")
    ArgsLabel.BackgroundTransparency = 1
    ArgsLabel.LayoutOrder = 3
    ArgsLabel.Size = UDim2.new(1, 0, 0, 0)
    ArgsLabel.AutomaticSize = Enum.AutomaticSize.Y
    ArgsLabel.Font = Enum.Font.Code
    ArgsLabel.Text = argsDisplay
    ArgsLabel.TextColor3 = Theme.Text
    ArgsLabel.TextSize = 11
    ArgsLabel.TextWrapped = true
    ArgsLabel.TextXAlignment = Enum.TextXAlignment.Left
    ArgsLabel.Parent = Entry

    local logData = {
        Frame = Entry,
        RemoteName = remoteName,
        RemotePath = remotePath,
    }

    table.insert(logs, 1, logData)
    Entry.Visible = matchesFilter(remoteName, remotePath)
    trimOldLogs()
end

-- ============================================================================
-- AGGRESSIVE HOOK LAYER
-- ============================================================================

local recentCalls: { [string]: number } = {}
local DEDUP_WINDOW = 0.03

local function buildCallSignature(remote: any, method: string, ...): string
    local packed = table.pack(...)
    local parts = { tostring(remote), method, tostring(packed.n) }

    for i = 1, math.min(packed.n, 12) do
        local arg = packed[i]
        parts[#parts + 1] = typeof(arg) .. ":" .. tostring(arg)
    end

    return table.concat(parts, "\0")
end

local function isDuplicate(remote: any, method: string, ...): boolean
    local signature = buildCallSignature(remote, method, ...)
    local now = os.clock()
    local lastSeen = recentCalls[signature]

    recentCalls[signature] = now

    if lastSeen and (now - lastSeen) < DEDUP_WINDOW then
        return true
    end

    return false
end

local function queueLog(remote: any, method: string, ...)
    if checkcaller() then
        return
    end

    if USE_IGNORE_LIST and typeof(remote) == "Instance" then
        local remoteName = "Unknown"
        pcall(function()
            remoteName = remote.Name
        end)
        if isIgnored(remoteName) then
            return
        end
    end

    if isDuplicate(remote, method, ...) then
        return
    end

    local packed = table.pack(...)

    task.spawn(function()
        local ok, err = pcall(function()
            createLogEntry(remote, method, table.unpack(packed, 1, packed.n))
        end)

        if not ok then
            warn("[Remote Spy] createLogEntry failed:", err)
        end
    end)
end

-- Capture original function references BEFORE any other script hooks them
local probeEvent = Instance.new("RemoteEvent")
local probeFunction = Instance.new("RemoteFunction")
local fireServerRef = clonefunction(probeEvent.FireServer)
local invokeServerRef = clonefunction(probeFunction.InvokeServer)
probeEvent:Destroy()
probeFunction:Destroy()

local oldFireServer
local oldInvokeServer
local oldNamecall

-- Direct function hooks (catches remote.FireServer(remote, ...) and internal direct calls)
oldFireServer = hookfunction(fireServerRef, newcclosure(function(self, ...)
    queueLog(self, "FireServer", ...)
    return oldFireServer(self, ...)
end))

oldInvokeServer = hookfunction(invokeServerRef, newcclosure(function(self, ...)
    queueLog(self, "InvokeServer", ...)
    return oldInvokeServer(self, ...)
end))

-- __namecall hook (catches remote:FireServer(...) / remote:InvokeServer(...))
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if checkcaller() then
        return oldNamecall(self, ...)
    end

    local method = getnamecallmethod()

    if method == "FireServer" or method == "InvokeServer" then
        queueLog(self, method, ...)
    end

    return oldNamecall(self, ...)
end))

print("[Remote Spy] Loaded — dual hooks active (__namecall + hookfunction)")
