-- KING Rivals Cheat Script (Team Check Fixed)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- Settings (Rivals-tuned defaults)
local settings = {
    aimbot = {enabled = false, smoothness = 20, fov = 90, targetPart = "Head"},
    esp = {enabled = false, distance = 200, wallCheck = true, showTeam = false},  -- New: showTeam for blue teammate ESP
    movement = {speedHack = false, speedMultiplier = 1.5, fly = false, bunnyHop = false, bunnyStrength = 60},
    aimCircle = {enabled = false, radius = 30, thickness = 2},
    gunSync = true,  -- Silent aim + rotation
    triggerBot = false,  -- Auto-fire on target
    antiBlind = true  -- Disable flashes/smoke
}

local keybinds = {aimLock = Enum.KeyCode.LeftShift, menuToggle = Enum.KeyCode.RightAlt}
local connections = {}
local espGuis = {}
local remoteHooks = {}
local currentTarget = nil

local function printDebug(msg)
    print("[KING Rivals] " .. msg)
end

local function isEnemy(player)
    if not localPlayer.Team then return true end  -- No teams = target all
    return player.Team ~= localPlayer.Team
end

local function raycastWallCheck(startPos, endPos)
    local ray = workspace:Raycast(startPos, (endPos - startPos).Unit * (endPos - startPos).Magnitude)
    return not ray or ray.Instance:IsDescendantOf(currentTarget and currentTarget.Character or workspace)
end

local function getClosestPlayer(fov)
    local origin = camera.CFrame.Position
    local closest, minDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 and isEnemy(p) then  -- Team check added
            local root = p.Character.HumanoidRootPart
            local dist = (root.Position - origin).Magnitude
            local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
            local angle = math.deg(math.asin(math.clamp((Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude / 2 / math.tan(math.rad(camera.FieldOfView / 2)), 0, 1)))
            local visible = not settings.esp.wallCheck or raycastWallCheck(origin, root.Position)
            if onScreen and angle <= fov and visible and dist < minDist and dist <= 500 then
                minDist = dist
                closest = p
            elseif not isEnemy(p) then
                printDebug("Skipped teammate: " .. p.Name)
            end
        end
    end
    return closest
end

local function hookFiringRemote(tool, targetPart)
    if not tool or not settings.gunSync then return end
    local remoteNames = {"Fire", "Shoot", "RemoteEvent", "OnFire", "Bullet", "FireServer"}  -- Rivals common remotes
    for _, name in ipairs(remoteNames) do
        local remote = tool:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name) or tool.Parent:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            local originalFire = remote.FireServer
            remote.FireServer = function(self, ...)
                local args = {...}
                if targetPart and currentTarget then
                    local dist = (targetPart.Position - camera.CFrame.Position).Magnitude
                    local predicted = targetPart.Position + (targetPart.Velocity * (dist / 800))  -- Rivals bullet speed ~800
                    if typeof(args[1]) == "Vector3" then
                        args[1] = predicted
                    elseif typeof(args[1]) == "CFrame" then
                        args[1] = CFrame.lookAt(args[1].Position, predicted)
                    end
                    printDebug("Silent aim: Bullet redirected to " .. currentTarget.Name .. "'s head")
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
        local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)  -- Faster for Rivals
        local lookCFrame = CFrame.lookAt(handle.Position, targetPart.Position)
        local tween = TweenService:Create(handle, tweenInfo, {CFrame = lookCFrame})
        tween:Play()
        hookFiringRemote(tool, targetPart)
        -- Recoil reset for Rivals guns
        pcall(function() handle.Recoil.Value = 0 end)
        printDebug("Gun synced + hooked for " .. targetPart.Parent.Name)
    end
    mouse.Hit = CFrame.lookAt(Vector3.new(), targetPart.Position)
end

local function updateAimbot()
    if not settings.aimbot.enabled then return end
    currentTarget = getClosestPlayer(settings.aimbot.fov)
    if currentTarget and currentTarget.Character then
        local targetPart = currentTarget.Character:FindFirstChild(settings.aimbot.targetPart)
        if targetPart then
            local dist = (targetPart.Position - camera.CFrame.Position).Magnitude
            local predictedPos = targetPart.Position + (currentTarget.Character.HumanoidRootPart.Velocity * (dist / 800))  -- Rivals bullet speed ~800
            local aimDir = (predictedPos - camera.CFrame.Position).Unit
            local currentDir = camera.CFrame.LookVector
            local lerpDir = currentDir:lerp(aimDir, settings.aimbot.smoothness / 100)
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + lerpDir)
            local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
            syncGunToTarget(targetPart, tool)
        end
    end
end

local function updateTriggerBot()
    if not settings.triggerBot then return end
    local target = getClosestPlayer(5)  -- Small FOV for trigger, with team check
    if target and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
        printDebug("Trigger bot fired on enemy " .. target.Name)
    end
end

local function updateAntiBlind()
    if not settings.antiBlind then return end
    -- Clear screen effects (flashes, smoke in Rivals)
    for _, effect in ipairs(workspace:GetDescendants()) do
        if effect:IsA("Explosion") or effect:IsA("Fire") or effect:IsA("Smoke") then
            if (effect.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude < 50 then
                effect.Transparency = 1
            end
        end
    end
end

local function updateESP()
    if not settings.esp.enabled then
        for _, gui in pairs(espGuis) do gui:Destroy() end
        espGuis = {}
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (p.Character.HumanoidRootPart.Position - camera.CFrame.Position).Magnitude
            local visible = not settings.esp.wallCheck or raycastWallCheck(camera.CFrame.Position, p.Character.HumanoidRootPart.Position)
            local show = settings.esp.showTeam or isEnemy(p)  -- Show teammates only if toggled
            if dist <= settings.esp.distance and visible and show then
                local gui = espGuis[p.Name]
                if not gui then
                    gui = Instance.new("BillboardGui")
                    gui.Adornee = p.Character.HumanoidRootPart
                    gui.Size = UDim2.new(0, 100, 0, 50)
                    gui.StudsOffset = Vector3.new(0, 3, 0)
                    gui.Parent = p.Character.HumanoidRootPart

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = p.Name
                    nameLabel.TextColor3 = isEnemy(p) and Color3.new(1, 0, 0) or Color3.new(0, 0, 1)  -- Red for enemy, blue for team
                    nameLabel.TextScaled = true
                    nameLabel.Font = Enum.Font.SourceSansBold
                    nameLabel.Parent = gui

                    local distLabel = Instance.new("TextLabel")
                    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
                    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
                    distLabel.BackgroundTransparency = 1
                    distLabel.Text = math.floor(dist) .. "m"
                    distLabel.TextColor3 = Color3.new(1, 1, 0)
                    distLabel.TextScaled = true
                    distLabel.Font = Enum.Font.SourceSans
                    distLabel.Parent = gui

                    espGuis[p.Name] = gui
                else
                    local nameLabel = gui:FindFirstChild("TextLabel")
                    if nameLabel then
                        nameLabel.TextColor3 = isEnemy(p) and Color3.new(1, 0, 0) or Color3.new(0, 0, 1)
                    end
                    local distLabel = gui:FindFirstChildOfClass("TextLabel", true)
                    if distLabel then distLabel.Text = math.floor(dist) .. "m" end
                end
            elseif espGuis[p.Name] then
                espGuis[p.Name]:Destroy()
                espGuis[p.Name] = nil
            end
        end
    end
end

local function updateMovement()
    local char = localPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") then return end
    local humanoid = char.Humanoid
    local root = char.HumanoidRootPart

    if settings.movement.speedHack then
        humanoid.WalkSpeed = 16 * settings.movement.speedMultiplier
    end

    if settings.movement.fly then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            local bodyVel = root:FindFirstChild("FlyBodyVelocity")
            if not bodyVel then
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(4000, 4000, 4000)
                bodyVel.Velocity = Vector3.new(0, 50, 0)
                bodyVel.Parent = root
            end
            bodyVel.Velocity = Vector3.new(0, 50, 0)
            humanoid.PlatformStand = true
        else
            local bodyVel = root:FindFirstChild("FlyBodyVelocity")
            if bodyVel then bodyVel:Destroy() end
            humanoid.PlatformStand = false
        end
    end

    if settings.movement.bunnyHop then
        humanoid.JumpPower = settings.movement.bunnyStrength
        if humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.MoveDirection.Magnitude > 0 then
            humanoid.Jump = true
        end
    end
end

local function updateAimCircle()
    if not settings.aimCircle.enabled then return end
    pcall(function()
        local circle = Drawing.new("Circle")
        circle.Radius = settings.aimCircle.radius
        circle.Color = Color3.new(0, 1, 0)
        circle.Thickness = settings.aimCircle.thickness
        circle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        circle.Visible = true
        circle.Filled = false
        circle.NumSides = 32
        circle.Transparency = 0.5
        connections.circleUpdate = RunService.RenderStepped:Connect(function()
            circle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        end)
    end)
end

local function aimLock()
    if UserInputService:IsKeyDown(keybinds.aimLock) then
        currentTarget = getClosestPlayer(settings.aimbot.fov)  -- Team check here
        if currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(settings.aimbot.targetPart)
            if targetPart then
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
                local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
                syncGunToTarget(targetPart, tool)
                printDebug("Rivals aimlock active on enemy " .. currentTarget.Name)
            end
        end
    else
        currentTarget = nil
    end
end

-- Main Loops
connections.updateAimbot = RunService.RenderStepped:Connect(updateAimbot)
connections.updateESP = RunService.Heartbeat:Connect(updateESP)
connections.updateMovement = RunService.Heartbeat:Connect(updateMovement)
connections.aimLock = RunService.RenderStepped:Connect(aimLock)
connections.updateAimCircle = RunService.Heartbeat:Connect(updateAimCircle)
connections.updateTriggerBot = RunService.Heartbeat:Connect(updateTriggerBot)
connections.updateAntiBlind = RunService.Heartbeat:Connect(updateAntiBlind)

-- UI Panel (added Team ESP toggle)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KING_UI"
screenGui.Parent = game.CoreGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 250, 0, 480)  -- Taller for new toggle
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
title.Text = "KING (Rivals)"
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

-- Controls (added Team ESP toggle)
addToggle("Aimbot", settings.aimbot.enabled, function(v) settings.aimbot.enabled = v end)
addSlider("Smoothness", settings.aimbot.smoothness, 0, 100, function(v) settings.aimbot.smoothness = v end)
addSlider("FOV", settings.aimbot.fov, 0, 180, function(v) settings.aimbot.fov = v end)
addToggle("Gun Sync (Silent Aim)", settings.gunSync, function(v) settings.gunSync = v end)
addToggle("Trigger Bot", settings.triggerBot, function(v) settings.triggerBot = v end)
addToggle("Anti-Blind", settings.antiBlind, function(v) settings.antiBlind = v end)
addToggle("ESP", settings.esp.enabled, function(v) settings.esp.enabled = v end)
addSlider("ESP Distance", settings.esp.distance, 10, 500, function(v) settings.esp.distance = v end)
addToggle("Wall Check", settings.esp.wallCheck, function(v) settings.esp.wallCheck = v end)
addToggle("Team ESP (Blue)", settings.esp.showTeam, function(v) settings.esp.showTeam = v end)  -- New toggle
addToggle("Speed Hack", settings.movement.speedHack, function(v) settings.movement.speedHack = v end)
addSlider("Speed Multi", settings.movement.speedMultiplier, 1, 5, function(v) settings.movement.speedMultiplier = v end)
addToggle("Fly", settings.movement.fly, function(v) settings.movement.fly = v end)
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

printDebug("KING Rivals script loaded - Team check active (no friendly fire)!")
