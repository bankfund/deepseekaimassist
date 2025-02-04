-- Universal Roblox Aim Assist (R6/R15)
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

-- Initialize centered FOV
local screenCenter = Camera.ViewportSize / 2
FOV.Visible = true
FOV.Filled = false
FOV.Transparency = 0.7
FOV.Color = Config.FOVColor
FOV.Thickness = Config.FOVThickness
FOV.NumSides = 64
FOV.Radius = Config.FOV
FOV.Position = screenCenter

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
    -- Priority: HumanoidRootPart > Torso > Head
    return character:FindFirstChild("HumanoidRootPart") 
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("Head")
end

local function ValidateTarget(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    return GetTargetPart(char)
end

local function WallCheck(targetPos)
    local origin = Camera.CFrame.Position
    local ray = Ray.new(origin, (targetPos - origin).Unit * 1000)
    local hit = WS:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    return hit and hit:IsDescendantOf(Players:GetPlayerFromCharacter(hit.Parent).Character)
end

local function FindTarget()
    local closest, distance = nil, Config.FOV
    
    for _, player in Players:GetPlayers() do
        local targetPart = ValidateTarget(player)
        if targetPart then
            local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
            if screenPos.Z > 0 then
                local calc = (GetScreenCenter() - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                if calc < distance then
                    closest = targetPart
                    distance = calc
                end
            end
        end
    end
    return closest
end

local function SmoothAim(targetPos)
    CancelTween()
    local tweenInfo = TweenInfo.new(
        Config.Smoothness,
        Config.EasingStyle,
        Config.EasingDirection
    )
    ActiveTween = TweenService:Create(Camera, tweenInfo, {
        CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    })
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
        end
    end
end)

RS.RenderStepped:Connect(function()
    FOV.Position = GetScreenCenter()

    if Config.Active then
        if CurrentTarget and CurrentTarget.Parent then
            if WallCheck(CurrentTarget.Position) then
                LastValidPosition = CurrentTarget.Position
                local predictedPos = LastValidPosition + (CurrentTarget.Velocity * Config.Prediction)
                SmoothAim(predictedPos)
            else
                CurrentTarget = nil
            end
        else
            CurrentTarget = FindTarget()
            CurrentTarget = CurrentTarget and WallCheck(CurrentTarget.Position) and CurrentTarget or nil
        end
    else
        if CurrentTarget or LastValidPosition then
            CurrentTarget = nil
            LastValidPosition = nil
        end
    end
end)

warn("Universal Aim Assist Loaded | R6/R15 Compatible")