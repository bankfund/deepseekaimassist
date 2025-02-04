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
    ResolverKey = Enum.KeyCode.R,
    FOV = 120,
    Smoothness = 0.4,
    Prediction = 0.1227,
    OutOfFOVRelease = true,
    AutoLock = true, -- Toggle for auto-lock (true = enabled, false = disabled)
    
    -- Team Check Configuration
    TeamCheck = true, -- Toggle for team check (true = enabled, false = disabled)

    -- Wall Check Configuration
    WallCheck = {
        Enabled = true, -- Toggle for wall check (true = enabled, false = disabled)
        Notifications = true -- Notify when a target is behind a wall
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
        Radius = 100
    },
    LockColor = Color3.new(0, 0, 0),
    
    -- Target Parts
    AimParts = {
        "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"
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

-- FOV Setup (Moved to Visuals Category)
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
    if Config.Resolver.Notifications or Config.WallCheck.Notifications then
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
    if not Config.TeamCheck then return false end -- Skip team check if disabled
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

-- Wall Check Function
local function RayCastCheck(part)
    if not Config.WallCheck.Enabled then return true end -- Skip wall check if disabled

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
    if IsTeammate(player) then return false end  -- Team check (if enabled)
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
                if part and RayCastCheck(part) then -- Wall check
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
                if part and RayCastCheck(part) then -- Wall check
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
        if Config.WallCheck.Enabled and not RayCastCheck(LockedTarget.Part) then
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

-- Initialization
if CheckAlive() then
    Notify("Pluto Aim Assist Loaded", "Aim assist initialized successfully")
else
    Notify("Pluto Aim Assist Off", "Waiting for respawn...")
end
warn("Aim Assist loaded with vertical offset system, auto-lock toggle, team check, and wall check (UPD)")