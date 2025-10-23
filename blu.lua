local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Settings
local Settings = {
    Render = {
        Tracers = { Enabled = false, Color = Color3.fromRGB(100, 150, 255), Thickness = 2 },
        ESP = { Enabled = false, Color = Color3.fromRGB(100, 150, 255), Thickness = 2 },
        Chams = { Enabled = false, FillColor = Color3.fromRGB(100, 150, 255), OutlineColor = Color3.fromRGB(150, 200, 255) },
        Distance = { Enabled = false, Color = Color3.fromRGB(255, 255, 255) },
        Nametags = { Enabled = false, Color = Color3.fromRGB(255, 255, 255) },
        HealthBar = { Enabled = false },
        Skeleton = { Enabled = false, Color = Color3.fromRGB(255, 255, 255) },
        FOVCircle = { Enabled = false, Radius = 100, Color = Color3.fromRGB(255, 255, 255) }
    },
    Combat = {
        Aimbot = { Enabled = false },
        TriggerBot = { Enabled = false },
        SpinBot = { Enabled = false },
        NoRecoil = { Enabled = false },
        RapidFire = { Enabled = false },
        InfiniteAmmo = { Enabled = false }
    },
    Misc = {
        TeamCheck = { Enabled = true },
        WalkSpeed = { Enabled = false, Value = 16 },
        JumpPower = { Enabled = false, Value = 50 },
        NoClip = { Enabled = false },
        Flight = { Enabled = false },
        AntiAFK = { Enabled = false }
    }
}

-- Logs System
local Logs = {}
local function AddLog(message)
    local timestamp = os.date("%H:%M:%S")
    table.insert(Logs, {Time = timestamp, Message = message})
    if #Logs > 100 then
        table.remove(Logs, 1)
    end
end

AddLog("blu.cc initialized successfully")

-- Storage
local ESPObjects = {}
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.ZIndex = 999

-- Helper Functions
local function IsTeamMate(player)
    if not Settings.Misc.TeamCheck.Enabled then return false end
    return player.Team == LocalPlayer.Team and player.Team ~= nil
end

local function CreateDrawing(type)
    local drawing = Drawing.new(type)
    return drawing
end

-- ESP Object Class
local function CreateESPForPlayer(player)
    if player == LocalPlayer then return end
    
    local esp = {
        Player = player,
        Tracer = CreateDrawing("Line"),
        BoxOutline = {},
        BoxInline = {},
        DistanceText = CreateDrawing("Text"),
        NameText = CreateDrawing("Text"),
        HealthBarOutline = CreateDrawing("Square"),
        HealthBarInline = CreateDrawing("Square"),
        Skeleton = {},
        Chams = {}
    }
    
    -- Setup Box
    for i = 1, 4 do
        esp.BoxOutline[i] = CreateDrawing("Line")
        esp.BoxInline[i] = CreateDrawing("Line")
    end
    
    -- Setup Skeleton
    for i = 1, 6 do
        esp.Skeleton[i] = CreateDrawing("Line")
    end
    
    -- Setup Tracer
    esp.Tracer.Thickness = Settings.Render.Tracers.Thickness
    esp.Tracer.Transparency = 1
    
    -- Setup Box Lines
    for i = 1, 4 do
        esp.BoxOutline[i].Thickness = Settings.Render.ESP.Thickness + 1
        esp.BoxInline[i].Thickness = Settings.Render.ESP.Thickness
    end
    
    -- Setup Text
    esp.DistanceText.Size = 14
    esp.DistanceText.Center = true
    esp.DistanceText.Outline = true
    
    esp.NameText.Size = 14
    esp.NameText.Center = true
    esp.NameText.Outline = true
    
    -- Setup Health Bar
    esp.HealthBarOutline.Thickness = 1
    esp.HealthBarOutline.Filled = false
    esp.HealthBarInline.Filled = true
    
    return esp
end

local function RemoveESP(esp)
    if esp.Tracer then esp.Tracer:Remove() end
    for _, line in pairs(esp.BoxOutline) do line:Remove() end
    for _, line in pairs(esp.BoxInline) do line:Remove() end
    for _, line in pairs(esp.Skeleton) do line:Remove() end
    if esp.DistanceText then esp.DistanceText:Remove() end
    if esp.NameText then esp.NameText:Remove() end
    if esp.HealthBarOutline then esp.HealthBarOutline:Remove() end
    if esp.HealthBarInline then esp.HealthBarInline:Remove() end
    for _, cham in pairs(esp.Chams) do
        if cham then pcall(function() cham:Destroy() end) end
    end
end

-- Update ESP
local function UpdateESP(esp)
    local player = esp.Player
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if not hrp or not head or not hum or hum.Health <= 0 then
        esp.Tracer.Visible = false
        for _, line in pairs(esp.BoxOutline) do line.Visible = false end
        for _, line in pairs(esp.BoxInline) do line.Visible = false end
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        esp.DistanceText.Visible = false
        esp.NameText.Visible = false
        esp.HealthBarOutline.Visible = false
        esp.HealthBarInline.Visible = false
        return
    end
    
    local isTeam = IsTeamMate(player)
    local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) 
        and (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude or 0
    
    -- Get 2D positions
    local hrpPos, hrpVis = Camera:WorldToViewportPoint(hrp.Position)
    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    
    if not hrpVis then
        esp.Tracer.Visible = false
        for _, line in pairs(esp.BoxOutline) do line.Visible = false end
        for _, line in pairs(esp.BoxInline) do line.Visible = false end
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
        esp.DistanceText.Visible = false
        esp.NameText.Visible = false
        esp.HealthBarOutline.Visible = false
        esp.HealthBarInline.Visible = false
        return
    end
    
    -- Colors
    local color = isTeam and Color3.fromRGB(100, 255, 100) or Settings.Render.ESP.Color
    
    -- Tracers
    if Settings.Render.Tracers.Enabled and not isTeam then
        esp.Tracer.Visible = true
        esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        esp.Tracer.To = Vector2.new(hrpPos.X, hrpPos.Y)
        esp.Tracer.Color = Settings.Render.Tracers.Color
    else
        esp.Tracer.Visible = false
    end
    
    -- Box ESP
    if Settings.Render.ESP.Enabled and not isTeam then
        local height = math.abs(headPos.Y - legPos.Y)
        local width = height / 2
        
        local positions = {
            Vector2.new(hrpPos.X - width/2, headPos.Y),
            Vector2.new(hrpPos.X + width/2, headPos.Y),
            Vector2.new(hrpPos.X + width/2, legPos.Y),
            Vector2.new(hrpPos.X - width/2, legPos.Y)
        }
        
        for i = 1, 4 do
            local next = i % 4 + 1
            esp.BoxOutline[i].Visible = true
            esp.BoxOutline[i].From = positions[i]
            esp.BoxOutline[i].To = positions[next]
            esp.BoxOutline[i].Color = Color3.new(0, 0, 0)
            
            esp.BoxInline[i].Visible = true
            esp.BoxInline[i].From = positions[i]
            esp.BoxInline[i].To = positions[next]
            esp.BoxInline[i].Color = color
        end
        
        -- Health Bar
        if Settings.Render.HealthBar.Enabled then
            local healthPercent = hum.Health / hum.MaxHealth
            esp.HealthBarOutline.Visible = true
            esp.HealthBarOutline.Size = Vector2.new(3, height)
            esp.HealthBarOutline.Position = Vector2.new(positions[4].X - 8, headPos.Y)
            esp.HealthBarOutline.Color = Color3.new(0, 0, 0)
            
            esp.HealthBarInline.Visible = true
            esp.HealthBarInline.Size = Vector2.new(2, height * healthPercent)
            esp.HealthBarInline.Position = Vector2.new(positions[4].X - 7.5, headPos.Y + height * (1 - healthPercent))
            esp.HealthBarInline.Color = Color3.fromRGB(
                255 * (1 - healthPercent),
                255 * healthPercent,
                0
            )
        else
            esp.HealthBarOutline.Visible = false
            esp.HealthBarInline.Visible = false
        end
    else
        for _, line in pairs(esp.BoxOutline) do line.Visible = false end
        for _, line in pairs(esp.BoxInline) do line.Visible = false end
        esp.HealthBarOutline.Visible = false
        esp.HealthBarInline.Visible = false
    end
    
    -- Skeleton
    if Settings.Render.Skeleton.Enabled and not isTeam then
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        local leftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm")
        local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
        local leftLeg = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg")
        local rightLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")
        
        if torso and leftArm and rightArm and leftLeg and rightLeg then
            local bodyParts = {
                {head, torso}, -- Head to torso
                {torso, leftArm}, -- Left arm
                {torso, rightArm}, -- Right arm
                {torso, leftLeg}, -- Left leg
                {torso, rightLeg} -- Right leg
            }
            
            for i, parts in ipairs(bodyParts) do
                if esp.Skeleton[i] and parts[1] and parts[2] then
                    local pos1, vis1 = Camera:WorldToViewportPoint(parts[1].Position)
                    local pos2, vis2 = Camera:WorldToViewportPoint(parts[2].Position)
                    
                    if vis1 and vis2 then
                        esp.Skeleton[i].Visible = true
                        esp.Skeleton[i].From = Vector2.new(pos1.X, pos1.Y)
                        esp.Skeleton[i].To = Vector2.new(pos2.X, pos2.Y)
                        esp.Skeleton[i].Color = Settings.Render.Skeleton.Color
                        esp.Skeleton[i].Thickness = 1
                    else
                        esp.Skeleton[i].Visible = false
                    end
                end
            end
        end
    else
        for _, line in pairs(esp.Skeleton) do line.Visible = false end
    end
    
    -- Distance
    if Settings.Render.Distance.Enabled and not isTeam then
        esp.DistanceText.Visible = true
        esp.DistanceText.Position = Vector2.new(hrpPos.X, legPos.Y + 5)
        esp.DistanceText.Text = string.format("%.0f studs", distance)
        esp.DistanceText.Color = Settings.Render.Distance.Color
    else
        esp.DistanceText.Visible = false
    end
    
    -- Nametags
    if Settings.Render.Nametags.Enabled and not isTeam then
        esp.NameText.Visible = true
        esp.NameText.Position = Vector2.new(hrpPos.X, headPos.Y - 15)
        esp.NameText.Text = player.Name
        esp.NameText.Color = Settings.Render.Nametags.Color
    else
        esp.NameText.Visible = false
    end
    
    -- Chams
    if Settings.Render.Chams.Enabled and not isTeam then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                if not esp.Chams[part] then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = part
                    highlight.FillColor = Settings.Render.Chams.FillColor
                    highlight.OutlineColor = Settings.Render.Chams.OutlineColor
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.Parent = part
                    esp.Chams[part] = highlight
                end
            end
        end
    else
        for part, cham in pairs(esp.Chams) do
            pcall(function() cham:Destroy() end)
            esp.Chams[part] = nil
        end
    end
end

-- Player Management
local function OnPlayerAdded(player)
    ESPObjects[player] = CreateESPForPlayer(player)
end

local function OnPlayerRemoving(player)
    if ESPObjects[player] then
        RemoveESP(ESPObjects[player])
        ESPObjects[player] = nil
    end
end

-- Initialize for existing players
for _, player in pairs(Players:GetPlayers()) do
    OnPlayerAdded(player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- FOV Circle Update
RunService.RenderStepped:Connect(function()
    -- Update FOV Circle
    if Settings.Render.FOVCircle.Enabled then
        FOVCircle.Visible = true
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Settings.Render.FOVCircle.Radius
        FOVCircle.Color = Settings.Render.FOVCircle.Color
    else
        FOVCircle.Visible = false
    end
    
    -- Update ESP
    for player, esp in pairs(ESPObjects) do
        if player and player.Parent then
            UpdateESP(esp)
        end
    end
end)

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BluCC"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 450, 0, 400)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

MainFrame.BackgroundTransparency = 0.1

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "blu.cc | Visual ESP v2"
TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    AddLog("GUI closed via button")
end)

-- Tab System
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 35)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 5)
TabLayout.Parent = TabBar

-- Content Frames
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -20, 1, -105)
ContentContainer.Position = UDim2.new(0, 10, 0, 95)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

local CurrentTab = nil

-- Tab Creator
local function CreateTab(name)
    local TabButton = Instance.new("TextButton")
    TabButton.Size = UDim2.new(0, 100, 1, 0)
    TabButton.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
    TabButton.Text = name
    TabButton.TextColor3 = Color3.new(1, 1, 1)
    TabButton.TextSize = 13
    TabButton.Font = Enum.Font.GothamBold
    TabButton.Parent = TabBar
    
    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 6)
    TabCorner.Parent = TabButton
    
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Size = UDim2.new(1, 0, 1, 0)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ScrollBarThickness = 4
    ContentFrame.BorderSizePixel = 0
    ContentFrame.Visible = false
    ContentFrame.Parent = ContentContainer
    
    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.Padding = UDim.new(0, 8)
    ContentLayout.Parent = ContentFrame
    
    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 10)
    end)
    
    TabButton.MouseButton1Click:Connect(function()
        for _, child in pairs(ContentContainer:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                child.Visible = false
            end
        end
        for _, tab in pairs(TabBar:GetChildren()) do
            if tab:IsA("TextButton") then
                tab.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
            end
        end
        
        ContentFrame.Visible = true
        TabButton.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        CurrentTab = name
        AddLog("Switched to " .. name .. " tab")
    end)
    
    return ContentFrame
end

-- Create Tabs
local RenderTab = CreateTab("Render")
local CombatTab = CreateTab("Combat")
local MiscTab = CreateTab("Misc")
local LogsTab = CreateTab("Logs")

-- Toggle Creator
local function CreateToggle(parent, name, setting, category)
    local Toggle = Instance.new("Frame")
    Toggle.Size = UDim2.new(1, -8, 0, 35)
    Toggle.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
    Toggle.BorderSizePixel = 0
    Toggle.Parent = parent
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = Toggle
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -65, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Toggle
    
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 50, 0, 25)
    Button.Position = UDim2.new(1, -60, 0.5, -12.5)
    Button.BackgroundColor3 = setting.Enabled and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 70)
    Button.Text = setting.Enabled and "ON" or "OFF"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.Font = Enum.Font.GothamBold
    Button.Parent = Toggle
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button
    
    Button.MouseButton1Click:Connect(function()
        setting.Enabled = not setting.Enabled
        Button.Text = setting.Enabled and "ON" or "OFF"
        Button.BackgroundColor3 = setting.Enabled and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 70)
        AddLog(name .. " " .. (setting.Enabled and "enabled" or "disabled"))
    end)
end

-- Render Tab Toggles
CreateToggle(RenderTab, "Tracers", Settings.Render.Tracers)
CreateToggle(RenderTab, "ESP Boxes", Settings.Render.ESP)
CreateToggle(RenderTab, "Chams", Settings.Render.Chams)
CreateToggle(RenderTab, "Distance", Settings.Render.Distance)
CreateToggle(RenderTab, "Nametags", Settings.Render.Nametags)
CreateToggle(RenderTab, "Health Bars", Settings.Render.HealthBar)
CreateToggle(RenderTab, "Skeleton ESP", Settings.Render.Skeleton)
CreateToggle(RenderTab, "FOV Circle", Settings.Render.FOVCircle)

-- Combat Tab Toggles (Placeholders - for visual only)
CreateToggle(CombatTab, "Aimbot", Settings.Combat.Aimbot)
CreateToggle(CombatTab, "Trigger Bot", Settings.Combat.TriggerBot)
CreateToggle(CombatTab, "Spin Bot", Settings.Combat.SpinBot)
CreateToggle(CombatTab, "No Recoil", Settings.Combat.NoRecoil)
CreateToggle(CombatTab, "Rapid Fire", Settings.Combat.RapidFire)
CreateToggle(CombatTab, "Infinite Ammo", Settings.Combat.InfiniteAmmo)

-- Misc Tab Toggles
CreateToggle(MiscTab, "Team Check", Settings.Misc.TeamCheck)
CreateToggle(MiscTab, "Walk Speed", Settings.Misc.WalkSpeed)
CreateToggle(MiscTab, "Jump Power", Settings.Misc.JumpPower)
CreateToggle(MiscTab, "No Clip", Settings.Misc.NoClip)
CreateToggle(MiscTab, "Flight", Settings.Misc.Flight)
CreateToggle(MiscTab, "Anti AFK", Settings.Misc.AntiAFK)

-- Logs Display
local LogsDisplay = Instance.new("TextLabel")
LogsDisplay.Size = UDim2.new(1, -8, 1, -8)
LogsDisplay.Position = UDim2.new(0, 4, 0, 4)
LogsDisplay.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
LogsDisplay.BorderSizePixel = 0
LogsDisplay.TextColor3 = Color3.fromRGB(200, 200, 200)
LogsDisplay.TextSize = 12
LogsDisplay.Font = Enum.Font.Code
LogsDisplay.TextXAlignment = Enum.TextXAlignment.Left
LogsDisplay.TextYAlignment = Enum.TextYAlignment.Top
LogsDisplay.Text = ""
LogsDisplay.TextWrapped = true
LogsDisplay.Parent = LogsTab

local LogsCorner = Instance.new("UICorner")
LogsCorner.CornerRadius = UDim.new(0, 8)
LogsCorner.Parent = LogsDisplay

local function UpdateLogs()
    local logText = ""
    for i = #Logs, math.max(1, #Logs - 20), -1 do
        logText = logText .. "[" .. Logs[i].Time .. "] " .. Logs[i].Message .. "\n"
    end
    LogsDisplay.Text = logText
end

-- Update logs every second
spawn(function()
    while true do
        wait(1)
        UpdateLogs()
    end
end)

-- Set default tab
for _, tab in pairs(TabBar:GetChildren()) do
    if tab:IsA("TextButton") and tab.Text == "Render" then
        tab.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        break
    end
end
RenderTab.Visible = true

-- Toggle GUI with Right Shift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
        if MainFrame.Visible then
            AddLog("GUI opened (Right Shift)")
        else
            AddLog("GUI closed (Right Shift)")
        end
    end
end)

AddLog("Press Right Shift to toggle GUI")
print("blu.cc loaded! Press Right Shift to toggle GUI")
