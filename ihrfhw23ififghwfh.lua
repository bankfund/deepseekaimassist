--- Pluto Version 1.0.0 with cspeed
--- Made by Last (Packtokin on Discord)

--- Features:
--- - Da Hood K.O. Check (Toggleable)
--- - Wall Check
--- - Team Check
--- - Auto-Lock
--- - Vertical Offsets
--- - Resolver
--- - Smooth Aim
--- - FOV Visuals
--- - Spinning Crosshair
--- - CFrame Fly and Speed
--- - cspeed (Custom Speed Control)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local Camera = WS.CurrentCamera
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Config = {
    -- Core Settings
    ToggleKey = Enum.KeyCode.E,
    RotationKey = Enum.KeyCode.Z,
    ResolverKey = Enum.KeyCode.G,
    FOV = 120,
    Smoothness = 0.1,
    Prediction = 0.1227,
    OutOfFOVRelease = false,
    AutoLock = false, -- Toggle for auto-lock (true = enabled, false = disabled)

    -- CFrame Fly and Speed Settings
    Fly = {
        Enabled = false, -- Toggle for CFrame fly (true = enabled, false = disabled)
        FlyKey = Enum.KeyCode.F, -- Key to toggle fly
        Speed = 300, -- Base speed for flying
        SpeedIncrement = 10, -- Speed increment when adjusting
        MaxSpeed = 300, -- Maximum speed
        MinSpeed = 10 -- Minimum speed
    },

    -- cspeed Settings
    cspeed = {
        Enabled = true, -- Toggle for cspeed (true = enabled, false = disabled)
        BaseSpeed = 16, -- Default player speed
        Multiplier = 1.0, -- Speed multiplier
        Increment = 1.0, -- Speed increment/decrement step
        MaxMultiplier = 35.0, -- Maximum speed multiplier
        MinMultiplier = 0.5, -- Minimum speed multiplier
        IncreaseKey = Enum.KeyCode.Equals, -- Key to increase cspeed
        DecreaseKey = Enum.KeyCode.Minus, -- Key to decrease cspeed
        ResetKey = Enum.KeyCode.N -- Key to reset cspeed to default
    },

    -- Checks Configuration
    Checks = {
        WallCheck = {
            Enabled = false, -- Toggle for wall check (true = enabled, false = disabled)
            Notifications = true -- Notify when a target is behind a wall
        },
        TeamCheck = {
            Enabled = true, -- Toggle for team check (true = enabled, false = disabled)
            Notifications = false -- Notify when a teammate is targeted
        },
        DaHoodKOCheck = {
            Enabled = true, -- Toggle for Da Hood K.O. check (true = enabled, false = disabled)
            Notifications = true -- Notify when a target is K.O.'d
        }
    },

    -- Bypasses Configuration
    Bypasses = {
        Adonis = {
            Enabled = true, -- Toggle for Adonis Anti-Cheat bypass (true = enabled, false = disabled)
            Notifications = true -- Notify when bypass is active
        }
    },

    -- Vertical Offset Configuration
    VerticalOffsets = {
        JumpOffset = 0.35,   -- Positive = aim higher when jumping
        FallOffset = -0.25   -- Negative = aim lower when falling
    },

    -- Resolver Configuration
    Resolver = {
        Enabled = false,
        Prediction = 0.15,
        Mode = "Prediction",
        Notifications = true
    },

    -- Easing Configuration
    EasingStyle = Enum.EasingStyle.Linear,
    EasingDirection = Enum.EasingDirection.InOut,
    
    -- Rotation Settings
    RotationSpeed = 3000,
    RotationSmoothness = 0.2,
    
    -- Visuals
    FOV = {
        Visible = true,
        Filled = true,
        Transparency = 0.4,
        Color = Color3.new(0, 0, 0),
        Thickness = 1,
        NumSides = 128,
        Radius = 120
    },
    LockColor = Color3.new(0, 0, 0),
    
    -- Target Parts
    AimParts = {
        "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
    },

    -- Spinning Crosshair Configuration
    Crosshair = {
        Enabled = true, -- Toggle for crosshair (true = enabled, false = disabled)
        Sticky = true, -- Stick to the middle of the screen or follow the mouse
        RefreshRate = 0, -- Refresh rate for the crosshair (0 = every frame)
        Mode = 'Mouse', -- 'Middle' or 'Mouse'
        Position = Vector2.new(0, 0), -- Custom position (if Mode is not 'Middle' or 'Mouse')
        Lines = 4, -- Number of lines in the crosshair
        Width = 1.8, -- Thickness of the crosshair lines
        Length = 15, -- Length of the crosshair lines
        Radius = 11, -- Distance from the center to the start of the lines
        Color = Color3.fromRGB(17, 17, 17), -- Color of the crosshair
        Spin = true, -- Enable spinning animation
        SpinSpeed = 150, -- Speed of the spin animation
        SpinMax = 340, -- Maximum spin angle
        SpinStyle = Enum.EasingStyle.Circular, -- Easing style for the spin animation
        Resize = false, -- Enable resizing animation
        ResizeSpeed = 150, -- Speed of the resize animation
        ResizeMin = 5, -- Minimum length of the lines
        ResizeMax = 22 -- Maximum length of the lines
    }
}

-- System Initialization
local LocalPlayer = Players.LocalPlayer
local FOV = Drawing.new("Circle")
local LockedTarget = {Player = nil, Part = nil, Humanoid = nil}
local ActiveTween = nil
local Alive = true

-- Rotation System
local rotationActive = false
local rotationStartCFrame = CFrame.new()
local rotationStartTime = 0

-- Fly System
local flyActive = false
local flySpeed = Config.Fly.Speed

-- FOV Setup
FOV.Visible = Config.FOV.Visible
FOV.Filled = Config.FOV.Filled
FOV.Transparency = Config.FOV.Transparency
FOV.Color = Config.FOV.Color
FOV.Thickness = Config.FOV.Thickness
FOV.NumSides = Config.FOV.NumSides
FOV.Radius = Config.FOV.Radius
FOV.Position = Camera.ViewportSize / 2

-- Notification System
local function Notify(title, message)
    if Config.Checks.WallCheck.Notifications or Config.Checks.TeamCheck.Notifications or Config.Checks.DaHoodKOCheck.Notifications or Config.Bypasses.Adonis.Notifications then
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 5
        })
    end
end

-- Death Check System
local function CheckAlive()
    local character = LocalPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

LocalPlayer.CharacterAdded:Connect(function()
    Alive = true
    local humanoid = LocalPlayer.Character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        Alive = false
        if LockedTarget.Player then
            AcquireOrReleaseLock()
        end
        Config.Resolver.Enabled = false
        FOV.Color = Config.FOV.Color
        Notify("Pluto Alert", "Aim assist disabled - Player died")
    end)
end)

-- Team Check Function
local function IsTeammate(player)
    if not Config.Checks.TeamCheck.Enabled then return false end -- Skip team check if disabled
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

-- Da Hood K.O. Check Function
local function IsKO(player)
    if not Config.Checks.DaHoodKOCheck.Enabled then return false end -- Skip K.O. check if disabled

    local character = player.Character
    if not character then return false end

    local bodyEffects = character:FindFirstChild("BodyEffects")
    if not bodyEffects then return false end

    local ko = bodyEffects:FindFirstChild("K.O")
    if not ko then return false end

    return ko.Value
end

-- Wall Check Function
local function RayCastCheck(part)
    if not Config.Checks.WallCheck.Enabled then return true end -- Skip wall check if disabled

    local character = LocalPlayer.Character
    if not character then return false end

    local origin = Camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {character, Camera}

    local result = workspace:Raycast(origin, part.Position - origin, raycastParams)

    if result then
        local partHit = result.Instance
        local visible = not partHit or partHit:IsDescendantOf(part.Parent)
        return visible
    end
    return true
end

-- Vertical Offset Calculation
local function CalculateVerticalOffset(targetHumanoid)
    if not targetHumanoid then return 0 end
    
    -- Jump detection
    if targetHumanoid.Jump then
        return Config.VerticalOffsets.JumpOffset
    end
    
    -- Fall detection using velocity
    local rootPart = targetHumanoid.Parent:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart.Velocity.Y < -5 then
        return Config.VerticalOffsets.FallOffset
    end
    
    return 0
end

-- Resolver Core
local function ApplyVelocityAdjustment(target)
    if not Alive then return end
    if not target.Character then return end
    local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    for _, part in ipairs(target.Character:GetChildren()) do
        if part:IsA("BasePart") then
            if Config.Resolver.Mode == "Prediction" then
                local moveDirection = humanoid.MoveDirection
                part.Velocity = moveDirection * Config.Resolver.Prediction
                part.AssemblyLinearVelocity = moveDirection * Config.Resolver.Prediction
            else
                part.Velocity = Vector3.new()
                part.AssemblyLinearVelocity = Vector3.new()
            end
        end
    end
end

-- Resolver Handler
RS.Heartbeat:Connect(function()
    if not Alive or not Config.Resolver.Enabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ApplyVelocityAdjustment(player)
        end
    end
end)

-- Target Validation
local function ValidateTarget(player)
    if not Alive then return false end
    if player == LocalPlayer then return false end
    if Config.Checks.TeamCheck.Enabled and IsTeammate(player) then return false end  -- Team check (if enabled)
    if Config.Checks.DaHoodKOCheck.Enabled and IsKO(player) then return false end  -- K.O. check (if enabled)
    local char = player.Character
    if not char then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Target Acquisition
local function GetValidParts(character)
    local validParts = {}
    for _, partName in ipairs(Config.AimParts) do
        local part = character:FindFirstChild(partName)
        if part then table.insert(validParts, part) end
    end
    return validParts
end

local function FindClosestPart(character)
    local closestPart, minDistance = nil, math.huge
    local screenCenter = Camera.ViewportSize / 2
    
    for _, part in ipairs(GetValidParts(character)) do
        local screenPos = Camera:WorldToViewportPoint(part.Position)
        if screenPos.Z > 0 then
            local distance = (screenCenter - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
            if distance < minDistance then
                closestPart = part
                minDistance = distance
            end
        end
    end
    return closestPart
end

-- FOV Check for Auto-Release
local function IsInFOV(targetPart)
    if not targetPart then return false end
    local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
    if screenPos.Z <= 0 then return false end
    local center = Camera.ViewportSize / 2
    local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    return distance <= Config.FOV.Radius
end

-- Lock System
local function AcquireOrReleaseLock()
    if not Alive then return end
    
    if not LockedTarget.Player then
        local closestPlayer, closestPart, minDist = nil, nil, Config.FOV.Radius
        
        for _, player in ipairs(Players:GetPlayers()) do
            if ValidateTarget(player) then
                local character = player.Character
                local part = FindClosestPart(character)
                if part and (not Config.Checks.WallCheck.Enabled or RayCastCheck(part)) then -- Wall check
                    local screenPos = Camera:WorldToViewportPoint(part.Position)
                    local distance = (Camera.ViewportSize/2 - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if distance < minDist then
                        closestPlayer, closestPart, minDist = player, part, distance
                    end
                end
            end
        end
        
        if closestPlayer then
            LockedTarget.Player = closestPlayer
            LockedTarget.Part = closestPart
            LockedTarget.Humanoid = closestPlayer.Character:FindFirstChildOfClass("Humanoid")
            FOV.Color = Config.LockColor
            Notify("Target Selected", "Tracking: " .. closestPlayer.Name)
        end
    else
        LockedTarget.Player = nil
        LockedTarget.Part = nil
        LockedTarget.Humanoid = nil
        FOV.Color = Config.FOV.Color
        if ActiveTween then ActiveTween:Cancel() end
        Notify("Pluto Aim Assist Update", "Target released")
    end
end

-- Enhanced Aim System with Vertical Offsets
local function SmoothAim(targetPos)
    if not Alive then return end
    if ActiveTween then ActiveTween:Cancel() end
    
    -- Apply vertical offsets and resolver prediction
    if LockedTarget.Humanoid then
        local verticalOffset = CalculateVerticalOffset(LockedTarget.Humanoid)
        targetPos += Vector3.new(0, verticalOffset, 0)
        
        if Config.Resolver.Enabled then
            targetPos += LockedTarget.Humanoid.MoveDirection * Config.Resolver.Prediction
        end
    end

    ActiveTween = TweenService:Create(
        Camera,
        TweenInfo.new(
            Config.Smoothness,
            Config.EasingStyle,
            Config.EasingDirection
        ),
        {CFrame = CFrame.new(Camera.CFrame.Position, targetPos)}
    )
    ActiveTween:Play()
end

-- Rotation Handler
local function HandleRotation(deltaTime)
    if not Alive then return end
    if not rotationActive then return end
    
    local currentTime = tick()
    local elapsed = currentTime - rotationStartTime
    local progress = math.min(elapsed / Config.RotationSmoothness, 1)
    local smoothFactor = math.sin(progress * math.pi/2)
    
    local targetRotation = math.rad(Config.RotationSpeed * elapsed)
    Camera.CFrame = rotationStartCFrame * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), targetRotation * smoothFactor)
    
    if targetRotation >= math.rad(360) then
        rotationActive = false
        Camera.CFrame = rotationStartCFrame
        if LockedTarget.Part then
            SmoothAim(LockedTarget.Part.Position + (LockedTarget.Part.Velocity * Config.Prediction))
        end
    end
end

-- Function to update player speed
local function UpdatePlayerSpeed()
    if not Alive or not Config.cspeed.Enabled then return end

    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    humanoid.WalkSpeed = Config.cspeed.BaseSpeed * Config.cspeed.Multiplier
end

-- Input Handling
UIS.InputBegan:Connect(function(input)
    if not Alive then return end
    if input.KeyCode == Config.ToggleKey then
        AcquireOrReleaseLock()
    elseif input.KeyCode == Config.RotationKey then
        if not rotationActive then
            rotationStartCFrame = Camera.CFrame
            rotationStartTime = tick()
            if ActiveTween then ActiveTween:Cancel() end
        end
        rotationActive = not rotationActive
    elseif input.KeyCode == Config.ResolverKey then
        Config.Resolver.Enabled = not Config.Resolver.Enabled
        Notify("Resolver Notification", "Resolver " .. (Config.Resolver.Enabled and "Enabled (" .. Config.Resolver.Mode .. ")" or "Disabled"))
    elseif input.KeyCode == Config.Fly.FlyKey then
        flyActive = not flyActive
        Notify("CFrame Fly", flyActive and "Fly enabled. Speed: " .. flySpeed or "Fly disabled")
    elseif input.KeyCode == Config.cspeed.IncreaseKey then
        Config.cspeed.Multiplier = math.min(Config.cspeed.Multiplier + Config.cspeed.Increment, Config.cspeed.MaxMultiplier)
        UpdatePlayerSpeed()
        Notify("cspeed", "Speed increased to: " .. Config.cspeed.Multiplier)
    elseif input.KeyCode == Config.cspeed.DecreaseKey then
        Config.cspeed.Multiplier = math.max(Config.cspeed.Multiplier - Config.cspeed.Increment, Config.cspeed.MinMultiplier)
        UpdatePlayerSpeed()
        Notify("cspeed", "Speed decreased to: " .. Config.cspeed.Multiplier)
    elseif input.KeyCode == Config.cspeed.ResetKey then
        Config.cspeed.Multiplier = 1.0
        UpdatePlayerSpeed()
        Notify("cspeed", "Speed reset to default")
    end
end)

-- Main Loop with Vertical Offset Integration
RS.RenderStepped:Connect(function(deltaTime)
    Alive = CheckAlive()
    if not Alive then return end
    HandleRotation(deltaTime)
    if rotationActive then return end

    FOV.Position = Camera.ViewportSize / 2
    
    -- Auto-lock logic
    if Config.AutoLock and not LockedTarget.Player then
        local closestPlayer, closestPart, minDist = nil, nil, Config.FOV.Radius
        
        for _, player in ipairs(Players:GetPlayers()) do
            if ValidateTarget(player) then
                local character = player.Character
                local part = FindClosestPart(character)
                if part and (not Config.Checks.WallCheck.Enabled or RayCastCheck(part)) then -- Wall check
                    local screenPos = Camera:WorldToViewportPoint(part.Position)
                    local distance = (Camera.ViewportSize/2 - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if distance < minDist then
                        closestPlayer, closestPart, minDist = player, part, distance
                    end
                end
            end
        end
        
        if closestPlayer then
            LockedTarget.Player = closestPlayer
            LockedTarget.Part = closestPart
            LockedTarget.Humanoid = closestPlayer.Character:FindFirstChildOfClass("Humanoid")
            FOV.Color = Config.LockColor
            Notify("Target Selected", "Tracking: " .. closestPlayer.Name)
        end
    end

    if LockedTarget.Player and LockedTarget.Part then
        -- Immediate wall check for locked target
        if Config.Checks.WallCheck.Enabled and not RayCastCheck(LockedTarget.Part) then
            AcquireOrReleaseLock()
            Notify("Target Lost", "Target is behind a wall")
            return
        end

        if Config.OutOfFOVRelease and not IsInFOV(LockedTarget.Part) then
            AcquireOrReleaseLock()
            Notify("Target Lost", "Target left aiming FOV")
            return
        end

        if not ValidateTarget(LockedTarget.Player) then
            AcquireOrReleaseLock()
            return
        end

        -- Check if the target is K.O.'d
        if Config.Checks.DaHoodKOCheck.Enabled and IsKO(LockedTarget.Player) then
            AcquireOrReleaseLock()
            Notify("Target K.O.'d", "Target has been knocked out")
            return
        end
        
        LockedTarget.Part = FindClosestPart(LockedTarget.Player.Character) or LockedTarget.Part
        
        if LockedTarget.Part and LockedTarget.Part.Parent then
            local basePrediction = LockedTarget.Part.Velocity * Config.Prediction
            local resolverAdjustment = Config.Resolver.Enabled and LockedTarget.Humanoid.MoveDirection * Config.Resolver.Prediction or Vector3.new()
            local verticalOffset = Vector3.new(0, CalculateVerticalOffset(LockedTarget.Humanoid), 0)
            
            SmoothAim(LockedTarget.Part.Position + basePrediction + resolverAdjustment + verticalOffset)
        else
            AcquireOrReleaseLock()
        end
    end
end)

-- Spinning Crosshair System
local last_render = 0
local drawings = {
    crosshair = {},
    text = {
        Drawing.new('Text', {Size = 13, Font = 2, Outline = true, Text = 'Pluto', Color = Color3.new(1, 1, 1)}),
        Drawing.new('Text', {Size = 13, Font = 2, Outline = true, Text = ' .CC'}),
    }
}

for idx = 1, Config.Crosshair.Lines do
    drawings.crosshair[idx] = Drawing.new('Line')
    drawings.crosshair[idx + Config.Crosshair.Lines] = Drawing.new('Line')
end

function solve(angle, radius)
    return Vector2.new(
        math.sin(math.rad(angle)) * radius,
        math.cos(math.rad(angle)) * radius
    )
end

RS.PostSimulation:Connect(function()
    local _tick = tick()

    if _tick - last_render > Config.Crosshair.RefreshRate then
        last_render = _tick

        local position = (
            Config.Crosshair.Mode == 'Middle' and Camera.ViewportSize / 2 or
            Config.Crosshair.Mode == 'Mouse' and UIS:GetMouseLocation() or
            Config.Crosshair.Position
        )

        local text_1 = drawings.text[1]
        local text_2 = drawings.text[2]

        text_1.Visible = Config.Crosshair.Enabled
        text_2.Visible = Config.Crosshair.Enabled

        if Config.Crosshair.Enabled then
            local text_x = text_1.TextBounds.X + text_2.TextBounds.X

            text_1.Position = position + Vector2.new(-text_x / 2, Config.Crosshair.Radius + (Config.Crosshair.Resize and Config.Crosshair.ResizeMax or Config.Crosshair.Length) + 15)
            text_2.Position = text_1.Position + Vector2.new(text_1.TextBounds.X)
            text_2.Color = Config.Crosshair.Color

            for idx = 1, Config.Crosshair.Lines do
                local outline = drawings.crosshair[idx]
                local inline = drawings.crosshair[idx + Config.Crosshair.Lines]

                local angle = (idx - 1) * (360 / Config.Crosshair.Lines)
                local length = Config.Crosshair.Length

                if Config.Crosshair.Spin then
                    local spin_angle = -_tick * Config.Crosshair.SpinSpeed % Config.Crosshair.SpinMax
                    angle = angle + TweenService:GetValue(spin_angle / 360, Config.Crosshair.SpinStyle, Enum.EasingDirection.InOut) * 360
                end

                if Config.Crosshair.Resize then
                    local resize_length = tick() * Config.Crosshair.ResizeSpeed % 180
                    length = Config.Crosshair.ResizeMin + math.sin(math.rad(resize_length)) * Config.Crosshair.ResizeMax
                end

                inline.Visible = true
                inline.Color = Config.Crosshair.Color
                inline.From = position + solve(angle, Config.Crosshair.Radius)
                inline.To = position + solve(angle, Config.Crosshair.Radius + length)
                inline.Thickness = Config.Crosshair.Width

                outline.Visible = true
                outline.From = position + solve(angle, Config.Crosshair.Radius - 1)
                outline.To = position + solve(angle, Config.Crosshair.Radius + length + 1)
                outline.Thickness = Config.Crosshair.Width + 1.5
            end
        else
            for idx = 1, Config.Crosshair.Lines do
                drawings.crosshair[idx].Visible = false
                drawings.crosshair[idx + Config.Crosshair.Lines].Visible = false
            end
        end
    end
end)

-- Fly Logic
RS.Heartbeat:Connect(function(deltaTime)
    if not Alive or not flyActive then return end

    local character = LocalPlayer.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local moveDirection = Vector3.new()

    if UIS:IsKeyDown(Enum.KeyCode.W) then
        moveDirection = moveDirection + Camera.CFrame.LookVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.S) then
        moveDirection = moveDirection - Camera.CFrame.LookVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.A) then
        moveDirection = moveDirection - Camera.CFrame.RightVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.D) then
        moveDirection = moveDirection + Camera.CFrame.RightVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection = moveDirection + Vector3.new(0, 1, 0)
    end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveDirection = moveDirection - Vector3.new(0, 1, 0)
    end

    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit * flySpeed
        rootPart.Velocity = moveDirection
    else
        rootPart.Velocity = Vector3.new()
    end
end)

-- Initialize cspeed on Character Load
LocalPlayer.CharacterAdded:Connect(function()
    Alive = true
    UpdatePlayerSpeed() -- Initialize cspeed
    local humanoid = LocalPlayer.Character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        Alive = false
    end)
end)

-- Initialization
if CheckAlive() then
    Notify("Pluto Aim Assist Loaded", "Aim assist initialized successfully")
else
    Notify("Pluto Aim Assist Off", "Waiting for respawn...")
end
warn("Aim Assist loaded with vertical offset system, auto-lock toggle, team check, wall check, and Da Hood K.O. check")