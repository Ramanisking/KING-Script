-- KING Ultra High FPS Script (Dead Body Fix)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- Settings (Ultra FPS optimized)
local settings = {
    aimbot = {enabled = false, smoothness = 15, fov = 90, targetPart = "Head", maxDist = 200},
    esp = {enabled = false, distance = 120, wallCheck = true, showTeam = false},
    movement = {speedHack = false, speedMultiplier = 1.5, bunnyHop = false, bunnyStrength = 60},
    aimCircle = {enabled = false, radius = 30, thickness = 2},
    gunSync = true,
    antiBlind = true
}

local keybinds = {aimLock = Enum.KeyCode.LeftShift, menuToggle = Enum.KeyCode.RightAlt}
local connections = {}
local espBoxes = {}
local remoteHooks = {}
local currentTarget = nil
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.FilterDescendantsInstances = {localPlayer.Character}
local aimCircleInstance = nil

local function printDebug(msg)
    print("[KING Ultra FPS] " .. msg)
end

local function isEnemy(player)
    if not localPlayer.Team then return true end
    return player.Team ~= localPlayer.Team
end

local function raycastVisible(startPos, endPos)
    raycastParams.FilterDescendantsInstances = {localPlayer.Character}
    local ray = workspace:Raycast(startPos, (endPos - startPos), raycastParams)
    return not ray or ray.Instance:IsDescendantOf(currentTarget and currentTarget.Character or workspace)
end

local function getClosestPlayer(fov)
    local origin = camera.CFrame.Position
    local candidates = {}
    local playerList = Players:GetPlayers()
    for i = 1, math.min(12, #playerList) do
        local p = playerList[i]
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 and isEnemy(p) then
            local root = p.Character.HumanoidRootPart
            local dist = (root.Position - origin).Magnitude
            if dist <= settings.aimbot.maxDist then
                local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
                local angle = math.deg(math.asin(math.clamp((Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude / 2 / math.tan(math.rad(camera.FieldOfView / 2)), 0, 1)))
                local visible = raycastVisible(origin, root.Position)
                if onScreen and angle <= fov and visible then
                    table.insert(candidates, {player = p, dist = dist})
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    return candidates[1] and candidates[1].player or nil
end

local function hookFiringRemote(tool, targetPart)
    if not tool or not settings.gunSync then return end
    local remoteNames = {"ShootGun", "FireBullet", "Fire", "Shoot", "RemoteEvent", "OnFire", "Bullet", "FireServer"}
    for _, name in ipairs(remoteNames) do
        local remote = tool:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name) or tool.Parent:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            local originalFire = remote.FireServer
            remote.FireServer = function(self, ...)
                local args = {...}
                if targetPart and currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("Humanoid") and currentTarget.Character.Humanoid.Health > 0 then
                    local dist = (targetPart.Position - camera.CFrame.Position).Magnitude
                    local predicted = targetPart.Position + (targetPart.Velocity * (dist / 1200))
                    if typeof(args[1]) == "Vector3" then
                        args[1] = predicted
                    elseif typeof(args[1]) == "CFrame" then
                        args[1] = CFrame.lookAt(args[1].Position, predicted)
                    end
                end
                return originalFire(self, unpack(args))
            end
            table.insert(remoteHooks, {remote = remote, original = originalFire})
        end
    end
end

local function syncGunToTarget(targetPart, tool)
    if not tool or not settings.gunSync then return end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("Part")
    if handle then
        handle.CFrame = CFrame.lookAt(handle.Position, targetPart.Position)
        hookFiringRemote(tool, targetPart)
        pcall(function() handle.Recoil.Value = 0 end)
    end
    mouse.Hit = CFrame.lookAt(Vector3.new(), targetPart.Position)
end

local function updateAimbot()
    if not settings.aimbot.enabled then return end
    currentTarget = getClosestPlayer(settings.aimbot.fov)
    if currentTarget and currentTarget.Character then
        local targetPart = currentTarget.Character:FindFirstChild(settings.aimbot.targetPart)
        if targetPart and currentTarget.Character.Humanoid.Health > 0 then
            local dist = (targetPart.Position - camera.CFrame.Position).Magnitude
            local predictedPos = targetPart.Position + (currentTarget.Character.HumanoidRootPart.Velocity * (dist / 1200))
            local aimDir = (predictedPos - camera.CFrame.Position).Unit
            local currentDir = camera.CFrame.LookVector
            local lerpDir = currentDir:lerp(aimDir, settings.aimbot.smoothness / 100)
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + lerpDir)
            local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
            syncGunToTarget(targetPart, tool)
        elseif currentTarget and currentTarget.Character.Humanoid.Health <= 0 then
            currentTarget = nil
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + camera.CFrame.LookVector)  -- Reset to forward
            printDebug("Target " .. (currentTarget and currentTarget.Name or "unknown") .. " died, reset aim")
        end
    end
end

local function updateAntiBlind()
    if not settings.antiBlind then return end
    for _, effect in ipairs(workspace:GetChildren()) do
        if effect:IsA("Explosion") or effect:IsA("Fire") or effect:IsA("Smoke") then
            if localPlayer.Character and (effect.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude < 50 then
                effect.Transparency = 1
            end
        end
    end
end

local function updateESP()
    if not settings.esp.enabled then
        for _, box in pairs(espBoxes) do
            if box then box:Remove() end
        end
        espBoxes = {}
        return
    end
    local playerList = Players:GetPlayers()
    for i = 1, math.min(10, #playerList) do
        local p = playerList[i]
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local dist = (p.Character.HumanoidRootPart.Position - camera.CFrame.Position).Magnitude
            if dist <= settings.esp.distance then
                local visible = not settings.esp.wallCheck or raycastVisible(camera.CFrame.Position, p.Character.HumanoidRootPart.Position)
                local show = settings.esp.showTeam or isEnemy(p)
                if visible and show then
                    local box = espBoxes[p.Name]
                    if not box then
                        box = Drawing.new("Square")
                        box.Color = Color3.new(1, 1, 1)
                        box.Thickness = 2
                        box.Filled = false
                        box.Transparency = 0.7
                        box.Visible = true
                        espBoxes[p.Name] = box
                    end
                    local cframe, onScreen = camera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position, camera.CFrame)
                    if onScreen then
                        local scale = 1200 / cframe.Z
                        box.Size = Vector2.new(scale * 3.5, scale * 6)
                        box.Position = Vector2.new(cframe.X - box.Size.X / 2, cframe.Y - box.Size.Y / 2)
                    end
                elseif espBoxes[p.Name] then
                    espBoxes[p.Name]:Remove()
                    espBoxes[p.Name] = nil
                end
            elseif espBoxes[p.Name] then
                espBoxes[p.Name]:Remove()
                espBoxes[p.Name] = nil
            end
        end
    end
end

local function updateMovement()
    local char = localPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") then return end
    local humanoid = char.Humanoid

    if settings.movement.speedHack then
        humanoid.WalkSpeed = 16 * settings.movement.speedMultiplier
    end

    if settings.movement.bunnyHop then
        humanoid.JumpPower = settings.movement.bunnyStrength
        if humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.MoveDirection.Magnitude > 0 then
            humanoid.Jump = true
        end
    end
end

local function updateAimCircle()
    if not settings.aimCircle.enabled then
        if aimCircleInstance then
            aimCircleInstance:Remove()
            aimCircleInstance = nil
        end
        return
    end
    if not aimCircleInstance then
        aimCircleInstance = Drawing.new("Circle")
        aimCircleInstance.Color = Color3.new(0, 1, 0)
        aimCircleInstance.Thickness = settings.aimCircle.thickness
        aimCircleInstance.Filled = false
        aimCircleInstance.NumSides = 32
        aimCircleInstance.Transparency = 0.5
        aimCircleInstance.Visible = true
    end
    aimCircleInstance.Radius = settings.aimCircle.radius
    aimCircleInstance.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

local function aimLock()
    if UserInputService:IsKeyDown(keybinds.aimLock) then
        local manualTarget = getClosestPlayer(settings.aimbot.fov)
        if manualTarget and manualTarget.Character then
            local targetPart = manualTarget.Character:FindFirstChild(settings.aimbot.targetPart)
            if targetPart and manualTarget.Character.Humanoid.Health > 0 then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
                local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
                syncGunToTarget(targetPart, tool)
            end
        end
    end
end

-- ULTRA HIGH FPS: ALL RenderStepped (500+ FPS)
connections.updateAimbot = RunService.RenderStepped:Connect(updateAimbot)
connections.updateESP = RunService.RenderStepped:Connect(updateESP)
connections.updateMovement = RunService.RenderStepped:Connect(updateMovement)
connections.aimLock = RunService.RenderStepped:Connect(aimLock)
connections.updateAimCircle = RunService.RenderStepped:Connect(updateAimCircle)
connections.updateAntiBlind = RunService.RenderStepped:Connect(updateAntiBlind)

-- Cleanup
local function cleanup()
    for _, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}
    for _, box in pairs(espBoxes) do
        if box then box:Remove() end
    end
    espBoxes = {}
    for _, hook in pairs(remoteHooks) do
        if hook.remote and hook.original then hook.remote.FireServer = hook.original end
    end
    remoteHooks = {}
    if aimCircleInstance then
        aimCircleInstance:Remove()
        aimCircleInstance = nil
    end
end

-- UI Panel
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KING_UI"
screenGui.Parent = game.CoreGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 250, 0, 420)
panel.Position = UDim2.new(0.1, 0, 0.1, 0)
panel.BackgroundColor3 = Color3.fromRGB(75, 0, 130)
panel.BorderSizePixel = 2
panel.BorderColor3 = Color3.new(1, 1, 1)
panel.Active = true
panel.Draggable = true
panel.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "KING (500+ FPS)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = panel

local yPos = 35

local function addToggle(name, setting, callback)
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, 25)
    toggle.Position = UDim2.new(0, 5, 0, yPos)
    toggle.Text = name .. ": " .. (setting and "On" or "Off")
    toggle.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.Parent = panel
    toggle.MouseButton1Click:Connect(function()
        setting = not setting
        toggle.Text = name .. ": " .. (setting and "On" or "Off")
        callback(setting)
        if not setting then cleanup() end
    end)
    yPos = yPos + 30
end

local function addSlider(name, value, min, max, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 25)
    frame.Position = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    frame.Parent = panel

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. math.floor(value)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(0.4, 0, 1, -2)
    slider.Position = UDim2.new(0.6, 0, 0, 1)
    slider.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
    slider.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.new(0, 0.5, 1)
    fill.Parent = slider

    local dragging = false
    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local percent = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            local newValue = min + (max - min) * percent
            callback(newValue)
            label.Text = name .. ": " .. math.floor(newValue)
            fill.Size = UDim2.new(percent, 0, 1, 0)
        end
    end)
    yPos = yPos + 30
end

-- Controls
addToggle("Aimbot (Visible Only)", settings.aimbot.enabled, function(v) settings.aimbot.enabled = v end)
addSlider("Smoothness", settings.aimbot.smoothness, 0, 100, function(v) settings.aimbot.smoothness = v end)
addSlider("FOV", settings.aimbot.fov, 0, 180, function(v) settings.aimbot.fov = v end)
addSlider("Max Distance", settings.aimbot.maxDist, 50, 500, function(v) settings.aimbot.maxDist = v end)
addToggle("Gun Sync (Silent Aim)", settings.gunSync, function(v) settings.gunSync = v end)
addToggle("Anti-Blind", settings.antiBlind, function(v) settings.antiBlind = v end)
addToggle("ESP (White Box)", settings.esp.enabled, function(v) settings.esp.enabled = v end)
addSlider("ESP Distance", settings.esp.distance, 10, 120, function(v) settings.esp.distance = v end)
addToggle("Wall Check", settings.esp.wallCheck, function(v) settings.esp.wallCheck = v end)
addToggle("Team ESP (Blue)", settings.esp.showTeam, function(v) settings.esp.showTeam = v end)
addToggle("Speed Hack", settings.movement.speedHack, function(v) settings.movement.speedHack = v end)
addSlider("Speed Multi", settings.movement.speedMultiplier, 1, 5, function(v) settings.movement.speedMultiplier = v end)
addToggle("Bunny Hop", settings.movement.bunnyHop, function(v) settings.movement.bunnyHop = v end)
addSlider("Bunny Strength", settings.movement.bunnyStrength, 0, 100, function(v) settings.movement.bunnyStrength = v end)
addToggle("Aim Circle", settings.aimCircle.enabled, function(v) settings.aimCircle.enabled = v end)
addSlider("Circle Radius", settings.aimCircle.radius, 10, 100, function(v) settings.aimCircle.radius = v end)

-- Menu Toggle
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == keybinds.menuToggle then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

printDebug("KING Ultra FPS loaded - Dead body fix applied (Oct 24, 2025)!")
