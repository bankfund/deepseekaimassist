-- Smooth Wall Transition Aim Assist
-- By: <｜end▁of▁thinking｜>

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local Camera = WS.CurrentCamera
local TweenService = game:GetService("TweenService")

local Config = {
    Active = false,
    ToggleKey = Enum.KeyCode.Q,
    FOV = 100,
    Smoothness = 0.55,
    Prediction = 0.12,
    DisengageSmoothness = 0.3, -- New: Smoothness when losing target
    EasingStyle = Enum.EasingStyle.Quad,
    EasingDirection = Enum.EasingDirection.Out,
    FOVColor = Color3.new(0.9, 0.9, 0.9),
    LockColor = Color3.new(1, 0.3, 0.2),
    FOVThickness = 2
}

-- System Objects
local LocalPlayer = Players.LocalPlayer
local FOV = Drawing.new("Circle")
local CurrentTarget = nil
local LastValidPosition = nil
local ActiveTween = nil
local Disengaging = false -- New: Smooth disengagement state
local Cooldown = 0 -- New: Prevent rapid re-acquisition

local function CancelTween()
    if ActiveTween then
        ActiveTween:Cancel()
        ActiveTween = nil
    end
end

local function GetScreenCenter()
    return Camera.ViewportSize / 2
end

local function GetTargetPart(character)
    return character:FindFirstChild("HumanoidRootPart") 
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
end

local function ValidateTarget(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function WallCheck(targetPos)
    local origin = Camera.CFrame.Position
    local distance = (origin - targetPos).Magnitude
    if distance > 200 then return false end -- Distance-based check
    
    local ray = Ray.new(origin, (targetPos - origin).Unit * distance)
    local hit = WS:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    return hit and hit:IsDescendantOf(Players:GetPlayerFromCharacter(hit.Parent).Character)
end

local function SmoothAim(targetPos, disengage)
    CancelTween()
    
    local tweenInfo = TweenInfo.new(
        disengage and Config.DisengageSmoothness or Config.Smoothness,
        Config.EasingStyle,
        Config.EasingDirection
    )

    local targetCFrame = disengage and Camera.CFrame 
        or CFrame.new(Camera.CFrame.Position, targetPos)
    
    ActiveTween = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
    ActiveTween:Play()
end

UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Config.ToggleKey then
        Config.Active = not Config.Active
        FOV.Color = Config.Active and Config.LockColor or Config.FOVColor
        
        if not Config.Active then
            CancelTween()
            CurrentTarget = nil
            LastValidPosition = nil
            Cooldown = 0.5 -- Prevent immediate re-lock
        end
    end
end)

RS.RenderStepped:Connect(function(dt)
    FOV.Position = GetScreenCenter()
    Cooldown = math.max(0, Cooldown - dt)

    if Config.Active then
        if CurrentTarget and CurrentTarget.Parent then
            if WallCheck(CurrentTarget.Position) then
                Disengaging = false
                LastValidPosition = CurrentTarget.Position
                local predictedPos = LastValidPosition + (CurrentTarget.Velocity * Config.Prediction)
                SmoothAim(predictedPos)
            else
                if not Disengaging then
                    SmoothAim(nil, true) -- Smooth disengagement
                    Disengaging = true
                end
                CurrentTarget = nil
                Cooldown = 0.2
            end
        elseif Cooldown <= 0 then
            CurrentTarget = FindTarget()
            if CurrentTarget and WallCheck(CurrentTarget.Position) then
                LastValidPosition = CurrentTarget.Position
                Disengaging = false
            else
                CurrentTarget = nil
            end
        end
    else
        if CurrentTarget or LastValidPosition then
            CurrentTarget = nil
            LastValidPosition = nil
        end
    end
end)