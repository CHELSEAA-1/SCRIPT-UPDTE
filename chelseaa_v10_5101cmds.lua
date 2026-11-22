--// =========================================================================
--// CHELSEAA SYSTEM V10 - 5,101 FEATURES EDITION (NO PLAIN CHAT BAR)
--// Theme: Obsidian Cyber-Anime | Mobile, Tablet & Desktop Compatible
--// Brand: MADE BY CHELSEAA
--// Highlights:
--//   * Full Rich Tabbed Control Hub (No plain bottom chat bar)
--//   * 100 Brand-New Interactive Features (ESP, Camera, Shaders, Waypoints,
--//     Air Platforms, Spinbot, Auto-Prompts, UI Themes, Character FX)
--//   * WalkSpeed Anti-Reset Lock + Dynamic Tween Speed + Auto Train Cursor
--//   * 5,101 Total Executable Features/Commands (#1 - #5101)
--// =========================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local VirtualUser = nil
pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

local function GetSafeGuiParent()
    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        local test = Instance.new("Folder")
        local canParent = pcall(function()
            test.Parent = core
        end)
        if canParent then
            test:Destroy()
            return core
        end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = GetSafeGuiParent()

-- Clean up previous version if re-executed
for _, oldName in ipairs({ "ChelseaaSystemV9", "ChelseaaSystemV10" }) do
    local old = GuiParent:FindFirstChild(oldName)
    if old then
        old:Destroy()
    end
end

--// =========================================================================
--// STATE & CONFIGURATION
--// =========================================================================
local State = {
    -- Movement & Physics
    WalkSpeed = 16,
    WalkSpeedLocked = false,
    JumpPower = 50,
    JumpPowerLocked = false,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 85,
    SpinSpeed = 0,
    AntiFling = false,
    BunnyHop = false,
    AirWalk = false,
    SwimAir = false,
    AntiRagdoll = false,

    -- Dynamic Tween & 5 Waypoint Slots
    TweenSpeed = 250,
    SyncTweenToWalkSpeed = false,
    TweenSpeedMultiplier = 2.0,
    Waypoints = {},
    ActiveTween = nil,

    -- Auto Train Cursor (1x, 2x, 2.30x, 3x, 4x) & Automation
    AutoTrainEnabled = false,
    AutoTrainFilter = "2X_PLUS", -- "ALL", "2X_PLUS", "MAX_ONLY", "2X_ONLY"
    AutoTrainMode = "SMART",     -- "SMART", "BAR_ALIGN", "POPUP_CLICK"
    CursorTolerancePx = 10,
    ClickCooldownMs = 70,
    LastClickTick = 0,
    TrainClickCount = 0,
    LastDetectedText = "None",

    AutoClickerCenter = false,
    AutoPrompts = false,
    AutoRespawnSpot = false,
    LastDeathCFrame = nil,

    -- Visuals, ESP & Avatar Cosmetics
    PlayerESP = false,
    RainbowChar = false,
    XRayActive = false,
    ClientHeadless = false,
    ClientHeadlessHorseman = false,
    ClientKorblox = false,
    CustomMenuImageUrl = "https://files.catbox.moe/5kbgpx.jpg",
    MenuWallpaperVisible = true,

    -- Browser Pagination & Filter
    CurrentPage = 1,
    ItemsPerPage = 40,
    SearchQuery = "",
    SelectedCategory = "ALL",
    NewFeatureFilter = "ALL",
    StatusMessage = "System Ready - 5,101 Features Loaded",
}

local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    FogColor = Lighting.FogColor,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
}

local SpawnedPlatforms = {}
local ActiveConnections = {}

local function TrackConn(conn)
    table.insert(ActiveConnections, conn)
    return conn
end

local function SetStatus(msg)
    State.StatusMessage = msg
end

--// =========================================================================
--// CHARACTER, TWEEN & CURSOR HELPERS
--// =========================================================================
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function GetEffectiveTweenSpeed()
    if State.SyncTweenToWalkSpeed then
        return math.max(10, State.WalkSpeed * State.TweenSpeedMultiplier)
    end
    return math.max(10, State.TweenSpeed)
end

local function StopActiveTween()
    if State.ActiveTween then
        pcall(function()
            State.ActiveTween:Cancel()
        end)
        State.ActiveTween = nil
    end
end

local function TweenToCFrame(targetCFrame, customSpeed)
    local root = GetRootPart()
    if not root then return end

    StopActiveTween()

    local speed = customSpeed or GetEffectiveTweenSpeed()
    local distance = (targetCFrame.Position - root.Position).Magnitude
    local duration = math.max(0.05, distance / speed)

    local info = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )

    local tween = TweenService:Create(root, info, { CFrame = targetCFrame })
    State.ActiveTween = tween
    tween:Play()
    SetStatus(string.format("Tweening %.0f studs @ %d spd (%.2fs)", distance, speed, duration))
    return tween, duration, distance
end

local function PerformCursorClickAt(screenX, screenY, guiObj)
    local now = os.clock()
    if (now - State.LastClickTick) * 1000 < State.ClickCooldownMs then
        return false
    end
    State.LastClickTick = now
    State.TrainClickCount = State.TrainClickCount + 1

    local inset = GuiService:GetGuiInset()
    local finalX = math.floor(screenX + inset.X)
    local finalY = math.floor(screenY + inset.Y)

    local clicked = false

    if VirtualInputManager then
        local ok = pcall(function()
            VirtualInputManager:SendMouseMoveEvent(finalX, finalY, game)
            VirtualInputManager:SendMouseButtonEvent(finalX, finalY, 0, true, game, 1)
            task.defer(function()
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(finalX, finalY, 0, false, game, 1)
                end)
            end)
        end)
        if ok then
            clicked = true
        end
    end

    if guiObj and (guiObj:IsA("TextButton") or guiObj:IsA("ImageButton")) then
        pcall(function()
            if type(firesignal) == "function" then
                firesignal(guiObj.MouseButton1Click)
                firesignal(guiObj.Activated)
            end
        end)
    end

    if not clicked and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(finalX, finalY))
        end)
    end

    return true
end

--// =========================================================================
--// AUTO TRAIN MULTIPLIER DETECTOR (1x, 2x, 2.30x, 3x, 4x)
--// =========================================================================
local MultiplierPatterns = {
    ["4x"]    = { val = 4.0, patterns = { "^4%.?0*x$", "%f[%d]4%.?0*x%f[%A]", "x4%.?0*$" } },
    ["3x"]    = { val = 3.0, patterns = { "^3%.?0*x$", "%f[%d]3%.?0*x%f[%A]", "x3%.?0*$" } },
    ["2.30x"] = { val = 2.3, patterns = { "2%.30*x", "2%.3x", "x2%.30*" } },
    ["2x"]    = { val = 2.0, patterns = { "^2%.?0*x$", "%f[%d]2%.?0*x%f[%A]", "x2%.?0*$" } },
    ["1x"]    = { val = 1.0, patterns = { "^1%.?0*x$", "%f[%d]1%.?0*x%f[%A]", "x1%.?0*$" } },
}

local function MatchMultiplierLabel(rawText)
    if not rawText or rawText == "" then return nil, 0 end
    local clean = string.lower(string.gsub(rawText, "%s+", ""))
    if #clean > 18 then return nil, 0 end

    for _, pat in ipairs(MultiplierPatterns["2.30x"].patterns) do
        if string.find(clean, pat) then
            return "2.30x", 2.3
        end
    end

    for _, tag in ipairs({ "4x", "3x", "2x", "1x" }) do
        for _, pat in ipairs(MultiplierPatterns[tag].patterns) do
            if string.find(clean, pat) then
                return tag, MultiplierPatterns[tag].val
            end
        end
    end

    return nil, 0
end

local function IsMultiplierAllowed(tag, val)
    if State.AutoTrainFilter == "ALL" then
        return true
    elseif State.AutoTrainFilter == "2X_PLUS" then
        return val >= 2.0
    elseif State.AutoTrainFilter == "MAX_ONLY" then
        return val >= 2.3
    elseif State.AutoTrainFilter == "2X_ONLY" then
        return tag == "2x" or tag == "2.30x"
    end
    return true
end

local function IsGuiVisibleOnScreen(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if not obj.Visible then return false end
    if obj.AbsoluteSize.X < 4 or obj.AbsoluteSize.Y < 4 then return false end

    local curr = obj.Parent
    while curr do
        if curr:IsA("ScreenGui") then
            return curr.Enabled
        elseif curr:IsA("GuiObject") then
            if not curr.Visible then
                return false
            end
        end
        curr = curr.Parent
    end
    return false
end

local function FindMovingIndicatorInContainer(container, zoneObj)
    if not container then return nil end
    local bestIndicator = nil
    for _, child in ipairs(container:GetDescendants()) do
        if child ~= zoneObj and child:IsA("GuiObject") and child.Visible then
            local nameLower = string.lower(child.Name)
            local isCursorName = string.find(nameLower, "cursor")
                or string.find(nameLower, "needle")
                or string.find(nameLower, "pointer")
                or string.find(nameLower, "arrow")
                or string.find(nameLower, "marker")
                or string.find(nameLower, "slider")
                or string.find(nameLower, "line")
                or string.find(nameLower, "indicator")

            local isThinBar = (child.AbsoluteSize.X >= 1 and child.AbsoluteSize.X <= 18 and child.AbsoluteSize.Y >= 12)
                or (child.AbsoluteSize.Y >= 1 and child.AbsoluteSize.Y <= 18 and child.AbsoluteSize.X >= 12)

            if isCursorName or isThinBar then
                bestIndicator = child
                if isCursorName then
                    break
                end
            end
        end
    end
    return bestIndicator
end

local function ProcessAutoTrainCursor()
    if not State.AutoTrainEnabled then return end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

    local candidates = {}

    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "ChelseaaSystemV10" then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and IsGuiVisibleOnScreen(desc) then
                    local tag, val = MatchMultiplierLabel(desc.Text)
                    if tag and IsMultiplierAllowed(tag, val) then
                        table.insert(candidates, {
                            obj = desc,
                            tag = tag,
                            val = val,
                        })
                    end
                end
            end
        end
    end

    if #candidates == 0 then return end

    table.sort(candidates, function(a, b)
        return a.val > b.val
    end)

    for _, item in ipairs(candidates) do
        local obj = item.obj
        local zonePos = obj.AbsolutePosition
        local zoneSize = obj.AbsoluteSize
        local zoneCenterX = zonePos.X + (zoneSize.X * 0.5)
        local zoneCenterY = zonePos.Y + (zoneSize.Y * 0.5)

        local barContainer = obj.Parent and obj.Parent.Parent or obj.Parent
        local indicator = FindMovingIndicatorInContainer(barContainer, obj)

        if indicator and (State.AutoTrainMode == "SMART" or State.AutoTrainMode == "BAR_ALIGN") then
            local indPos = indicator.AbsolutePosition
            local indSize = indicator.AbsoluteSize
            local indCenterX = indPos.X + (indSize.X * 0.5)
            local indCenterY = indPos.Y + (indSize.Y * 0.5)

            local isHorizontal = barContainer and (barContainer.AbsoluteSize.X >= barContainer.AbsoluteSize.Y)
            local dist = isHorizontal and math.abs(indCenterX - zoneCenterX) or math.abs(indCenterY - zoneCenterY)
            local halfZone = isHorizontal and (zoneSize.X * 0.5) or (zoneSize.Y * 0.5)

            if dist <= math.max(State.CursorTolerancePx, halfZone * 0.65) then
                local clickTarget = obj:IsA("TextButton") and obj or (obj.Parent:IsA("GuiButton") and obj.Parent or obj)
                if PerformCursorClickAt(zoneCenterX, zoneCenterY, clickTarget) then
                    State.LastDetectedText = item.tag .. " (Bar Align)"
                    return
                end
            end
        elseif State.AutoTrainMode == "SMART" or State.AutoTrainMode == "POPUP_CLICK" then
            local clickTarget = obj:IsA("TextButton") and obj or (obj.Parent:IsA("GuiButton") and obj.Parent or obj)
            if PerformCursorClickAt(zoneCenterX, zoneCenterY, clickTarget) then
                State.LastDetectedText = item.tag .. " (Cursor Hit)"
                return
            end
        end
    end
end

--// =========================================================================
--// VISUAL / ESP / CHARACTER EFFECT HELPERS
--// =========================================================================
local function UpdatePlayerESP(enabled)
    State.PlayerESP = enabled
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local existing = plr.Character:FindFirstChild("ChelseaaESP")
            if enabled then
                if not existing then
                    local hl = Instance.new("Highlight")
                    hl.Name = "ChelseaaESP"
                    hl.FillColor = Color3.fromRGB(220, 38, 68)
                    hl.OutlineColor = Color3.fromRGB(56, 189, 248)
                    hl.FillTransparency = 0.55
                    hl.OutlineTransparency = 0
                    hl.Parent = plr.Character
                end
            else
                if existing then
                    existing:Destroy()
                end
            end
        end
    end
end

local function ToggleCharacterAura(auraClass, auraName)
    local root = GetRootPart()
    if not root then return end
    local existing = root:FindFirstChild(auraName)
    if existing then
        existing:Destroy()
        SetStatus("Removed " .. auraName)
    else
        local inst = Instance.new(auraClass)
        inst.Name = auraName
        inst.Parent = root
        SetStatus("Activated " .. auraName)
    end
end

local function SetXRayWalls(enabled)
    State.XRayActive = enabled
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(LocalPlayer.Character or Instance.new("Folder")) then
            if enabled then
                if v.Transparency < 0.5 and v.CanCollide then
                    v:SetAttribute("ChelseaaOrigTrans", v.Transparency)
                    v.Transparency = 0.65
                end
            else
                local orig = v:GetAttribute("ChelseaaOrigTrans")
                if orig ~= nil then
                    v.Transparency = orig
                    v:SetAttribute("ChelseaaOrigTrans", nil)
                end
            end
        end
    end
end

local function ClearAllSpawnedPlatforms()
    for _, p in ipairs(SpawnedPlatforms) do
        if p and p.Parent then
            p:Destroy()
        end
    end
    SpawnedPlatforms = {}
end

local function ApplyClientHeadless(enabled)
    State.ClientHeadless = enabled
    local char = GetCharacter()
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        head.Transparency = enabled and 1 or 0
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then
                child.Transparency = enabled and 1 or 0
            end
        end
    end
end

local function ApplyClientKorblox(enabled)
    State.ClientKorblox = enabled
    local char = GetCharacter()
    if not char then return end

    local r15Parts = { "RightUpperLeg", "RightLowerLeg", "RightFoot" }
    local r6Part = char:FindFirstChild("Right Leg")
    local attachTarget = char:FindFirstChild("RightUpperLeg") or r6Part

    -- Remove previous custom Korblox mesh if present
    local oldMeshPart = char:FindFirstChild("ChelseaaKorbloxLeg")
    if oldMeshPart then
        oldMeshPart:Destroy()
    end

    if enabled then
        for _, partName in ipairs(r15Parts) do
            local p = char:FindFirstChild(partName)
            if p and p:IsA("BasePart") then
                p.Transparency = 1
            end
        end
        if r6Part and r6Part:IsA("BasePart") then
            r6Part.Transparency = 1
        end

        if attachTarget and attachTarget:IsA("BasePart") then
            local kPart = Instance.new("Part")
            kPart.Name = "ChelseaaKorbloxLeg"
            kPart.Size = Vector3.new(1, 2, 1)
            kPart.CanCollide = false
            kPart.Massless = true
            kPart.Color = Color3.fromRGB(45, 52, 68)
            kPart.Material = Enum.Material.SmoothPlastic
            kPart.CFrame = attachTarget.CFrame * CFrame.new(0, -0.35, 0)
            kPart.Parent = char

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://101851696"
            mesh.TextureId = "rbxassetid://101851254"
            mesh.Scale = Vector3.new(1, 1, 1)
            mesh.Parent = kPart

            local weld = Instance.new("WeldConstraint")
            weld.Part0 = attachTarget
            weld.Part1 = kPart
            weld.Parent = kPart
        end
    else
        for _, partName in ipairs(r15Parts) do
            local p = char:FindFirstChild(partName)
            if p and p:IsA("BasePart") then
                p.Transparency = 0
            end
        end
        if r6Part and r6Part:IsA("BasePart") then
            r6Part.Transparency = 0
        end
    end
end

local function UpdateHorsemanArmPose(char)
    if not char then return end
    local r15Shoulder = char:FindFirstChild("RightShoulder", true)
    local r15Elbow = char:FindFirstChild("RightElbow", true)
    local r15Wrist = char:FindFirstChild("RightWrist", true)
    if r15Shoulder and r15Shoulder:IsA("Motor6D") then
        r15Shoulder.Transform = CFrame.Angles(math.rad(56), math.rad(12), math.rad(-14))
        if r15Elbow and r15Elbow:IsA("Motor6D") then
            r15Elbow.Transform = CFrame.Angles(math.rad(32), 0, 0)
        end
        if r15Wrist and r15Wrist:IsA("Motor6D") then
            r15Wrist.Transform = CFrame.Angles(math.rad(-12), 0, 0)
        end
        return
    end

    local torso = char:FindFirstChild("Torso")
    local r6Shoulder = torso and torso:FindFirstChild("Right Shoulder")
    if r6Shoulder and r6Shoulder:IsA("Motor6D") then
        r6Shoulder.Transform = CFrame.Angles(0, 0, math.rad(68)) * CFrame.Angles(0, math.rad(-16), 0)
    end
end

local function ApplyClientHeadlessHorseman(enabled)
    State.ClientHeadlessHorseman = enabled
    local char = GetCharacter()
    if not char then return end

    -- Clean up any existing held Horseman head & neck flame
    local oldHeld = char:FindFirstChild("ChelseaaHorsemanHeldHead")
    if oldHeld then oldHeld:Destroy() end
    local oldNeck = char:FindFirstChild("ChelseaaHorsemanNeckFlame", true)
    if oldNeck then oldNeck:Destroy() end

    local head = char:FindFirstChild("Head")
    if enabled then
        if head and head:IsA("BasePart") then
            head.Transparency = 1
            for _, child in ipairs(head:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    child.Transparency = 1
                end
            end
        end

        -- Pose the right arm forward in the classic Headless Horseman carry stance
        UpdateHorsemanArmPose(char)

        local root = GetRootPart()
        local isR15 = char:FindFirstChild("RightHand") ~= nil
        local handPart = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if handPart and handPart:IsA("BasePart") then
            local heldHead = Instance.new("Part")
            heldHead.Name = "ChelseaaHorsemanHeldHead"
            heldHead.Size = Vector3.new(1.25, 1.25, 1.25)
            heldHead.CanCollide = false
            heldHead.Massless = true
            heldHead.Color = Color3.fromRGB(255, 115, 0)
            heldHead.Material = Enum.Material.Neon

            -- Position upright in front/cradled in the raised right hand, facing forward
            if root then
                local forwardDir = root.CFrame.LookVector
                local rightDir = root.CFrame.RightVector
                local palmOffset = isR15
                    and (forwardDir * 0.35 + Vector3.new(0, 0.38, 0) - rightDir * 0.05)
                    or (forwardDir * 0.85 + Vector3.new(0, -0.15, 0) - rightDir * 0.08)
                local headPos = handPart.Position + palmOffset
                heldHead.CFrame = CFrame.lookAt(headPos, headPos + forwardDir, Vector3.yAxis)
                    * CFrame.Angles(math.rad(10), math.rad(12), 0)
            else
                local fallbackOffset = isR15
                    and (CFrame.new(0, 0.35, -0.35) * CFrame.Angles(math.rad(-75), 0, 0))
                    or (CFrame.new(0, -0.85, -0.45) * CFrame.Angles(math.rad(-65), 0, 0))
                heldHead.CFrame = handPart.CFrame * fallbackOffset
            end
            heldHead.Parent = char

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://16627529"
            mesh.TextureId = "rbxassetid://16627494"
            mesh.Scale = Vector3.new(1.18, 1.18, 1.18)
            mesh.Parent = heldHead

            local hFire = Instance.new("Fire")
            hFire.Name = "HalloweenFire"
            hFire.Color = Color3.fromRGB(255, 110, 0)
            hFire.SecondaryColor = Color3.fromRGB(168, 35, 255)
            hFire.Size = 4.5
            hFire.Heat = 8
            hFire.Parent = heldHead

            local hLight = Instance.new("PointLight")
            hLight.Color = Color3.fromRGB(255, 125, 20)
            hLight.Brightness = 2.2
            hLight.Range = 12
            hLight.Parent = heldHead

            local hSparkles = Instance.new("Sparkles")
            hSparkles.SparkleColor = Color3.fromRGB(255, 145, 0)
            hSparkles.Parent = heldHead

            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handPart
            weld.Part1 = heldHead
            weld.Parent = heldHead
        end

        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if torso and torso:IsA("BasePart") then
            local neckAtt = Instance.new("Attachment")
            neckAtt.Name = "ChelseaaHorsemanNeckFlame"
            neckAtt.Position = Vector3.new(0, torso.Size.Y * 0.5, 0)
            neckAtt.Parent = torso

            local neckFire = Instance.new("Fire")
            neckFire.Color = Color3.fromRGB(255, 95, 0)
            neckFire.SecondaryColor = Color3.fromRGB(145, 25, 255)
            neckFire.Size = 2.5
            neckFire.Heat = 5
            neckFire.Parent = neckAtt
        end
    else
        -- Reset right arm Motor6D transform when turned off
        local r15Shoulder = char:FindFirstChild("RightShoulder", true)
        local r15Elbow = char:FindFirstChild("RightElbow", true)
        local r15Wrist = char:FindFirstChild("RightWrist", true)
        if r15Shoulder and r15Shoulder:IsA("Motor6D") then r15Shoulder.Transform = CFrame.new() end
        if r15Elbow and r15Elbow:IsA("Motor6D") then r15Elbow.Transform = CFrame.new() end
        if r15Wrist and r15Wrist:IsA("Motor6D") then r15Wrist.Transform = CFrame.new() end
        local torso = char:FindFirstChild("Torso")
        local r6Shoulder = torso and torso:FindFirstChild("Right Shoulder")
        if r6Shoulder and r6Shoulder:IsA("Motor6D") then r6Shoulder.Transform = CFrame.new() end

        if not State.ClientHeadless and head and head:IsA("BasePart") then
            head.Transparency = 0
            for _, child in ipairs(head:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    child.Transparency = 0
                end
            end
        end
    end
end

local function LoadCustomMenuImage(url, fileName)
    local resolved = ""
    pcall(function()
        local getAsset = getcustomasset or getsynasset
        if type(getAsset) == "function" and type(writefile) == "function" then
            local rawBytes = game:HttpGet(url)
            if rawBytes and #rawBytes > 0 then
                writefile(fileName, rawBytes)
                resolved = getAsset(fileName)
            end
        end
    end)
    return resolved
end

-- Forward reference for Theme switcher
local ApplyUITheme = function(_) end

--// =========================================================================
--// COMMANDS & 100 NEW FEATURES REGISTRY (TOTAL = 5,100)
--// =========================================================================
local Commands = {}
local New100Features = {}
local CommandLookup = {}

local function RegisterCommand(name, category, subTag, desc, isNew100, callback)
    local idx = #Commands + 1
    local entry = {
        id = idx,
        name = name,
        category = category,
        subTag = subTag,
        desc = desc,
        isNew100 = isNew100 or false,
        run = function()
            callback()
            SetStatus(string.format("[#%d] %s", idx, desc))
        end,
    }
    Commands[idx] = entry
    CommandLookup[string.lower(name)] = entry
    CommandLookup[tostring(idx)] = entry
    if isNew100 then
        table.insert(New100Features, entry)
    end
end

-- =========================================================================
-- PART A: 100 BRAND-NEW INTERESTING FEATURES (#1 - #100)
-- =========================================================================

-- 1. Visual & ESP (20 Features)
RegisterCommand("Player Highlight ESP ON", "100 NEW", "Visual/ESP", "Highlight all players through walls (Crimson/Cyan)", true, function()
    UpdatePlayerESP(true)
end)
RegisterCommand("Player Highlight ESP OFF", "100 NEW", "Visual/ESP", "Disable Player Highlight ESP", true, function()
    UpdatePlayerESP(false)
end)
RegisterCommand("X-Ray Walls ON", "100 NEW", "Visual/ESP", "Make map walls semi-transparent (X-Ray)", true, function()
    SetXRayWalls(true)
end)
RegisterCommand("X-Ray Walls OFF", "100 NEW", "Visual/ESP", "Restore solid wall transparency", true, function()
    SetXRayWalls(false)
end)
RegisterCommand("Rainbow Character ON", "100 NEW", "Visual/ESP", "Cycle smooth RGB neon colors across your character", true, function()
    State.RainbowChar = true
end)
RegisterCommand("Rainbow Character OFF", "100 NEW", "Visual/ESP", "Stop Rainbow Character color cycle", true, function()
    State.RainbowChar = false
end)
RegisterCommand("ForceField Body Shield", "100 NEW", "Visual/ESP", "Apply glowing ForceField material to avatar", true, function()
    local char = GetCharacter()
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.Material = Enum.Material.ForceField end
        end
    end
end)
RegisterCommand("Neon Glow Body", "100 NEW", "Visual/ESP", "Apply bright Neon material to avatar parts", true, function()
    local char = GetCharacter()
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.Material = Enum.Material.Neon end
        end
    end
end)
RegisterCommand("Fire Aura Toggle", "100 NEW", "Visual/ESP", "Toggle blazing Fire aura on HumanoidRootPart", true, function()
    ToggleCharacterAura("Fire", "ChelseaaFireAura")
end)
RegisterCommand("Sparkles Aura Toggle", "100 NEW", "Visual/ESP", "Toggle cyber Sparkles aura on HumanoidRootPart", true, function()
    ToggleCharacterAura("Sparkles", "ChelseaaSparklesAura")
end)
RegisterCommand("Smoke Aura Toggle", "100 NEW", "Visual/ESP", "Toggle dark Smoke aura on HumanoidRootPart", true, function()
    ToggleCharacterAura("Smoke", "ChelseaaSmokeAura")
end)
RegisterCommand("Cyber Trail Toggle", "100 NEW", "Visual/ESP", "Attach glowing crimson-cyan motion trail behind you", true, function()
    local root = GetRootPart()
    if not root then return end
    local old = root:FindFirstChild("ChelseaaTrail")
    if old then
        old:Destroy()
        return
    end
    local a0 = Instance.new("Attachment", root)
    a0.Position = Vector3.new(0, 1.5, 0)
    local a1 = Instance.new("Attachment", root)
    a1.Position = Vector3.new(0, -1.5, 0)
    local tr = Instance.new("Trail")
    tr.Name = "ChelseaaTrail"
    tr.Attachment0 = a0
    tr.Attachment1 = a1
    tr.Lifetime = 0.6
    tr.Color = ColorSequence.new(Color3.fromRGB(220, 38, 68), Color3.fromRGB(56, 189, 248))
    tr.Parent = root
end)
RegisterCommand("Fullbright Max", "100 NEW", "Visual/ESP", "Maximum daylight brightness with zero shadows", true, function()
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
end)
RegisterCommand("Midnight Obsidian Sky", "100 NEW", "Visual/ESP", "Switch world sky to sleek dark midnight mode", true, function()
    Lighting.ClockTime = 0
    Lighting.Brightness = 1
    Lighting.Ambient = Color3.fromRGB(35, 35, 50)
end)
RegisterCommand("Cyber Crimson Shader", "100 NEW", "Visual/ESP", "Apply red-tinted cyber-anime atmosphere lighting", true, function()
    Lighting.Ambient = Color3.fromRGB(140, 30, 55)
    Lighting.OutdoorAmbient = Color3.fromRGB(160, 40, 70)
    Lighting.FogColor = Color3.fromRGB(45, 10, 20)
    Lighting.FogEnd = 800
end)
RegisterCommand("Golden Sunset Shader", "100 NEW", "Visual/ESP", "Apply warm golden hour sunset lighting", true, function()
    Lighting.ClockTime = 17.8
    Lighting.Ambient = Color3.fromRGB(150, 105, 65)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 120, 70)
end)
RegisterCommand("Remove Map Fog", "100 NEW", "Visual/ESP", "Clear all distance fog for crystal-clear vision", true, function()
    Lighting.FogEnd = 1000000
    Lighting.FogStart = 999999
end)
RegisterCommand("FPS Booster LowGFX", "100 NEW", "Visual/ESP", "Convert parts to SmoothPlastic & hide decals for max FPS", true, function()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        end
    end
end)
RegisterCommand("Disable Map Particles", "100 NEW", "Visual/ESP", "Turn off laggy ParticleEmitters & Beams in map", true, function()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Beam") then
            v.Enabled = false
        end
    end
end)
RegisterCommand("Restore Default Lighting", "100 NEW", "Visual/ESP", "Reset lighting & fog back to original map settings", true, function()
    for k, v in pairs(OriginalLighting) do
        Lighting[k] = v
    end
end)

-- 2. Camera & View (15 Features)
RegisterCommand("Camera FOV 60 (Zoom)", "100 NEW", "Camera", "Set tight sniper zoom Field of View (60)", true, function()
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 60 end
end)
RegisterCommand("Camera FOV 70 (Default)", "100 NEW", "Camera", "Reset Field of View to standard Roblox default (70)", true, function()
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 70 end
end)
RegisterCommand("Camera FOV 90 (Wide)", "100 NEW", "Camera", "Set wide action Field of View (90)", true, function()
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 90 end
end)
RegisterCommand("Camera FOV 105 (Pro)", "100 NEW", "Camera", "Set competitive wide Field of View (105)", true, function()
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 105 end
end)
RegisterCommand("Camera FOV 120 (Ultra)", "100 NEW", "Camera", "Set maximum ultra-wide Field of View (120)", true, function()
    if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 120 end
end)
RegisterCommand("Unlock Zoom 500 Studs", "100 NEW", "Camera", "Allow zooming camera out up to 500 studs", true, function()
    LocalPlayer.CameraMaxZoomDistance = 500
end)
RegisterCommand("Unlock Zoom 5000 Studs", "100 NEW", "Camera", "Allow zooming camera out across entire map (5000)", true, function()
    LocalPlayer.CameraMaxZoomDistance = 5000
end)
RegisterCommand("First Person Mode", "100 NEW", "Camera", "Lock camera into First-Person perspective", true, function()
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end)
RegisterCommand("Third Person Classic", "100 NEW", "Camera", "Unlock Third-Person camera perspective", true, function()
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    LocalPlayer.CameraMinZoomDistance = 0.5
end)
RegisterCommand("Spectate Nearest Player", "100 NEW", "Camera", "Focus camera onto the closest player near you", true, function()
    local root = GetRootPart()
    local cam = workspace.CurrentCamera
    if not root or not cam then return end
    local bestHum, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local d = (hrp.Position - root.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestHum = hum
                end
            end
        end
    end
    if bestHum then cam.CameraSubject = bestHum end
end)
RegisterCommand("Spectate Random Player", "100 NEW", "Camera", "Switch camera view to a random player in server", true, function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local pool = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
            table.insert(pool, plr.Character:FindFirstChildOfClass("Humanoid"))
        end
    end
    if #pool > 0 then
        cam.CameraSubject = pool[math.random(1, #pool)]
    end
end)
RegisterCommand("Reset Camera to Self", "100 NEW", "Camera", "Return camera focus back to your own character", true, function()
    local cam = workspace.CurrentCamera
    local hum = GetHumanoid()
    if cam and hum then
        cam.CameraSubject = hum
    end
end)
RegisterCommand("ShiftLock Enable", "100 NEW", "Camera", "Enable Mouse ShiftLock toggle option", true, function()
    LocalPlayer.DevEnableMouseLock = true
end)
RegisterCommand("Clear Camera Blur/Color", "100 NEW", "Camera", "Disable BlurEffect & ColorCorrection post-processing", true, function()
    for _, fx in ipairs(Lighting:GetChildren()) do
        if fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect") or fx:IsA("DepthOfFieldEffect") then
            fx.Enabled = false
        end
    end
end)
RegisterCommand("Cyber Contrast Enhance", "100 NEW", "Camera", "Add crisp ColorCorrection contrast boost", true, function()
    local cc = Lighting:FindFirstChild("ChelseaaCC") or Instance.new("ColorCorrectionEffect", Lighting)
    cc.Name = "ChelseaaCC"
    cc.Enabled = true
    cc.Contrast = 0.22
    cc.Saturation = 0.18
end)

-- 3. Physics & Fun Movement (20 Features)
RegisterCommand("Slow Spin (Speed 5)", "100 NEW", "Physics/Fun", "Rotate character smoothly at speed 5", true, function()
    State.SpinSpeed = 5
end)
RegisterCommand("Fast Spinbot (Speed 25)", "100 NEW", "Physics/Fun", "Spin character rapidly at speed 25", true, function()
    State.SpinSpeed = 25
end)
RegisterCommand("Tornado Spin (Speed 65)", "100 NEW", "Physics/Fun", "Ultra-fast tornado spinbot at speed 65", true, function()
    State.SpinSpeed = 65
end)
RegisterCommand("Stop Character Spin", "100 NEW", "Physics/Fun", "Stop character rotation immediately", true, function()
    State.SpinSpeed = 0
end)
RegisterCommand("Moon Gravity (35)", "100 NEW", "Physics/Fun", "Low lunar gravity for floaty high jumps", true, function()
    workspace.Gravity = 35
end)
RegisterCommand("Zero-G Space Float (5)", "100 NEW", "Physics/Fun", "Near-zero gravity space floating", true, function()
    workspace.Gravity = 5
end)
RegisterCommand("Heavy Planet Gravity (350)", "100 NEW", "Physics/Fun", "High gravity for instant fast landing", true, function()
    workspace.Gravity = 350
end)
RegisterCommand("Reset Standard Gravity", "100 NEW", "Physics/Fun", "Restore standard Roblox gravity (196.2)", true, function()
    workspace.Gravity = 196.2
end)
RegisterCommand("Bunny Hop Auto-Jump ON", "100 NEW", "Physics/Fun", "Automatically jump continuously while moving", true, function()
    State.BunnyHop = true
end)
RegisterCommand("Bunny Hop Auto-Jump OFF", "100 NEW", "Physics/Fun", "Disable Bunny Hop auto-jump", true, function()
    State.BunnyHop = false
end)
RegisterCommand("Air Walk Sky Floor ON", "100 NEW", "Physics/Fun", "Walk in mid-air on an invisible dynamic floor", true, function()
    State.AirWalk = true
end)
RegisterCommand("Air Walk Sky Floor OFF", "100 NEW", "Physics/Fun", "Disable mid-air walking floor", true, function()
    State.AirWalk = false
end)
RegisterCommand("Spawn Neon Glass Platform", "100 NEW", "Physics/Fun", "Spawn a solid neon glass platform beneath your feet", true, function()
    local root = GetRootPart()
    if not root then return end
    local plat = Instance.new("Part")
    plat.Size = Vector3.new(16, 1, 16)
    plat.Anchored = true
    plat.Material = Enum.Material.Neon
    plat.Color = Color3.fromRGB(220, 38, 68)
    plat.Transparency = 0.35
    plat.CFrame = root.CFrame * CFrame.new(0, -3.5, 0)
    plat.Parent = workspace
    table.insert(SpawnedPlatforms, plat)
end)
RegisterCommand("Clear Spawned Platforms", "100 NEW", "Physics/Fun", "Remove all platforms spawned by Chelseaa System", true, function()
    ClearAllSpawnedPlatforms()
end)
RegisterCommand("Anti-Fling Protection ON", "100 NEW", "Physics/Fun", "Clamp extreme velocity spikes to prevent flinging", true, function()
    State.AntiFling = true
end)
RegisterCommand("Anti-Fling Protection OFF", "100 NEW", "Physics/Fun", "Disable Anti-Fling velocity clamp", true, function()
    State.AntiFling = false
end)
RegisterCommand("Swim in Air ON", "100 NEW", "Physics/Fun", "Enable mid-air swimming state anywhere", true, function()
    State.SwimAir = true
end)
RegisterCommand("Swim in Air OFF", "100 NEW", "Physics/Fun", "Disable mid-air swimming state", true, function()
    State.SwimAir = false
end)
RegisterCommand("Forward Dash Boost (+45)", "100 NEW", "Physics/Fun", "Instant forward momentum dash burst", true, function()
    local root = GetRootPart()
    if root then
        root.CFrame = root.CFrame * CFrame.new(0, 0, -45)
    end
end)
RegisterCommand("Super Sky Launch (+140)", "100 NEW", "Physics/Fun", "Launch character upward with vertical velocity", true, function()
    local root = GetRootPart()
    if root then
        root.Velocity = Vector3.new(root.Velocity.X, 140, root.Velocity.Z)
    end
end)

-- 4. Tween & Multi-Slot Waypoints (15 Features)
for slot = 1, 5 do
    RegisterCommand("Save Waypoint Slot " .. slot, "100 NEW", "Tween/Waypoints", "Save current coordinates to Waypoint Slot #" .. slot, true, function()
        local root = GetRootPart()
        if root then
            State.Waypoints[slot] = root.CFrame
        end
    end)
    RegisterCommand("Tween to Waypoint Slot " .. slot, "100 NEW", "Tween/Waypoints", "Smoothly tween to Waypoint Slot #" .. slot .. " at Tween Speed", true, function()
        if State.Waypoints[slot] then
            TweenToCFrame(State.Waypoints[slot])
        end
    end)
end
RegisterCommand("Tween to Nearest Player", "100 NEW", "Tween/Waypoints", "Tween smoothly to the nearest player at Tween Speed", true, function()
    local root = GetRootPart()
    if not root then return end
    local nearest, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - root.Position).Magnitude
            if d < bestDist then
                bestDist = d
                nearest = plr.Character.HumanoidRootPart
            end
        end
    end
    if nearest then
        TweenToCFrame(nearest.CFrame * CFrame.new(0, 0, 3))
    end
end)
RegisterCommand("Tween to Farthest Player", "100 NEW", "Tween/Waypoints", "Tween across the map to the farthest player", true, function()
    local root = GetRootPart()
    if not root then return end
    local farthest, maxDist = nil, -1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - root.Position).Magnitude
            if d > maxDist then
                maxDist = d
                farthest = plr.Character.HumanoidRootPart
            end
        end
    end
    if farthest then
        TweenToCFrame(farthest.CFrame * CFrame.new(0, 0, 3))
    end
end)
RegisterCommand("Tween to Map Origin (0,50,0)", "100 NEW", "Tween/Waypoints", "Tween smoothly to center coordinates (0, 50, 0)", true, function()
    TweenToCFrame(CFrame.new(0, 50, 0))
end)
RegisterCommand("Tween High Sky (+500)", "100 NEW", "Tween/Waypoints", "Tween 500 studs straight up into the sky", true, function()
    local root = GetRootPart()
    if root then
        TweenToCFrame(root.CFrame + Vector3.new(0, 500, 0))
    end
end)
RegisterCommand("Instant TP to Slot 1", "100 NEW", "Tween/Waypoints", "Instant CFrame teleport to Waypoint Slot #1", true, function()
    local root = GetRootPart()
    if root and State.Waypoints[1] then
        root.CFrame = State.Waypoints[1]
    end
end)

-- 5. Automation & Utility (15 Features)
RegisterCommand("Auto Train Cursor ON", "100 NEW", "Automation", "Enable precision cursor clicker for 1x/2x/2.30x/3x/4x", true, function()
    State.AutoTrainEnabled = true
end)
RegisterCommand("Auto Train Cursor OFF", "100 NEW", "Automation", "Disable Auto Train Cursor", true, function()
    State.AutoTrainEnabled = false
end)
RegisterCommand("Auto Train Filter: 2x+", "100 NEW", "Automation", "Target 2x, 2.30x, 3x, and 4x multipliers only", true, function()
    State.AutoTrainFilter = "2X_PLUS"
    State.AutoTrainEnabled = true
end)
RegisterCommand("Auto Train Filter: High Max", "100 NEW", "Automation", "Target highest multipliers (2.30x / 3x / 4x)", true, function()
    State.AutoTrainFilter = "MAX_ONLY"
    State.AutoTrainEnabled = true
end)
RegisterCommand("Auto Screen Clicker ON", "100 NEW", "Automation", "Auto-tap center screen continuously for rapid training", true, function()
    State.AutoClickerCenter = true
end)
RegisterCommand("Auto Screen Clicker OFF", "100 NEW", "Automation", "Stop center screen auto-clicker", true, function()
    State.AutoClickerCenter = false
end)
RegisterCommand("Auto ProximityPrompts ON", "100 NEW", "Automation", "Automatically trigger nearby interact/collect prompts", true, function()
    State.AutoPrompts = true
end)
RegisterCommand("Auto ProximityPrompts OFF", "100 NEW", "Automation", "Disable automatic ProximityPrompt interaction", true, function()
    State.AutoPrompts = false
end)
RegisterCommand("Auto Respawn Death Spot ON", "100 NEW", "Automation", "Return automatically to your exact death location on respawn", true, function()
    State.AutoRespawnSpot = true
end)
RegisterCommand("Auto Respawn Death Spot OFF", "100 NEW", "Automation", "Disable auto-return on respawn", true, function()
    State.AutoRespawnSpot = false
end)
RegisterCommand("Anti-AFK Idle Bypass", "100 NEW", "Automation", "Prevent 20-minute idle disconnect kick", true, function()
    TrackConn(LocalPlayer.Idled:Connect(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end))
end)
RegisterCommand("Freeze Character Position", "100 NEW", "Automation", "Anchor HumanoidRootPart in place", true, function()
    local root = GetRootPart()
    if root then root.Anchored = true end
end)
RegisterCommand("Unfreeze Character Position", "100 NEW", "Automation", "Unanchor HumanoidRootPart to move freely", true, function()
    local root = GetRootPart()
    if root then root.Anchored = false end
end)
RegisterCommand("Rejoin Current Server", "100 NEW", "Automation", "Reconnect immediately to current server instance", true, function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
RegisterCommand("Server Hop (New Server)", "100 NEW", "Automation", "Join another active public server", true, function()
    pcall(function()
        local raw = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(raw)
        if data and data.data then
            for _, srv in ipairs(data.data) do
                if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                    break
                end
            end
        end
    end)
end)

-- 6. Character FX, Headless, Korblox & UI Themes (19 Features)
RegisterCommand("Client Headless ON", "100 NEW", "Character/UI", "Make avatar head & face invisible (keeps hair/hats)", true, function()
    ApplyClientHeadless(true)
end)
RegisterCommand("Client Headless OFF", "100 NEW", "Character/UI", "Restore avatar head & face visibility", true, function()
    ApplyClientHeadless(false)
end)
RegisterCommand("Client Headless Horseman ON", "100 NEW", "Character/UI", "31K Robux Halloween bundle: Headless + flaming pumpkin head held in hand", true, function()
    ApplyClientHeadlessHorseman(true)
end)
RegisterCommand("Client Headless Horseman OFF", "100 NEW", "Character/UI", "Remove Headless Horseman held head & Halloween fire", true, function()
    ApplyClientHeadlessHorseman(false)
end)
RegisterCommand("Client Korblox ON", "100 NEW", "Character/UI", "Equip Korblox Deathspeaker right leg (R6 & R15)", true, function()
    ApplyClientKorblox(true)
end)
RegisterCommand("Client Korblox OFF", "100 NEW", "Character/UI", "Restore normal avatar right leg", true, function()
    ApplyClientKorblox(false)
end)
RegisterCommand("Anti-Ragdoll Lock ON", "100 NEW", "Character/UI", "Prevent falling down / ragdoll states", true, function()
    State.AntiRagdoll = true
end)
RegisterCommand("Anti-Ragdoll Lock OFF", "100 NEW", "Character/UI", "Disable Anti-Ragdoll lock", true, function()
    State.AntiRagdoll = false
end)
RegisterCommand("Sit Character", "100 NEW", "Character/UI", "Force local character to sit", true, function()
    local hum = GetHumanoid()
    if hum then hum.Sit = true end
end)
RegisterCommand("Stand Up Character", "100 NEW", "Character/UI", "Stand up from seated state", true, function()
    local hum = GetHumanoid()
    if hum then hum.Sit = false end
end)
RegisterCommand("HipHeight Float (+5)", "100 NEW", "Character/UI", "Hover 5 studs above ground via HipHeight", true, function()
    local hum = GetHumanoid()
    if hum then hum.HipHeight = 5 end
end)
RegisterCommand("HipHeight Reset (0)", "100 NEW", "Character/UI", "Reset character HipHeight to default", true, function()
    local hum = GetHumanoid()
    if hum then hum.HipHeight = 0 end
end)
RegisterCommand("Remove Accessories (Clean)", "100 NEW", "Character/UI", "Strip hats/accessories locally for clean hitbox view", true, function()
    local char = GetCharacter()
    if char then
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") then acc:Destroy() end
        end
    end
end)
RegisterCommand("Client Ghost Invisibility", "100 NEW", "Character/UI", "Make character semi-invisible locally (0.75)", true, function()
    local char = GetCharacter()
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.Transparency = 0.75
            end
        end
    end
end)
RegisterCommand("Restore Character Visibility", "100 NEW", "Character/UI", "Restore full opacity to character parts", true, function()
    local char = GetCharacter()
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.Transparency = 0
            end
        end
    end
end)
RegisterCommand("Reset Character", "100 NEW", "Character/UI", "Respawn local character cleanly", true, function()
    local hum = GetHumanoid()
    if hum then hum.Health = 0 end
end)
RegisterCommand("UI Theme: Cyber Crimson", "100 NEW", "Character/UI", "Switch UI accent to Obsidian Cyber Crimson", true, function()
    ApplyUITheme("CRIMSON")
end)
RegisterCommand("UI Theme: Electric Cyan", "100 NEW", "Character/UI", "Switch UI accent to Neon Electric Cyan", true, function()
    ApplyUITheme("CYAN")
end)
RegisterCommand("UI Theme: Emerald Matrix", "100 NEW", "Character/UI", "Switch UI accent to Emerald Matrix Green", true, function()
    ApplyUITheme("EMERALD")
end)
RegisterCommand("UI Theme: Royal Violet", "100 NEW", "Character/UI", "Switch UI accent to Cyber Royal Violet", true, function()
    ApplyUITheme("VIOLET")
end)
RegisterCommand("UI Theme: Pure Monochrome", "100 NEW", "Character/UI", "Switch UI accent to Sleek Silver Monochrome", true, function()
    ApplyUITheme("MONO")
end)

-- =========================================================================
-- PART B: CORE SYSTEM TOGGLES + 5,000 PRECISION COMMANDS (TOTAL = 5,100)
-- =========================================================================
RegisterCommand("wslock_on", "Movement", "Lock", "Lock WalkSpeed permanently against resets", false, function()
    State.WalkSpeedLocked = true
end)
RegisterCommand("wslock_off", "Movement", "Lock", "Unlock WalkSpeed", false, function()
    State.WalkSpeedLocked = false
end)
RegisterCommand("jplock_on", "Movement", "Lock", "Lock JumpPower permanently", false, function()
    State.JumpPowerLocked = true
end)
RegisterCommand("jplock_off", "Movement", "Lock", "Unlock JumpPower", false, function()
    State.JumpPowerLocked = false
end)
RegisterCommand("infjump_on", "Movement", "Jump", "Enable Infinite Jump", false, function()
    State.InfiniteJump = true
end)
RegisterCommand("infjump_off", "Movement", "Jump", "Disable Infinite Jump", false, function()
    State.InfiniteJump = false
end)
RegisterCommand("noclip_on", "Movement", "Clip", "Enable Noclip (walk through walls)", false, function()
    State.Noclip = true
end)
RegisterCommand("noclip_off", "Movement", "Clip", "Disable Noclip", false, function()
    State.Noclip = false
end)
RegisterCommand("fly_on", "Movement", "Fly", "Enable Smooth Fly", false, function()
    State.Fly = true
end)
RegisterCommand("fly_off", "Movement", "Fly", "Disable Smooth Fly", false, function()
    State.Fly = false
end)
RegisterCommand("tweensync_on", "Tween", "Sync", "Sync Tween Speed dynamically with WalkSpeed (2x)", false, function()
    State.SyncTweenToWalkSpeed = true
end)
RegisterCommand("tweensync_off", "Tween", "Sync", "Use manual Tween Speed value", false, function()
    State.SyncTweenToWalkSpeed = false
end)
RegisterCommand("stoptween", "Tween", "Stop", "Cancel active Tween movement immediately", false, function()
    StopActiveTween()
end)
RegisterCommand("train_all", "AutoTrain", "Filter", "Auto Train Cursor Filter: All (1x - 4x)", false, function()
    State.AutoTrainFilter = "ALL"
    State.AutoTrainEnabled = true
end)

-- WalkSpeed Precision: ws1 to ws1000 (1,000)
for spd = 1, 1000 do
    RegisterCommand("ws" .. spd, "WalkSpeed", "Preset", "Set WalkSpeed to " .. spd .. " & lock anti-reset", false, function()
        State.WalkSpeed = spd
        State.WalkSpeedLocked = true
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = spd end
    end)
end

-- Tween Speed Precision: tw10 to tw1500 (1,491)
for tws = 10, 1500 do
    RegisterCommand("tw" .. tws, "Tween", "Speed", "Set Tween Speed to " .. tws .. " studs/sec", false, function()
        State.TweenSpeed = tws
        State.SyncTweenToWalkSpeed = false
    end)
end

-- JumpPower Precision: jp10 to jp1000 (991)
for jp = 10, 1000 do
    RegisterCommand("jp" .. jp, "JumpPower", "Preset", "Set JumpPower to " .. jp .. " & lock", false, function()
        State.JumpPower = jp
        State.JumpPowerLocked = true
        local hum = GetHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = jp
        end
    end)
end

-- Gravity Precision: grav0 to grav500 (501)
for gv = 0, 500 do
    RegisterCommand("grav" .. gv, "Gravity", "Preset", "Set Workspace Gravity to " .. gv, false, function()
        workspace.Gravity = gv
    end)
end

-- Tween Directional Dash: tweenup1..500 & tweenfwd1..503 -> Exact 5,100 Total!
for up = 1, 500 do
    RegisterCommand("tweenup" .. up, "Tween", "Dash", "Tween upward +" .. up .. " studs at current Tween Speed", false, function()
        local root = GetRootPart()
        if root then
            TweenToCFrame(root.CFrame + Vector3.new(0, up, 0))
        end
    end)
end

local remainingTo5101 = 5101 - #Commands
for fwd = 1, remainingTo5101 do
    RegisterCommand("tweenfwd" .. fwd, "Tween", "Dash", "Tween forward +" .. fwd .. " studs at current Tween Speed", false, function()
        local root = GetRootPart()
        if root then
            TweenToCFrame(root.CFrame * CFrame.new(0, 0, -fwd))
        end
    end)
end

--// =========================================================================
--// RUNTIME LOOPS
--// =========================================================================
local AirPlatformPart = nil
local RainbowHue = 0
local LastPromptTick = 0

TrackConn(RunService.Heartbeat:Connect(function(dt)
    local char = GetCharacter()
    local hum = GetHumanoid()
    local root = GetRootPart()

    if hum then
        if State.WalkSpeedLocked and hum.WalkSpeed ~= State.WalkSpeed then
            hum.WalkSpeed = State.WalkSpeed
        end
        if State.JumpPowerLocked then
            hum.UseJumpPower = true
            if hum.JumpPower ~= State.JumpPower then
                hum.JumpPower = State.JumpPower
            end
        end
        if State.BunnyHop and hum.MoveDirection.Magnitude > 0 and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        if State.SwimAir then
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
            hum:ChangeState(Enum.HumanoidStateType.Swimming)
        end
        if State.AntiRagdoll then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
    end

    if State.Noclip and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    if State.Fly and root and hum then
        local cam = workspace.CurrentCamera
        local moveDir = hum.MoveDirection
        if cam then
            local flyVel = Vector3.zero
            if moveDir.Magnitude > 0 then
                flyVel = cam.CFrame.LookVector * moveDir.Magnitude * State.FlySpeed
            end
            root.Velocity = flyVel
        end
    end

    if State.SpinSpeed > 0 and root then
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(State.SpinSpeed), 0)
    end

    if State.AntiFling and root then
        if root.AssemblyLinearVelocity.Magnitude > 180 then
            root.AssemblyLinearVelocity = Vector3.zero
        end
        if root.AssemblyAngularVelocity.Magnitude > 50 then
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if State.AirWalk and root then
        if not AirPlatformPart or not AirPlatformPart.Parent then
            AirPlatformPart = Instance.new("Part")
            AirPlatformPart.Name = "ChelseaaAirWalk"
            AirPlatformPart.Size = Vector3.new(12, 1, 12)
            AirPlatformPart.Anchored = true
            AirPlatformPart.Transparency = 1
            AirPlatformPart.Parent = workspace
        end
        AirPlatformPart.CFrame = CFrame.new(root.Position.X, root.Position.Y - 3.5, root.Position.Z)
    elseif AirPlatformPart then
        AirPlatformPart:Destroy()
        AirPlatformPart = nil
    end

    if State.RainbowChar and char then
        RainbowHue = (RainbowHue + dt * 0.35) % 1
        local col = Color3.fromHSV(RainbowHue, 0.85, 1)
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Color = col
            end
        end
    end

    if State.AutoTrainEnabled then
        ProcessAutoTrainCursor()
    end

    if State.AutoClickerCenter then
        local cam = workspace.CurrentCamera
        if cam then
            local vp = cam.ViewportSize
            PerformCursorClickAt(vp.X * 0.5, vp.Y * 0.5, nil)
        end
    end

    if State.AutoPrompts and root and (os.clock() - LastPromptTick) > 0.25 then
        LastPromptTick = os.clock()
        if type(fireproximityprompt) == "function" then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.Enabled then
                    local parentPart = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstChildWhichIsA("BasePart"))
                    if parentPart and (parentPart.Position - root.Position).Magnitude <= (obj.MaxActivationDistance + 8) then
                        pcall(fireproximityprompt, obj)
                    end
                end
            end
        end
    end
end))

TrackConn(RunService.Stepped:Connect(function()
    if State.ClientHeadlessHorseman then
        local char = GetCharacter()
        if char then
            UpdateHorsemanArmPose(char)
        end
    end
end))

TrackConn(UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = GetHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

local function BindCharacterEvents(char)
    local hum = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if hum then
        if State.WalkSpeedLocked then hum.WalkSpeed = State.WalkSpeed end
        if State.JumpPowerLocked then
            hum.UseJumpPower = true
            hum.JumpPower = State.JumpPower
        end
        hum.Died:Connect(function()
            if root then
                State.LastDeathCFrame = root.CFrame
            end
        end)
    end
    if State.AutoRespawnSpot and State.LastDeathCFrame and root then
        task.wait(0.2)
        root.CFrame = State.LastDeathCFrame
    end
    task.defer(function()
        task.wait(0.15)
        if State.ClientHeadless then ApplyClientHeadless(true) end
        if State.ClientHeadlessHorseman then ApplyClientHeadlessHorseman(true) end
        if State.ClientKorblox then ApplyClientKorblox(true) end
    end)
end

if LocalPlayer.Character then
    task.spawn(BindCharacterEvents, LocalPlayer.Character)
end
TrackConn(LocalPlayer.CharacterAdded:Connect(BindCharacterEvents))

--// =========================================================================
--// OBSIDIAN CYBER-ANIME RICH TABBED GUI (NO PLAIN CHAT BAR!)
--// =========================================================================
local Themes = {
    CRIMSON = {
        Accent = Color3.fromRGB(220, 38, 68),
        AccentSoft = Color3.fromRGB(48, 20, 28),
        Secondary = Color3.fromRGB(56, 189, 248),
    },
    CYAN = {
        Accent = Color3.fromRGB(14, 165, 233),
        AccentSoft = Color3.fromRGB(18, 42, 58),
        Secondary = Color3.fromRGB(244, 63, 94),
    },
    EMERALD = {
        Accent = Color3.fromRGB(16, 185, 129),
        AccentSoft = Color3.fromRGB(18, 48, 38),
        Secondary = Color3.fromRGB(56, 189, 248),
    },
    VIOLET = {
        Accent = Color3.fromRGB(168, 85, 247),
        AccentSoft = Color3.fromRGB(42, 24, 62),
        Secondary = Color3.fromRGB(236, 72, 153),
    },
    MONO = {
        Accent = Color3.fromRGB(228, 228, 235),
        AccentSoft = Color3.fromRGB(38, 38, 46),
        Secondary = Color3.fromRGB(161, 161, 170),
    },
}

local Palette = {
    BgMain     = Color3.fromRGB(10, 10, 14),
    BgPanel    = Color3.fromRGB(17, 17, 23),
    BgCard     = Color3.fromRGB(24, 24, 33),
    BgInput    = Color3.fromRGB(14, 14, 20),
    Stroke     = Color3.fromRGB(50, 52, 68),
    Accent     = Themes.CRIMSON.Accent,
    AccentSoft = Themes.CRIMSON.AccentSoft,
    Cyan       = Themes.CRIMSON.Secondary,
    Green      = Color3.fromRGB(34, 197, 94),
    TextMain   = Color3.fromRGB(244, 244, 248),
    TextMuted  = Color3.fromRGB(154, 158, 176),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChelseaaSystemV10"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

local function AddCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function AddStroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Palette.Stroke
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

-- Floating Minimize Bubble
local ToggleBubble = Instance.new("TextButton")
ToggleBubble.Name = "ToggleBubble"
ToggleBubble.Size = UDim2.new(0, 50, 0, 50)
ToggleBubble.Position = UDim2.new(0, 16, 0.5, -25)
ToggleBubble.BackgroundColor3 = Palette.BgMain
ToggleBubble.Text = "CS"
ToggleBubble.Font = Enum.Font.GothamBlack
ToggleBubble.TextSize = 15
ToggleBubble.TextColor3 = Palette.Accent
ToggleBubble.Visible = false
ToggleBubble.Parent = ScreenGui
AddCorner(ToggleBubble, 25)
local BubbleStroke = AddStroke(ToggleBubble, Palette.Accent, 1.6)

-- Floating Bubble Custom Image Overlay
local BubbleImage = Instance.new("ImageLabel")
BubbleImage.Name = "BubbleImage"
BubbleImage.Size = UDim2.new(1, 0, 1, 0)
BubbleImage.BackgroundTransparency = 1
BubbleImage.Image = ""
BubbleImage.ScaleType = Enum.ScaleType.Crop
BubbleImage.Parent = ToggleBubble
AddCorner(BubbleImage, 25)

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 395)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -197)
MainFrame.BackgroundColor3 = Palette.BgMain
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
AddCorner(MainFrame, 12)
local MainStroke = AddStroke(MainFrame, Palette.Stroke, 1.3)

-- Custom Wallpaper Image inside Menu UI (https://files.catbox.moe/5kbgpx.jpg)
local MenuWallpaper = Instance.new("ImageLabel")
MenuWallpaper.Name = "MenuWallpaper"
MenuWallpaper.Size = UDim2.new(1, 0, 1, 0)
MenuWallpaper.Position = UDim2.new(0, 0, 0, 0)
MenuWallpaper.BackgroundTransparency = 1
MenuWallpaper.Image = ""
MenuWallpaper.ImageTransparency = 0.45
MenuWallpaper.ScaleType = Enum.ScaleType.Crop
MenuWallpaper.ZIndex = 0
MenuWallpaper.Parent = MainFrame
AddCorner(MenuWallpaper, 12)

-- Top Header Bar
local Topbar = Instance.new("Frame")
Topbar.Name = "Topbar"
Topbar.Size = UDim2.new(1, 0, 0, 42)
Topbar.BackgroundColor3 = Palette.BgPanel
Topbar.BackgroundTransparency = 0.15
Topbar.Parent = MainFrame
AddCorner(Topbar, 12)

local BrandBadge = Instance.new("TextLabel")
BrandBadge.Size = UDim2.new(0, 36, 0, 24)
BrandBadge.Position = UDim2.new(0, 10, 0.5, -12)
BrandBadge.BackgroundColor3 = Palette.Accent
BrandBadge.Text = "V10"
BrandBadge.Font = Enum.Font.GothamBlack
BrandBadge.TextSize = 11
BrandBadge.TextColor3 = Palette.BgMain
BrandBadge.Parent = Topbar
AddCorner(BrandBadge, 6)

local HeaderAvatar = Instance.new("ImageLabel")
HeaderAvatar.Name = "HeaderAvatar"
HeaderAvatar.Size = UDim2.new(0, 28, 0, 28)
HeaderAvatar.Position = UDim2.new(0, 52, 0.5, -14)
HeaderAvatar.BackgroundColor3 = Palette.BgCard
HeaderAvatar.Image = ""
HeaderAvatar.ScaleType = Enum.ScaleType.Crop
HeaderAvatar.Parent = Topbar
AddCorner(HeaderAvatar, 6)
AddStroke(HeaderAvatar, Palette.Accent, 1)

task.spawn(function()
    local customAsset = LoadCustomMenuImage(State.CustomMenuImageUrl, "chelseaa_v10_5kbgpx.jpg")
    if customAsset ~= "" then
        MenuWallpaper.Image = customAsset
        HeaderAvatar.Image = customAsset
        BubbleImage.Image = customAsset
        ToggleBubble.Text = ""
    end
end)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -168, 1, 0)
TitleLabel.Position = UDim2.new(0, 88, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "CHELSEAA SYSTEM  |  5,101 FEATURES HUB"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextColor3 = Palette.TextMain
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Topbar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinBtn.BackgroundColor3 = Palette.BgCard
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.TextColor3 = Palette.TextMain
MinBtn.Parent = Topbar
AddCorner(MinBtn, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Palette.AccentSoft
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Palette.Accent
CloseBtn.Parent = Topbar
AddCorner(CloseBtn, 6)

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    ToggleBubble.Visible = true
end)

ToggleBubble.MouseButton1Click:Connect(function()
    ToggleBubble.Visible = false
    MainFrame.Visible = true
end)

CloseBtn.MouseButton1Click:Connect(function()
    State.AutoTrainEnabled = false
    State.WalkSpeedLocked = false
    State.AutoClickerCenter = false
    State.AutoPrompts = false
    State.SpinSpeed = 0
    StopActiveTween()
    ClearAllSpawnedPlatforms()
    if AirPlatformPart then AirPlatformPart:Destroy() end
    for _, c in ipairs(ActiveConnections) do
        pcall(function() c:Disconnect() end)
    end
    ScreenGui:Destroy()
end)

-- Drag Support (Touch & Mouse)
local function EnableDrag(handle, target)
    local dragging = false
    local dragInput, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    TrackConn(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))
end

EnableDrag(Topbar, MainFrame)
EnableDrag(ToggleBubble, ToggleBubble)

-- 5 Rich Category Navigation Tabs
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 34)
TabBar.Position = UDim2.new(0, 10, 0, 48)
TabBar.BackgroundColor3 = Palette.BgPanel
TabBar.BackgroundTransparency = 0.15
TabBar.Parent = MainFrame
AddCorner(TabBar, 8)
AddStroke(TabBar, Palette.Stroke, 1)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 4)
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Parent = TabBar

local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -20, 1, -124)
PagesContainer.Position = UDim2.new(0, 10, 0, 88)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

-- Sleek Telemetry & Status Footer Bar (Replaces plain chat box!)
local FooterBar = Instance.new("Frame")
FooterBar.Size = UDim2.new(1, -20, 0, 26)
FooterBar.Position = UDim2.new(0, 10, 1, -32)
FooterBar.BackgroundColor3 = Palette.BgPanel
FooterBar.BackgroundTransparency = 0.15
FooterBar.Parent = MainFrame
AddCorner(FooterBar, 7)
AddStroke(FooterBar, Palette.Stroke, 1)

local TelemetryLabel = Instance.new("TextLabel")
TelemetryLabel.Size = UDim2.new(1, -16, 1, 0)
TelemetryLabel.Position = UDim2.new(0, 10, 0, 0)
TelemetryLabel.BackgroundTransparency = 1
TelemetryLabel.Text = "MADE BY CHELSEAA  |  5,101 Features Active"
TelemetryLabel.Font = Enum.Font.GothamBold
TelemetryLabel.TextSize = 10
TelemetryLabel.TextColor3 = Palette.Cyan
TelemetryLabel.TextXAlignment = Enum.TextXAlignment.Left
TelemetryLabel.Parent = FooterBar

-- Tab Builder
local Tabs = {}
local Pages = {}
local ActiveTabName = "Movement"

local function CreatePage(name, labelText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.192, 0, 0, 25)
    btn.BackgroundColor3 = Palette.BgCard
    btn.Text = labelText
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Palette.TextMuted
    btn.Parent = TabBar
    AddCorner(btn, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Palette.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.Parent = PagesContainer

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    Tabs[name] = btn
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        ActiveTabName = name
        for k, p in pairs(Pages) do
            p.Visible = (k == name)
            Tabs[k].BackgroundColor3 = (k == name) and Palette.Accent or Palette.BgCard
            Tabs[k].TextColor3 = (k == name) and (Palette.Accent == Themes.MONO.Accent and Palette.BgMain or Palette.TextMain) or Palette.TextMuted
        end
    end)

    return page
end

local PageMove   = CreatePage("Movement", "Speed & Tween")
local PageTrain  = CreatePage("Train",    "Auto Train")
local PageVisual = CreatePage("Visual",   "Visual & World")
local PageNew100 = CreatePage("New100",   "100 New FX")
local PageAll    = CreatePage("All5100",  "All 5,100")

Pages["Movement"].Visible = true
Tabs["Movement"].BackgroundColor3 = Palette.Accent
Tabs["Movement"].TextColor3 = Palette.TextMain

ApplyUITheme = function(themeKey)
    local th = Themes[themeKey] or Themes.CRIMSON
    Palette.Accent = th.Accent
    Palette.AccentSoft = th.AccentSoft
    Palette.Cyan = th.Secondary
    BrandBadge.BackgroundColor3 = th.Accent
    ToggleBubble.TextColor3 = th.Accent
    BubbleStroke.Color = th.Accent
    CloseBtn.BackgroundColor3 = th.AccentSoft
    CloseBtn.TextColor3 = th.Accent
    TelemetryLabel.TextColor3 = th.Secondary
    for k, btn in pairs(Tabs) do
        btn.BackgroundColor3 = (k == ActiveTabName) and th.Accent or Palette.BgCard
        btn.TextColor3 = (k == ActiveTabName) and (themeKey == "MONO" and Palette.BgMain or Palette.TextMain) or Palette.TextMuted
    end
end

-- Widget Helpers
local function CreateCard(parent, titleText, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, height)
    card.BackgroundColor3 = Palette.BgPanel
    card.BackgroundTransparency = 0.18
    card.Parent = parent
    AddCorner(card, 8)
    AddStroke(card, Palette.Stroke, 1)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 22)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextColor3 = Palette.TextMain
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    return card
end

local function CreateToggleButton(parent, pos, size, text, initialState, onToggle)
    local btn = Instance.new("TextButton")
    btn.Position = pos
    btn.Size = size
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = parent
    AddCorner(btn, 6)

    local stateVal = initialState
    local function Refresh()
        btn.BackgroundColor3 = stateVal and Palette.Green or Palette.BgCard
        btn.TextColor3 = stateVal and Palette.BgMain or Palette.TextMain
        btn.Text = text .. (stateVal and ": ON" or ": OFF")
    end
    Refresh()

    btn.MouseButton1Click:Connect(function()
        stateVal = not stateVal
        Refresh()
        onToggle(stateVal)
    end)

    return btn
end

--// =========================================================================
--// TAB 1: WALKSPEED, PHYSICS & DYNAMIC TWEEN SPEED
--// =========================================================================
local WsCard = CreateCard(PageMove, "WALKSPEED & MOVEMENT LOCK (ANTI-RESET)", 148)

local WsInput = Instance.new("TextBox")
WsInput.Size = UDim2.new(0, 100, 0, 28)
WsInput.Position = UDim2.new(0, 10, 0, 32)
WsInput.BackgroundColor3 = Palette.BgInput
WsInput.Text = tostring(State.WalkSpeed)
WsInput.PlaceholderText = "16 - 5000"
WsInput.Font = Enum.Font.GothamBold
WsInput.TextSize = 12
WsInput.TextColor3 = Palette.Cyan
WsInput.Parent = WsCard
AddCorner(WsInput, 6)
AddStroke(WsInput, Palette.Stroke, 1)

local ApplyWsBtn = Instance.new("TextButton")
ApplyWsBtn.Size = UDim2.new(0, 76, 0, 28)
ApplyWsBtn.Position = UDim2.new(0, 116, 0, 32)
ApplyWsBtn.BackgroundColor3 = Palette.Accent
ApplyWsBtn.Text = "SET WS"
ApplyWsBtn.Font = Enum.Font.GothamBold
ApplyWsBtn.TextSize = 10
ApplyWsBtn.TextColor3 = Palette.TextMain
ApplyWsBtn.Parent = WsCard
AddCorner(ApplyWsBtn, 6)

CreateToggleButton(WsCard, UDim2.new(0, 198, 0, 32), UDim2.new(0, 106, 0, 28), "WS Lock", State.WalkSpeedLocked, function(v)
    State.WalkSpeedLocked = v
end)

CreateToggleButton(WsCard, UDim2.new(0, 310, 0, 32), UDim2.new(0, 102, 0, 28), "Noclip", State.Noclip, function(v)
    State.Noclip = v
end)

CreateToggleButton(WsCard, UDim2.new(0, 418, 0, 32), UDim2.new(0, 106, 0, 28), "Inf Jump", State.InfiniteJump, function(v)
    State.InfiniteJump = v
end)

local function SetWalkSpeedValue(val)
    local num = tonumber(val)
    if not num then return end
    num = math.clamp(num, 1, 5000)
    State.WalkSpeed = num
    State.WalkSpeedLocked = true
    WsInput.Text = tostring(num)
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = num end
    SetStatus("WalkSpeed locked at " .. num)
end

ApplyWsBtn.MouseButton1Click:Connect(function()
    SetWalkSpeedValue(WsInput.Text)
end)

local WsPresets = { 16, 50, 100, 250, 500, 1000 }
for i, spd in ipairs(WsPresets) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0, 80, 0, 26)
    pBtn.Position = UDim2.new(0, 10 + (i - 1) * 86, 0, 70)
    pBtn.BackgroundColor3 = Palette.BgCard
    pBtn.Text = "WS " .. spd
    pBtn.Font = Enum.Font.GothamBold
    pBtn.TextSize = 10
    pBtn.TextColor3 = Palette.TextMain
    pBtn.Parent = WsCard
    AddCorner(pBtn, 6)

    pBtn.MouseButton1Click:Connect(function()
        SetWalkSpeedValue(spd)
    end)
end

CreateToggleButton(WsCard, UDim2.new(0, 10, 0, 106), UDim2.new(0, 122, 0, 28), "Smooth Fly", State.Fly, function(v)
    State.Fly = v
end)
CreateToggleButton(WsCard, UDim2.new(0, 138, 0, 106), UDim2.new(0, 124, 0, 28), "Air Walk", State.AirWalk, function(v)
    State.AirWalk = v
end)
CreateToggleButton(WsCard, UDim2.new(0, 268, 0, 106), UDim2.new(0, 124, 0, 28), "Anti-Fling", State.AntiFling, function(v)
    State.AntiFling = v
end)
CreateToggleButton(WsCard, UDim2.new(0, 398, 0, 106), UDim2.new(0, 126, 0, 28), "Bunny Hop", State.BunnyHop, function(v)
    State.BunnyHop = v
end)

-- Dynamic Tween Speed & Waypoint Slots Card
local TwCard = CreateCard(PageMove, "DYNAMIC TWEEN SPEED & WAYPOINTS (SPEED-DEPENDENT)", 152)

local TwInput = Instance.new("TextBox")
TwInput.Size = UDim2.new(0, 100, 0, 28)
TwInput.Position = UDim2.new(0, 10, 0, 32)
TwInput.BackgroundColor3 = Palette.BgInput
TwInput.Text = tostring(State.TweenSpeed)
TwInput.PlaceholderText = "Studs/Sec"
TwInput.Font = Enum.Font.GothamBold
TwInput.TextSize = 12
TwInput.TextColor3 = Palette.Cyan
TwInput.Parent = TwCard
AddCorner(TwInput, 6)
AddStroke(TwInput, Palette.Stroke, 1)

local ApplyTwBtn = Instance.new("TextButton")
ApplyTwBtn.Size = UDim2.new(0, 86, 0, 28)
ApplyTwBtn.Position = UDim2.new(0, 116, 0, 32)
ApplyTwBtn.BackgroundColor3 = Palette.Accent
ApplyTwBtn.Text = "SET TWEEN"
ApplyTwBtn.Font = Enum.Font.GothamBold
ApplyTwBtn.TextSize = 10
ApplyTwBtn.TextColor3 = Palette.TextMain
ApplyTwBtn.Parent = TwCard
AddCorner(ApplyTwBtn, 6)

CreateToggleButton(TwCard, UDim2.new(0, 208, 0, 32), UDim2.new(0, 148, 0, 28), "Sync = 2x WS", State.SyncTweenToWalkSpeed, function(v)
    State.SyncTweenToWalkSpeed = v
end)

local StopTwBtn = Instance.new("TextButton")
StopTwBtn.Size = UDim2.new(0, 160, 0, 28)
StopTwBtn.Position = UDim2.new(0, 362, 0, 32)
StopTwBtn.BackgroundColor3 = Palette.AccentSoft
StopTwBtn.Text = "STOP ACTIVE TWEEN"
StopTwBtn.Font = Enum.Font.GothamBold
StopTwBtn.TextSize = 10
StopTwBtn.TextColor3 = Palette.Accent
StopTwBtn.Parent = TwCard
AddCorner(StopTwBtn, 6)

ApplyTwBtn.MouseButton1Click:Connect(function()
    local num = tonumber(TwInput.Text)
    if num then
        State.TweenSpeed = math.clamp(num, 10, 15000)
        State.SyncTweenToWalkSpeed = false
        TwInput.Text = tostring(State.TweenSpeed)
        SetStatus("Tween Speed set to " .. State.TweenSpeed .. " studs/sec")
    end
end)

StopTwBtn.MouseButton1Click:Connect(function()
    StopActiveTween()
    SetStatus("Tween movement cancelled")
end)

-- Waypoint Slot 1 & Quick Tween Actions
local SaveWp1 = Instance.new("TextButton")
SaveWp1.Size = UDim2.new(0, 122, 0, 28)
SaveWp1.Position = UDim2.new(0, 10, 0, 70)
SaveWp1.BackgroundColor3 = Palette.BgCard
SaveWp1.Text = "Save Slot 1"
SaveWp1.Font = Enum.Font.GothamBold
SaveWp1.TextSize = 10
SaveWp1.TextColor3 = Palette.TextMain
SaveWp1.Parent = TwCard
AddCorner(SaveWp1, 6)

local GoWp1 = Instance.new("TextButton")
GoWp1.Size = UDim2.new(0, 124, 0, 28)
GoWp1.Position = UDim2.new(0, 138, 0, 70)
GoWp1.BackgroundColor3 = Palette.BgCard
GoWp1.Text = "Tween Slot 1"
GoWp1.Font = Enum.Font.GothamBold
GoWp1.TextSize = 10
GoWp1.TextColor3 = Palette.Cyan
GoWp1.Parent = TwCard
AddCorner(GoWp1, 6)

local TweenUpBtn = Instance.new("TextButton")
TweenUpBtn.Size = UDim2.new(0, 124, 0, 28)
TweenUpBtn.Position = UDim2.new(0, 268, 0, 70)
TweenUpBtn.BackgroundColor3 = Palette.BgCard
TweenUpBtn.Text = "Tween Up +100"
TweenUpBtn.Font = Enum.Font.GothamBold
TweenUpBtn.TextSize = 10
TweenUpBtn.TextColor3 = Palette.TextMain
TweenUpBtn.Parent = TwCard
AddCorner(TweenUpBtn, 6)

local TweenNearBtn = Instance.new("TextButton")
TweenNearBtn.Size = UDim2.new(0, 126, 0, 28)
TweenNearBtn.Position = UDim2.new(0, 398, 0, 70)
TweenNearBtn.BackgroundColor3 = Palette.BgCard
TweenNearBtn.Text = "Tween Nearest"
TweenNearBtn.Font = Enum.Font.GothamBold
TweenNearBtn.TextSize = 10
TweenNearBtn.TextColor3 = Palette.TextMain
TweenNearBtn.Parent = TwCard
AddCorner(TweenNearBtn, 6)

SaveWp1.MouseButton1Click:Connect(function()
    local root = GetRootPart()
    if root then
        State.Waypoints[1] = root.CFrame
        SetStatus("Saved Waypoint Slot 1")
    end
end)
GoWp1.MouseButton1Click:Connect(function()
    if State.Waypoints[1] then TweenToCFrame(State.Waypoints[1]) end
end)
TweenUpBtn.MouseButton1Click:Connect(function()
    local root = GetRootPart()
    if root then TweenToCFrame(root.CFrame + Vector3.new(0, 100, 0)) end
end)
TweenNearBtn.MouseButton1Click:Connect(function()
    CommandLookup["tween to nearest player"].run()
end)

-- Tween Speed Quick Presets
local TwPresets = { 100, 250, 500, 800, 1200, 1500 }
for i, tspd in ipairs(TwPresets) do
    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(0, 80, 0, 26)
    tBtn.Position = UDim2.new(0, 10 + (i - 1) * 86, 0, 108)
    tBtn.BackgroundColor3 = Palette.BgCard
    tBtn.Text = "TW " .. tspd
    tBtn.Font = Enum.Font.GothamBold
    tBtn.TextSize = 10
    tBtn.TextColor3 = Palette.TextMain
    tBtn.Parent = TwCard
    AddCorner(tBtn, 6)

    tBtn.MouseButton1Click:Connect(function()
        State.TweenSpeed = tspd
        State.SyncTweenToWalkSpeed = false
        TwInput.Text = tostring(tspd)
        SetStatus("Tween Speed set to " .. tspd)
    end)
end

--// =========================================================================
--// TAB 2: AUTO TRAIN CURSOR (1x, 2x, 2.30x, 3x, 4x) & AUTOMATION
--// =========================================================================
local TrainCard = CreateCard(PageTrain, "AUTO TRAIN CURSOR PRECISION (1x / 2x / 2.30x / 3x / 4x)", 230)

local TrainStatusLabel = Instance.new("TextLabel")
TrainStatusLabel.Size = UDim2.new(1, -20, 0, 20)
TrainStatusLabel.Position = UDim2.new(0, 10, 0, 30)
TrainStatusLabel.BackgroundTransparency = 1
TrainStatusLabel.Text = "Cursor Status: IDLE  |  Last Hit: None  |  Clicks: 0"
TrainStatusLabel.Font = Enum.Font.GothamBold
TrainStatusLabel.TextSize = 11
TrainStatusLabel.TextColor3 = Palette.Cyan
TrainStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
TrainStatusLabel.Parent = TrainCard

CreateToggleButton(TrainCard, UDim2.new(0, 10, 0, 56), UDim2.new(0, 168, 0, 30), "Auto Train Cursor", State.AutoTrainEnabled, function(v)
    State.AutoTrainEnabled = v
end)

CreateToggleButton(TrainCard, UDim2.new(0, 184, 0, 56), UDim2.new(0, 168, 0, 30), "Center Clicker", State.AutoClickerCenter, function(v)
    State.AutoClickerCenter = v
end)

CreateToggleButton(TrainCard, UDim2.new(0, 358, 0, 56), UDim2.new(0, 166, 0, 30), "Auto Prompts", State.AutoPrompts, function(v)
    State.AutoPrompts = v
end)

local FilterLabel = Instance.new("TextLabel")
FilterLabel.Size = UDim2.new(1, -20, 0, 18)
FilterLabel.Position = UDim2.new(0, 10, 0, 96)
FilterLabel.BackgroundTransparency = 1
FilterLabel.Text = "Multiplier Target Filter:"
FilterLabel.Font = Enum.Font.GothamBold
FilterLabel.TextSize = 10
FilterLabel.TextColor3 = Palette.TextMuted
FilterLabel.TextXAlignment = Enum.TextXAlignment.Left
FilterLabel.Parent = TrainCard

local FilterOptions = {
    { id = "2X_PLUS",  label = "2x+ (2x/2.30x/3x/4x)" },
    { id = "ALL",      label = "All (1x - 4x)" },
    { id = "MAX_ONLY", label = "High (2.30x/3x/4x)" },
    { id = "2X_ONLY",  label = "2x / 2.30x Only" },
}

local FilterBtns = {}
for i, opt in ipairs(FilterOptions) do
    local fBtn = Instance.new("TextButton")
    fBtn.Size = UDim2.new(0, 124, 0, 28)
    fBtn.Position = UDim2.new(0, 10 + (i - 1) * 129, 0, 116)
    fBtn.BackgroundColor3 = (State.AutoTrainFilter == opt.id) and Palette.Accent or Palette.BgCard
    fBtn.Text = opt.label
    fBtn.Font = Enum.Font.GothamBold
    fBtn.TextSize = 10
    fBtn.TextColor3 = Palette.TextMain
    fBtn.Parent = TrainCard
    AddCorner(fBtn, 6)
    FilterBtns[opt.id] = fBtn

    fBtn.MouseButton1Click:Connect(function()
        State.AutoTrainFilter = opt.id
        for k, b in pairs(FilterBtns) do
            b.BackgroundColor3 = (k == opt.id) and Palette.Accent or Palette.BgCard
        end
    end)
end

local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(1, -20, 0, 18)
ModeLabel.Position = UDim2.new(0, 10, 0, 154)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "Cursor Precision Mode:"
ModeLabel.Font = Enum.Font.GothamBold
ModeLabel.TextSize = 10
ModeLabel.TextColor3 = Palette.TextMuted
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ModeLabel.Parent = TrainCard

local ModeOptions = {
    { id = "SMART",       label = "Smart Auto (Bar + Popup)" },
    { id = "BAR_ALIGN",   label = "Bar Needle Alignment" },
    { id = "POPUP_CLICK", label = "Direct Cursor Tap" },
}

local ModeBtns = {}
for i, mOpt in ipairs(ModeOptions) do
    local mBtn = Instance.new("TextButton")
    mBtn.Size = UDim2.new(0, 166, 0, 30)
    mBtn.Position = UDim2.new(0, 10 + (i - 1) * 172, 0, 174)
    mBtn.BackgroundColor3 = (State.AutoTrainMode == mOpt.id) and Palette.Accent or Palette.BgCard
    mBtn.Text = mOpt.label
    mBtn.Font = Enum.Font.GothamBold
    mBtn.TextSize = 10
    mBtn.TextColor3 = Palette.TextMain
    mBtn.Parent = TrainCard
    AddCorner(mBtn, 6)
    ModeBtns[mOpt.id] = mBtn

    mBtn.MouseButton1Click:Connect(function()
        State.AutoTrainMode = mOpt.id
        for k, b in pairs(ModeBtns) do
            b.BackgroundColor3 = (k == mOpt.id) and Palette.Accent or Palette.BgCard
        end
    end)
end

--// =========================================================================
--// TAB 3: VISUAL, ESP, CAMERA & WORLD CONTROLS
--// =========================================================================
local VisCard = CreateCard(PageVisual, "ESP, HEADLESS HORSEMAN, KORBLOX & WORLD SHADERS", 296)

CreateToggleButton(VisCard, UDim2.new(0, 10, 0, 32), UDim2.new(0, 166, 0, 28), "Player ESP", State.PlayerESP, function(v)
    UpdatePlayerESP(v)
end)
CreateToggleButton(VisCard, UDim2.new(0, 184, 0, 32), UDim2.new(0, 166, 0, 28), "X-Ray Walls", State.XRayActive, function(v)
    SetXRayWalls(v)
end)
CreateToggleButton(VisCard, UDim2.new(0, 358, 0, 32), UDim2.new(0, 166, 0, 28), "Rainbow Body", State.RainbowChar, function(v)
    State.RainbowChar = v
end)

local QuickVisualCmds = {
    "Client Headless Horseman ON",
    "Client Headless Horseman OFF",
    "Client Headless ON",
    "Client Headless OFF",
    "Client Korblox ON",
    "Client Korblox OFF",
    "Fullbright Max",
    "Midnight Obsidian Sky",
    "Cyber Crimson Shader",
    "Golden Sunset Shader",
    "FPS Booster LowGFX",
    "Restore Default Lighting",
    "Camera FOV 70 (Default)",
    "Camera FOV 105 (Pro)",
    "Camera FOV 120 (Ultra)",
    "Unlock Zoom 5000 Studs",
    "Spectate Nearest Player",
    "Reset Camera to Self",
}

for idx, cmdName in ipairs(QuickVisualCmds) do
    local col = (idx - 1) % 3
    local row = math.floor((idx - 1) / 3)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 166, 0, 28)
    b.Position = UDim2.new(0, 10 + col * 172, 0, 72 + row * 34)
    b.BackgroundColor3 = Palette.BgCard
    b.Text = cmdName
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextColor3 = Palette.TextMain
    b.Parent = VisCard
    AddCorner(b, 6)

    b.MouseButton1Click:Connect(function()
        local entry = CommandLookup[string.lower(cmdName)]
        if entry then pcall(entry.run) end
    end)
end

--// =========================================================================
--// TAB 4: 100 NEW INTERESTING FEATURES SHOWCASE (FILTERABLE INTERACTIVE LIST)
--// =========================================================================
local NewFilterBar = Instance.new("Frame")
NewFilterBar.Size = UDim2.new(1, -6, 0, 32)
NewFilterBar.BackgroundColor3 = Palette.BgPanel
NewFilterBar.Parent = PageNew100
AddCorner(NewFilterBar, 8)
AddStroke(NewFilterBar, Palette.Stroke, 1)

local NewSubCats = { "ALL", "Visual/ESP", "Camera", "Physics/Fun", "Tween/Waypoints", "Automation", "Character/UI" }
local NewCatBtns = {}
local NewFeatureRows = {}

local function RenderNew100List()
    local shown = 0
    for _, item in ipairs(NewFeatureRows) do
        local match = (State.NewFeatureFilter == "ALL") or (item.cmd.subTag == State.NewFeatureFilter)
        item.btn.Visible = match
        if match then shown = shown + 1 end
    end
end

for i, sub in ipairs(NewSubCats) do
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0, 72, 0, 22)
    cb.Position = UDim2.new(0, 6 + (i - 1) * 75, 0.5, -11)
    cb.BackgroundColor3 = (sub == "ALL") and Palette.Accent or Palette.BgCard
    cb.Text = (sub == "Tween/Waypoints") and "Waypoints" or sub
    cb.Font = Enum.Font.GothamBold
    cb.TextSize = 9
    cb.TextColor3 = Palette.TextMain
    cb.Parent = NewFilterBar
    AddCorner(cb, 5)
    NewCatBtns[sub] = cb

    cb.MouseButton1Click:Connect(function()
        State.NewFeatureFilter = sub
        for k, b in pairs(NewCatBtns) do
            b.BackgroundColor3 = (k == sub) and Palette.Accent or Palette.BgCard
        end
        RenderNew100List()
    end)
end

for _, cmd in ipairs(New100Features) do
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -6, 0, 30)
    row.BackgroundColor3 = Palette.BgPanel
    row.Text = ""
    row.AutoButtonColor = true
    row.Parent = PageNew100
    AddCorner(row, 6)
    AddStroke(row, Palette.Stroke, 1)

    local tagBadge = Instance.new("TextLabel")
    tagBadge.Size = UDim2.new(0, 92, 0, 20)
    tagBadge.Position = UDim2.new(0, 6, 0.5, -10)
    tagBadge.BackgroundColor3 = Palette.AccentSoft
    tagBadge.Text = cmd.subTag
    tagBadge.Font = Enum.Font.GothamBold
    tagBadge.TextSize = 9
    tagBadge.TextColor3 = Palette.Accent
    tagBadge.Parent = row
    AddCorner(tagBadge, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -112, 1, 0)
    lbl.Position = UDim2.new(0, 104, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("#%d  %s  —  %s", cmd.id, cmd.name, cmd.desc)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextColor3 = Palette.TextMain
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    row.MouseButton1Click:Connect(function()
        pcall(cmd.run)
    end)

    table.insert(NewFeatureRows, { btn = row, cmd = cmd })
end

--// =========================================================================
--// TAB 5: ALL 5,100 FEATURES BROWSER (PAGINATED + FILTER + SEARCH)
--// =========================================================================
local SearchRow = Instance.new("Frame")
SearchRow.Size = UDim2.new(1, -6, 0, 32)
SearchRow.BackgroundTransparency = 1
SearchRow.Parent = PageAll

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -172, 1, 0)
SearchBox.BackgroundColor3 = Palette.BgPanel
SearchBox.PlaceholderText = "Filter 5,101 features (e.g. ws500, tw1200, esp, fov, grav50)..."
SearchBox.Text = ""
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 11
SearchBox.TextColor3 = Palette.TextMain
SearchBox.PlaceholderColor3 = Palette.TextMuted
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = SearchRow
AddCorner(SearchBox, 6)
AddStroke(SearchBox, Palette.Stroke, 1)

local PrevPageBtn = Instance.new("TextButton")
PrevPageBtn.Size = UDim2.new(0, 42, 1, 0)
PrevPageBtn.Position = UDim2.new(1, -164, 0, 0)
PrevPageBtn.BackgroundColor3 = Palette.BgCard
PrevPageBtn.Text = "<"
PrevPageBtn.Font = Enum.Font.GothamBold
PrevPageBtn.TextSize = 13
PrevPageBtn.TextColor3 = Palette.TextMain
PrevPageBtn.Parent = SearchRow
AddCorner(PrevPageBtn, 6)

local PageInfoLabel = Instance.new("TextLabel")
PageInfoLabel.Size = UDim2.new(0, 74, 1, 0)
PageInfoLabel.Position = UDim2.new(1, -118, 0, 0)
PageInfoLabel.BackgroundTransparency = 1
PageInfoLabel.Text = "1 / 128"
PageInfoLabel.Font = Enum.Font.GothamBold
PageInfoLabel.TextSize = 11
PageInfoLabel.TextColor3 = Palette.Cyan
PageInfoLabel.Parent = SearchRow

local NextPageBtn = Instance.new("TextButton")
NextPageBtn.Size = UDim2.new(0, 42, 1, 0)
NextPageBtn.Position = UDim2.new(1, -42, 0, 0)
NextPageBtn.BackgroundColor3 = Palette.BgCard
NextPageBtn.Text = ">"
NextPageBtn.Font = Enum.Font.GothamBold
NextPageBtn.TextSize = 13
NextPageBtn.TextColor3 = Palette.TextMain
NextPageBtn.Parent = SearchRow
AddCorner(NextPageBtn, 6)

local CmdRows = {}
local RowBoundCmds = {}

for i = 1, State.ItemsPerPage do
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -6, 0, 28)
    row.BackgroundColor3 = Palette.BgPanel
    row.Text = ""
    row.AutoButtonColor = true
    row.Parent = PageAll
    AddCorner(row, 6)
    AddStroke(row, Palette.Stroke, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextColor3 = Palette.TextMain
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    row.MouseButton1Click:Connect(function()
        local bound = RowBoundCmds[i]
        if bound then
            pcall(bound.run)
        end
    end)

    CmdRows[i] = row
end

local FilteredCommands = Commands

local function RebuildFilteredCommands()
    local q = string.lower(string.gsub(State.SearchQuery, "%s+", ""))
    if q == "" then
        FilteredCommands = Commands
    else
        local res = {}
        for _, cmd in ipairs(Commands) do
            local nameClean = string.lower(string.gsub(cmd.name, "%s+", ""))
            local descClean = string.lower(string.gsub(cmd.desc, "%s+", ""))
            if string.find(nameClean, q, 1, true)
                or string.find(descClean, q, 1, true)
                or tostring(cmd.id) == q then
                res[#res + 1] = cmd
            end
        end
        FilteredCommands = res
    end
    State.CurrentPage = 1
end

local function RenderCommandPage()
    local total = #FilteredCommands
    local maxPage = math.max(1, math.ceil(total / State.ItemsPerPage))
    State.CurrentPage = math.clamp(State.CurrentPage, 1, maxPage)
    PageInfoLabel.Text = State.CurrentPage .. " / " .. maxPage

    local startIdx = (State.CurrentPage - 1) * State.ItemsPerPage + 1
    for i = 1, State.ItemsPerPage do
        local row = CmdRows[i]
        local cmd = FilteredCommands[startIdx + i - 1]
        RowBoundCmds[i] = cmd
        if cmd then
            row.Visible = true
            row.Label.Text = string.format("[#%d | %s] %s  -  %s", cmd.id, cmd.category, cmd.name, cmd.desc)
        else
            row.Visible = false
        end
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    State.SearchQuery = SearchBox.Text
    RebuildFilteredCommands()
    RenderCommandPage()
end)

PrevPageBtn.MouseButton1Click:Connect(function()
    if State.CurrentPage > 1 then
        State.CurrentPage = State.CurrentPage - 1
        RenderCommandPage()
    end
end)

NextPageBtn.MouseButton1Click:Connect(function()
    local maxPage = math.max(1, math.ceil(#FilteredCommands / State.ItemsPerPage))
    if State.CurrentPage < maxPage then
        State.CurrentPage = State.CurrentPage + 1
        RenderCommandPage()
    end
end)

RenderCommandPage()

-- Live Telemetry & Auto Train Status Updater
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        local st = State.AutoTrainEnabled and "ACTIVE" or "IDLE"
        TrainStatusLabel.Text = string.format(
            "Cursor Status: %s  |  Last Hit: %s  |  Clicks: %d",
            st,
            State.LastDetectedText,
            State.TrainClickCount
        )
        TelemetryLabel.Text = string.format(
            "WS: %d%s  |  Tween: %d  |  Train: %s  |  %s",
            State.WalkSpeed,
            State.WalkSpeedLocked and " (LOCK)" or "",
            GetEffectiveTweenSpeed(),
            st,
            State.StatusMessage
        )
        task.wait(0.25)
    end
end)
