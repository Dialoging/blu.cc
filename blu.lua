local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SOUND_IDS = {
    Click = "rbxassetid://15675059323",
    Hover = "rbxassetid://10066931761"
}

local Settings = {
    Render = {
        Tracers    = { Enabled = false, Color = Color3.fromRGB(100,150,255), Thickness = 2 },
        ESP        = { Enabled = false, Color = Color3.fromRGB(100,150,255), Thickness = 2 },
        Chams      = { Enabled = false, FillColor = Color3.fromRGB(100,150,255), OutlineColor = Color3.fromRGB(150,200,255) },
        Distance  = { Enabled = false, Color = Color3.new(1,1,1) },
        Nametags  = { Enabled = false, Color = Color3.new(1,1,1) },
        HealthBar = { Enabled = false },
        Skeleton  = { Enabled = false, Color = Color3.new(1,1,1) },
        FOVCircle = { Enabled = false, Radius = 100, Color = Color3.new(1,1,1) }
    },
    Combat = {
        Aimbot     = { Enabled = false },
        TriggerBot   = { Enabled = false },
        SpinBot      = { Enabled = false },
        NoRecoil     = { Enabled = false },
        RapidFire    = { Enabled = false },
        InfiniteAmmo = { Enabled = false }
    },
    Misc = {
        TeamCheck = { Enabled = true },
        WalkSpeed = { Enabled = false, Value = 16 },
        JumpPower = { Enabled = false, Value = 50 },
        NoClip    = { Enabled = false },
        Flight    = { Enabled = false },
        AntiAFK   = { Enabled = false }
    }
}

local ESPObjects = {}
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.ZIndex = 999

local function PlaySound(soundId)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.5
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Wait()
    sound:Destroy()
end

local function IsTeamMate(player)
    if not Settings.Misc.TeamCheck.Enabled then return false end
    return player.Team == LocalPlayer.Team and player.Team ~= nil
end

local function NewDrawing(type)
    return Drawing.new(type)
end

local function CreateESPForPlayer(player)
    if player == LocalPlayer then return end

    local esp = {
        Player = player,
        Tracer = NewDrawing("Line"),
        BoxOutline = {},
        BoxInline = {},
        DistanceText = NewDrawing("Text"),
        NameText = NewDrawing("Text"),
        HealthBarOutline = NewDrawing("Square"),
        HealthBarInline = NewDrawing("Square"),
        Skeleton = {},
        Chams = {}
    }

    for i = 1, 4 do
        esp.BoxOutline[i] = NewDrawing("Line")
        esp.BoxInline[i] = NewDrawing("Line")
    end

    for i = 1, 6 do
        esp.Skeleton[i] = NewDrawing("Line")
    end

    esp.DistanceText.Size = 14
    esp.DistanceText.Center = true
    esp.DistanceText.Outline = true

    esp.NameText.Size = 14
    esp.NameText.Center = true
    esp.NameText.Outline = true

    esp.HealthBarOutline.Thickness = 1
    esp.HealthBarOutline.Filled = false
    esp.HealthBarInline.Filled = true

    return esp
end

local function RemoveESP(esp)
    esp.Tracer:Remove()
    for _, v in ipairs(esp.BoxOutline) do v:Remove() end
    for _, v in ipairs(esp.BoxInline)  do v:Remove() end
    for _, v in ipairs(esp.Skeleton)    do v:Remove() end
    esp.DistanceText:Remove()
    esp.NameText:Remove()
    esp.HealthBarOutline:Remove()
    esp.HealthBarInline:Remove()
    for _, cham in pairs(esp.Chams) do
        pcall(function() cham:Destroy() end)
    end
end

local function UpdateESP(esp)
    local player = esp.Player
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not hrp or not head or not hum or hum.Health <= 0 then
        esp.Tracer.Visible = false
        for i = 1, 4 do
            esp.BoxOutline[i].Visible = false
            esp.BoxInline[i].Visible  = false
        end
        for i = 1, 6 do esp.Skeleton[i].Visible = false end
        esp.DistanceText.Visible = false
        esp.NameText.Visible       = false
        esp.HealthBarOutline.Visible = false
        esp.HealthBarInline.Visible  = false
        return
    end

    local isTeam = IsTeamMate(player)
    local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) and
        (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude or 0

    local hrp2d, vis = Camera:WorldToViewportPoint(hrp.Position)
    if not vis then
        esp.Tracer.Visible = false
        for i = 1, 4 do
            esp.BoxOutline[i].Visible = false
            esp.BoxInline[i].Visible  = false
        end
        for i = 1, 6 do esp.Skeleton[i].Visible = false end
        esp.DistanceText.Visible = false
        esp.NameText.Visible       = false
        esp.HealthBarOutline.Visible = false
        esp.HealthBarInline.Visible  = false
        return
    end

    local head2d = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local leg2d  = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    local color  = isTeam and Color3.fromRGB(100, 255, 100) or Settings.Render.ESP.Color

    if Settings.Render.Tracers.Enabled and not isTeam then
        esp.Tracer.Visible = true
        esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        esp.Tracer.To    = Vector2.new(hrp2d.X, hrp2d.Y)
        esp.Tracer.Color = Settings.Render.Tracers.Color
        esp.Tracer.Thickness = Settings.Render.Tracers.Thickness
    else
        esp.Tracer.Visible = false
    end

    if Settings.Render.ESP.Enabled and not isTeam then
        local height = math.abs(head2d.Y - leg2d.Y)
        local width  = height / 2
        local pts = {
            Vector2.new(hrp2d.X - width/2, head2d.Y),
            Vector2.new(hrp2d.X + width/2, head2d.Y),
            Vector2.new(hrp2d.X + width/2, leg2d.Y),
            Vector2.new(hrp2d.X - width/2, leg2d.Y)
        }

        for i = 1, 4 do
            local n = i % 4 + 1
            esp.BoxOutline[i].Visible = true
            esp.BoxOutline[i].From = pts[i]
            esp.BoxOutline[i].To    = pts[n]
            esp.BoxOutline[i].Color = Color3.new(0, 0, 0)
            esp.BoxOutline[i].Thickness = Settings.Render.ESP.Thickness + 1

            esp.BoxInline[i].Visible = true
            esp.BoxInline[i].From = pts[i]
            esp.BoxInline[i].To    = pts[n]
            esp.BoxInline[i].Color = color
            esp.BoxInline[i].Thickness  = Settings.Render.ESP.Thickness
        end

        if Settings.Render.HealthBar.Enabled then
            local pct = hum.Health / hum.MaxHealth
            esp.HealthBarOutline.Visible = true
            esp.HealthBarOutline.Size = Vector2.new(3, height)
            esp.HealthBarOutline.Position = Vector2.new(pts[4].X - 8, head2d.Y)
            esp.HealthBarOutline.Color = Color3.new(0, 0, 0)

            esp.HealthBarInline.Visible = true
            esp.HealthBarInline.Size = Vector2.new(2, height * pct)
            esp.HealthBarInline.Position = Vector2.new(pts[4].X - 7.5, head2d.Y + height * (1 - pct))
            esp.HealthBarInline.Color = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
        else
            esp.HealthBarOutline.Visible = false
            esp.HealthBarInline.Visible  = false
        end
    else
        for i = 1, 4 do
            esp.BoxOutline[i].Visible = false
            esp.BoxInline[i].Visible  = false
        end
        esp.HealthBarOutline.Visible = false
        esp.HealthBarInline.Visible  = false
    end

    if Settings.Render.Skeleton.Enabled and not isTeam then
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        local la = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm")
        local ra = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
        local ll = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg")
        local rl = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")

        if torso and la and ra and ll and rl then
            local bones = {
                {head, torso},
                {torso, la},
                {torso, ra},
                {torso, ll},
                {torso, rl}
            }
            for i = 1, 5 do
                local p1, p2 = bones[i][1], bones[i][2]
                local v1, v2 = Camera:WorldToViewportPoint(p1.Position), Camera:WorldToViewportPoint(p2.Position)
                if v1.Z > 0 and v2.Z > 0 then
                    esp.Skeleton[i].Visible = true
                    esp.Skeleton[i].From = Vector2.new(v1.X, v1.Y)
                    esp.Skeleton[i].To    = Vector2.new(v2.X, v2.Y)
                    esp.Skeleton[i].Color = Settings.Render.Skeleton.Color
                    esp.Skeleton[i].Thickness = 1
                else
                    esp.Skeleton[i].Visible = false
                end
            end
        end
    else
        for i = 1, 6 do esp.Skeleton[i].Visible = false end
    end

    if Settings.Render.Distance.Enabled and not isTeam then
        esp.DistanceText.Visible = true
        esp.DistanceText.Position = Vector2.new(hrp2d.X, leg2d.Y + 5)
        esp.DistanceText.Text = string.format("%.0f studs", distance)
        esp.DistanceText.Color = Settings.Render.Distance.Color
    else
        esp.DistanceText.Visible = false
    end

    if Settings.Render.Nametags.Enabled and not isTeam then
        esp.NameText.Visible = true
        esp.NameText.Position = Vector2.new(hrp2d.X, head2d.Y - 15)
        esp.NameText.Text = player.Name
        esp.NameText.Color = Settings.Render.Nametags.Color
    else
        esp.NameText.Visible = false
    end

    if Settings.Render.Chams.Enabled and not isTeam then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not esp.Chams[part] then
                local h = Instance.new("Highlight")
                h.Adornee = part
                h.FillColor = Settings.Render.Chams.FillColor
                h.OutlineColor = Settings.Render.Chams.OutlineColor
                h.FillTransparency = 0.5
                h.OutlineTransparency = 0
                h.Parent = part
                esp.Chams[part] = h
            end
        end
    else
        for part, cham in pairs(esp.Chams) do
            pcall(function() cham:Destroy() end)
            esp.Chams[part] = nil
        end
    end
end

local function OnPlayerAdded(player)
    ESPObjects[player] = CreateESPForPlayer(player)
end

local function OnPlayerRemoving(player)
    if ESPObjects[player] then
        RemoveESP(ESPObjects[player])
        ESPObjects[player] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do OnPlayerAdded(player) end
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

RunService.RenderStepped:Connect(function()
    if Settings.Render.FOVCircle.Enabled then
        FOVCircle.Visible = true
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Settings.Render.FOVCircle.Radius
        FOVCircle.Color = Settings.Render.FOVCircle.Color
    else
        FOVCircle.Visible = false
    end

    for player, esp in pairs(ESPObjects) do
        if player and player.Parent then UpdateESP(esp) end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "blu.cc"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 450, 0, 400)
Main.Position = UDim2.new(0.5, -225, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "blu.cc"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -35, 0, 5)
Close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
Close.Text = "X"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.TextSize = 16
Close.Font = Enum.Font.GothamBold
Close.Parent = TitleBar
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 6)

Close.MouseButton1Click:Connect(function()  
    PlaySound(SOUND_IDS.Click)
    ScreenGui:Destroy() 
end)
Close.MouseEnter:Connect(function() PlaySound(SOUND_IDS.Hover) end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 35)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 5)
TabLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -105)
Content.Position = UDim2.new(0, 10, 0, 95)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Tabs, Frames = {}, {}

local function AddTab(name)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 80, 1, 0)
    Button.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
    Button.Text = name
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 13
    Button.Font = Enum.Font.GothamBold
    Button.Parent = TabBar
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 6)

    local Frame = Instance.new("ScrollingFrame")
    Frame.Size = UDim2.new(1, 0, 1, 0)
    Frame.BackgroundTransparency = 1
    Frame.ScrollBarThickness = 4
    Frame.BorderSizePixel = 0
    Frame.Visible = false
    Frame.Parent = Content

    local List = Instance.new("UIListLayout")
    List.Padding = UDim.new(0, 6)
    List.Parent = Frame

    List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Frame.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 10)
    end)

    Button.MouseButton1Click:Connect(function()
        PlaySound(SOUND_IDS.Click)
        for _, f in ipairs(Frames) do f.Visible = false end
        for _, b in ipairs(Tabs) do b.BackgroundColor3 = Color3.fromRGB(25, 35, 50) end
        Frame.Visible = true
        Button.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
    end)
    Button.MouseEnter:Connect(function() PlaySound(SOUND_IDS.Hover) end)

    table.insert(Tabs, Button)
    table.insert(Frames, Frame)
    return Frame
end

local RenderTab  = AddTab("Render")
local CombatTab  = AddTab("Combat")
local MiscTab    = AddTab("Misc")
local SettingsTab= AddTab("Settings")

local function CreateToggle(parent, name, tbl)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -8, 0, 32)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
    Frame.BorderSizePixel = 0
    Frame.Parent = parent
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -65, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 50, 0, 24)
    Button.Position = UDim2.new(1, -60, 0.5, -12)
    Button.BackgroundColor3 = tbl.Enabled and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 70)
    Button.Text = tbl.Enabled and "ON" or "OFF"
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.Font = Enum.Font.GothamBold
    Button.Parent = Frame
    Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 6)

    Button.MouseButton1Click:Connect(function()
        PlaySound(SOUND_IDS.Click)
        tbl.Enabled = not tbl.Enabled
        Button.Text = tbl.Enabled and "ON" or "OFF"
        Button.BackgroundColor3 = tbl.Enabled and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 70)
    end)
    Button.MouseEnter:Connect(function() PlaySound(SOUND_IDS.Hover) end)
end

local function CreateSlider(parent, name, min, max, value, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -8, 0, 36)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
    Frame.BorderSizePixel = 0
    Frame.Parent = parent
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -10, 0, 18)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0, 50, 0, 18)
    Box.Position = UDim2.new(1, -60, 0, 2)
    Box.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
    Box.Text = tostring(value)
    Box.TextColor3 = Color3.new(1, 1, 1)
    Box.TextSize = 12
    Box.Font = Enum.Font.Gotham
    Box.ClearTextOnFocus = false
    Box.Parent = Frame
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)

    Box.FocusLost:Connect(function()
        PlaySound(SOUND_IDS.Click)
        local n = tonumber(Box.Text) or value
        n = math.clamp(n, min, max)
        Box.Text = tostring(n)
        callback(n)
    end)
    Box.MouseEnter:Connect(function() PlaySound(SOUND_IDS.Hover) end)
end

do
    CreateToggle(RenderTab, "Tracers",    Settings.Render.Tracers)
    CreateToggle(RenderTab, "ESP Boxes", Settings.Render.ESP)
    CreateToggle(RenderTab, "Chams",      Settings.Render.Chams)
    CreateToggle(RenderTab, "Distance",  Settings.Render.Distance)
    CreateToggle(RenderTab, "Nametags",  Settings.Render.Nametags)
    CreateToggle(RenderTab, "Health Bars", Settings.Render.HealthBar)
    CreateToggle(RenderTab, "Skeleton",  Settings.Render.Skeleton)
    CreateToggle(RenderTab, "FOV Circle", Settings.Render.FOVCircle)
end

do
    CreateToggle(CombatTab, "Aimbot",        Settings.Combat.Aimbot)
    CreateToggle(CombatTab, "Trigger Bot",  Settings.Combat.TriggerBot)
    CreateToggle(CombatTab, "Spin Bot",      Settings.Combat.SpinBot)
    CreateToggle(CombatTab, "No Recoil",    Settings.Combat.NoRecoil)
    CreateToggle(CombatTab, "Rapid Fire",    Settings.Combat.RapidFire)
    CreateToggle(CombatTab, "Infinite Ammo", Settings.Combat.InfiniteAmmo)
end

do
    CreateToggle(MiscTab, "Team Check", Settings.Misc.TeamCheck)
    CreateToggle(MiscTab, "Walk Speed", Settings.Misc.WalkSpeed)
    CreateToggle(MiscTab, "Jump Power", Settings.Misc.JumpPower)
    CreateToggle(MiscTab, "No Clip",    Settings.Misc.NoClip)
    CreateToggle(MiscTab, "Flight",      Settings.Misc.Flight)
    CreateToggle(MiscTab, "Anti AFK",    Settings.Misc.AntiAFK)
end

do
    CreateSlider(SettingsTab, "ESP Thickness",    1, 5, Settings.Render.ESP.Thickness,
        function(v) Settings.Render.ESP.Thickness = v end)
    CreateSlider(SettingsTab, "Tracer Thickness", 1, 5, Settings.Render.Tracers.Thickness,
        function(v) Settings.Render.Tracers.Thickness = v end)
    CreateSlider(SettingsTab, "FOV Radius",        30, 300, Settings.Render.FOVCircle.Radius,
        function(v) Settings.Render.FOVCircle.Radius = v end)
end

Tabs[1].BackgroundColor3 = Color3.fromRGB(50, 120, 220)
Frames[1].Visible = true

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
        PlaySound(SOUND_IDS.Click)
    end
end)
