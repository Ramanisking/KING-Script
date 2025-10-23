# KING-Script
Roblox script loader
-- KING Panel Loader Script
local panelConfig = {
    enabled = true,
    position = UDim2.new(0.1, 0, 0.1, 0),
    size = UDim2.new(0, 250, 0, 400),
    backgroundColor = Color3.fromRGB(75, 0, 130),
    borderSize = 2,
    borderColor = Color3.new(1, 1, 1)
}

local aimbotSettings = { enabled = false, smoothness = 50, fov = 10, targetPart = "Head" }
local espSettings = { enabled = false, distance = 120 }
local movementSettings = { speedHack = false, speedMultiplier = 2, fly = false, bunnyHop = false, bunnyStrength = 50 }
local aimCircleSettings = { enabled = false, radius = 50, color = Color3.new(0, 1, 0), thickness = 2 }

local keybinds = { aimLockKey = Enum.KeyCode.LeftShift, menuToggleKey = Enum.KeyCode.RightAlt }
local localPlayer = game.Players.LocalPlayer

local function printDebug(msg)
    print("KING_DEBUG: " .. msg)
end

local function getClosestPlayer(fov)
    if not localPlayer.Character then return nil end
    local camera = workspace.CurrentCamera
    local origin = camera.CFrame.Position
    local closest, minDist = nil, math.huge
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local root = p.Character.HumanoidRootPart
            local dist = (root.Position - origin).Magnitude
            if dist < minDist and dist <= fov * 10 then
                minDist = dist
                closest = p
            end
        end
    end
    return closest
end

local function update()
    local char = localPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") then
        return
    end
    local humanoid = char.Humanoid
    local root = char.HumanoidRootPart

    -- Aimbot
    if aimbotSettings.enabled then
        local target = getClosestPlayer(aimbotSettings.fov)
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(aimbotSettings.targetPart)
            if targetPart then
                local aimVector = (targetPart.Position - camera.CFrame.Position).Unit
                local newAim = camera.CFrame.LookVector:Lerp(aimVector, aimbotSettings.smoothness / 100)
                camera.CFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + newAim)
            end
        end
    end

    -- Movement
    if movementSettings.speedHack then
        humanoid.WalkSpeed = 16 * movementSettings.speedMultiplier
    end
    if movementSettings.fly and game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
        root.Velocity = root.Velocity + Vector3.new(0, 50, 0)
        humanoid.PlatformStand = true
    else
        humanoid.PlatformStand = false
    end
    if movementSettings.bunnyHop and humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.MoveDirection.Magnitude > 0 then
        humanoid.JumpPower = movementSettings.bunnyStrength
        humanoid.Jump = true
    end

    -- Aim Lock
    if game:GetService("UserInputService"):IsKeyDown(keybinds.aimLockKey) then
        local target = getClosestPlayer(aimbotSettings.fov)
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(aimbotSettings.targetPart)
            if targetPart then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
            end
        end
    end
end

-- Simple UI (No sliders for now to avoid complexity; toggles only)
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = game.CoreGui
    screenGui.Name = "KING_UI"

    local panel = Instance.new("Frame")
    panel.Size = panelConfig.size
    panel.Position = panelConfig.position
    panel.BackgroundColor3 = panelConfig.backgroundColor
    panel.BorderSizePixel = panelConfig.borderSize
    panel.BorderColor3 = panelConfig.borderColor
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "KING"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.Parent = panel

    local yOffset = 35
    local function addToggle(name, setting, callback)
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(1, -10, 0, 25)
        toggle.Position = UDim2.new(0, 5, 0, yOffset)
        toggle.Text = name .. ": Off"
        toggle.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        toggle.TextColor3 = Color3.new(1, 1, 1)
        toggle.Parent = panel
        toggle.MouseButton1Click:Connect(function()
            setting = not setting
            toggle.Text = name .. ": " .. (setting and "On" or "Off")
            callback(setting)
        end)
        yOffset = yOffset + 30
    end

    addToggle("Aimbot", aimbotSettings.enabled, function(v) aimbotSettings.enabled = v end)
    addToggle("ESP", espSettings.enabled, function(v) espSettings.enabled = v end)
    addToggle("Speed Hack", movementSettings.speedHack, function(v) movementSettings.speedHack = v end)
    addToggle("Fly (Hold Space)", movementSettings.fly, function(v) movementSettings.fly = v end)
    addToggle("Bunny Hop", movementSettings.bunnyHop, function(v) movementSettings.bunnyHop = v end)
    addToggle("Aim Circle", aimCircleSettings.enabled, function(v) aimCircleSettings.enabled = v end)

    -- Toggle panel with RightAlt
    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.KeyCode == keybinds.menuToggleKey then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)
end

-- Run
game:GetService("RunService").RenderStepped:Connect(update)
createUI()
printDebug("KING loaded successfully!")
