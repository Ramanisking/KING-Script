-- KING Script for Roblox
local panelConfig = {
    enabled = true,
    position = UDim2.new(0.1, 0, 0.1, 0),
    size = UDim2.new(0, 250, 0, 300),
    backgroundColor = Color3.fromRGB(75, 0, 130),
    borderSize = 2,
    borderColor = Color3.new(1, 1, 1)
}

local aimbotSettings = { enabled = false, smoothness = 50, fov = 10, targetPart = "Head" }
local movementSettings = { speedHack = false, speedMultiplier = 2, fly = false }
local keybinds = { aimLockKey = Enum.KeyCode.LeftShift, menuToggleKey = Enum.KeyCode.RightAlt }

local function printDebug(msg)
    print("KING_DEBUG: " .. msg)
end

local function getClosestPlayer(fov)
    local player = game.Players.LocalPlayer
    if not player.Character then return nil end
    local camera = workspace.CurrentCamera
    local origin = camera.CFrame.Position
    local closest, minDist = nil, math.huge
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
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
    local player = game.Players.LocalPlayer
    local char = player.Character
    if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") then
        printDebug("No character loaded")
        return
    end
    local humanoid = char.Humanoid
    local root = char.HumanoidRootPart

    if aimbotSettings.enabled then
        local target = getClosestPlayer(aimbotSettings.fov)
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(aimbotSettings.targetPart)
            if targetPart then
                local aimVector = (targetPart.Position - workspace.CurrentCamera.CFrame.Position).Unit
                local newAim = workspace.CurrentCamera.CFrame.LookVector:Lerp(aimVector, aimbotSettings.smoothness / 100)
                workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + newAim)
            end
        end
    end

    if movementSettings.speedHack then
        humanoid.WalkSpeed = 16 * movementSettings.speedMultiplier
    end
    if movementSettings.fly and game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
        root.Velocity = root.Velocity + Vector3.new(0, 50, 0)
        humanoid.PlatformStand = true
    else
        humanoid.PlatformStand = false
    end

    if game:GetService("UserInputService"):IsKeyDown(keybinds.aimLockKey) then
        local target = getClosestPlayer(aimbotSettings.fov)
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(aimbotSettings.targetPart)
            if targetPart then
                workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, targetPart.Position)
            end
        end
    end
end

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
    title.Position = UDim2.new(0, 0, 0, 0)
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
        toggle.Text = name .. ": " .. (setting and "On" or "Off")
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
    addToggle("Speed Hack", movementSettings.speedHack, function(v) movementSettings.speedHack = v end)
    addToggle("Fly", movementSettings.fly, function(v) movementSettings.fly = v end)

    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.KeyCode == keybinds.menuToggleKey then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)
end

game:GetService("RunService").RenderStepped:Connect(update)
createUI()
printDebug("KING loaded at 11:20 PM CEST, Oct 23, 2025")
