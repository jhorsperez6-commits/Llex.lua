-- =========================================================================
-- ALEX HUB (ULTIMATE EDITION) - LIMPIO Y OPTIMIZADO
-- =========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end

local camera = workspace.CurrentCamera

-- KEYS PERMITIDAS: "gratis" o "Alex"
local KEY_GRATIS = "gratis"
local KEY_PERMANENTE = "Alex"
local archivoCacheLocal = "AlexHub_CacheSession_10h.txt"
local keyIngresada = ""

local function verificarCacheLocal()
    local autorizado = false
    pcall(function()
        if isfile and isfile(archivoCacheLocal) then
            local datosCache = HttpService:JSONDecode(readfile(archivoCacheLocal))
            if (os.time() - datosCache.timestamp) < 36000 then 
                autorizado = true
            end
        end
    end)
    return autorizado
end

local fovVisiblePreference = false
local fovRadius = 120
local autoShootEnabled = false
local autoShootAgresivoEnabled = false
local autoShootTargetPart = "Cabeza"
local teamCheckEnabled = true
local espEnabled = false
local espColor = Color3.fromRGB(255, 255, 255)
local espSettings = { Glow = true }
local KillAllEnabled = false
local hitboxEnabled = false
local hitboxInvisible = false
local hitboxSize = 3.5
local hitboxColor = Color3.fromRGB(255, 0, 0)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AlexHub_Overlays"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = player:WaitForChild("PlayerGui")

local espFolder = Instance.new("Folder")
espFolder.Name = "AlexESPFolder"
espFolder.Parent = screenGui

local COLORES_NEUTROS = {
    ["White"] = true, ["Medium stone grey"] = true, ["Medium Stone Grey"] = true,
    ["Really black"] = true, ["Really Black"] = true, ["Institutional white"] = true,
    ["Institutional White"] = true, ["Ghost grey"] = true, ["Ghost Grey"] = true,
}

local function esColorVerde(c)
    if typeof(c) ~= "Color3" then return false end
    return c.G >= 0.55 and c.G > c.R and c.G > c.B and (c.G - c.R) >= 0.15 and (c.G - c.B) >= 0.15
end

local marcaAliadoCache = {}
local MARCA_CACHE_TTL = 1.0

local function invalidarMarcaAliado(targetPlayer)
    if targetPlayer then marcaAliadoCache[targetPlayer] = nil end
end

local ATTRS_ALIADO = {
    "IsAlly","Ally","AllyMarker","isAlly","is_ally","ally",
    "Teammate","isTeammate","is_teammate","IsTeammate",
    "Friendly","isFriendly","IsFriendly","is_friendly"
}

local function tieneMarcaAliado(targetPlayer)
    if not targetPlayer then return false end
    local now = os.clock()
    local cached = marcaAliadoCache[targetPlayer]
    if cached and (now - cached.time) < MARCA_CACHE_TTL then return cached.value end
    local resultado = false
    local char = targetPlayer.Character
    for _, attrName in ipairs(ATTRS_ALIADO) do
        local v1 = targetPlayer:GetAttribute(attrName)
        if v1 == true or v1 == "true" or v1 == "Ally" or v1 == "ally" then resultado = true; break end
        if char then
            local v2 = char:GetAttribute(attrName)
            if v2 == true or v2 == "true" or v2 == "Ally" or v2 == "ally" then resultado = true; break end
        end
    end
    marcaAliadoCache[targetPlayer] = { value = resultado, time = now }
    return resultado
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    if tieneMarcaAliado(targetPlayer) then return false end
    if not teamCheckEnabled then return true end
    local myColorName = player.TeamColor and player.TeamColor.Name or "White"
    local otherColorName = targetPlayer.TeamColor and targetPlayer.TeamColor.Name or "White"
    if not COLORES_NEUTROS[myColorName] and not COLORES_NEUTROS[otherColorName] then
        return player.TeamColor ~= targetPlayer.TeamColor
    end
    if player.Team and targetPlayer.Team then
        return player.Team ~= targetPlayer.Team
    end
    return true
end

local function esCompaneroDeEquipo(targetPlayer)
    if not targetPlayer or targetPlayer == player then return true end
    return not isEnemy(targetPlayer)
end

local function estaEnLobby()
    local char = player.Character
    if not char then return true end
    if char:FindFirstChildOfClass("ForceField") then return true end
    if player.Team then
        local tName = string.lower(player.Team.Name)
        if string.find(tName, "lobby") or string.find(tName, "spectat") or string.find(tName, "menu") or string.find(tName, "dead") then
            return true
        end
    end
    return false
end

local function IsInMatchStrict()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    local main = gui:FindFirstChild("Main") or gui
    local gameFrame = main:FindFirstChild("MainGameFrame")
    if not gameFrame or not gameFrame.Visible then return false end
    local score = gameFrame:FindFirstChild("IngameScore")
    local timer = score and score:FindFirstChild("Timer")
    if not timer then return false end
    local txt = tostring(timer.Text or ""):gsub("%s", "")
    return txt:match("^%d+:%d%d$") ~= nil
end

local function esEnemigoValido(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    if not isEnemy(targetPlayer) then return false end
    local char = targetPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end
    return true
end

local function esCuchillo(item)
    if not item or not item:IsA("Tool") then return false end
    if item:FindFirstChild("Slash") or item:FindFirstChild("SlashStart") then return true end
    local nombre = string.lower(item.Name)
    return string.find(nombre, "knife") or string.find(nombre, "cuchillo") or string.find(nombre, "dagger")
end

local function esPistola(item)
    if not item or not item:IsA("Tool") then return false end
    if esCuchillo(item) then return false end
    local nombre = string.lower(item.Name)
    local ignorar = {"combat", "fist", "wallet", "phone", "punch", "boombox", "radio", "knife", "blade", "cuchillo", "dagger", "sword"}
    for _, palabra in ipairs(ignorar) do if string.find(nombre, palabra) then return false end end
    return true
end

local function obtenerPistola()
    local char = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    if char then for _, item in ipairs(char:GetChildren()) do if esPistola(item) then return item end end end
    if backpack then for _, item in ipairs(backpack:GetChildren()) do if esPistola(item) then return item end end end
    return nil
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then p.CharacterAdded:Connect(function() invalidarMarcaAliado(p) end) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= player then p.CharacterAdded:Connect(function() invalidarMarcaAliado(p) end) end
end)
Players.PlayerRemoving:Connect(function(p) invalidarMarcaAliado(p) end)

local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager
function ConnectionManager.new() return setmetatable({ Items = {} }, ConnectionManager) end
function ConnectionManager:Add(task) self.Items[#self.Items + 1] = task; return task end
function ConnectionManager:Cleanup()
    for i = #self.Items, 1, -1 do
        local item = self.Items[i]
        self.Items[i] = nil
        local t = typeof(item)
        if t == "RBXScriptConnection" then pcall(function() item:Disconnect() end)
        elseif t == "Instance" then pcall(function() item:Destroy() end)
        elseif t == "function" then pcall(item) end
    end
end

local function limpiarHitboxes()
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        local character = targetPlayer.Character
        if character then
            local hitbox = character:FindFirstChild("GhostHitbox")
            if hitbox then hitbox:Destroy() end
        end
    end
end

task.spawn(function()
    while task.wait(0.2) do
        if not hitboxEnabled then continue end
        if not IsInMatchStrict() then
            limpiarHitboxes()
            continue
        end
        local tamanoObjetivo = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        local transObjetivo = hitboxInvisible and 1 or 0.6
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer ~= player and not esCompaneroDeEquipo(targetPlayer) and isEnemy(targetPlayer) then
                local character = targetPlayer.Character
                if character then
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if rootPart and humanoid and humanoid.Health > 0 then
                        local hitbox = character:FindFirstChild("GhostHitbox")
                        if not hitbox then
                            hitbox = Instance.new("Part")
                            hitbox.Name = "GhostHitbox"
                            hitbox.Size = tamanoObjetivo
                            hitbox.Transparency = transObjetivo
                            hitbox.Color = hitboxColor
                            hitbox.CanCollide = false
                            hitbox.Massless = true
                            hitbox.CanQuery = true
                            hitbox.CFrame = rootPart.CFrame
                            hitbox.Parent = character
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = rootPart
                            weld.Part1 = hitbox
                            weld.Parent = hitbox
                        else
                            if hitbox.Size ~= tamanoObjetivo then hitbox.Size = tamanoObjetivo end
                            if hitbox.Transparency ~= transObjetivo then hitbox.Transparency = transObjetivo end
                            if hitbox.Color ~= hitboxColor then hitbox.Color = hitboxColor end
                        end
                    else
                        local hitbox = character:FindFirstChild("GhostHitbox")
                        if hitbox then hitbox:Destroy() end
                    end
                end
            end
        end
    end
end)

local PadZoneConfig = {
    ["Right Platforms"] = {
        ["1v1"] = { ZoneName = "PadZone1", MainPad = "Pad1", AltPad = "Pad2" },
        ["2v2"] = { ZoneName = "PadZone2", MainPad = "Pad1", AltPad = "Pad2" },
        ["3v3"] = { ZoneName = "PadZone3", MainPad = "Pad1", AltPad = "Pad2" },
        ["4v4"] = { ZoneName = "PadZone4", MainPad = "Pad1", AltPad = "Pad2" }
    },
    ["Left Platforms"] = {
        ["1v1"] = { ZoneName = "PadZone5", MainPad = "Pad1", AltPad = "Pad2" },
        ["2v2"] = { ZoneName = "PadZone6", MainPad = "Pad1", AltPad = "Pad2" },
        ["3v3"] = { ZoneName = "PadZone7", MainPad = "Pad1", AltPad = "Pad2" },
        ["4v4"] = { ZoneName = "PadZone8", MainPad = "Pad1", AltPad = "Pad2" }
    }
}

AutoTeleportMainAlt = {}
AutoTeleportMainAlt.__index = AutoTeleportMainAlt
function AutoTeleportMainAlt.new()
    return setmetatable({
        Running = false, Connections = ConnectionManager.new(), Acc = 0, TickInterval = 0.5,
        ActiveRole = nil, DuelType = "1v1", PlatformRow = "Right Platforms",
        LastTeleport = 0, LastVote = 0, LastCancel = 0,
        TeleportCooldown = 0.5, VoteCooldown = 1, CancelCooldown = 1,
        VotedMap = nil, HighlightedPad = nil, PadColors = {}, ManualHold = false,
    }, AutoTeleportMainAlt)
end

function AutoTeleportMainAlt:GetActiveRole()
    if self.ActiveRole == "Main" then return "Main" end
    if self.ActiveRole == "Alt" then return "Alt" end
    return nil
end

function AutoTeleportMainAlt:GetRoot()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    return (root and root:IsA("BasePart")) and root or nil
end

function AutoTeleportMainAlt:GetHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

function AutoTeleportMainAlt:Attr(name)
    local v = player:GetAttribute(name)
    if typeof(v) == "string" and v ~= "" then return v end
    return nil
end

function AutoTeleportMainAlt:Snapshot()
    local gameAttr = self:Attr("Game")
    local mapAttr = self:Attr("Map")
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local alive = hum ~= nil and hum.Health > 0 and root ~= nil
    return { Game = gameAttr, Map = mapAttr, InGame = gameAttr ~= nil, InMap = gameAttr ~= nil and mapAttr ~= nil, Alive = alive }
end

function AutoTeleportMainAlt:IsOnMatch()
    local s = self:Snapshot()
    return s and s.InGame == true and s.InMap ~= true and s.Alive
end

function AutoTeleportMainAlt:ResolvePad(role)
    local rowConfig = PadZoneConfig[self.PlatformRow] or PadZoneConfig["Right Platforms"]
    local cfg = rowConfig[self.DuelType] or rowConfig["1v1"]
    local padZones = workspace:FindFirstChild("PadZones")
    if not padZones then return nil end
    local zone = padZones:FindFirstChild(cfg.ZoneName)
    if not zone then return nil end
    local padName = (role == "Alt") and cfg.AltPad or cfg.MainPad
    local holder = zone:FindFirstChild(padName)
    if not holder then return nil end
    local pad = holder:FindFirstChild("Pad")
    return (pad and pad:IsA("BasePart")) and pad or nil
end

function AutoTeleportMainAlt:IsOnPad(pad)
    if not pad then return false end
    local root = self:GetRoot()
    if not root then return false end
    local rel = pad.CFrame:PointToObjectSpace(root.Position)
    local half = pad.Size / 2
    return math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and rel.Y >= -(half.Y + 6) and rel.Y <= half.Y + 14
end

function AutoTeleportMainAlt:MarkPad(pad, isAlt)
    if not pad then self:UnmarkPad(); return end
    if self.HighlightedPad == pad then return end
    self:UnmarkPad()
    self.HighlightedPad = pad
    self.PadColors[pad] = { Color = pad.Color, Transparency = pad.Transparency }
    pcall(function()
        pad.Color = isAlt and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(70, 145, 255)
        pad.Transparency = 0.5
    end)
end

function AutoTeleportMainAlt:UnmarkPad()
    if self.HighlightedPad and self.PadColors[self.HighlightedPad] then
        local pad = self.HighlightedPad
        local saved = self.PadColors[pad]
        pcall(function()
            if pad.Parent then
                pad.Color = saved.Color
                pad.Transparency = saved.Transparency
            end
        end)
    end
    self.HighlightedPad = nil
end

function AutoTeleportMainAlt:FindVoteRemote()
    local pkgs = ReplicatedStorage:FindFirstChild("Packages")
    local net = pkgs and pkgs:FindFirstChild("Networking")
    return net and net:FindFirstChild("RF/Voting/Vote") or nil
end

function AutoTeleportMainAlt:FindVisibleMapVote()
    local pg = player:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local mv = main and main:FindFirstChild("MapVoting")
    local holder = mv and mv:FindFirstChild("VotingHolder")
    if not holder then return nil end
    for _, b in ipairs(holder:GetChildren()) do
        if b:IsA("ImageButton") and b.Visible and b.Name ~= "" then return b.Name end
    end
    return nil
end

function AutoTeleportMainAlt:VoteMap()
    local s = self:Snapshot()
    if not self:IsOnMatch() then return end
    if self.VotedMap == s.Game then return end
    local now = os.clock()
    if now - (self.LastVote or 0) < self.VoteCooldown then return end
    self.LastVote = now
    local target = self:FindVisibleMapVote()
    local rf = self:FindVoteRemote()
    if not (target and rf) then return end
    self.VotedMap = s.Game
    pcall(function() rf:InvokeServer(target) end)
end

function AutoTeleportMainAlt:FindSetStateRemote()
    local pkgs = ReplicatedStorage:FindFirstChild("Packages")
    local net = pkgs and pkgs:FindFirstChild("Networking")
    return net and net:FindFirstChild("RE/Match/SetStatePlr") or nil
end

function AutoTeleportMainAlt:CancelQueue()
    local now = os.clock()
    if now - (self.LastCancel or 0) < self.CancelCooldown then return end
    local ev = self:FindSetStateRemote()
    if not ev then return end
    self.LastCancel = now
    pcall(function() ev:FireServer("REMOVE") end)
end

function AutoTeleportMainAlt:HideGameFrame()
    local pg = player:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local mgf = main and main:FindFirstChild("MainGameFrame")
    if mgf and mgf:IsA("GuiObject") then pcall(function() mgf.Visible = false end) end
end

function AutoTeleportMainAlt:HoldCenter()
    local hum = self:GetHumanoid()
    local root = self:GetRoot()
    if hum and root then pcall(function() hum:MoveTo(root.Position) end) end
end

function AutoTeleportMainAlt:Teleport(pad)
    if not pad then return end
    local root = self:GetRoot()
    local hum = self:GetHumanoid()
    if not (root and hum) then return end
    pcall(function()
        root.AssemblyAngularVelocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        self:CancelQueue()
        self:HideGameFrame()
        hum:MoveTo(pad.Position)
    end)
end

function AutoTeleportMainAlt:Process()
    if not self.Running then return end
    local s = self:Snapshot()
    if s.InGame then
        self:UnmarkPad(); self:HoldCenter(); self:VoteMap(); return
    end
    local role = self:GetActiveRole()
    if not role then self:UnmarkPad(); return end
    local pad = self:ResolvePad(role)
    self:MarkPad(pad, role == "Alt")
    if not pad then return end
    if self:IsOnPad(pad) then return end
    local now = os.clock()
    if not self.ManualHold and now - (self.LastTeleport or 0) < self.TeleportCooldown then return end
    self.LastTeleport = now
    self:Teleport(pad)
end

function AutoTeleportMainAlt:Start()
    if self.Running then return end
    self.Running = true
    self.Acc = 0; self.LastTeleport = 0; self.LastVote = 0; self.LastCancel = 0
    self.Connections:Add(player:GetAttributeChangedSignal("Game"):Connect(function() task.defer(function() if self.Running then self:Process() end end) end))
    self.Connections:Add(player:GetAttributeChangedSignal("Map"):Connect(function() task.defer(function() if self.Running then self:Process() end end) end))
    self.Connections:Add(player:GetAttributeChangedSignal("Team"):Connect(function() task.defer(function() if self.Running then self:Process() end end) end))
    self.Connections:Add(RunService.Heartbeat:Connect(function(dt)
        if not self.Running then return end
        self.Acc = self.Acc + dt
        if self.Acc >= self.TickInterval then self.Acc = 0; self:Process() end
    end))
    self:Process()
end

function AutoTeleportMainAlt:Stop()
    if not self.Running then return end
    self.Running = false
    self.Connections:Cleanup()
    self.Connections = ConnectionManager.new()
    self:UnmarkPad()
    self.VotedMap = nil
end

AutoTeleportMainAltInstance = AutoTeleportMainAlt.new()

local KILLALL_MOVE_SPEED               = 39.9
local KILLALL_APPROACH_DISTANCE        = 2.5
local KILLALL_APPROACH_TOLERANCE       = 0.35
local KILLALL_SWING_INTERVAL           = 0.5
local KILLALL_SAFE_GROUND_THRESHOLD    = 3
local KILLALL_STICK_MAX_TIME           = 2.5
local KILLALL_STICK_MAX_DISTANCE       = 20
local KILLALL_VOID_PROTECTION          = 15
local KILLALL_HEALTH_STALL_TIME        = 1.5
local KILLALL_TARGET_GRACE_TIME        = 1.2
local KILLALL_PITCH_DEGREES            = 90
local KILLALL_HEIGHT_OFFSET            = 1.9
local KILLALL_HIDE_DEPTH               = 4
local KILLALL_HIDE_DURATION            = 0.5
local KILLALL_KNIFE_RANGE_Y            = 4.5
local KILLALL_JITTER_AMPLITUDE         = 0.8
local KILLALL_JITTER_SWITCH_MIN        = 0.05
local KILLALL_JITTER_SWITCH_MAX        = 0.12
local KILLALL_JITTER_LERP_SPEED        = 25
local KILLALL_UNDERGROUND_DEPTH        = 5
local KILLALL_UNDERGROUND_TOLERANCE    = 1.5
local KILLALL_TRIGGER_RADIUS           = 6.0
local KILLALL_VALIDATION_TOLERANCE     = 1.0
local KILLALL_VALIDATION_FRAMES        = 3

local KillAll = {}
KillAll.__index = KillAll
function KillAll.new()
    return setmetatable({
        running = false, connections = ConnectionManager.new(), savedCollisions = {},
        swingAccumulator = 0, safePosition = nil, sticking = false, stickingStartTime = 0,
        lastEnemyHealth = nil, lastHealthChangeTime = 0, lastTargetSeenTime = 0,
        currentTarget = nil, lockedTargetPlayer = nil, lastStickTarget = nil,
        lastStickTargetHum = nil, hiding = false, hidingUntil = 0, targetFloor = nil,
        targetFloorY = nil, lastFloorTarget = nil, inKnifeRangeNow = false,
        forceDescent = false, jitterSide = 1, jitterCurrent = 0, jitterNextSwitch = 0,
        lastSetCFrame = nil, validFrames = 0, killActivated = false,
    }, KillAll)
end

function KillAll:DisableCollisions()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            if self.savedCollisions[part] == nil then self.savedCollisions[part] = part.CanCollide end
            part.CanCollide = false
        end
    end
end

function KillAll:RestoreCollisions()
    for part, value in pairs(self.savedCollisions) do
        if part.Parent then pcall(function() part.CanCollide = value end) end
    end
    table.clear(self.savedCollisions)
end

function KillAll:GetRoot(p)
    local char = p and p.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    return (root and root:IsA("BasePart")) and root or nil
end

function KillAll:GetHumanoid(p)
    local char = p and p.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

function KillAll:GetFloorY(targetRoot)
    local hum = targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
    local hip = hum and tonumber(hum.HipHeight) or 2
    return targetRoot.Position.Y - hip - targetRoot.Size.Y / 2
end

function KillAll:GetPlatformFloorY(targetRoot)
    if not targetRoot then return nil end
    if self.lastFloorTarget == targetRoot and self.targetFloorY then return self.targetFloorY end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character, targetRoot.Parent }
    local result = workspace:Raycast(targetRoot.Position + Vector3.new(0, 3, 0), Vector3.new(0, -500, 0), params)
    if result then
        self.targetFloorY = result.Position.Y
        self.lastFloorTarget = targetRoot
        return self.targetFloorY
    end
    self.targetFloorY = self:GetFloorY(targetRoot)
    self.lastFloorTarget = targetRoot
    return self.targetFloorY
end

function KillAll:IsInKnifeRange(myRoot, targetRoot)
    if not myRoot or not targetRoot then return false end
    local delta = targetRoot.Position - myRoot.Position
    return Vector3.new(delta.X, 0, delta.Z).Magnitude <= (KILLALL_APPROACH_DISTANCE + KILLALL_APPROACH_TOLERANCE) and math.abs(delta.Y) <= KILLALL_KNIFE_RANGE_Y
end

function KillAll:IsLockedTargetValid()
    local lp = self.lockedTargetPlayer
    if not lp or not lp.Parent or not esEnemigoValido(lp) then return false end
    local char = lp.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return false end
    return root
end

function KillAll:GetClosestEnemy()
    local myRoot = self:GetRoot(player)
    if not myRoot then return nil end
    local lockedRoot = self:IsLockedTargetValid()
    if lockedRoot then return lockedRoot end

    self.lockedTargetPlayer = nil
    self.currentTarget = nil

    local best, bestDist, bestPlayer = nil, nil, nil
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and esEnemigoValido(other) then
            local hum = self:GetHumanoid(other)
            local root = self:GetRoot(other)
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if not bestDist or dist < bestDist then
                    best, bestDist, bestPlayer = root, dist, other
                end
            end
        end
    end
    if bestPlayer then self.lockedTargetPlayer = bestPlayer end
    return best
end

function KillAll:IsInMatch() return IsInMatchStrict() end

function KillAll:ResetState()
    self.sticking = false
    self.stickingStartTime = 0
    self.lastEnemyHealth = nil
    self.lastHealthChangeTime = 0
    self.targetFloor = nil
    self.inKnifeRangeNow = false
    self.forceDescent = false
    self.jitterSide = 1
    self.jitterCurrent = 0
    self.jitterNextSwitch = 0
    self.lastSetCFrame = nil
    self.validFrames = 0
    self.killActivated = false
    self:RestoreCollisions()
    local hum = self:GetHumanoid(player)
    if hum and hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
end

function KillAll:ReturnToSafePosition(myRoot)
    if not self.safePosition or not myRoot then return end
    if myRoot.Position.Y < (self.safePosition.Y - KILLALL_SAFE_GROUND_THRESHOLD) then
        pcall(function()
            myRoot.CFrame = CFrame.new(self.safePosition)
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

function KillAll:ForceReturnToSafe(myRoot)
    if not self.safePosition or not myRoot then return end
    pcall(function()
        myRoot.CFrame = CFrame.new(self.safePosition)
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
    end)
end

function KillAll:IsFallingIntoVoid(myRoot)
    if not self.safePosition or not myRoot then return false end
    return myRoot.Position.Y < (self.safePosition.Y - KILLALL_VOID_PROTECTION)
end

function KillAll:HideBelowMap()
    local myRoot = self:GetRoot(player)
    if not myRoot then return end
    local baseY = self.safePosition and self.safePosition.Y or myRoot.Position.Y
    pcall(function()
        myRoot.CFrame = CFrame.new(myRoot.Position.X, baseY - KILLALL_HIDE_DEPTH, myRoot.Position.Z)
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
    end)
    self.hiding = true
    self.hidingUntil = os.clock() + KILLALL_HIDE_DURATION
end

function KillAll:IsKnife(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    if tool:FindFirstChild("fire") or tool:FindFirstChild("showBeam") then return false end
    return tool:FindFirstChild("Slash") ~= nil or tool:FindFirstChild("SlashStart") ~= nil
end

function KillAll:FindKnife()
    local char = player.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if self:IsKnife(child) then return child, true end
        end
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if self:IsKnife(child) then return child, false end
        end
    end
    return nil, false
end

function KillAll:SwingKnife(dt)
    self.swingAccumulator = self.swingAccumulator + dt
    if self.swingAccumulator < KILLALL_SWING_INTERVAL then return end
    self.swingAccumulator = 0
    local tool, equipped = self:FindKnife()
    if not tool then return end
    if not equipped then
        local hum = self:GetHumanoid(player)
        if not hum then return end
        pcall(function() hum:EquipTool(tool) end)
        if tool.Parent ~= player.Character then return end
    end
    pcall(function() tool:Activate() end)
end

function KillAll:UpdateJitter(dt)
    local now = os.clock()
    if now >= self.jitterNextSwitch then
        self.jitterSide = (math.random() < 0.5) and 1 or -1
        self.jitterNextSwitch = now + KILLALL_JITTER_SWITCH_MIN + math.random() * (KILLALL_JITTER_SWITCH_MAX - KILLALL_JITTER_SWITCH_MIN)
    end
    local targetOffset = self.jitterSide * KILLALL_JITTER_AMPLITUDE
    self.jitterCurrent = self.jitterCurrent + (targetOffset - self.jitterCurrent) * math.clamp(dt * KILLALL_JITTER_LERP_SPEED, 0, 1)
end

function KillAll:CheckServerValidation(myRoot)
    if self.killActivated then return true end
    if not self.lastSetCFrame then return false end
    if (myRoot.Position - self.lastSetCFrame.Position).Magnitude <= KILLALL_VALIDATION_TOLERANCE then
        self.validFrames = self.validFrames + 1
        if self.validFrames >= KILLALL_VALIDATION_FRAMES then
            self.killActivated = true
            self.swingAccumulator = KILLALL_SWING_INTERVAL
            return true
        end
    else
        self.validFrames = 0
    end
    return false
end

function KillAll:ForceUnderground(myRoot, targetRoot)
    if not myRoot or not targetRoot then return end
    local floorY = self:GetPlatformFloorY(targetRoot)
    if not floorY then return end
    local targetY = floorY - KILLALL_UNDERGROUND_DEPTH
    if myRoot.Position.Y > targetY + KILLALL_UNDERGROUND_TOLERANCE then
        pcall(function()
            myRoot.CFrame = CFrame.new(myRoot.Position.X, targetY, myRoot.Position.Z)
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

function KillAll:ApproachTarget(myRoot, targetRoot, dt)
    dt = dt or 0
    local myPos = myRoot.Position
    local targetPos = targetRoot.Position
    local deltaXZ = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
    local hDist = deltaXZ.Magnitude

    if hDist <= KILLALL_TRIGGER_RADIUS then
        if not self.sticking then
            local targetCF = CFrame.lookAt(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
            self.lastSetCFrame = targetCF
            pcall(function()
                myRoot.CFrame = targetCF
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end)
            if self:CheckServerValidation(myRoot) then
                self.sticking = true
                self.stickingStartTime = os.clock()
                self.lastStickTarget = targetRoot
                self.targetFloor = nil
                self.forceDescent = true
                local hum = self:GetHumanoid(targetRoot.Parent)
                self.lastEnemyHealth = hum and hum.Health or nil
                self.lastHealthChangeTime = os.clock()
                self.lastStickTargetHum = hum
                self.jitterCurrent = 0
            end
        end
        return
    end

    self.lastSetCFrame = nil
    self.validFrames = 0
    local dir = deltaXZ.Unit
    local perp = Vector3.new(-dir.Z, 0, dir.X)
    self:UpdateJitter(dt)

    local step = KILLALL_MOVE_SPEED * dt
    local travel = math.min(step, math.max(0, hDist - KILLALL_TRIGGER_RADIUS))
    local maxJitter = math.sqrt(math.max(0, travel * (2 * hDist - travel))) * 0.85
    local actualJitter = math.clamp(self.jitterCurrent * math.clamp((hDist - KILLALL_TRIGGER_RADIUS) / 8, 0, 1), -maxJitter, maxJitter)

    local newX = myPos.X + dir.X * travel + perp.X * actualJitter
    local newZ = myPos.Z + dir.Z * travel + perp.Z * actualJitter
    local floorY = self:GetPlatformFloorY(targetRoot)
    local newY = floorY and (floorY - KILLALL_UNDERGROUND_DEPTH) or myPos.Y

    pcall(function()
        myRoot.CFrame = CFrame.lookAt(Vector3.new(newX, newY, newZ), Vector3.new(targetPos.X, newY, targetPos.Z))
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
    end)
end

function KillAll:CanStickToTarget(myRoot, targetRoot)
    if not targetRoot or not targetRoot.Parent then return false end
    local targetPlayer = Players:GetPlayerFromCharacter(targetRoot.Parent)
    if not targetPlayer or not esEnemigoValido(targetPlayer) then return false end
    local targetHum = targetRoot.Parent:FindFirstChildOfClass("Humanoid")
    if not targetHum or targetHum.Health <= 0 then return false end
    return (Vector3.new(myRoot.Position.X, 0, myRoot.Position.Z) - Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z)).Magnitude <= KILLALL_STICK_MAX_DISTANCE
end

function KillAll:StickToTarget(myRoot, targetRoot)
    local targetPos = targetRoot.Position
    local targetHum = targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
    local onGround = targetHum and targetHum.FloorMaterial ~= Enum.Material.Air
    if targetRoot ~= self.lastStickTarget then
        self.lastStickTarget = targetRoot
        self.targetFloor = nil
    end
    if onGround or not self.targetFloor then
        self.targetFloor = self:GetFloorY(targetRoot)
    end
    local myPos = myRoot.Position
    local dir = Vector3.new(myPos.X - targetPos.X, 0, myPos.Z - targetPos.Z)
    dir = dir.Magnitude < 0.05 and Vector3.new(0, 0, 1) or dir.Unit
    local x = targetPos.X + dir.X * KILLALL_APPROACH_DISTANCE
    local z = targetPos.Z + dir.Z * KILLALL_APPROACH_DISTANCE
    local inRange = self:IsInKnifeRange(myRoot, targetRoot)
    local y = (inRange and not self.forceDescent) and myPos.Y or (self.targetFloor - KILLALL_HEIGHT_OFFSET)
    if inRange then self.forceDescent = false end
    pcall(function()
        myRoot.CFrame = CFrame.new(x, y, z) * CFrame.Angles(math.rad(KILLALL_PITCH_DEGREES), 0, 0)
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
    end)
end

function KillAll:CheckEnemyHealth(targetRoot)
    local targetHum = targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
    if not targetHum then return false end
    local currentHealth = targetHum.Health
    if self.lastEnemyHealth == nil then
        self.lastEnemyHealth = currentHealth
        self.lastHealthChangeTime = os.clock()
        return false
    end
    if currentHealth < self.lastEnemyHealth then
        self.lastEnemyHealth = currentHealth
        self.lastHealthChangeTime = os.clock()
        return false
    end
    return (os.clock() - self.lastHealthChangeTime) >= KILLALL_HEALTH_STALL_TIME
end

function KillAll:Update(dt)
    if not self:IsInMatch() then
        self:ResetState()
        self.currentTarget = nil
        self.lockedTargetPlayer = nil
        self.lastStickTarget = nil
        self.lastFloorTarget = nil
        self.targetFloorY = nil
        return
    end

    local myRoot = self:GetRoot(player)
    if not myRoot then
        self:ResetState()
        self.currentTarget = nil
        self.lockedTargetPlayer = nil
        return
    end

    if self.lastStickTargetHum and (not self.lastStickTargetHum.Parent or self.lastStickTargetHum.Health <= 0) then
        self:HideBelowMap()
        self:ResetState()
        return
    end

    if self.hiding then
        if os.clock() >= self.hidingUntil then self.hiding = false
        else
            pcall(function()
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end)
            return
        end
    end

    if self:IsFallingIntoVoid(myRoot) then
        self:ForceReturnToSafe(myRoot)
        self:ResetState()
        return
    end

    local target = self:GetClosestEnemy()
    if target then
        self.currentTarget = target
        self.lastTargetSeenTime = os.clock()
    end

    if not target then
        if (os.clock() - (self.lastTargetSeenTime or 0)) < KILLALL_TARGET_GRACE_TIME and self.safePosition and myRoot.Position.Y < (self.safePosition.Y - 2) then
            pcall(function()
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end)
            return
        end
        self:ReturnToSafePosition(myRoot)
        self:ResetState()
        return
    end

    self:DisableCollisions()

    if self.lastStickTarget then
        local inRange = self:IsInKnifeRange(myRoot, self.lastStickTarget)
        if inRange and not self.inKnifeRangeNow then
            self.swingAccumulator = KILLALL_SWING_INTERVAL
            self.inKnifeRangeNow = true
        elseif not inRange then
            self.inKnifeRangeNow = false
        end
    end

    self:SwingKnife(dt or 0)
    local hum = self:GetHumanoid(player)
    if hum and not hum.PlatformStand then pcall(function() hum.PlatformStand = true end) end

    if self.safePosition and myRoot.Position.Y >= (self.safePosition.Y - KILLALL_SAFE_GROUND_THRESHOLD) then
        self.safePosition = Vector3.new(myRoot.Position.X, self.safePosition.Y, myRoot.Position.Z)
    end

    if not self.sticking then self:ForceUnderground(myRoot, target) end

    if self.sticking then
        if (target ~= self.lastStickTarget) or ((os.clock() - self.stickingStartTime) > KILLALL_STICK_MAX_TIME) or not self:CanStickToTarget(myRoot, target) or self:CheckEnemyHealth(target) then
            self:ResetState()
        else
            self:StickToTarget(myRoot, target)
            return
        end
    end

    self:ApproachTarget(myRoot, target, dt or 0)
end

function KillAll:Start()
    if self.running then return end
    self.running = true
    self:ResetState()
    local myRoot = self:GetRoot(player)
    if myRoot then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { player.Character }
        local result = workspace:Raycast(myRoot.Position + Vector3.new(0, 5, 0), Vector3.new(0, -500, 0), params)
        self.safePosition = result and Vector3.new(myRoot.Position.X, result.Position.Y + 3, myRoot.Position.Z) or myRoot.Position
    else
        self.safePosition = nil
    end

    self.connections:Add(RunService.Heartbeat:Connect(function(dt)
        if not self.running then return end
        self:Update(dt)
    end))
    self.connections:Add(player.CharacterAdded:Connect(function() self:ResetState() end))
end

function KillAll:Stop()
    if not self.running then return end
    local myRoot = self:GetRoot(player)
    if myRoot and self.safePosition then
        pcall(function()
            myRoot.CFrame = CFrame.new(self.safePosition)
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    self.running = false
    self.connections:Cleanup()
    self.connections = ConnectionManager.new()
    self:ResetState()
end

KillAllInstance = KillAll.new()

local WindUI
local _version = "1.6.66"
local ok, result = pcall(function()
    local codigoUi = game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. _version .. "/main.lua")
    return loadstring(codigoUi)()
end)

if ok and result and type(result) == "table" then
    WindUI = result
else
    warn("Error al cargar WindUI: " .. tostring(result))
    return
end

local function IniciarMenuPrincipal()
    local Window = WindUI:CreateWindow({
        Title = "ALEX HUB",
        Author = "alex@11",
        Folder = "AlexHub_WindUI",
        Acrylic = false,
        Transparent = true,
        NewElements = true,
        HideSearchBar = false,
        SideBarWidth = 200,
        OpenButton = {
            Title = "alex@11",
            Icon = "rbxthumb://type=Asset&id=118232139384203&w=420&h=420",
            IconSize = 9,
            CornerRadius = UDim.new(1),
            StrokeThickness = 2,
            Enabled = true,
            Draggable = true,
            Scale = 0.9,
            Color = ColorSequence.new(Color3.fromHex("#110070"), Color3.fromHex("#300364"))
        },
        Topbar = { Height = 44, ButtonsType = "Default" }
    })

    local MainSection = Window:Section({ Title = "Menú Principal", Icon = "solar:star-bold", Opened = true })
    local OwnersSection = Window:Section({ Title = "Propietario", Icon = "solar:crown-bold", Opened = true })

    local Tabs = {
        Inicio = MainSection:Tab({ Title = "Inicio", Icon = "solar:home-bold" }),
        Aim = MainSection:Tab({ Title = "Aimbot", Icon = "solar:target-bold" }),
        Vis = MainSection:Tab({ Title = "Visuales", Icon = "solar:eye-bold" }),
        Farm = MainSection:Tab({ Title = "AutoFarm", Icon = "solar:dollar-bold" }),
        KillAll = MainSection:Tab({ Title = "Kill All", Icon = "solar:danger-triangle-bold" }),
        RachaFarm = MainSection:Tab({ Title = "Racha Farm", Icon = "solar:flame-bold" }),
        Animaciones = MainSection:Tab({ Title = "Animaciones", Icon = "solar:smile-circle-bold" }),
        Owners = OwnersSection:Tab({ Title = "Owners", Icon = "solar:crown-bold" })
    }

    Tabs.Inicio:Section({ Title = "Perfil del Jugador", Icon = "solar:user-bold" })
    Tabs.Inicio:Paragraph({
        Title = "Usuario: " .. player.DisplayName,
        Desc = "Usuario: @" .. player.Name .. "\nID: " .. player.UserId,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=420&h=420",
        ImageSize = 48
    })

    Tabs.Aim:Section({ Title = "Auto Shoot", Icon = "solar:target-bold" })
    Tabs.Aim:Toggle({
        Title = "Auto Shoot (Normal)",
        Callback = function(Value) autoShootEnabled = Value end
    })

    Tabs.Vis:Section({ Title = "Configuración de ESP", Icon = "solar:eye-bold" })
    Tabs.Vis:Toggle({ Title = "ESP Jugadores", Callback = function(s) espEnabled = s end })

    Tabs.Farm:Section({ Title = "Farmeo de Evento", Icon = "solar:gift-bold" })
    getgenv().AutoEventFarm = false
    local Networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
    local RemoteFarm = Networking and Networking:FindFirstChild("RE/Events/CollectEventSpawnable")
    Tabs.Farm:Toggle({
        Title = "Auto Farmear Evento",
        Callback = function(s)
            getgenv().AutoEventFarm = s
            if s then
                task.spawn(function()
                    while getgenv().AutoEventFarm do
                        pcall(function() if RemoteFarm then RemoteFarm:FireServer() end end)
                        task.wait(0.05)
                    end
                end)
            end
        end
    })

    Tabs.KillAll:Section({ Title = "Kill All", Icon = "solar:danger-triangle-bold" })
    Tabs.KillAll:Toggle({
        Title = "Kill All",
        Callback = function(Value)
            KillAllEnabled = Value
            if Value then KillAllInstance:Start() else KillAllInstance:Stop() end
        end
    })

    Tabs.RachaFarm:Section({ Title = "Auto Teleport Main/Alt", Icon = "solar:map-arrow-square-bold" })
    Tabs.RachaFarm:Toggle({
        Title = "Auto Teleport (Main)",
        Callback = function(value)
            if value then
                AutoTeleportMainAltInstance.ActiveRole = "Main"
                AutoTeleportMainAltInstance:Stop()
                AutoTeleportMainAltInstance:Start()
            else
                AutoTeleportMainAltInstance.ActiveRole = nil
                AutoTeleportMainAltInstance:Stop()
            end
        end
    })

    Tabs.Animaciones:Section({ Title = "Paquetes", Icon = "solar:folder-with-files-bold" })
    Tabs.Animaciones:Dropdown({ Title = "Elegir Paquete", Values = { "Ninguno", "Ninja", "Zombie" }, Value = "Ninguno", Callback = function() end })

    Tabs.Owners:Section({ Title = "CREADOR OFICIAL", Icon = "solar:crown-bold" })
    Tabs.Owners:Paragraph({
        Title = "<b>alex@11</b>",
        Desc = "<font color='#FFD700'><b>[FOUNDER]</b></font> <b>Alex_12alex28</b>\nFundador y creador de Alex Hub",
        Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=420&height=420&format=png",
        ImageSize = 72
    })
end

if verificarCacheLocal() then
    IniciarMenuPrincipal()
else
    local KeyWindow = WindUI:CreateWindow({
        Title = "ALEX HUB",
        Author = "alex@11",
        Folder = "AlexHub_KeySystem",
        Acrylic = false,
        Transparent = true,
        NewElements = true,
        HideSearchBar = true,
        OpenButton = { Enabled = false },
        Topbar = { Height = 44, ButtonsType = "None" }
    })

    local KeySection = KeyWindow:Section({ Title = "Sistema de Key", Icon = "solar:shield-keyhole-bold", Opened = true })
    local KeyTab = KeySection:Tab({ Title = "Key", Icon = "solar:key-bold" })

    KeyTab:Input({
        Title = "Ingresa tu Key",
        Placeholder = "Usa 'gratis' o 'Alex'...",
        Callback = function(Value)
            keyIngresada = Value
        end
    })

    KeyTab:Button({
        Title = "VERIFICAR KEY",
        Variant = "Primary",
        Callback = function()
            if keyIngresada == KEY_GRATIS or keyIngresada == KEY_PERMANENTE then
                pcall(function()
                    if writefile then
                        writefile(archivoCacheLocal, HttpService:JSONEncode({key = keyIngresada, timestamp = os.time()}))
                    end
                end)

                WindUI:Notify({ Title = "¡Acceso Conectado!", Content = "Key correcta. ¡Disfruta el Hub!", Duration = 3 })
                pcall(function() KeyWindow:Close() end)
                task.wait(0.4)
                IniciarMenuPrincipal()
            else
                WindUI:Notify({ Title = "Acceso Denegado", Content = "Key incorrecta. Usa 'gratis' o 'Alex'.", Duration = 4 })
            end
        end
    })
end
