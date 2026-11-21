local KynInternal = {}

function KynInternal.hasPremium()
    return getgenv().PremiumAccess
end

local GuiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/timmyg69420/GuiLib/refs/heads/main/main.lua"))()

local GLOBALVAR = {}

local Runtime = {
    Humanoid = nil,
    LastSpoof = 0,
    LastBuy = 0,
    LastLucky = 0,
    FarmThread = nil,
    SellThread = nil,
    SkinThread = nil,
    HopThread = nil,
    SpoofThread = nil,
}

GLOBALVAR.ItemSpawnHandlerEnabled = true

local CONFIG_FOLDER = "KynYBAScript"

if isfolder and makefolder and not isfolder(CONFIG_FOLDER) then
    makefolder(CONFIG_FOLDER)
end


local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "KynYBAScript/settings.json"

local EXCLUDED = {
    KynHooks = true,
    UI = true,
    Novex_SkinFarmToggle = true,
    __NovexCharAddedConn = true,
}

function KynInternal.serialize(value, seen)
    local kind = type(value)

    if typeof(value) == "EnumItem" then
        return value.Name
    end

    if kind == "boolean" or kind == "number" or kind == "string" then
        return value
    end

    if kind ~= "table" then
        return nil
    end

    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true

    local result = {}

    for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then
            local clean = KynInternal.serialize(v, seen)
            if clean ~= nil then
                result[k] = clean
            end
        end
    end

    seen[value] = nil
    return result
end

function KynInternal.saveSettings()
    if not writefile then return false end

    local data = {}

    for key, value in pairs(GLOBALVAR) do
        if not EXCLUDED[key]
            and type(key) == "string"
            and key:sub(1, 2) ~= "__" then

            local clean = KynInternal.serialize(value)
            if clean ~= nil then
                data[key] = clean
            end
        end
    end

    local ok, err = pcall(function()
        if makefolder and isfolder
            and not isfolder("KynYBAScript") then
            makefolder("KynYBAScript")
        end

        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)

    if not ok then
        warn("[Kyn Config] Save failed:", err)
    end

    return ok
end

function KynInternal.LoadConfig()
    if not readfile or not isfile or not isfile(CONFIG_FILE) then
        return false
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)

    if not ok or type(data) ~= "table" then
        warn("[Kyn Config] Invalid config")
        return false
    end

    for key, value in pairs(data) do
        if not EXCLUDED[key]
            and type(key) == "string"
            and key:sub(1, 2) ~= "__"
            and (type(value) == "boolean"
                or type(value) == "number"
                or type(value) == "string"
                or type(value) == "table") then

            GLOBALVAR[key] = value
        end
    end

    print("[Kyn Config] Loaded")
    return true
end

KynInternal.LoadConfig()
do
    local farmResume = getgenv().__KynFarmTeleportResume
    getgenv().__KynFarmTeleportResume = nil

    GLOBALVAR.ItemFarm = type(farmResume) == "table" and farmResume.ItemFarm == true or false
    GLOBALVAR.skin_farm = type(farmResume) == "table" and farmResume.skin_farm == true or false
end

function KynInternal.queueKynTeleport(loaderUrl)
    local queue = queue_on_teleport or queueonteleport

    if type(queue) ~= "function" then
        warn("[Kyn] Executor does not support queue-on-teleport")
        return false
    end
    
local code = string.format([[
    getgenv().PremiumAccess = true
    getgenv().__KynFarmTeleportResume = {
        ItemFarm = %s,
        skin_farm = %s,
    }

    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    warn("[Kyn] tp attempt")

    local loaderUrl = %q

    for attempt = 1, 5 do
        local ok, err = pcall(function()
            local source = game:HttpGet(loaderUrl)
            local loader = assert(loadstring(source))
            loader()
        end)

        if ok then
            print("[Kyn] executed after teleport")
            break
        end

        warn("[Kyn] Reload attempt", attempt, "failed:", err)
        task.wait(3)
    end
]],
    tostring(GLOBALVAR.ItemFarm == true),
    tostring(GLOBALVAR.skin_farm == true),
    loaderUrl
)

    local ok, err = pcall(queue, code)

    if not ok then
        warn("[Kyn] Queue failed:", err)
    end

    return ok
end

local UIRegistry = {}
function KynInternal.Register(name, element)
    UIRegistry[name] = element
    return element
end

local global_lock = false
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

GLOBALVAR.KynHooks = GLOBALVAR.KynHooks or {}
local KynHooks = GLOBALVAR.KynHooks

KynHooks.Enabled         = KynHooks.Enabled         or false
KynHooks.TargetValid     = KynHooks.TargetValid     or false
KynHooks.TargetPosition  = KynHooks.TargetPosition  or Vector3.zero
KynHooks.LockedBodies    = KynHooks.LockedBodies    or setmetatable({}, { __mode = "k" })
KynHooks.SaFake          = KynHooks.SaFake          or nil
KynHooks.LocalRemote     = KynHooks.LocalRemote     or nil
KynHooks.IsReturnerBypass = true

if not KynHooks._installed and getrawmetatable and newcclosure then
    KynHooks._installed = true

    local gameMt = getrawmetatable(game)
    setreadonly(gameMt, false)

    local hookUIS = game:GetService("UserInputService")
    local hookPlayer = game:GetService("Players").LocalPlayer
    local oldNamecall = gameMt.__namecall
    gameMt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if KynHooks.SaFake and method == "GetMouseLocation" then
            if self == hookUIS then
                return KynHooks.SaFake
            end
        end

        if method == "InvokeServer" then
            if KynHooks.IsReturnerBypass then
    if self.Name == "Returner" and (select(1, ...)) == "idklolbrah2de" then
        return "  ___XP DE KEY"
    end
end
        end

        if method == "Kick" and self == hookPlayer then
            return
        end

        return oldNamecall(self, ...)
    end)

    local oldNewIndex = gameMt.__newindex
    gameMt.__newindex = newcclosure(function(self, key, value)
        if key == "WalkSpeed" then
            if GLOBALVAR.WalkSpeedModifier == true
                and self == Runtime.Humanoid then
                value = GLOBALVAR.WalkSpeedValue or value
            end
        elseif key == "JumpPower" then
            if GLOBALVAR.JumpModifier == true
                and self:IsA("Humanoid") then
                value = GLOBALVAR.JumpValue or value
            end 
        elseif KynHooks.Enabled and KynHooks.TargetValid then
            if key == "Velocity"
            or key == "VectorVelocity"
            or key == "Force" then
            local info = KynHooks.LockedBodies[self]
            if info and info.part and info.part.Parent then
                local isVelocity = (key == "Velocity" and self:IsA("BodyVelocity"))
                    or (key == "VectorVelocity" and self:IsA("LinearVelocity"))
                local isForce = (key == "Force" and self:IsA("VectorForce"))
                if isVelocity or isForce then
                    local dest = KynHooks.TargetPosition
                    local delta = KynHooks.TargetPosition - info.part.Position
                    local mag = delta.Magnitude
                    if mag > 0.1 then
                        value = delta * ((isVelocity and 150 or 1e6) / mag)
                    end
                end
            end
        end
        end

        return oldNewIndex(self, key, value)
    end)

    setreadonly(gameMt, true)
end

KynHooks.SyncState = function(state)
    KynHooks.Enabled     = state.aiming or false
    KynHooks.TargetValid = state.targetValid or false
    KynHooks.TargetPosition = state.targetPosition or Vector3.zero
    KynHooks.SaFake      = state.saFake
    KynHooks.LocalRemote = state.localRemote
end

local mt = getrawmetatable(Vector3.new())
local oldIndex = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(self, index)
    if GLOBALVAR.ItemFarm then
        if index == "Magnitude" or index == "magnitude" then
            if not checkcaller() then
                local script = getcallingscript()
                if script and script.Name == "ItemSpawn" then
                    return 0
                end
            end
        end
    end
    return oldIndex(self, index)
end)
setreadonly(mt, true)

local InventoryBusy = false
local DialogueBusy = false

function KynInternal.acquireInventory()
    if InventoryBusy then return false end
    InventoryBusy = true
    return true
end

function KynInternal.releaseInventory()
    InventoryBusy = false
end

if GLOBALVAR.BuyLuckyArrows == nil then
GLOBALVAR.BuyLuckyArrows = false
end
if GLOBALVAR.ItemFarm == nil then
GLOBALVAR.ItemFarm = false
end
if GLOBALVAR.sellall == nil then
GLOBALVAR.sellall = false
end
if GLOBALVAR.pickup_delay == nil then
GLOBALVAR.pickup_delay = 0.5
end
if GLOBALVAR.hop_enabled == nil then
GLOBALVAR.hop_enabled = false
end
if GLOBALVAR.BuyRokas == nil then
    GLOBALVAR.BuyRokas = false
end
if GLOBALVAR.BuyArrows == nil then
    GLOBALVAR.BuyArrows = false
end
if GLOBALVAR.skin_farm == nil then
GLOBALVAR.skin_farm = false
end
if GLOBALVAR.evo_skins == nil then
GLOBALVAR.evo_skins = false
end
if GLOBALVAR.swapslots == nil then
    GLOBALVAR.swapslots = false
end
if GLOBALVAR.selectedArrows == nil then
    GLOBALVAR.selectedArrows = {"Mysterious Arrow"}
end
if GLOBALVAR.itemsToSell == nil then
    GLOBALVAR.itemsToSell = { 
    "Gold Coin",
    "Rokakaka", 
    "Ancient Scroll",
    "Caesar's Headband",
    "Clackers",
    "Diamond",
    "Dio's Diary",
    "Mysterious Arrow",
    "Quinton's Glove",
    "Rib Cage of The Saint's Corpse",
    "Zeppeli's Hat",
    "Stone Mask",
    "Steel Ball",
    "Pure Rokakaka",
    "DIO's Headband"
}
end
if GLOBALVAR.itemsToGrab == nil then
    GLOBALVAR.itemsToGrab = { 
    "Gold Coin",
    "Rokakaka", 
    "Ancient Scroll",
    "Caesar's Headband",
    "Clackers",
    "Diamond",
    "Dio's Diary",
    "Mysterious Arrow",
    "Quinton's Glove",
    "Rib Cage of The Saint's Corpse",
    "Zeppeli's Hat",
    "Stone Mask",
    "Steel Ball",
    "Pure Rokakaka",
    "Green Candy",
    "Red Candy",
    "Yellow Candy",
    "Blue Candy"
}
end
if GLOBALVAR.webhook_enabled == nil then
    GLOBALVAR.webhook_enabled = false
end
if GLOBALVAR.webhook == nil then
    GLOBALVAR.webhook = ""
end
if GLOBALVAR.onlyLAwhenPityGood == nil then
    GLOBALVAR.onlyLAwhenPityGood = true
end
if GLOBALVAR.spoof_user == nil then
    GLOBALVAR.spoof_user = true
end
if GLOBALVAR.Invis == nil then
    GLOBALVAR.Invis = false
end
if GLOBALVAR.StandPilot == nil then
    GLOBALVAR.StandPilot = false
end
if GLOBALVAR.StandSpeed == nil then
    GLOBALVAR.StandSpeed = 1.5
end
if GLOBALVAR.PilotJumpPower == nil then
    GLOBALVAR.PilotJumpPower = 1.5
end
if GLOBALVAR.HidePilotBody == nil then
    GLOBALVAR.HidePilotBody = true
end
if GLOBALVAR.TeleportBodyToStand == nil then
    GLOBALVAR.TeleportBodyToStand = true
end
if GLOBALVAR.PilotBodyDistance == nil then
    GLOBALVAR.PilotBodyDistance = 37
end
if GLOBALVAR.PilotKey == nil then
    GLOBALVAR.PilotKey = "H"
end
if GLOBALVAR.AutoBoss == nil then
    GLOBALVAR.AutoBoss = false
end
if GLOBALVAR.AutoBossTarget == nil then
    GLOBALVAR.AutoBossTarget = "Jotaro"
end
if GLOBALVAR.evo_stands == nil then
    GLOBALVAR.evo_stands = {
    "Silver Chariot",
    "Gold Experience",
    "Star Platinum",
    "King Crimson",
    "Killer Queen"
}
end
if GLOBALVAR.WalkSpeedModifier == nil then
    GLOBALVAR.WalkSpeedModifier = false
end
if GLOBALVAR.WalkSpeedValue == nil then
    GLOBALVAR.WalkSpeedValue = 32
end
if GLOBALVAR.JumpModifier == nil then
    GLOBALVAR.JumpModifier = false
end
if GLOBALVAR.JumpValue == nil then
    GLOBALVAR.JumpValue = 50
end
if GLOBALVAR.SilentAimEnabled == nil then
    GLOBALVAR.SilentAimEnabled = false
end
if GLOBALVAR.ReachDistance == nil then
    GLOBALVAR.ReachDistance = 2
end
if GLOBALVAR.watermark_enabled == nil then
    GLOBALVAR.watermark_enabled = true
end
if GLOBALVAR.AccuracyBlatant == nil then
    GLOBALVAR.AccuracyBlatant = false
end
if GLOBALVAR.AccuracyRange == nil then
    GLOBALVAR.AccuracyRange = 250
end
if GLOBALVAR.AutoWeatherReport == nil then
    GLOBALVAR.AutoWeatherReport = false
end
if GLOBALVAR.AutoDiverDown == nil then
    GLOBALVAR.AutoDiverDown = false
end

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

if getconnections then
local connection = getconnections(game.Players.LocalPlayer.Idled)[1]
connection:Disable()
else
task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)
end

local tp = false
game:GetService("CoreGui").DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local GrabError = child:FindFirstChild("ErrorMessage",true)
        repeat task.wait() until GrabError.Text ~= "Label"
        local Reason = GrabError.Text
        if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
            if not tp then
            tp = true
            KynInternal.queueKynTeleport("https://raw.githubusercontent.com/lklkkklkllklk/temp/refs/heads/main/main.lua")
            game:GetService("TeleportService"):Teleport(2809202155, game:GetService("Players").LocalPlayer)
        end
        end
    end
end)

for _, d in ipairs(game:GetService("CoreGui"):GetDescendants()) do
    if d.Name == "ErrorPrompt" then
        local GrabError = d:FindFirstChild("ErrorMessage", true)
        if GrabError then
            task.spawn(function()
                repeat task.wait() until GrabError.Text ~= "Label" and GrabError.Text ~= ""
                local Reason = GrabError.Text
                if Reason:match("kick") or Reason:match("You") or Reason:match("conn") or Reason:match("rejoin") then
                    if not tp then
                    tp = true
                    KynInternal.queueKynTeleport("https://raw.githubusercontent.com/lklkkklkllklk/temp/refs/heads/main/main.lua")
                    game:GetService("TeleportService"):Teleport(2809202155, game:GetService("Players").LocalPlayer)
                end
                end
            end)
        end
    end
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not PlayerGui then return end

local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local remote = Character:WaitForChild("RemoteEvent", 10)

if remote then
    pcall(function() remote:FireServer("PressedPlay") end)
end

for _, name in ipairs({"DepthOfField", "PlayScreenBlur"}) do
    local e = Lighting:FindFirstChild(name)
    if e then e:Destroy() end
end

if not Lighting:FindFirstChildWhichIsA("Atmosphere") then
    local a = RS:FindFirstChildWhichIsA("Atmosphere")
    if a then a.Parent = Lighting end
end

if not PlayerGui:FindFirstChild("HUD") then
    local o = RS:FindFirstChild("Objects")
    local h = o and o:FindFirstChild("HUD")
    if h then h:Clone().Parent = PlayerGui end
end

for _, name in ipairs({"LoadingScreen1", "LoadingScreen"}) do
    local g = PlayerGui:FindFirstChild(name)
    if g then g:Destroy() end
end
local folder = workspace:FindFirstChild("LoadingScreen")
if folder then folder:Destroy() end

local ct = RS:FindFirstChild("ClockTime")
if ct then Lighting.ClockTime = ct.Value end

pcall(function() SG:SetCore("TopbarEnabled", true) end)

local chat = PlayerGui:FindFirstChild("Chat")
if chat and chat.Frame then
    chat.Frame.AnchorPoint = Vector2.new(0, 1)
    chat.Frame.Position = UDim2.new(0, 0, 1, 0)
end

task.delay(10,function()
    if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") or LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen1") then
        KynInternal.queueKynTeleport("https://raw.githubusercontent.com/lklkkklkllklk/temp/refs/heads/main/main.lua")
        game:GetService("TeleportService"):Teleport(2809202155, game:GetService("Players").LocalPlayer)
    end
end)

local unequip_tools
unequip_tools = function()
    for _,v in pairs(LocalPlayer.Character:GetChildren()) do
        if v:IsA("Tool") then
            v.Parent = LocalPlayer:WaitForChild("Backpack",5)
        end
    end
end

function KynInternal.get_character()
    local character = LocalPlayer.Character
    if not character or not character.Parent then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    local remote = character:FindFirstChild("RemoteFunction")

    if not humanoid or humanoid.Health <= 0.15 or not root then
        return nil
    end

    return character, remote
end

local Items = { 
    "Gold Coin",
    "Rokakaka", 
    "Ancient Scroll",
    "Caesar's Headband",
    "Clackers",
    "Diamond",
    "Dio's Diary",
    "Mysterious Arrow",
    "Quinton's Glove",
    "Rib Cage of The Saint's Corpse",
    "Zeppeli's Hat",
    "Stone Mask",
    "Steel Ball",
    "Pure Rokakaka",
    "Lucky Arrow",
    "DIO's Headband",
    "Green Candy",
    "Red Candy",
    "Yellow Candy",
    "Blue Candy"
}

local Max_Space = {
    ["Mysterious Arrow"] = 25,
    ["Lucky Arrow"] = 10,
    ["Rokakaka"] = 25,
    ["Gold Coin"] = 45,
    ["Ancient Scroll"] = 10,
    ["Caesar's Headband"] = 10,
    ["Clackers"] = 10,
    ["Diamond"] = 30,
    ["Dio's Diary"] = 10,
    ["Quinton's Glove"] = 10,
    ["Rib Cage of The Saint's Corpse"] = 20,
    ["Zeppeli's Hat"] = 10,
    ["Stone Mask"] = 10,
    ["Steel Ball"] = 10,
    ["Pure Rokakaka"] = 10,
    ["Yellow Candy"] = 45,
    ["Blue Candy"] = 45,
    ["Red Candy"] = 45,
    ["Green Candy"] = 45
}

local can_item_farmma = true

function SendMessageEMBED(url, payload)
    local http = game:GetService("HttpService")

    local success, response = pcall(function()
        return request({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = http:JSONEncode(payload)
        })
    end)

    if not success then
        warn("[Webhook] Request failed:", response)
    elseif response.StatusCode < 200 or response.StatusCode >= 300 then
        warn("[Webhook] HTTP error:", response.StatusCode, response.Body)
    end
end

function KynInternal.press_key(key,duration)
task.spawn(function()
for i = 1,5 do
local args = {
    [1] = "InputBegan",
    [2] = {
        ["Input"] = key
    }
}

local char = LocalPlayer.Character
if char then
    local event = char:FindFirstChild("RemoteEvent")
    if event then event:FireServer(unpack(args)) end
end
end
task.wait(duration)
local args = {
    [1] = "InputEnded",
    [2] = {
        ["Input"] = key
    }
}

game:GetService("Players").LocalPlayer.Character.RemoteEvent:FireServer(unpack(args))
end)
end

function KynInternal.waitForOption(options, optionName, timeout)
    local deadline = os.clock() + timeout

    repeat
        if not options or not options.Parent then
            return nil
        end

        local clickcontinue = PlayerGui.DialogueGui:FindFirstChild("ClickContinue",true)
        if clickcontinue then
            firesignal(clickcontinue.MouseButton1Click)
        end

        local option = options:FindFirstChild(optionName)

        if option then
            local button = option:FindFirstChild("TextButton", true)

            if button and button:IsA("TextButton") then
                return button
            end
        end

        task.wait(0.1)
    until os.clock() >= deadline

    return nil
end

function KynInternal.waitDialogueClick(timeout, optionName)
    local deadline = os.clock() + timeout
    while os.clock() < deadline do
        local gui = PlayerGui:FindFirstChild("DialogueGui")
        if not gui then
            task.wait(0.1)
        else
            local frame = gui:FindFirstChild("Frame")
            local options = frame and frame:FindFirstChild("Options")

            if options and optionName then
                local opt = options:FindFirstChild(optionName)
                local tb = opt and opt:FindFirstChild("TextButton")
                if tb and tb:IsA("TextButton") then
                    pcall(function() firesignal(tb.MouseButton1Click) end)
                    task.wait(0.15)
                    return true
                end
            end

            local cc = frame and frame:FindFirstChild("ClickContinue")
            if cc then
                pcall(function() firesignal(cc.MouseButton1Click) end)
            end
            task.wait(0.1)
        end
    end
    return false
end

function KynInternal.buy_req()

    if LocalPlayer.PlayerStats.Money.Value < 7500 then
    return false
    end
    
    local skip = false
    for _,v in pairs(LocalPlayer:WaitForChild("Backpack", 5):GetChildren()) do
        if v.Name == "Requiem Arrow" then
            skip = true
        end
    end
    
    for _,v in pairs(LocalPlayer.Character:GetChildren()) do
        if v.Name == "Requiem Arrow" then
            skip = true
        end
    end

    if skip then
        GuiLib:Notify({
    Title = "Already have Requiem Arrow",
    Content = "Skipping..",
    Duration = 3
})
        return
    end

        GuiLib:Notify({
    Title = "Buying Requiem Arrow",
    Content = "Please wait..",
    Duration = 3
})

local dialogues = workspace:FindFirstChild("Dialogues")
        local npc = dialogues and dialogues:FindFirstChild(
            "Suno the Arrowsmith"
        )
local prompt = npc and npc:FindFirstChild("ProximityPrompt")

        if not prompt then
            error("npc prompt not found")
        end

        fireproximityprompt(prompt)

local dialogueGui = PlayerGui:WaitForChild("DialogueGui", 5)
        local frame = dialogueGui and dialogueGui:WaitForChild("Frame", 5)
        local options = frame and frame:WaitForChild("Options", 5)

        if not options then
            if PlayerGui:FindFirstChild("DialogueGui") then
            firesignal(frame:WaitForChild("ClickContinue",5).MouseButton1Click)
            end
            error("Dialogue options not found")
        end

        local deadline = os.clock() + 15
local got = false

while os.clock() < deadline do
    if LocalPlayer:WaitForChild("Backpack", 5):FindFirstChild("Requiem Arrow")
       or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Requiem Arrow")) then
        got = true
        break
    end

    local dialogueGui = PlayerGui:FindFirstChild("DialogueGui")
    local frame = dialogueGui and dialogueGui:FindFirstChild("Frame")
    local options = frame and frame:FindFirstChild("Options")

    local button = options and options:FindFirstChild("Option1")
    local textButton = button and button:FindFirstChild("TextButton")

    if textButton then
        firesignal(textButton.MouseButton1Click)
        task.wait(0.15)
    else
        local clickcontinue = frame and frame:FindFirstChild("ClickContinue")
        if clickcontinue then
            firesignal(clickcontinue.MouseButton1Click)
            task.wait(0.15)
        else
            task.wait(0.05)
        end
    end
end

if got then
    local closeDeadline = os.clock() + 3
    while PlayerGui:FindFirstChild("DialogueGui") and os.clock() < closeDeadline do
        local dg = PlayerGui.DialogueGui
        local cc = dg:FindFirstChild("ClickContinue", true)
        if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        task.wait(0.1)
    end
    task.wait(0.4)
end

        GuiLib:Notify({
    Title = got and "Success" or "Failed",
    Content = got and "Bought Requiem Arrow." or "Could not buy Requiem Arrow.",
    Duration = 3
})
return got
end

local DiverRuntime = {
    Running = false, Thread = nil, Busy = false,
    State = "IDLE", Cycle = 0, Prepared = false,
}

local WeatherRuntime = {
    Running = false, Thread = nil, Busy = false,
    State = "IDLE", LastKill = 0, LastDisc = 0,
    FarmingBoss = false,
}

function WeatherRuntime.get_stand()
    local stats = LocalPlayer:FindFirstChild("PlayerStats")
    local stand = stats and stats:FindFirstChild("Stand")
    if not stand then return "None" end
    return stand.Value
end

function KynInternal.ddIsHandlingStoneFree()
    if not (GLOBALVAR.AutoDiverDown and DiverRuntime.Running) then
        return false
    end
    if WeatherRuntime.get_stand() == "Stone Free" then
        return true
    end
    local s = DiverRuntime.State
    return s ~= nil and s ~= "IDLE" and s ~= "WAITING_FOR_STONE_FREE"
end

local HUDCache = { HUD = nil, EquippedLabel = nil, PityLabel = nil }

function KynInternal.getHUDPaths()
    local hud = PlayerGui:FindFirstChild("HUD")
    if not hud then return nil end
    if HUDCache.HUD ~= hud then
        HUDCache.HUD = hud
        local main = hud:FindFirstChild("Main")
        local frames = main and main:FindFirstChild("Frames")
        local stands = frames and frames:FindFirstChild("Stands")
        local scroll = stands and stands:FindFirstChild("ScrollingFrame")
        local equipped = scroll and scroll:FindFirstChild("Equipped")
        HUDCache.EquippedLabel = equipped and equipped:FindFirstChild("TextLabel")

        local store = frames and frames:FindFirstChild("Store")
        local list = store and store:FindFirstChild("List")
        local shop = list and list:FindFirstChild("StandShop")
        local chances = shop and shop:FindFirstChild("SkinChances")
        local chanceList = chances and chances:FindFirstChild("List")
        local base = chanceList and chanceList:FindFirstChild("SkinBaseChance")
        HUDCache.PityLabel = base and base:FindFirstChild("Skin_PityCount")
    end
    return HUDCache
end

function KynInternal.is_skin()
    local cache = KynInternal.getHUDPaths()
    local label = cache and cache.EquippedLabel
    if not label or not label.Parent then return nil end
    return label:FindFirstChild("Shiny")
end

function KynInternal.get_pity_count()
    return LocalPlayer.PlayerStats.PityCount.Value
end

function KynInternal.get_skin_name()
    local c = KynInternal.getHUDPaths()
    local label = c and c.EquippedLabel
    if not label or not label.Parent then return nil end

    local text = label.Text:match("^EQUIPPED:%s*(.-)%s*$")
    if not text or text == "" then return nil end

    return text:match("^(.-)%s+%([^()]*%)$")
        or text
end

function KynInternal.swap_slots()
    local hud = PlayerGui:FindFirstChild("HUD")
    local main = hud and hud:FindFirstChild("Main")
    local frames = main and main:FindFirstChild("Frames")
    local stands = frames and frames:FindFirstChild("Stands")
    local scrolling = stands and stands:FindFirstChild("ScrollingFrame")
    local equip_button = stands and stands:FindFirstChild("Equip")

    if not scrolling or not equip_button then
        return nil
    end

    for index = 1, 100 do
        local slot = scrolling:FindFirstChild("Slot" .. index)
        local label = slot and slot:FindFirstChild("TextLabel")

        if not label then
            return nil
        end

        local text = label.Text
        local skin = text:match("SLOT " .. index .. ":%s*(.-)%s*%(")
            or text:match("SLOT " .. index .. ":%s*(.+)")

        if skin and skin == "None" and not table.find(GLOBALVAR.wanted_skins, skin) then
        firesignal(slot.MouseButton1Click)
        task.wait(1)
        firesignal(equip_button.MouseButton1Click)
        task.wait(5)
        return true
        end
    end

        GuiLib:Notify({
    Title = "no free slots, disabling skin farm",
    Content = "Please wait..",
    Duration = 3
    })
    if GLOBALVAR.Novex_SkinFarmToggle then
    GLOBALVAR.Novex_SkinFarmToggle:SetValue(false)
    end
    GLOBALVAR.skin_farm = false
    return false
end

function KynInternal.click_skin_option()
    local character = KynInternal.get_character()
    if not character then
        return false
    end

    local dialogue = PlayerGui:WaitForChild("DialogueGui", 5)
    if not dialogue then return false end

    local frame = dialogue:WaitForChild("Frame", 5)
    if not frame then return false end

    local clickcontinue = PlayerGui.DialogueGui:FindFirstChild("ClickContinue",true)
    if clickcontinue then
        firesignal(clickcontinue.MouseButton1Click)
    end

    local options = frame:WaitForChild("Options", 5)
    if not options then 
        local clickcontinue = PlayerGui.DialogueGui:FindFirstChild("ClickContinue",true)
        if clickcontinue then
            firesignal(clickcontinue.MouseButton1Click)
        end
        return false
    end

    local button = KynInternal.waitForOption(options, "Option1", 4)
    if not button then return false end

    character = KynInternal.get_character()
    if not character then
        return false
    end

    firesignal(button.MouseButton1Click)
    local clickcontinue = PlayerGui.DialogueGui:FindFirstChild("ClickContinue",true)
    if clickcontinue then
        firesignal(clickcontinue.MouseButton1Click)
    end
    return true
end

function KynInternal.use_skin_item(itemName)
    local character = KynInternal.get_character()
    if not character then return false end

    local item = LocalPlayer:WaitForChild("Backpack",1):FindFirstChild(itemName) or character:FindFirstChild(itemName)
    if not item then return false end

    unequip_tools()

    character = KynInternal.get_character()
    if not character then return false end

    item = LocalPlayer:WaitForChild("Backpack",1):FindFirstChild(itemName)
    if not item then return false end

    item.Parent = character

    character = KynInternal.get_character()
    if not character then return false end

    if item.Parent ~= character then
        return false
    end

    item:Activate()

    return KynInternal.click_skin_option()
end

function KynInternal.invoke_with_timeout(remote, timeout, ...)
    if not remote then return false, "remote is nil" end

    local result
    local done = false
    local args = table.pack(...)

    task.spawn(function()
        local ok, ret = pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end)
        result = { ok = ok, ret = ret }
        done = true
    end)

    local deadline = os.clock() + (timeout or 5)
    while not done and os.clock() < deadline do
        task.wait(0.05)
    end

    if not done then
        return false, "timeout"
    end

    return result.ok, result.ret
end

function KynInternal.is_wanted_skin(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local wanted = GLOBALVAR.wanted_skins
    if type(wanted) ~= "table" then
        return nil
    end

    for _, wantedName in ipairs(wanted) do
        if type(wantedName) == "string" and name == wantedName then
            return true
        end
    end

    return false
end

function KynInternal.can_roka_current_skin()
    local first = KynInternal.get_skin_name()
    if KynInternal.is_wanted_skin(first) ~= false then
        return false
    end

    task.wait(0.1)

    local second = KynInternal.get_skin_name()
    if second ~= first or KynInternal.is_wanted_skin(second) ~= false then
        return false
    end

    local stats = LocalPlayer:FindFirstChild("PlayerStats")
    local stand = stats and stats:FindFirstChild("Stand")
    if not stand or stand.Value == "None" then
        return false
    end

    return true
end

local TeleportService = game:GetService("TeleportService")

function KynInternal.serverhop()

        GuiLib:Notify({
    Title = "Server Hopping",
    Content = "Please wait..",
    Duration = 3
})

    local PlaceId = game.PlaceId
    local JobId = game.JobId
    local cursor = ""

    for page = 1, 10 do
        local url = "https://games.roblox.com/v1/games/"
            .. PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"

        if cursor ~= "" then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local success, result = pcall(function()
            local response = game:HttpGet(url)
            return HttpService:JSONDecode(response)
        end)

        if not success or not result or not result.data then
            warn("Server hop failed: couldn't fetch server list.")
            return
        end

        for _, server in ipairs(result.data) do
            if server.id ~= JobId
                and server.playing < server.maxPlayers then

                local teleportSuccess, teleportError = pcall(function()

if queue_on_teleport then
    KynInternal.queueKynTeleport("https://raw.githubusercontent.com/lklkkklkllklk/temp/refs/heads/main/main.lua")
elseif queueonteleport then
    KynInternal.queueKynTeleport("https://raw.githubusercontent.com/lklkkklkllklk/temp/refs/heads/main/main.lua")
else
    warn("[Server Hop] Executor does not support queue-on-teleport.")
end

TeleportService:TeleportToPlaceInstance(
    PlaceId,
    server.id,
    LocalPlayer,
    nil
)
                end)

                if not teleportSuccess then
                    warn("Teleport failed:", teleportError)
                end

                return
            end
        end

        cursor = result.nextPageCursor
        if not cursor then
            break
        end
    end

    warn("Server hop failed: no available server found.")
end

function KynInternal.firePrompt(prompt)
    if not prompt or not prompt.Parent or prompt.Enabled == false then return false end
    local oldHold = prompt.HoldDuration
    prompt.HoldDuration = 0
    local ok = false
    if fireproximityprompt then
        ok = pcall(fireproximityprompt, prompt, 0, true)
            or pcall(fireproximityprompt, prompt)
    end
    if not ok and getconnections then
        local conns = getconnections(prompt.Triggered)
        for _, c in ipairs(conns or {}) do
            if c.Fire then pcall(function() c:Fire(prompt) end) end
        end
        ok = true
    end
    prompt.HoldDuration = oldHold
    return ok
end

local can_sell = true
local skin_busy = false

local money = LocalPlayer.PlayerStats.Money.Value
local SellRuntime = {
    Running = false,
    Locked = false,
    NextAt = 0,
    Thread = nil,
}

function KynInternal.acquireSellLock()
    if SellRuntime.Locked then return false end
    SellRuntime.Locked = true
    return true
end

function KynInternal.releaseSellLock()
    SellRuntime.Locked = false
end

function KynInternal.sellOne(tool)
    if not tool or not tool:IsA("Tool") or not tool.Parent then
        return false
    end

    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return false end

    local function correctToolEquipped()
        if tool.Parent ~= char then return false end

        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and v ~= tool then
                return false
            end
        end

        return true
    end

    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            v.Parent = backpack
        end
    end

    tool.Parent = char
    task.wait(0.1)

    if not correctToolEquipped() then
        return false
    end

    local dialogues = workspace:FindFirstChild("Dialogues")
    local merchant = dialogues and dialogues:FindFirstChild(
        "ShiftPlox, The Travelling Merchant"
    )
    local prompt = merchant and merchant:FindFirstChild("ProximityPrompt")

    if not prompt then return false end
    if not correctToolEquipped() then return false end

    if not KynInternal.firePrompt(prompt) then
        return false
    end

    for _, option in ipairs({"Option1", "Option1", "Option6"}) do
        if not correctToolEquipped() then
            warn("[Sell All] Equipped item changed; aborting sale")
            return false
        end

        if not KynInternal.waitDialogueClick(5, option) then
            return false
        end
    end

    local deadline = os.clock() + 2.5

    while os.clock() < deadline and tool.Parent do
        RunService.Heartbeat:Wait()
    end

    return tool.Parent == nil
end

function KynInternal.sellAllLoop()
    while SellRuntime.Running do
        if global_lock
            or not GLOBALVAR.sellall
            or not can_sell
            or skin_busy then
            task.wait(0.6)
            continue
        end

        task.wait(0.1)
        if not SellRuntime.Running then break end

        local inventoryAcquired = false
        local sellAcquired = false

        local success, err = pcall(function()
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if not backpack then return end

            local sellNames = {}
            for _, name in ipairs(GLOBALVAR.itemsToSell or {}) do
                sellNames[name] = true
            end

            if GLOBALVAR.skin_farm then
                sellNames["Rokakaka"] = nil
                sellNames["Redeemed Rokakaka"] = nil

                for _, name in ipairs(GLOBALVAR.selectedArrows or {}) do
                    sellNames[name] = nil
                end
            end

            local toSell = {}
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool")
                    and item.Name ~= "Lucky Arrow"
                    and sellNames[item.Name] then
                    toSell[#toSell + 1] = item
                end
            end

            if #toSell == 0 then return end

if not KynInternal.acquireSellLock() then
    return
end
sellAcquired = true

while SellRuntime.Running and GLOBALVAR.sellall do
    if KynInternal.acquireInventory() then
        inventoryAcquired = true
        break
    end

    task.wait(0.05)
end

if not inventoryAcquired then
    return
end

            if not can_sell or skin_busy or global_lock then
                return
            end

            local moneyBefore = LocalPlayer.PlayerStats.Money.Value

            for _, item in ipairs(toSell) do
                if not SellRuntime.Running
                    or not GLOBALVAR.sellall
                    or not can_sell
                    or skin_busy
                    or global_lock then
                    break
                end

                if item.Parent == backpack then
                    KynInternal.sellOne(item)
                end
            end

            local moneyAfter = LocalPlayer.PlayerStats.Money.Value

            if GLOBALVAR.webhook_enabled
                and moneyAfter > moneyBefore then
                SendMessageEMBED(GLOBALVAR.webhook, {
                    content = "",
                    embeds = {{
                        title = "Sold Inventory",
                        description = ("$%d -> $%d"):format(
                            moneyBefore, moneyAfter
                        ),
                        color = 65280,
                        footer = { text = "Kyn" },
                    }},
                })
            end
        end)

        if sellAcquired then
            KynInternal.releaseSellLock()
        end

        if inventoryAcquired then
            KynInternal.releaseInventory()
        end

        if not success then
            warn("[Sell All] " .. tostring(err))
        end

        task.wait(0.5)
    end
end

function startSellAll()
    if SellRuntime.Running then return end
    SellRuntime.Running = true
    SellRuntime.Thread = task.spawn(KynInternal.sellAllLoop)
end

function stopSellAll()
    SellRuntime.Running = false
    SellRuntime.Thread = nil
end

function KynInternal.onSellToggle()
    if GLOBALVAR.sellall and not SellRuntime.Running then startSellAll()
    elseif not GLOBALVAR.sellall and SellRuntime.Running then stopSellAll() end
end

function KynInternal.buy_roka()
    if GLOBALVAR.BuyRokas and LocalPlayer.PlayerStats.Money.Value >= 11250 then
        local args = {[1] = "PurchaseShopItem", [2] = {["ItemName"] = "5x Rokakaka"}}
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("RemoteEvent") then
            char:WaitForChild("RemoteEvent", 5):FireServer(unpack(args))
        end

        if GLOBALVAR.webhook_enabled then
        local embed = {
    ["title"] = "Success",
    ["description"] = "Bought 5x Rokakakas",
    ["color"] = 65280,
    ["footer"] = {
        ["text"] = "Kyn"
    }
}
local payload = {
    content = "",
    embeds = {embed},
}
SendMessageEMBED(GLOBALVAR.webhook, payload)
end

        GuiLib:Notify({
    Title = "Success",
    Content = "Bought 5x Rokakakas",
    Duration = 3
})
    end
end

function KynInternal.buy_arrow()
    if GLOBALVAR.BuyArrows and LocalPlayer.PlayerStats.Money.Value >= 3375 then
        local args = {[1] = "PurchaseShopItem", [2] = {["ItemName"] = "5x Mysterious Arrow"}}
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("RemoteEvent") then
            char:WaitForChild("RemoteEvent", 5):FireServer(unpack(args))
        end

        if GLOBALVAR.webhook_enabled then
        local embed = {
    ["title"] = "Success",
    ["description"] = "Bought 5x Arrows",
    ["color"] = 65280,
    ["footer"] = {
        ["text"] = "Kyn"
    }
}
local payload = {
    content = "",
    embeds = {embed},
}
SendMessageEMBED(GLOBALVAR.webhook, payload)
end

        GuiLib:Notify({
    Title = "Success",
    Content = "Bought 5x Arrows",
    Duration = 3
})
    end
end

function KynInternal.buy_rib()
    if GLOBALVAR.BuyRibs and LocalPlayer.PlayerStats.Money.Value >= 15750 then
        local args = {[1] = "PurchaseShopItem", [2] = {["ItemName"] = "5x Rib Cage of the Saint's Corpse"}}
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("RemoteEvent") then
            char:WaitForChild("RemoteEvent", 5):FireServer(unpack(args))
        end

        if GLOBALVAR.webhook_enabled then
        local embed = {
    ["title"] = "Success",
    ["description"] = "Bought 5x Ribcages",
    ["color"] = 65280,
    ["footer"] = {
        ["text"] = "Kyn"
    }
}
local payload = {
    content = "",
    embeds = {embed},
}
SendMessageEMBED(GLOBALVAR.webhook, payload)
end

        GuiLib:Notify({
    Title = "Success",
    Content = "Bought 5x Ribcages",
    Duration = 3
})
    end
end

function KynInternal.buy_lucky()
    if GLOBALVAR.BuyLuckyArrows then
        local args = {[1] = "PurchaseShopItem", [2] = {["ItemName"] = "1x Lucky Arrow"}}
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("RemoteEvent") then
            char:WaitForChild("RemoteEvent", 5):FireServer(unpack(args))
        end

        if GLOBALVAR.webhook_enabled then
        local embed = {
    ["title"] = "Success",
    ["description"] = "Bought Lucky Arrow",
    ["color"] = 65280,
    ["footer"] = {
        ["text"] = "Kyn"
    }
}
local payload = {
    content = "",
    embeds = {embed},
}
SendMessageEMBED(GLOBALVAR.webhook, payload)
end

        GuiLib:Notify({
    Title = "Success",
    Content = "Bought Lucky Arrow",
    Duration = 3
})
    end
end

GLOBALVAR.wanted_skins = GLOBALVAR.wanted_skins or {
    "Joe's Pride",
    "Bloodthirster",
    "Ghost World",
    "Crazy Overseer",
    "The Doorman",
    "SCP-106",
    "Diva Down",
    "Bondrewd",
    "Jack-O-Platinum",
    "Grim Reaper",
    "Ghostface",
    "Astral Enigma",
    "The Bunny Devil",
    "Wispy Willow",
    "Haunted Jack-O-Platinum"
}

function KynInternal.spoof_user()
    local s,f = pcall(function()
    local hud = PlayerGui:FindFirstChild("HUD")
    if not hud then return end

    local playerlist = hud:FindFirstChild("Playerlist")
    if playerlist then
        for _, v in ipairs(playerlist:GetChildren()) do
            local playerName = v:FindFirstChild("PlayerName")
            if playerName then
                playerName.Text = (v.Name == LocalPlayer.Name) and "User" or "Player"
            end
        end
    end

    local living = workspace:FindFirstChild("Living")
    if living then
        for _, v in ipairs(living:GetChildren()) do
            local hum = v:FindFirstChildOfClass("Humanoid")
            if hum and Players:FindFirstChild(v.Name) then
                hum.DisplayName = "Player"
            end
        end
    end
end) 
if f then warn(f) end
end

function KynInternal.decide_skin_action()
    if not GLOBALVAR.skin_farm then
        return "STOP"
    end

    local stand = LocalPlayer.PlayerStats.Stand.Value
    local skin_name = KynInternal.get_skin_name()

    if table.find(GLOBALVAR.wanted_skins, skin_name) then
        return "WANTED"
    end

    if GLOBALVAR.evo_skins
        and table.find(GLOBALVAR.evo_stands, stand) and not KynInternal.is_skin() then
        return "EVOLVE"
    end

    if stand == "None" then
        return "ARROW"
    end

    return "ROKA"
end

local lastWebhookSkin = nil
local lastWebhookTime = 0

function KynInternal.send_skin_webhook(skin_name)
    if not GLOBALVAR.webhook_enabled then return end

    local webhook = GLOBALVAR.webhook
    if type(webhook) ~= "string" or webhook == "" then
        warn("[Webhook] Webhook URL is empty.")
        return
    end

    if type(skin_name) ~= "string" or skin_name == "" or skin_name == "None" then
        warn("[Webhook] Invalid skin name; skipping.")
        return
    end

    if not KynInternal.is_skin() then return end

    local now = os.clock()
    if skin_name == lastWebhookSkin or now - lastWebhookTime < 15 then
        return
    end

    local wanted = KynInternal.is_wanted_skin(skin_name) == true

    local embed = {
        title = "New Skin",
        description = skin_name,
        color = wanted and 16711680 or 16753920,
        fields = {
            {
                name = "Keep?",
                value = tostring(wanted),
                inline = true
            }
        },
        footer = {
            text = "Kyn"
        }
    }

    local payload = {
        content = wanted and "@everyone" or "",
        embeds = {embed},
        allowed_mentions = {
            parse = wanted and {"everyone"} or {}
        }
    }

    local ok, err = pcall(function()
        SendMessageEMBED(webhook, payload)
    end)

    if ok then
        lastWebhookSkin = skin_name
        lastWebhookTime = now
    else
        warn("[Webhook] Failed:", tostring(err))
    end
end

local roka_cd = 0
local req_cd = 0
local ITEM_CD = 5
local skin_cd = 0
local wanted_cd = 0
local can_use_arrow = true

function KynInternal.skin_farm()

    if SellRuntime.Locked then
    return
    end

    local s,f = pcall(function()
    
    if LocalPlayer.Character:FindFirstChild("SummonedStand") and LocalPlayer.Character:FindFirstChild("SummonedStand").Value then

local char = LocalPlayer.Character
local remote = char and char:FindFirstChild("RemoteFunction")

local ok = KynInternal.invoke_with_timeout(
    remote,
    5,
    "ToggleStand",
    "Toggle"
)

if not ok then
    warn("[Skin Farm] Stand toggle timed out or failed")
    return
end
    end
    
    local skin_check = KynInternal.is_skin()
    if skin_check then
        if os.clock() - skin_cd < ITEM_CD then
           skin_busy = false
           return
        end

        skin_cd = os.clock()

        local skin_name = KynInternal.get_skin_name()
        KynInternal.send_skin_webhook(skin_name)
    end

    local action = KynInternal.decide_skin_action()

    if GLOBALVAR.AutoDiverDown and not DiverRuntime.Running
        and WeatherRuntime.get_stand() == "Stone Free" then
        GLOBALVAR.startDiverDown()
        skin_busy = false
        return
    end

    if action ~= "WANTED" then
    if skin_busy or not GLOBALVAR.skin_farm then
        return
    end
    end

    if action == "WANTED" then

        if GLOBALVAR.swapslots then
            KynInternal.swap_slots()
        else
            GLOBALVAR.skin_farm = false
        end

        if os.clock() - wanted_cd < ITEM_CD then
           return
        end

        wanted_cd = os.clock()

        local skin_name = KynInternal.get_skin_name()
        KynInternal.send_skin_webhook(skin_name)
        skin_busy = false
    elseif action == "ARROW" and can_use_arrow then
    can_use_arrow = false
    can_sell = false

    if not GLOBALVAR.selectedArrows or #GLOBALVAR.selectedArrows == 0 then
        GuiLib:Notify({
            Title = "Skin Farm",
            Content = "No arrows selected",
            Type = "warning",
            Duration = 5,
        })
        can_use_arrow = true
        can_sell = true
        return
    end

    local eligible = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    local restrictLucky = GLOBALVAR.onlyLAwhenPityGood and KynInternal.get_pity_count() >= 25
    for _, selectedItem in ipairs(GLOBALVAR.selectedArrows) do
        if not (restrictLucky and selectedItem == "Lucky Arrow")
            and ((backpack and backpack:FindFirstChild(selectedItem))
                or (char and char:FindFirstChild(selectedItem))) then
            eligible[#eligible + 1] = selectedItem
        end
    end
    if #eligible == 0 then
        skin_busy = false
        can_use_arrow = true
        can_sell = true
        return
    end
    local item_to_use = eligible[math.random(1, #eligible)]

    if not LocalPlayer:WaitForChild("Backpack",5):FindFirstChild(item_to_use) and not LocalPlayer.Character:FindFirstChild(item_to_use) then skin_busy = false can_use_arrow = true can_sell = true return end

    local _, remote = KynInternal.get_character()

    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", {
        Skill = "Vitality I",
        SkillTreeType = "Character",
    })
    task.wait()
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", {
        Skill = "Vitality II",
        SkillTreeType = "Character",
    })
    task.wait()
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", {
        Skill = "Vitality III",
        SkillTreeType = "Character",
    })
    task.wait()
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", {
        Skill = "Worthiness",
        SkillTreeType = "Character",
    })

    GuiLib:Notify({
    Title = "Using "..item_to_use,
    Content = "Please wait..",
    Duration = 3
    })

    local old_stand = LocalPlayer.PlayerStats.Stand.Value
    if not KynInternal.use_skin_item(item_to_use) then
        if PlayerGui:FindFirstChild("DialogueGui") then
        local clickcontinue = PlayerGui.DialogueGui:FindFirstChild("ClickContinue",true)
        if clickcontinue then
            firesignal(clickcontinue.MouseButton1Click)
            can_use_arrow = true
            can_sell = true
            return
        end
    end
        can_sell = true
        can_use_arrow = true
        return
    end

    local deadline = os.clock() + 8
    while LocalPlayer.PlayerStats.Stand.Value == old_stand and os.clock() < deadline do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.1)
    end

    if LocalPlayer.PlayerStats.Stand.Value == old_stand then
        can_use_arrow = true
        can_sell = true
    end

    skin_busy = false
    DialogueBusy = false
    can_item_farmma = true
    can_sell = true
    task.wait(2)
    elseif action == "ROKA" and not skin_busy then
        if os.clock() - roka_cd < ITEM_CD then
           return
        end

        if not KynInternal.can_roka_current_skin() then
            return
        end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
local char = LocalPlayer.Character

local hasRoka =
    (backpack and (
        backpack:FindFirstChild("Rokakaka")
        or backpack:FindFirstChild("Redeemed Rokakaka")
    ))
    or (char and (
        char:FindFirstChild("Rokakaka")
        or char:FindFirstChild("Redeemed Rokakaka")
    ))

if not hasRoka then
    DialogueBusy = false
    can_item_farmma = true
    can_sell = true
    skin_busy = false
    return
end     
  
        can_item_farmma = false
        can_sell = false
        skin_busy = true
        DialogueBusy = true

        local skin_name = KynInternal.get_skin_name()

        if skin_name == "Star Platinum" or skin_name == nil or skin_name == "None" then
        local deadline = os.clock() + 2

        repeat
        task.wait(0.05)
        local current_name = KynInternal.get_skin_name()

        if current_name ~= "Star Platinum" and current_name ~= nil then
            skin_name = current_name
            break
        end
        until os.clock() >= deadline
        end

        if KynInternal.get_skin_name() == "None" then
            can_item_farmma = true
            can_sell = true
            skin_busy = false
            DialogueBusy = false
            return
        end

        GuiLib:Notify({
        Title = "Using Rokakaka",
        Content = "Please wait..",
        Duration = 3
        })

        roka_cd = os.clock()

        local confirmedSkin = KynInternal.get_skin_name()
        if KynInternal.is_wanted_skin(confirmedSkin) ~= false then
            skin_busy = false
            can_sell = true
            DialogueBusy = false
            can_item_farmma = true
            return
        end

        local skin_name = KynInternal.get_skin_name()

if skin_name == "Star Platinum" or skin_name == nil then
    local deadline = os.clock() + 2

    repeat
        task.wait(0.05)
        local current_name = KynInternal.get_skin_name()

        if current_name ~= "Star Platinum" and current_name ~= nil then
            skin_name = current_name
            break
        end
    until os.clock() >= deadline
end

        local skin_name = KynInternal.get_skin_name()
        if table.find(GLOBALVAR.wanted_skins, skin_name) then
            skin_busy = false
            can_sell = true
            DialogueBusy = false
            can_item_farmma = true
            return
        end

        if LocalPlayer:WaitForChild("Backpack",5):FindFirstChild("Redeemed Rokakaka") then
        if not KynInternal.use_skin_item("Redeemed Rokakaka") then
        skin_busy = false
        can_sell = true
        DialogueBusy = false
        can_item_farmma = true
        return
        end
    else
        if not KynInternal.use_skin_item("Rokakaka") then
        skin_busy = false
        can_sell = true
        DialogueBusy = false
        can_item_farmma = true
        return
        end
    end

        local old_stand = LocalPlayer.PlayerStats.Stand.Value
    local deadline = os.clock() + 8
    while LocalPlayer.PlayerStats.Stand.Value == old_stand and os.clock() < deadline do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.1)
    end

    skin_busy = false
    can_sell = true
    if not GLOBALVAR.AutoDiverDown
    and not GLOBALVAR.AutoWeatherReport then
    DialogueBusy = false
end

    elseif action == "EVOLVE" and not skin_busy then
    if os.clock() < req_cd then
        return
    end

    skin_busy = true

    if not LocalPlayer.Backpack:FindFirstChild("Requiem Arrow")
       and not LocalPlayer.Character:FindFirstChild("Requiem Arrow") then
        if not KynInternal.buy_req() then
            skin_busy = false
            return
        end
        local bp_deadline = os.clock() + 3
        while os.clock() < bp_deadline
              and not LocalPlayer.Backpack:FindFirstChild("Requiem Arrow")
              and not LocalPlayer.Character:FindFirstChild("Requiem Arrow") do
            task.wait(0.1)
        end
    end

        GuiLib:Notify({
        Title = "Using Requiem Arrow",
        Content = "Please wait..",
        Duration = 3
    })

    req_cd = os.clock() + 10
    local old_stand = LocalPlayer.PlayerStats.Stand.Value

    if not KynInternal.use_skin_item("Requiem Arrow") then
        if PlayerGui:FindFirstChild("DialogueGui") then
            local cc = PlayerGui.DialogueGui:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        skin_busy = false
        return 
    end

    local deadline = os.clock() + 8
    while LocalPlayer.PlayerStats.Stand.Value == old_stand and os.clock() < deadline do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.1)
    end

    task.wait(5)
    skin_busy = false
end
end)

if f then warn("skin farm: "..f) end
skin_busy = false
can_use_arrow = true
can_sell = true
if not GLOBALVAR.AutoDiverDown
    and not GLOBALVAR.AutoWeatherReport then
    DialogueBusy = false
end
end

local SkinFarm = {
    Running = false,
    Busy = false,
    Thread = nil,
    NextAt = 0,
}

function KynInternal.skinFarmLoop()
    while SkinFarm.Running do
        if global_lock then task.wait(0.5); continue end
        if not GLOBALVAR.skin_farm or SkinFarm.Busy then
            task.wait(0.5)
            continue
        end

        if KynInternal.ddIsHandlingStoneFree() then
            task.wait(0.5)
            continue
        end

        if SellRuntime.Locked then
            task.wait(0.1)
            continue
        end

        if not KynInternal.acquireInventory() then task.wait(0.25); continue end
        SkinFarm.Busy = true
        local ok, err = pcall(KynInternal.skin_farm)
        SkinFarm.Busy = false
        KynInternal.releaseInventory()
        if not ok then warn("[Skin Farm] " .. tostring(err)) end
        task.wait(0.25)
    end
end

function startSkinFarm()
    if SkinFarm.Running then return end
    SkinFarm.Running = true
    SkinFarm.Thread = task.spawn(KynInternal.skinFarmLoop)
end

function stopSkinFarm()
    SkinFarm.Running = false
    SkinFarm.Thread = nil
end

local V347 = {
    mainLoopSeconds = 0.2,
    sweepStepSeconds = 0.07,
    pingDivisor = 220,
    pingDelayMaxSeconds = 0.1,
    emptyRescanSeconds = 3,
    hopOnEmptyWaitSeconds = 0.3,
}

function KynInternal.V189()
    local UIS = game:GetService("UserInputService")
    return UIS.TouchEnabled and not UIS.KeyboardEnabled
end
if KynInternal.V189() then
    V347.mainLoopSeconds = 0.35
    V347.sweepStepSeconds = 0.14
    V347.emptyRescanSeconds = 4
    V347.hopOnEmptyWaitSeconds = 0.45
end

function KynInternal.V194(Arg1)
    local V3 = Arg1 or 0
    local V6 = KynInternal.V189() and math.max(V3, 0.06) or V3
    return V6
end

function KynInternal.V242()
    local ok, ret = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 100
    end)
    return ok and ret or 50
end

function KynInternal.V227()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        return c:FindFirstChild("HumanoidRootPart")
    end
    return c and c:WaitForChild("HumanoidRootPart", 5)
end

local V172 = { registeredItems = {} }
local V312 = {}
local V313 = {}

function KynInternal.V314(Arg1)
    local V3 = V312[Arg1]
    if V3 then
        if V313[Arg1] then
            V313[Arg1]:Disconnect()
            V313[Arg1] = nil
        end
        V312[Arg1] = nil
        if V172.registeredItems[V3] then
            local V6 = table.find(V172.registeredItems[V3], Arg1)
            if V6 then
                table.remove(V172.registeredItems[V3], V6)
            end
            if #V172.registeredItems[V3] == 0 then
                V172.registeredItems[V3] = nil
            end
        end
        return
    else
        return
    end
end

function KynInternal.V316(Arg1)
    if Arg1.ClassName == "ProximityPrompt" then
        if Arg1.Enabled then
            return
        elseif Arg1.Parent:FindFirstChild("PointLight", true) then
            local V3 = Arg1.Parent:FindFirstChildWhichIsA("MeshPart") or Arg1.Parent:FindFirstChildWhichIsA("Part")
            if V3 and 1 <= V3.Transparency then
                return
            else
                local ObjectText = Arg1.ObjectText
                if not V172.registeredItems[ObjectText] then
                    V172.registeredItems[ObjectText] = {}
                end
                if table.find(V172.registeredItems[ObjectText], Arg1) then
                    return
                else
                    table.insert(V172.registeredItems[ObjectText], Arg1)
                    V312[Arg1] = ObjectText
                    local Connection = Arg1.AncestryChanged:Connect(function()
                        if not Arg1:IsDescendantOf(workspace) then
                            KynInternal.V314(Arg1)
                        end
                    end)
                    V313[Arg1] = Connection
                    return
                end
            end
        else
            return
        end
    else
        return
    end
end

pcall(function()
    for _, Descendant in pairs(workspace.Item_Spawns.Items:GetDescendants()) do
        KynInternal.V316(Descendant)
    end
    workspace.Item_Spawns.Items.DescendantAdded:Connect(KynInternal.V316)
    workspace.Item_Spawns.Items.DescendantRemoving:Connect(KynInternal.V314)
end)

local priority_list = {
    ["Lucky Arrow"] = 1,
    ["Rokakaka"] = 1,
    ["Dio's Diary"] = 2,
    ["Rib Cage of The Saint's Corpse"] = 2,
    ["Ancient Scroll"] = 2,
    ["Stone Mask"] = 2,
    ["Clackers"] = 2,
    ["Quinton's Glove"] = 2,
    ["Zeppeli's Hat"] = 2,
    ["Steel Ball"] = 2,
    ["Diamond"] = 3,
}

function KynInternal.get_priority(name)
    return priority_list[name] or 3
end

function KynInternal.V354(Arg1)
    local V3 = 0
    for _, Child in pairs(LocalPlayer:WaitForChild("Backpack", 5):GetChildren()) do
        if Child.Name == Arg1 then
            V3 = V3 + 1
        end
    end

    local character = LocalPlayer.Character
    if character then
        for _, Child in pairs(character:GetChildren()) do
            if Child:IsA("Tool") and Child.Name == Arg1 then
                V3 = V3 + 1
            end
        end
    end

    local V6 = Max_Space[Arg1] or 999
    return V3 >= V6
end

local ItemFarmRuntime = {
    Running = false,
    Thread = nil,
    Selected = {},
    SelectedOrder = {},
    SortDirty = true,
    Generation = 0,
}

function KynInternal.Utils_basePart(obj)
    if not obj or not obj.Parent then return nil end
    if obj.Parent:IsA("BasePart") then return obj.Parent end
    return obj.Parent:FindFirstChildWhichIsA("BasePart", true)
        or (obj.Parent.Parent and obj.Parent.Parent:FindFirstChildWhichIsA("BasePart", true))
end

function KynInternal.is_item_visible(part)
    if not part or not part.Parent then return false end
    if part.Transparency >= 1 then return false end
    if part.LocalTransparencyModifier >= 1 then return false end
    return true
end

function KynInternal.Utils_invisible(part)
    if not part or not part.Parent then return true end
    if part.Transparency >= 1 then return true end
    if part.LocalTransparencyModifier >= 1 then return true end
    return false
end

function KynInternal.rebuildSelected()
    ItemFarmRuntime.Selected = {}
    ItemFarmRuntime.SelectedOrder = {}
    for _, name in ipairs(GLOBALVAR.itemsToGrab or {}) do
        if not ItemFarmRuntime.Selected[name] then
            ItemFarmRuntime.Selected[name] = true
            table.insert(ItemFarmRuntime.SelectedOrder, name)
        end
    end
    table.sort(ItemFarmRuntime.SelectedOrder, function(a, b)
        local pa, pb = KynInternal.get_priority(a), KynInternal.get_priority(b)
        if pa == pb then return a < b end
        return pa < pb
    end)
end

function KynInternal.moveToPart(part, shouldContinue)
    if not can_item_farmma or global_lock then
        return false
    end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local target = CFrame.new(part.Position + Vector3.new(0, 3, 0))

    if cancelled then return false end
    root.CFrame = target
    root.AssemblyLinearVelocity = Vector3.zero

    local standmorph5r = root.Parent:FindFirstChild("StandMorph")
    if standmorph5r then
        standmorph5r.PrimaryPart.CFrame = target
    end
    return true
end

function KynInternal.tryPickup(part, data)
    if not can_item_farmma then return false end
    if not part or not part.Parent or KynInternal.Utils_invisible(part) then return false end

    local prompt = data and data.Obj
    if not prompt or not prompt.Parent then
        prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    if not prompt then return false end

    local parent = prompt.Parent
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if (part.Position - root.Position).Magnitude > 6 then return false end

    local remote = prompt:FindFirstChildOfClass("RemoteEvent")
        or parent:FindFirstChildWhichIsA("RemoteEvent", true)
    if not remote then return false end

    local deadline = os.clock() + 1.5
    while os.clock() < deadline do
        if not can_item_farmma then break end
        if not prompt.Parent or not parent.Parent
            or not parent:FindFirstChild("ProximityPrompt") then
            return true
        end

        if prompt.Enabled then
            return false
        end

        if not parent:FindFirstChild("PointLight", true) then
            return false
        end

        if not ItemFarmRuntime.Running or not GLOBALVAR.ItemFarm then
            return false
        end

        pcall(function() remote:FireServer() end)
        RunService.Heartbeat:Wait()
    end
    return false
end

function KynInternal.collectItemsLoop(generation)
    local function active()
        return ItemFarmRuntime.Running and GLOBALVAR.ItemFarm
            and ItemFarmRuntime.Generation == generation
    end

    while active() do
        task.wait(0.1)
        if not active() then break end
        if global_lock then task.wait(0.2); continue end
        if DialogueBusy then
            task.wait(0.2)
            continue
        end
        if not GLOBALVAR.ItemFarm or not can_item_farmma then
            task.wait(0.2)
            continue
        end

        if ItemFarmRuntime.SortDirty then
            KynInternal.rebuildSelected()
            ItemFarmRuntime.SortDirty = false
        end

        local s,f = pcall(function()

        local picked = false
        for _, key in ipairs(ItemFarmRuntime.SelectedOrder) do
            if not active() then break end
            if DialogueBusy then break end
            if global_lock then break end
            if not can_item_farmma then break end
            if Runtime.Humanoid and Runtime.Humanoid.Health <= 0.15 then break end
            local list = V172.registeredItems[key]
            if list and #list > 0 then
                local prompt = list[1]
                local part = prompt and KynInternal.Utils_basePart(prompt)
                if part and part.Parent and KynInternal.is_item_visible(part) then
                    if KynInternal.V354(key) then
                        task.wait(0.1)
                        continue
                    end

                    local ok = KynInternal.moveToPart(part, function()
                        return active()
                            and part.Parent ~= nil
                    end)
                    if ok then
                        task.wait(GLOBALVAR.pickup_delay + 0.05)
                        if active() and part.Parent and can_item_farmma then
                            local fired = KynInternal.tryPickup(part, { Obj = prompt })
                            if fired then
                                local deadline = os.clock() + 1.5
                                while os.clock() < deadline
                                    and part.Parent
                                    and prompt.Parent
                                    and active() do
                                    RunService.Heartbeat:Wait()
                                end
                            end
                        end
                    end
                    picked = true
                end
            end
        end

        if not picked then task.wait(0.2) end

        end)
        if f then warn(f) end
    end
end

function startItemFarm()
    if ItemFarmRuntime.Running then return end
    ItemFarmRuntime.Generation += 1
    local generation = ItemFarmRuntime.Generation
    ItemFarmRuntime.Running = true
    ItemFarmRuntime.SortDirty = true
    ItemFarmRuntime.Thread = task.spawn(function()
        local ok, err = pcall(KynInternal.collectItemsLoop, generation)
        if not ok then warn("[Item Farm] Worker error:", err) end
        if ItemFarmRuntime.Generation == generation then
            ItemFarmRuntime.Running = false
            ItemFarmRuntime.Thread = nil
        end
    end)
end

function stopItemFarm()
    ItemFarmRuntime.Generation += 1
    ItemFarmRuntime.Running = false
    local thread = ItemFarmRuntime.Thread
    ItemFarmRuntime.Thread = nil
    if thread and coroutine.status(thread) ~= "dead" then
        pcall(task.cancel, thread)
    end
end

function KynInternal.onItemFarmToggle()
    if GLOBALVAR.ItemFarm and not ItemFarmRuntime.Running then
        startItemFarm()
    elseif not GLOBALVAR.ItemFarm and ItemFarmRuntime.Running then
        stopItemFarm()
    end
end

local CONFIG_FILE = CONFIG_FOLDER .. "/settings.json"

local AB_CONFIG = {
    enabled       = false,
    reblocking    = true,
    distance = 50,
    AutoEpitaph = false,
    AutoEpitaphKey = Enum.KeyCode.T
}
GLOBALVAR.AutoBlockConfig = GLOBALVAR.AutoBlockConfig or {}
if type(GLOBALVAR.AutoBlockConfig.AutoEpitaphKey) == "string" then
    GLOBALVAR.AutoBlockConfig.AutoEpitaphKey = Enum.KeyCode[GLOBALVAR.AutoBlockConfig.AutoEpitaphKey] or Enum.KeyCode.T
end

for key, value in pairs(AB_CONFIG) do
    if GLOBALVAR.AutoBlockConfig[key] == nil then
        GLOBALVAR.AutoBlockConfig[key] = value
    end
end

GLOBALVAR.FaceMinDot = tonumber(GLOBALVAR.FaceMinDot) or 0
GLOBALVAR.StableTime = tonumber(GLOBALVAR.StableTime) or 0

function KynInternal.serializeCustomThemes()
    local out = {}
    for name, palette in pairs(GLOBALVAR.__customThemes or {}) do
        local entry = {}
        for key, c in pairs(palette) do
            if typeof(c) == "Color3" then
                entry[key] = {
                    math.floor(c.R * 255 + 0.5),
                    math.floor(c.G * 255 + 0.5),
                    math.floor(c.B * 255 + 0.5),
                }
            end
        end
        out[name] = entry
    end
    return out
end

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local LocalPlayer      = Players.LocalPlayer

local holdTime = 0
local Holding = false
local FHELD = false

function KynInternal.unblock(remote)
    for i = 1,2 do
    remote:FireServer("StopBlocking", "pass")
    task.wait()
    end
end

function KynInternal.block(remote)
    remote:FireServer("StartBlocking", "pass")
end

function KynInternal.get_root()
    return KynInternal.get_character():FindFirstChild("HumanoidRootPart")
end

function KynInternal.get_remote()
    return KynInternal.get_character():FindFirstChild("RemoteEvent")
end

local parriableAnimationIds = {
    ["rbxassetid://5227558947"] = { -- chop / hemmorhage strike
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://4095625816"] = { -- normal m2
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://4211804997"] = { -- boxing m2
        timeBeforeBlock = 0.2,
        blockDuration = 0.5
    },
    ["rbxassetid://4096014941"] = { -- barrage finisher
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://4812642386"] = { -- platinum slam
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://7250792726"] = { -- cd beatdown
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://4879759800"] = { -- rod slap
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://6049426097"] = { -- memory disk / impale
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://6651725175"] = { -- grapple 2
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://6105486059"] = { -- reality overwrite
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://99196384875527"] = { -- no mickey
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://6696145049"] = { -- enraged fury
        timeBeforeBlock = 0,
        blockDuration = 0.5
    },
    ["rbxassetid://6704817082"] = { -- anubis finisher
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://7250792726"] = { -- sptw beatdown
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://108667816546723"] = { -- cd beatdown
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://111984140207587"] = { -- restoration trap
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12293318922"] = { -- bubble prison
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12292882610"] = { -- friction beatdown
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12472183894"] = { -- ice swipe
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    }
}
local blockableAnimationIds = {
    ["rbxassetid://4139919881"] = { -- star finger
        timeBeforeBlock = 0.2,
        blockDuration = 0.5
    },
    ["rbxassetid://11886825775"] = { -- liver shot
        timeBeforeBlock = 0.2,
        blockDuration = 0.5
    },
    ["rbxassetid://10726619714"] = { -- yo angelo
        timeBeforeBlock = 0,
        blockDuration = 1
    },
    ["rbxassetid://10726618090"] = { -- blood slash
        timeBeforeBlock = 0.2,
        blockDuration = 1
    },
    ["rbxassetid://4825999731"] = { -- rod pull
        timeBeforeBlock = 0.2,
        blockDuration = 1
    },
    ["rbxassetid://6869896659"] = { -- red bind
        timeBeforeBlock = 0,
        blockDuration = 1.5
    },
    ["rbxassetid://6869897553"] = { -- crossfire special
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://4691787301"] = { -- grapple 1
        timeBeforeBlock = 0.3,
        blockDuration = 1.5
    },
    ["rbxassetid://5303988283"] = { -- erasure 2
        timeBeforeBlock = 0.2,
        blockDuration = 1
    },
    ["rbxassetid://7189005773"] = { -- plant bomb
        timeBeforeBlock = 0.2,
        blockDuration = 1
    },
    ["rbxassetid://7189003645"] = { -- scattered bombs
        timeBeforeBlock = 0.2,
        blockDuration = 1
    },
    ["rbxassetid://5248107852"] = { -- knives
        timeBeforeBlock = 0.2,
        blockDuration = 0.5
    },
    ["rbxassetid://7250792726"] = { -- life punch
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://105314776561082"] = { -- diver down chop
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://119227701023654"] = { -- diver down dive
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://6780938176"] = { -- lightning jabs
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://5805023656"] = { -- lightning elbow
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://96844575736939"] = { -- thunderbolt
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://10726617608"] = { -- bearing shot
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://70706217552888"] = { -- blood reformation
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://80942004535945"] = { -- bubble launcher
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12020154554"] = { -- hamon hypnosis
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12020106156"] = { -- metal silver overdrive
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://11835659609"] = { -- joseph boomerang
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://118093111712149"] = { -- clacker volley
        timeBeforeBlock = 0.3,
        blockDuration = 1.5
    },
    ["rbxassetid://140176415013134"] = { -- wave kick
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12020102983"] = { -- zoom punch
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://13819637981"] = { -- dino army full form
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://13819639002"] = { -- dino army hybrid form
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://124500775323666"] = { -- stand combo stw
        timeBeforeBlock = 0,
        blockDuration = 0.5
    },
    ["rbxassetid://101069786143553"] = { -- punishment stw
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://83378529435767"] = { -- knife barrage stw
        timeBeforeBlock = 0.3,
        blockDuration = 1
    },
    ["rbxassetid://98740926401939"] = { -- heavy chop stw
        timeBeforeBlock = 0.1,
        blockDuration = 0.5
    },
    ["rbxassetid://12293320463"] = { -- friction plunder
        timeBeforeBlock = 0,
        blockDuration = 0.5
    },
    ["rbxassetid://12292668429"] = { -- moisture plunder
        timeBeforeBlock = 0,
        blockDuration = 1
    },
    ["rbxassetid://12292887648"] = { -- vision plunder
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://15573647320"] = { -- zipper extension
        timeBeforeBlock = 0,
        blockDuration = 0.5
    },
    ["rbxassetid://9973363678"] = { -- home run
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://9957254307"] = { -- kick barrage stone free
        timeBeforeBlock = 0,
        blockDuration = 0.5
    },
    ["rbxassetid://10444683732"] = { -- crescent slice
        timeBeforeBlock = 0,
        blockDuration = 1
    },
    ["rbxassetid://10443021814"] = { -- pierce strike
        timeBeforeBlock = 0,
        blockDuration = 0.5
    },
    ["rbxassetid://10443024044"] = { -- unsealed steel
        timeBeforeBlock = 0,
        blockDuration = 1
    },
    ["rbxassetid://12733016318"] = { -- life absorb
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12733014191"] = { -- oblivion of death
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://108692865610507"] = { -- soaring tempest
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://6812870605"] = { -- atmospheric manipulation
        timeBeforeBlock = 0,
        blockDuration = 1.5
    },
    ["rbxassetid://12472187035"] = { -- ice punch
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    },
    ["rbxassetid://12472188145"] = { -- ice sweeps
        timeBeforeBlock = 0.3,
        blockDuration = 1.5
    },
    ["rbxassetid://6570142118"] = { -- wormhole bd
        timeBeforeBlock = 0.3,
        blockDuration = 0.5
    }
}
local unblockableAnimationIds = {
    ["rbxassetid://11886827025"] = {}, -- jawbreaker
    ["rbxassetid://10726618791"] = {}, -- crazy wall
    ["rbxassetid://6869895377"] = {}, -- crossfire
    ["rbxassetid://5788842822"] = {}, -- ws gun
    ["rbxassetid://4608513484"] = {}, -- hg splash
    ["rbxassetid://7189004232"] = {}, -- coin bomb
    ["rbxassetid://5232933086"] = {}, -- revolver
    ["rbxassetid://6105486422"] = {}, -- smite
    ["rbxassetid://4120490143"] = {}, -- life summon 
    ["rbxassetid://6780937804"] = {}, -- pinky slash
    ["rbxassetid://6701277902"] = {}, -- cursed slice
    ["rbxassetid://5804883693"] = {}, -- lightning drop
    ["rbxassetid://124642862134776"] = {}, -- bubble barrier
    ["rbxassetid://112674371551659"] = {}, -- bubble cutter
    ["rbxassetid://12020154554"] = {}, -- scarlet overdrive
    ["rbxassetid://74382652219174"] = {}, -- rebuff overdrive
    ["rbxassetid://10443019808"] = {}, -- blitz strike
    ["rbxassetid://138805248482322"] = {}, -- ice spike
    ["rbxassetid://12472184729"] = {} -- flash freeze
}
local barrageAnimationId = "rbxassetid://11154840409"

local localRemote

function KynInternal.refreshLocalRemote()
    local char = LocalPlayer.Character
    localRemote = char and char:FindFirstChild("RemoteEvent") or nil
    if KynHooks then
        KynHooks.LocalRemote = localRemote
    end
end

KynInternal.refreshLocalRemote()

local dummy = Instance.new("RemoteEvent")
local old
old = hookfunction(dummy.FireServer, newcclosure(function(self, ...)
    if self == localRemote and Holding then
        local config = GLOBALVAR.AutoBlockConfig

        if config and config.enabled and tick() < holdTime then
            local a1, a2 = ...

            if a1 == "HoldAttack"
                and type(a2) == "table"
                and a2.Bool == true then
                return
            end

            if (a1 == "StartBlocking" or a1 == "StopBlocking")
                and a2 ~= "pass" then
                return
            end
        end
    end

    return old(self, ...)
end))

dummy:Destroy()

function KynInternal.get_ping_compensation()
    local ok, val = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and val or 50) / 1000
end

function KynInternal.enable_m1()
    local args = {
    [1] = "HoldAttack",
    [2] = {
        ["Bool"] = true,
        ["Type"] = "m1"
    }
}

game:GetService("Players").LocalPlayer.Character.RemoteEvent:FireServer(unpack(args))
end

function KynInternal.disable_m1()
    local args = {
    [1] = "HoldAttack",
    [2] = {
        ["Bool"] = false,
        ["Type"] = "m1"
    }
}

game:GetService("Players").LocalPlayer.Character.RemoteEvent:FireServer(unpack(args))
end

function KynInternal.faceEnemy(enemyModel)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local target = enemyModel and enemyModel:FindFirstChild("HumanoidRootPart")

    if not root or not hum or not target then return end

    local oldAutoRotate = hum.AutoRotate
    hum.AutoRotate = false

    local duration = 0.18
    local turnSpeed = math.rad(850)
    local startTime = os.clock()

    while os.clock() - startTime < duration do
        if not root.Parent or not target.Parent then break end

        local delta = target.Position - root.Position
        local direction = Vector3.new(delta.X, 0, delta.Z)

        if direction.Magnitude < 0.01 then break end

        local desired = CFrame.lookAt(
            root.Position,
            root.Position + direction
        )

        local current = root.CFrame
        local angle = math.acos(math.clamp(
            current.LookVector:Dot(desired.LookVector),
            -1, 1
        ))

        if angle < math.rad(3) then break end

        local dt = RunService.Heartbeat:Wait()
        local alpha = math.min(1, turnSpeed * dt / math.max(angle, 0.001))

        root.CFrame = current:Lerp(desired, alpha)
    end

    if hum.Parent then
        hum.AutoRotate = oldAutoRotate
    end
end

function KynInternal.m1_cancel(enemyModel)
task.spawn(function()
    KynInternal.faceEnemy(enemyModel)
end)
KynInternal.enable_m1()
task.wait(0.4)
KynInternal.disable_m1()
end

function KynInternal.handle_auto_parry(AnimationID, enemyModel)
   if not GLOBALVAR.AutoBlockConfig.enabled then return end

   local ok, err = pcall(function()
   local remote = KynInternal.get_remote()
   if not remote then return end

   if AnimationID == barrageAnimationId and GLOBALVAR.BarrageBack then
       KynInternal.disable_m1()
       local tb = math.max(0.2 - KynInternal.get_ping_compensation(), 0)
       if tb > 0 then task.wait(tb) end
       KynInternal.press_key(Enum.KeyCode.E,5)
       return
   end

   local parriable = parriableAnimationIds[AnimationID]
   local blockable = blockableAnimationIds[AnimationID]
   local unblockable = unblockableAnimationIds[AnimationID]

   local eRoot = enemyModel and enemyModel:FindFirstChild("HumanoidRootPart")
   local myRoot = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
   local function isFacingMe()
       if not eRoot or not eRoot.Parent or not myRoot or not myRoot.Parent then
           return true
       end
       local toMe = myRoot.Position - eRoot.Position
       if toMe.Magnitude < 0.1 then return true end
       return eRoot.CFrame.LookVector:Dot(toMe.Unit) >= GLOBALVAR.FaceMinDot
   end

   if parriable then
    Holding = true
    local tb = math.max(parriable.timeBeforeBlock - KynInternal.get_ping_compensation(), 0)
    local blockDuration = parriable.blockDuration
    holdTime = tick() + parriable.timeBeforeBlock + blockDuration + 0.4
    KynInternal.disable_m1()
    KynInternal.unblock(remote)

local stableTime = math.max(tonumber(GLOBALVAR.StableTime) or 0, 0)
local hardCap = tb + 0.3
local startTime = os.clock()
local stableSince = nil
local facingConfirmed = stableTime == 0

while GLOBALVAR.AutoBlockConfig.enabled do
    local now = os.clock()
    local elapsed = now - startTime

    if not facingConfirmed then
        if isFacingMe() then
            stableSince = stableSince or now

            if now - stableSince >= stableTime then
                facingConfirmed = true
            end
        else
            stableSince = nil
        end
    end

    if elapsed >= tb and facingConfirmed then
        break
    end

    if elapsed >= hardCap then
        break
    end

    task.wait()
end

if not GLOBALVAR.AutoBlockConfig.enabled then
    Holding = false
    return
end

    KynInternal.block(remote)

    task.wait(blockDuration)

    if FHELD and not GLOBALVAR.AutoBlockConfig.reblocking then
    KynInternal.unblock(remote)
    end
    if GLOBALVAR.AutoBlockConfig.reblocking and not FHELD then
    KynInternal.unblock(remote)
    end
    Holding = false

elseif blockable then
    Holding = true
    local tb = math.max(blockable.timeBeforeBlock - KynInternal.get_ping_compensation(), 0)
    holdTime = tick() + blockable.timeBeforeBlock + blockable.blockDuration + 0.3

    KynInternal.disable_m1()

    if not FHELD then
        KynInternal.unblock(remote)
    end

    if tb > 0 then task.wait(tb) end

    if not GLOBALVAR.AutoBlockConfig.enabled then
        Holding = false
        return
    end

    KynInternal.block(remote)
    task.wait(blockable.blockDuration)

    if FHELD and not GLOBALVAR.AutoBlockConfig.reblocking then
        KynInternal.unblock(remote)
    end

    if GLOBALVAR.AutoBlockConfig.reblocking and not FHELD then
        KynInternal.unblock(remote)
    end

   Holding = false
   elseif unblockable then
       KynInternal.unblock(remote)
       if GLOBALVAR.MoveCancel then
           KynInternal.m1_cancel(enemyModel)
       end
       local tb = math.max(0.3 - KynInternal.get_ping_compensation(), 0)
       if tb > 0 then task.wait(tb) end
       if GLOBALVAR.AutoBlockConfig.AutoEpitaph and GLOBALVAR.AutoBlockConfig.AutoEpitaphKey then
           KynInternal.press_key(GLOBALVAR.AutoBlockConfig.AutoEpitaphKey,0.2)
       end
    end
    end)

    if not ok then
    warn("[AutoParry] Error:", err)
    end
end

local charConnections = {}

function KynInternal.disconnectCharacterConns(character)
    local conns = charConnections[character]
    if not conns then return end
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    charConnections[character] = nil
end

function KynInternal.trackConn(character, conn)
    charConnections[character] = charConnections[character] or {}
    table.insert(charConnections[character], conn)
end

function KynInternal.hookAnimator(character, animator, model)
    if not animator or not animator:IsA("Animator") then return end

    KynInternal.trackConn(character, animator.AnimationPlayed:Connect(function(track)
        if not GLOBALVAR.AutoBlockConfig.enabled then return end
        local anim = track.Animation
        if not anim then return end
        local id = anim.AnimationId

        if not (parriableAnimationIds[id] or blockableAnimationIds[id]
                or unblockableAnimationIds[id]
                or (id == barrageAnimationId and GLOBALVAR.BarrageBack)) then
            return
        end

        if not GLOBALVAR.AutoBlockConfig.enabled then return end

        local myRoot = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
        if not myRoot then return end

        local eRoot = model:FindFirstChild("HumanoidRootPart")
        if not eRoot then return end

        if (myRoot.Position - eRoot.Position).Magnitude > GLOBALVAR.AutoBlockConfig.distance then
            return
        end

        KynInternal.handle_auto_parry(id, model)
    end))
end

function KynInternal.setup_stand_animator(character, sm)
    task.spawn(function()
        local controller = sm:WaitForChild("AnimationController", 10)
        if not controller then return end

        local animator = controller:WaitForChild("Animator", 10)
        if not animator then return end

        if not sm.Parent or not character.Parent then return end

        KynInternal.hookAnimator(character, animator, character)
    end)
end

function KynInternal.setup_character_ap(character)
    if not character or not character:IsA("Model") then return end
    if character.Name == LocalPlayer.Name then return end
    if not character:WaitForChild("HumanoidRootPart", 1) then return end

    KynInternal.disconnectCharacterConns(character)

    task.spawn(function()
        local charHum = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 5)
        if not charHum or not charHum.Parent then return end

        local anim = charHum:FindFirstChildOfClass("Animator")
            or charHum:WaitForChild("Animator", 5)
        if not anim or not anim.Parent then return end

        if not character.Parent then return end

        KynInternal.hookAnimator(character, anim, character)
    end)

    local sm = character:FindFirstChild("StandMorph")
    if sm then
        KynInternal.setup_stand_animator(character, sm)
    end

    KynInternal.trackConn(character, character.ChildAdded:Connect(function(obj)
        if obj.Name == "StandMorph" then
            KynInternal.setup_stand_animator(character, obj)
        end
    end))

    local standBool = character:FindFirstChild("SummonedStand")
    if standBool then
        KynInternal.trackConn(character, standBool.Changed:Connect(function()
            KynInternal.setup_character_ap(character)
        end))
    end

    KynInternal.trackConn(character, character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            KynInternal.disconnectCharacterConns(character)
        end
    end))
end

local living = workspace.Living
local connection
function KynInternal.enable_ap_childadded()
for _, v in pairs(living:GetChildren()) do
    if v.Name ~= LocalPlayer.Name then
        KynInternal.setup_character_ap(v)
    end
end
connection = living.ChildAdded:Connect(KynInternal.setup_character_ap)
end

function KynInternal.disable_ap_childadded()
for _, v in pairs(living:GetChildren()) do
    if v.Name ~= LocalPlayer.Name then
        KynInternal.disconnectCharacterConns(v)
    end
end
if connection then connection:Disconnect() end
end

living.ChildRemoved:Connect(KynInternal.disconnectCharacterConns)


local autoBossConnection

function KynInternal.stopAutoBoss()

local args = {
    [1] = "HoldAttack",
    [2] = {
        ["Bool"] = false,
        ["Type"] = "m1"
    }
}

game:GetService("Players").LocalPlayer.Character.RemoteEvent:FireServer(unpack(args))

    if autoBossConnection then
        autoBossConnection:Disconnect()
        autoBossConnection = nil
    end

    if LocalPlayer.Character:FindFirstChild("FocusCam") then
        LocalPlayer.Character.FocusCam.Value = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") or LocalPlayer.Character.PrimaryPart
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local stand = character and character:FindFirstChild("StandMorph")
    if root and stand then
        root.CFrame = stand.PrimaryPart.CFrame
        local bv = root:FindFirstChild("AutoBossVelocity")
    local bav = root:FindFirstChild("AutoBossAngular")

    if bv then bv:Destroy() end
    if bav then bav:Destroy() end
    end
end

local function spoofServerInfo()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    local main = hud and hud:FindFirstChild("Main")
    local original = main and main:FindFirstChild("ServerInfo")

    if not original then return end

    local clone = main:FindFirstChild("KynServerInfo")

    if not clone then
        clone = original:Clone()
        clone.Name = "KynServerInfo"
        clone.Parent = main
    end

    clone.Text = "Kyn"
    clone.ZIndex = original.ZIndex + 10
    clone.Position = original.Position
    clone.Size = original.Size
    clone.AnchorPoint = original.AnchorPoint
    clone.Visible = true

    original.Visible = false
end

local spoofThread = nil

function KynInternal.spoofloopo()
    while true do
        task.wait(2)
        if GLOBALVAR.spoof_user then
            KynInternal.spoof_user()
            spoofServerInfo()
        end
    end
end

function KynInternal.toggleSpoof()
    if spoofThread then
        pcall(task.cancel, spoofThread)
        spoofThread = nil
    end
    if GLOBALVAR.spoof_user then
        spoofThread = task.spawn(KynInternal.spoofloopo)
        KynInternal.spoof_user()
        spoofServerInfo()
    end
end

function KynInternal.disableBodyPhysics(root)
    if root:FindFirstChild("AutoBossVelocity") or root:FindFirstChild("AutoBossAngular") then return end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AutoBossVelocity"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = root

    local bav = Instance.new("BodyAngularVelocity")
    bav.Name = "AutoBossAngular"
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.AngularVelocity = Vector3.zero
    bav.Parent = root
end

function KynInternal.dd_reset_player()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return false end
    local rf = char:FindFirstChild("RemoteFunction")
    if not rf then
        warn("[Diver Down] no RemoteFunction on character for reset")
        return false
    end
    pcall(function()
        rf:InvokeServer("Reset", { Anchored = false })
    end)
    task.wait(1.5)

    local dl = os.clock() + 15
    while os.clock() < dl do
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if c and c.Parent and h and h.Health > 15 and c:FindFirstChild("HumanoidRootPart") then
            return true
        end
        task.wait(0.25)
    end
    return false
end

function KynInternal.grabAutoQuest()
    if not GLOBALVAR.AutoQuest then return false end
    local questName = GLOBALVAR.AutoQuestTarget
    if type(questName) ~= "string" or questName == "" then return false end
    local dialogues = workspace:FindFirstChild("Dialogues")
    local npc = dialogues and dialogues:FindFirstChild(questName)
    local prompt = npc and npc:FindFirstChild("ProximityPrompt", true)
    if not prompt then warn("[AutoQuest] NPC prompt missing:", questName); return false end
    if not KynInternal.firePrompt(prompt) then return false end

    local deadline = os.clock() + 8
    local clicked = false
    while os.clock() < deadline and GLOBALVAR.AutoQuest do
        local gui = PlayerGui:FindFirstChild("DialogueGui")
        local frame = gui and gui:FindFirstChild("Frame")
        local options = frame and frame:FindFirstChild("Options")
        local opt = options and options:FindFirstChild("Option1")
        local button = opt and opt:FindFirstChild("TextButton", true)
        if button and button:IsA("GuiButton") then
            pcall(firesignal, button.MouseButton1Click)
            clicked = true
            task.wait(0.2)
        elseif gui then
            local cc = gui:FindFirstChild("ClickContinue", true)
            if cc and cc:IsA("GuiButton") then pcall(firesignal, cc.MouseButton1Click) end
        elseif clicked then
            print("[AutoQuest] Dialogue closed after Option1")
            return true
        end
        task.wait(0.12)
    end
    if clicked then
        print("[AutoQuest] Option1 clicked; quest acceptance not verified")
    else
        warn("[AutoQuest] Option1 never appeared:", questName)
    end
    return clicked
end

local function allocateSkills()
    task.spawn(function()
        local char, RemoteFunction = KynInternal.get_character()
        if not RemoteFunction then warn("failed to get remote allocateskills") return end
        RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Destructive Power V",["SkillTreeType"] = "Stand"})
        RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Destructive Power IV",["SkillTreeType"] = "Stand"})
        RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Destructive Power III",["SkillTreeType"] = "Stand"})
        RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Destructive Power II",["SkillTreeType"] = "Stand"})
        RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Destructive Power I",["SkillTreeType"] = "Stand"})
        
        if LocalPlayer.PlayerStats.Spec.Value == "Hamon (William Zeppeli)" then
            RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Hamon Punch III",["SkillTreeType"] = "Spec"})
            RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Lung Capacity III", ["SkillTreeType"] = "Spec"})
            RemoteFunction:InvokeServer("LearnSkill", {["Skill"] = "Breathing Technique III",["SkillTreeType"] = "Spec"})
        end
    end)
end

function KynInternal.startAutoBoss()
    KynInternal.stopAutoBoss()
    KynInternal.dd_reset_player()
    task.wait(5)
    allocateSkills()
    if not GLOBALVAR.AutoBoss then return end

    if GLOBALVAR.AutoQuest then
        local ok, err = pcall(KynInternal.grabAutoQuest)
        if not ok then
            warn("[AutoQuest] Error:", err)
        end
    end

    if not GLOBALVAR.AutoBoss then return end

    local lastStandCheck = 0
    local lastM1         = 0
    local lastHamon      = 0

    local bossWasAlive = false
    local bossLastSeen = 0
    local lastBossModel = nil
    local deathHandled = false
    local bossPreviouslyHealthy = false
    local questBusy = false
    local questPending = false

    local function grabQuestAfterKill()
        if questBusy or not GLOBALVAR.AutoQuest then return end

        questBusy = true
        questPending = true

        task.spawn(function()
            for attempt = 1, 3 do
                if not GLOBALVAR.AutoBoss or not GLOBALVAR.AutoQuest then break end
                local ok, result = pcall(KynInternal.grabAutoQuest)
                if ok and result then break end
                warn("[AutoQuest] Quest attempt", attempt, "failed:", result)
                task.wait(0.75)
            end

            questPending = false
            questBusy = false
        end)
    end

    autoBossConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not humanoid or humanoid.Health <= 0.15 then return end

        local now = os.clock()

        if now - lastStandCheck >= 0.5 then
            lastStandCheck = now
            local ss = character:FindFirstChild("SummonedStand")
            if ss and not ss.Value then
                local rf = character:FindFirstChild("RemoteFunction")
                if rf then
                    pcall(function() rf:InvokeServer("ToggleStand", "Toggle") end)
                end
            end
        end

        local root = character:FindFirstChild("HumanoidRootPart")
        local stand = character:FindFirstChild("StandMorph")
        local living = workspace:FindFirstChild("Living")
        
        local target = living and living:FindFirstChild(GLOBALVAR.AutoBossTarget)
        local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
        local targetRoot = target and target:FindFirstChild("HumanoidRootPart")

        local health = targetHumanoid and targetHumanoid.Health or 0
        local state = targetHumanoid and targetHumanoid:GetState()
        local stateDead = state == Enum.HumanoidStateType.Dead
        local lowHealth = targetHumanoid and health <= 0.2
        local defeated = stateDead or (bossPreviouslyHealthy and lowHealth)
        local bossAlive = targetHumanoid ~= nil and not defeated and health > 0.2

        if target and target ~= lastBossModel then
            lastBossModel = target
            deathHandled = false
            bossPreviouslyHealthy = false
            bossWasAlive = false
        end
        if targetHumanoid and health > 1 and not stateDead then
            bossPreviouslyHealthy = true
            bossWasAlive = true
            bossLastSeen = now
        end
        if bossWasAlive and not deathHandled and (defeated or not targetHumanoid) then
            deathHandled = true
            bossWasAlive = false
            print(('[AutoBoss] Boss defeated: health=%.6f, state=%s'):format(health, tostring(state)))
            grabQuestAfterKill()
        end

        if questPending then return end

        if not root or not stand or not stand.PrimaryPart
            or not targetRoot or not bossAlive then
            return
        end

        local distanceaaa = GLOBALVAR.DistanceFromBoss or -25
        root.CFrame = targetRoot.CFrame + Vector3.new(0, distanceaaa, 0) + targetRoot.CFrame.LookVector *- 5
        stand.PrimaryPart.CFrame =
        targetRoot.CFrame + targetRoot.CFrame.LookVector * -2

        if now - lastM1 >= 0.05 and not Holding then
            lastM1 = now
            local re = character:FindFirstChild("RemoteEvent")
            if re then
                pcall(function()
                    re:FireServer("HoldAttack", { Bool = true, Type = "m1" })
                end)
            end
        end

        if not character:FindFirstChild("FocusCam") then
            local fc = Instance.new("ObjectValue")
            fc.Name = "FocusCam"
            fc.Value = stand.PrimaryPart
            fc.Parent = character
        elseif character.FocusCam.Value ~= stand.PrimaryPart then
            character.FocusCam.Value = stand.PrimaryPart
        end

        KynInternal.disableBodyPhysics(root)

        if now - lastHamon >= 1 then
            lastHamon = now
            local hamongui = LocalPlayer.PlayerGui:FindFirstChild("Hamon Gui")
            if hamongui then
                local frame = hamongui:FindFirstChild("Frame")
                if frame and not frame.Visible then
                    local skills = character:FindFirstChild("SpecSkills")
                    if skills then
                        for _, v in ipairs(skills:GetChildren()) do
                            local key = tostring(v.Name):match("Enum%.KeyCode%.(.+)")
                            if key and v.Value == "Hamon Breathing" then
                                local tool = LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
                                if tool then tool.Parent = character end
                                KynInternal.press_key(Enum.KeyCode[key], 3)
                                if tool then tool.Parent = LocalPlayer.Backpack end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local TARGET_ATTACK = CFrame.new(0, 0, -2)
local writing = false
local reachConnection = nil
local reachThread = nil
local reachGeneration = 0

function KynInternal.isClose(a, b, eps)
    eps = eps or 0.001
    return (a.Position - b.Position).Magnitude < eps
end

function KynInternal.unhookStandAttachment()
    reachGeneration += 1
    if reachConnection then
        reachConnection:Disconnect()
        reachConnection = nil
    end
    if reachThread then
        pcall(task.cancel, reachThread)
        reachThread = nil
    end
end

function KynInternal.hookStandAttachment(character)
    KynInternal.unhookStandAttachment()
    if not GLOBALVAR.ReachEnabled then return end

    if not character or character.Name ~= LocalPlayer.Name then
        character = LocalPlayer.Character
        if not character then return end
    end

    local generation = reachGeneration
    reachThread = task.spawn(function()
        local hrp = character:WaitForChild("HumanoidRootPart")
        if not hrp then return end
        local attach = hrp:WaitForChild("StandAttach")
        if not attach or generation ~= reachGeneration
            or not GLOBALVAR.ReachEnabled or LocalPlayer.Character ~= character then
            return
        end

        if reachConnection then reachConnection:Disconnect() end
        reachConnection = attach:GetPropertyChangedSignal("CFrame"):Connect(function()
            if writing or not GLOBALVAR.ReachEnabled then return end
            if generation ~= reachGeneration or not attach.Parent then return end
            if not KynInternal.isClose(attach.CFrame, TARGET_ATTACK) then return end

            writing = true
            attach.CFrame = CFrame.new(0, 0, -GLOBALVAR.ReachDistance)
            writing = false
        end)
    end)
end

task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 5)
    KynInternal.hookStandAttachment(char)
end)

local _SA = (function()
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local GuiService       = game:GetService("GuiService")
local LocalPlayer      = Players.LocalPlayer

SA_BLATANT_DIST = SA_BLATANT_DIST or 250
SA_FOV_RADIUS = GLOBALVAR.SilentAimFOV or 150
SA_MAX_DIST   = GLOBALVAR.SilentAimRange or 200
SA_AIM_HEAD   = SA_AIM_HEAD   or false
sa_aiming     = sa_aiming     or false
sa_mouse      = sa_mouse      or Vector2.new(0, 0)
sa_Camera     = sa_Camera     or workspace.CurrentCamera
SA_Y_SCALE    = SA_Y_SCALE    or 6
currentTarget = currentTarget or nil
cacheAccum    = cacheAccum    or 0
scanAccum     = scanAccum     or 0

if type(CACHE_INTERVAL) ~= "number" then CACHE_INTERVAL = 0.25 end
if type(SCAN_INTERVAL)  ~= "number" then SCAN_INTERVAL  = 1 / 30 end

if type(refreshTargetCache) ~= "function" then
    function refreshTargetCache() end
end

if type(saGLOBALVARetTarget) ~= "function" then
    function saGLOBALVARetTarget()
        local char   = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local living = workspace:FindFirstChild("Living")
        if not living then return nil end

        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local mouse = UserInputService:GetMouseLocation()
        local inset = GuiService:GetGuiInset()

        local maxDist
        if GLOBALVAR.AccuracyBlatant then
            maxDist = SA_BLATANT_DIST or 250
        else
            maxDist = SA_MAX_DIST or 200
        end

        local best, bestDist = nil, maxDist
        for _, model in ipairs(living:GetChildren()) do
            if model ~= char then
                local root = model:FindFirstChild("HumanoidRootPart")
                local hum  = model:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 then
                    local d = (root.Position - myRoot.Position).Magnitude
                    if d < bestDist then
                        local screen, onScreen = cam:WorldToScreenPoint(root.Position)
                        if onScreen then
                            local sp = Vector2.new(screen.X, screen.Y + inset.Y)
                            if (sp - Vector2.new(mouse.X, mouse.Y)).Magnitude <= SA_FOV_RADIUS then
                                bestDist = d
                                best = root
                            end
                        end
                    end
                end
            end
        end
        return best
    end
end

if not saGLOBALVARui then
    saGLOBALVARui = Instance.new("ScreenGui")
    saGLOBALVARui.Name = "FOVBubble"
    saGLOBALVARui.IgnoreGuiInset = true
    saGLOBALVARui.ResetOnSpawn = false
    saGLOBALVARui.Enabled = true
    saGLOBALVARui.DisplayOrder = 999
    saGLOBALVARui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end

if not sa_circle or not sa_circle.Parent then
    sa_circle = Instance.new("Frame")
    sa_circle.Size = UDim2.fromOffset(SA_FOV_RADIUS * 2, SA_FOV_RADIUS * 2)
    sa_circle.AnchorPoint = Vector2.new(0.5, 0.5)
    sa_circle.BackgroundTransparency = 1
    sa_circle.BorderSizePixel = 0
    sa_circle.Parent = saGLOBALVARui

    sa_stroke = Instance.new("UIStroke")
    sa_stroke.Color = Color3.fromRGB(255, 255, 255)
    sa_stroke.Thickness = 1.5
    sa_stroke.Transparency = 0.4
    sa_stroke.Parent = sa_circle

    local sa_corner = Instance.new("UICorner")
    sa_corner.CornerRadius = UDim.new(1, 0)
    sa_corner.Parent = sa_circle
end

if not GLOBALVAR._SilentAimBooted then
    sa_aiming = false
    GLOBALVAR._SilentAimBooted = true
end

local AccuracyRuntime = {
    Enabled        = false,
    Connection     = nil,
    Processed      = setmetatable({}, { __mode = "k" }),
    LockedBodies   = setmetatable({}, { __mode = "k" }),
    Debug          = true,
}

local TargetState = {
    part = nil,
    position = Vector3.zero,
    valid = false,
}

local _cachedMyRoot = nil
local _cachedMyRootChar = nil

function KynInternal.getMyRoot()
    local char = LocalPlayer.Character
    if char ~= _cachedMyRootChar then
        _cachedMyRootChar = char
        _cachedMyRoot = char and char:FindFirstChild("HumanoidRootPart")
    end
    return _cachedMyRoot
end

function KynInternal.getAccuracyTarget()
    local myRoot = KynInternal.getMyRoot()
    if not myRoot then return nil end

    if currentTarget and currentTarget.Parent then
        local d = (currentTarget.Position - myRoot.Position).Magnitude
        if d < (SA_BLATANT_DIST or 250) then
            return currentTarget
        end
    end
    return nil
end

local targetUpdaterConn = nil

function KynInternal.startTargetUpdater()
    if targetUpdaterConn then return end
    local elapsed = 0
    targetUpdaterConn = RunService.Heartbeat:Connect(function(dt)
        if not GLOBALVAR.AccuracyBlatant then
            TargetState.valid = false
            TargetState.part = nil
            elapsed = 0
            return
        end
        elapsed += dt
        if elapsed < 1 / 30 then return end
        elapsed %= (1 / 30)
        local target = KynInternal.getAccuracyTarget()
        if target then
            TargetState.part = target
            TargetState.position = target.Position
            TargetState.valid = true
        else
            TargetState.valid = false
            TargetState.part = nil
        end
    end)
end

function KynInternal.stopTargetUpdater()
    if targetUpdaterConn then
        targetUpdaterConn:Disconnect()
        targetUpdaterConn = nil
    end
    TargetState.valid = false
    TargetState.part = nil
end

function KynInternal.accPrint(fmt, ...)
    if not AccuracyRuntime.Debug then return end
    pcall(print, ("[silent aim] " .. fmt):format(...))
end

function KynInternal.scanForClosestEnemy(maxRange)
    local char   = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local living = workspace:FindFirstChild("Living")
    if not living then return nil end
    local best, bestDist = nil, maxRange or 500
    for _, model in ipairs(living:GetChildren()) do
        if model ~= char then
            local root = model:FindFirstChild("HumanoidRootPart")
            local hum  = model:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local d = (root.Position - myRoot.Position).Magnitude
                if d < bestDist then bestDist = d; best = root end
            end
        end
    end
    return best
end

function KynInternal.getCurrentFOVAimTarget()
    if type(saGLOBALVARetTarget) == "function" then
        local ok, t = pcall(saGLOBALVARetTarget)
        if ok and t and t.Parent then return t end
    end
    if currentTarget and currentTarget.Parent then return currentTarget end
    return KynInternal.scanForClosestEnemy(SA_MAX_DIST or 200)
end

function KynInternal.findOwnerValue(tool, handle)
    local names = {"Attacker", "Owner", "Player", "Thrower", "Character"}
    for _, n in ipairs(names) do
        local v = handle:FindFirstChild(n) or tool:FindFirstChild(n)
        if v and (v:IsA("ObjectValue") or v:IsA("StringValue")) then
            return v, n
        end
    end
    return nil
end

function KynInternal.isOwnedByMe(value)
    if typeof(value) == "Instance" then
        if value == LocalPlayer then return true end
        if value == LocalPlayer.Character then return true end
        if value.Parent == LocalPlayer.Character then return true end
        if value.Parent == LocalPlayer then return true end
    elseif typeof(value) == "string" then
        if value == LocalPlayer.Name or value == LocalPlayer.DisplayName then
            return true
        end
    end
    return false
end

function KynInternal.findMovers(root)
    local list = {}
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("BodyVelocity")
            or d:IsA("LinearVelocity")
            or d:IsA("VectorForce") then
            table.insert(list, d)
        end
    end
    return list
end

function KynInternal.aimVector(fromPos, targetPart)
    local dir = (targetPart.Position - fromPos)
    if dir.Magnitude < 0.1 then return nil end
    return dir.Unit
end

function KynInternal.hookMover(mover, tool, part)
    if AccuracyRuntime.LockedBodies[mover] then return end
    AccuracyRuntime.LockedBodies[mover] = { tool = tool, part = part }

    pcall(function()
        if mover:IsA("BodyVelocity") then
            mover.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            mover.P = 5000
        elseif mover:IsA("LinearVelocity") then
            mover.MaxForce = math.huge
            mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
            mover.MaxAxesForce = Vector3.new(1e6, 1e6, 1e6)
        elseif mover:IsA("VectorForce") then
            mover.Force = Vector3.new(1e6, 1e6, 1e6)
            mover.RelativeTo = Enum.ActuatorRelativeTo.World
        end
    end)

    mover.AncestryChanged:Connect(function()
        if not mover.Parent then
            AccuracyRuntime.LockedBodies[mover] = nil
        end
    end)
end

function KynInternal.lockKnifeOntoTarget(tool, handle, target)
    local movers = KynInternal.findMovers(tool)

    if #movers == 0 then
        task.spawn(function()
            for i = 1, 20 do
                task.wait(0.02)
                if not tool.Parent then return end
                local m = KynInternal.findMovers(tool)
                if #m > 0 then
                    for _, mv in ipairs(m) do
                        KynInternal.hookMover(mv, tool, mv.Parent)
                    end
                    return
                end
            end
        end)
        return
    end

    for _, mover in ipairs(movers) do
        KynInternal.hookMover(mover, tool, mover.Parent)
    end

    if not handle then return end

    local hb = nil
    local cleaned = false
    local function cleanup()
        if cleaned then return end
        cleaned = true
        if hb then hb:Disconnect(); hb = nil end
    end

    local weldConn
    weldConn = tool.DescendantAdded:Connect(function(d)
        if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
            cleanup()
            if weldConn then weldConn:Disconnect() end
        end
    end)

    hb = RunService.Heartbeat:Connect(function()
        if cleaned then return end
        if not AccuracyRuntime.Enabled then return cleanup() end
        if not tool.Parent then return cleanup() end
        if not TargetState.valid then return end
        if not handle.Parent then return cleanup() end
        pcall(function()
            handle.CFrame = CFrame.new(TargetState.position)
        end)
    end)

    task.delay(5, cleanup)
    tool.AncestryChanged:Connect(function()
        if not tool.Parent then cleanup() end
    end)
end

local knifeCount = 0

function KynInternal.handleKnife(instance)
    if not instance or not instance.Parent then return end
    if not (instance:IsA("Model") or instance:IsA("Tool")) then return end

    local ownerVal = instance:FindFirstChild("Attacker", true)
    if not ownerVal then return end
    if not (ownerVal:IsA("ObjectValue") or ownerVal:IsA("StringValue")) then return end
    if AccuracyRuntime.Processed[instance] then return end

    local ok = false
    if instance.Parent == workspace then
        ok = true
    else
        local living = workspace:FindFirstChild("Living")
        if living and instance.Parent and instance.Parent.Parent == living then
            ok = true
        end
    end
    if not ok then return end

    knifeCount += 1
    AccuracyRuntime.Processed[instance] = true

    if not AccuracyRuntime.Enabled or not GLOBALVAR.AccuracyBlatant then return end
    if not KynInternal.isOwnedByMe(ownerVal.Value) then return end

    local target = KynInternal.getAccuracyTarget()
    if not target then return end

    local movers = KynInternal.findMovers(instance)
    local part = (movers[1] and movers[1].Parent) or instance.PrimaryPart
        or instance:FindFirstChildWhichIsA("BasePart")

    if not part then
        return
    end

    KynInternal.lockKnifeOntoTarget(instance, part, target)
end

function AccuracyRuntime.start()
    if AccuracyRuntime.Connection then
        return
    end
    AccuracyRuntime.Enabled = true
    AccuracyRuntime.Connection = workspace.ChildAdded:Connect(function(desc)
        pcall(KynInternal.handleKnife, desc)
    end)
    KynInternal.accPrint("started")
end

function AccuracyRuntime.stop()
    AccuracyRuntime.Enabled = false
    if AccuracyRuntime.Connection then
        AccuracyRuntime.Connection:Disconnect()
        AccuracyRuntime.Connection = nil
    end
    KynInternal.accPrint("stopped")
end

function AccuracyRuntime.setRange(v)
    SA_BLATANT_DIST = v
end

function AccuracyRuntime.setEnabled(v)
    if v then AccuracyRuntime.start() else AccuracyRuntime.stop() end
end

GLOBALVAR.AccuracyAim = AccuracyRuntime

local saConn = nil

function KynInternal.start_sa1()
    if saConn then return end
    refreshTargetCache()

    saConn = RunService.RenderStepped:Connect(function(dt)
        sa_Camera = workspace.CurrentCamera

        if not sa_aiming then return end

        local mouse = UserInputService:GetMouseLocation()
        sa_mouse = Vector2.new(mouse.X, mouse.Y)

        cacheAccum += dt
        if cacheAccum >= CACHE_INTERVAL then
            cacheAccum = 0
            refreshTargetCache()
        end

        scanAccum += dt
        if scanAccum >= SCAN_INTERVAL then
            scanAccum %= SCAN_INTERVAL
            currentTarget = saGLOBALVARetTarget()
        end

        if currentTarget and currentTarget.Parent then
            local screen, onScreen =
                sa_Camera:WorldToScreenPoint(currentTarget.Position)
            if onScreen then
                local screenPos = Vector2.new(screen.X, screen.Y)
                local distance  = (screenPos - sa_mouse).Magnitude
                if distance <= SA_FOV_RADIUS then
                    local myRoot = KynInternal.getMyRoot()
                    local worldDist = myRoot
                        and (currentTarget.Position - myRoot.Position).Magnitude
                        or 0
                    local distanceFactor = math.clamp(worldDist / SA_MAX_DIST, 0, 1)
                    local inset = GuiService:GetGuiInset()
                    KynHooks.SaFake = Vector2.new(
                        screenPos.X,
                        screenPos.Y + inset.Y + distanceFactor * SA_Y_SCALE
                    )
                    if sa_circle then
                        sa_circle.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
                    end
                    if sa_stroke then
                        sa_stroke.Color = Color3.fromRGB(80, 255, 80)
                    end
                else
                    KynHooks.SaFake = nil
                    if sa_stroke then
                        sa_stroke.Color = Color3.fromRGB(255, 255, 255)
                    end
                end
            else
                if sa_circle then
                    sa_circle.Position = UDim2.fromOffset(sa_mouse.X, sa_mouse.Y)
                end
                KynHooks.SaFake = nil
                if sa_stroke then
                    sa_stroke.Color = Color3.fromRGB(255, 255, 255)
                end
            end
        else
            if sa_circle then
                sa_circle.Position = UDim2.fromOffset(sa_mouse.X, sa_mouse.Y)
            end
            KynHooks.SaFake = nil
            if sa_stroke then
                sa_stroke.Color = Color3.fromRGB(255, 255, 255)
            end
        end
    end)
end

function KynInternal.stop_sa1()
    if saConn then
        saConn:Disconnect()
        saConn = nil
    end
    currentTarget = nil
    KynHooks.SaFake = nil
    if sa_stroke then sa_stroke.Color = Color3.fromRGB(255, 255, 255) end
end

GLOBALVAR.SilentAim = {
    start_sa = KynInternal.start_sa1,
    stop_sa  = KynInternal.stop_sa1,
    setEnabled = function(v)
        if v then
            sa_aiming = true
            if saGLOBALVARui then saGLOBALVARui.Enabled = true end
            KynInternal.start_sa1()
        else
            sa_aiming = false
            KynInternal.stop_sa1()
        end
        if GLOBALVAR.UpdateSACircle then GLOBALVAR.UpdateSACircle() end
    end,
    setFOV     = function(px)
        SA_FOV_RADIUS = px
        if sa_circle then
            sa_circle.Size = UDim2.fromOffset(px * 2, px * 2)
        end
    end,
    setRange   = function(s) SA_MAX_DIST = s end,
    setAimHead = function(v) SA_AIM_HEAD = v end,
    getEnabled = function() return sa_aiming end,
    getFOV     = function() return SA_FOV_RADIUS end,
    getRange   = function() return SA_MAX_DIST end,
    setBlatant = function(v) GLOBALVAR.AccuracyBlatant = not not v end
}

function KynInternal.updateCircleVisibility()
    if not sa_circle then return end
    local on = sa_aiming or (GLOBALVAR.AccuracyBlatant == true)
    sa_circle.Visible = on
    if not on and sa_stroke then
        sa_stroke.Color = Color3.fromRGB(255, 255, 255)
    end
end
GLOBALVAR.UpdateSACircle = KynInternal.updateCircleVisibility
if saGLOBALVARui then saGLOBALVARui.Enabled = false end
KynInternal.updateCircleVisibility()
end)()

local TempStore = ReplicatedStorage:FindFirstChild("TempStorage")
if not TempStore then
    TempStore = Instance.new("Folder")
    TempStore.Name = "TempStorage"
    TempStore.Parent = ReplicatedStorage
end

local CurrentCharacter
local Humanoid
local SummonedStand
local StandMorph
local StandHumanoid
local Camera
local CurrentArgs
local PilotActive = false
local PilotEnabled = false

local StayInPilot = Instance.new("BoolValue")
StayInPilot.Name = "StayInPilot"
StayInPilot.Value = false
StayInPilot.Parent = workspace

function KynInternal.UpdateIndex()
    CurrentCharacter = LocalPlayer.Character
    if not CurrentCharacter then return false end

    Humanoid = CurrentCharacter:FindFirstChildOfClass("Humanoid")
    SummonedStand = CurrentCharacter:FindFirstChild("SummonedStand")
    StandMorph = CurrentCharacter:FindFirstChild("StandMorph")
    Camera = workspace.CurrentCamera

    if not Humanoid or not SummonedStand or not StandMorph then
        return false
    end

    StandHumanoid = StandMorph:FindFirstChildOfClass("Humanoid")
    return StandHumanoid ~= nil
        and CurrentCharacter.PrimaryPart ~= nil
        and StandMorph.PrimaryPart ~= nil
end

function KynInternal.PilotStand()
    if PilotActive or not KynInternal.UpdateIndex() then return nil end
    PilotActive = true

    local StandSpeed = GLOBALVAR.StandSpeed or 1.5
    local PilotJumpPower = GLOBALVAR.PilotJumpPower or 1.5
    local HideBody = GLOBALVAR.HidePilotBody ~= false
    local BodyDistance = GLOBALVAR.PilotBodyDistance or 37

    for _, v in ipairs(workspace.Locations:GetChildren()) do
        if v.Name == "Naples' Sewers" then
            v.Parent = TempStore
        end
    end
    
    local FocusCam = CurrentCharacter:FindFirstChild("FocusCam")

if not FocusCam then
    FocusCam = Instance.new("ObjectValue")
    FocusCam.Name = "FocusCam"
    FocusCam.Parent = CurrentCharacter
end

FocusCam.Value = StandMorph:FindFirstChild("AnimationController")

    local PilotFunctions = {
        FocusCam = FocusCam,
        CFrame = CurrentCharacter.PrimaryPart.CFrame,
        Character = CurrentCharacter,
        StandMorph = StandMorph,
        HideBody = HideBody,
        Humanoid = CurrentCharacter:FindFirstChildOfClass("Humanoid"),
    }

    for _, v in ipairs(CurrentCharacter:GetChildren()) do
        if v:IsA("BasePart") then
            v.CanCollide = false
        end
    end

    PilotFunctions.JumpSignal =
        Humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
            if Humanoid and StandHumanoid and Humanoid.Jump then
                StandHumanoid.Jump = true
            end
        end)

    StandHumanoid.WalkSpeed = Humanoid.WalkSpeed * StandSpeed
    PilotFunctions.PilotSpeed =
        Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if Humanoid and StandHumanoid then
                StandHumanoid.WalkSpeed = Humanoid.WalkSpeed * (GLOBALVAR.StandSpeed or 1.5)
            end
        end)

    StandHumanoid.JumpPower = Humanoid.JumpPower * PilotJumpPower
    PilotFunctions.JumpPower =
        Humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
            if Humanoid and StandHumanoid then
                StandHumanoid.JumpPower = Humanoid.JumpPower * (GLOBALVAR.PilotJumpPower or 1.5)
            end
        end)

    if not HideBody then
        CurrentCharacter.PrimaryPart.Anchored = true
    end

    PilotFunctions.LoopTP = RunService.Heartbeat:Connect(function()
        if not PilotActive or not CurrentCharacter.Parent
            or not StandMorph.Parent or not Humanoid.Parent then
            return
        end

        Camera = workspace.CurrentCamera
        local MoveDirection = Camera.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
        StandHumanoid:Move(MoveDirection, true)

        if GLOBALVAR.HidePilotBody ~= false then
            CurrentCharacter.PrimaryPart.CFrame =
                StandMorph.PrimaryPart.CFrame
                + Vector3.new(0, -(GLOBALVAR.PilotBodyDistance or 37), 0)
        end
    end)

    local AlignOrientation = StandMorph:FindFirstChild("AlignOrientation", true)
    local AlignPosition = StandMorph:FindFirstChild("AlignPosition", true)

    if AlignOrientation then AlignOrientation.Enabled = false end
    if AlignPosition then AlignPosition.Enabled = false end

    for _, v in ipairs(StandMorph:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                PhysicsService:SetPartCollisionGroup(v, "Players")
            end)
        end
    end

    return PilotFunctions
end

function KynInternal.UnPilotStand(Returned)
    if not PilotActive then return end
    PilotActive = false

    if not Returned then
        Returned = CurrentArgs
    end

    if Returned then
        for _, v in pairs(Returned) do
            if typeof(v) == "RBXScriptConnection" then
                v:Disconnect()
            end
        end

        local Character = Returned.Character
        local Stand = Returned.StandMorph

        if Character and Character.Parent and Character.PrimaryPart then

        if not Character:FindFirstChild("FocusCam") then
        local FocusCam = Instance.new("ObjectValue", Character)
        FocusCam.Name = "FocusCam"
        FocusCam.Value = Returned.Humanoid
        end
            
        if Character:FindFirstChild("FocusCam") and Character.FocusCam.Value ~= Character.PrimaryPart then
        Character.FocusCam.Value = Returned.Humanoid
        end

            Character.PrimaryPart.AssemblyLinearVelocity = Vector3.zero

            if GLOBALVAR.TeleportBodyToStand ~= false
                and Stand and Stand.Parent and Stand.PrimaryPart then
                Character.PrimaryPart.CFrame = Stand.PrimaryPart.CFrame
            else
                Character.PrimaryPart.CFrame = Returned.CFrame
            end

            if not Returned.HideBody then
                Character.PrimaryPart.Anchored = false
            end
        end

        if Stand and Stand.Parent then
            local AlignOrientation = Stand:FindFirstChild("AlignOrientation", true)
            local AlignPosition = Stand:FindFirstChild("AlignPosition", true)

            if AlignOrientation then AlignOrientation.Enabled = true end
            if AlignPosition then AlignPosition.Enabled = true end

            for _, v in ipairs(Stand:GetDescendants()) do
                if v:IsA("BasePart") then
                    pcall(function()
                        PhysicsService:SetPartCollisionGroup(v, "Stands")
                    end)
                end
            end
        end
    end

    for _, v in ipairs(TempStore:GetChildren()) do
        if v.Name == "Naples' Sewers" then
            v.Parent = workspace.Locations
        end
    end

    CurrentArgs = nil
end

function KynInternal.SetStandPilot(state)
    StayInPilot.Value = state

    if state then
        CurrentArgs = KynInternal.PilotStand()
        if not CurrentArgs then
            PilotActive = false
            StayInPilot.Value = false
            PilotEnabled = false
        end
    else
        KynInternal.UnPilotStand(CurrentArgs)
    end
end

GLOBALVAR.StartStandPilot = function()
    KynInternal.SetStandPilot(true)
end

GLOBALVAR.StopStandPilot = function()
    KynInternal.SetStandPilot(false)
end

StayInPilot:GetPropertyChangedSignal("Value"):Connect(function()
    PilotEnabled = StayInPilot.Value
end)

local loop
function KynInternal.enable_m1_loop()
if loop then loop:Disconnect() end
loop = nil
loop = RunService.Heartbeat:Connect(function()
local args = {
    [1] = "HoldAttack",
    [2] = {
        ["Bool"] = true,
        ["Type"] = "m1"
    }
}

game:GetService("Players").LocalPlayer.Character:WaitForChild("RemoteEvent"):FireServer(unpack(args))
end)
end

function KynInternal.disable_m1_loop()
if loop then loop:Disconnect() end
loop = nil
loop = RunService.Heartbeat:Connect(function()
local args = {
    [1] = "HoldAttack",
    [2] = {
        ["Bool"] = false,
        ["Type"] = "m1"
    }
}

game:GetService("Players").LocalPlayer.Character:WaitForChild("RemoteEvent"):FireServer(unpack(args))
end)
end

UserInputService.InputBegan:Connect(function(InputObject,gpe)
    if UserInputService:GetFocusedTextBox() or gpe then return end

    if InputObject.KeyCode == Enum.KeyCode.F then
        FHELD = true
        if not Holding then
        KynInternal.block(LocalPlayer.Character:FindFirstChild("RemoteEvent"))
        end
    end

    if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
        KynInternal.enable_m1_loop()
    end

    if InputObject.KeyCode == (Enum.KeyCode[GLOBALVAR.PilotKey] or Enum.KeyCode.H) and GLOBALVAR.StandPilot then
        KynInternal.SetStandPilot(not StayInPilot.Value)
    end
end)

UserInputService.InputEnded:Connect(function(input,gpe)
    if gpe then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        KynInternal.disable_m1_loop()
    end

    if input.KeyCode == Enum.KeyCode.F then
        FHELD = false
        if not Holding then
        KynInternal.unblock(LocalPlayer.Character:FindFirstChild("RemoteEvent"))
        end
    end
end)

local IsInvisibile
local UndergroundAnimation
function PlayAnimation(HumanoidCharacter, AnimationID, AnimationSpeed, Time)
    local CreatedAnimation = Instance.new("Animation")
    CreatedAnimation.AnimationId = AnimationID
    local animationTrack = HumanoidCharacter:WaitForChild("Humanoid",5):WaitForChild("Animator",5):LoadAnimation(CreatedAnimation)

    animationTrack:Play()
    animationTrack:AdjustSpeed(AnimationSpeed)
    animationTrack.Priority= Enum.AnimationPriority.Action4
    animationTrack.TimePosition = Time
    animationTrack.Looped = false
    return animationTrack
end

function KynInternal.Invisibile()
    Character = LocalPlayer.Character
    local HUD = PlayerGui:FindFirstChild("HUD")
    HUD.Parent = nil

    UndergroundAnimation = PlayAnimation(Character, "rbxassetid://7189062263", 0, 5)
    LocalPlayer.Character = nil

    UndergroundAnimation:Stop()
    LocalPlayer.Character = Character

    HUD.Parent = PlayerGui
end

function KynInternal.Uninvisible()
    Character = LocalPlayer.Character
    PlayAnimation(Character, "rbxassetid://7189062263", 0, 5):Stop()
end

if KynInternal.hasPremium() and GLOBALVAR.Invis then
task.spawn(KynInternal.Invisibile)
end

local DiscFarm = {}

function DiscFarm.click_option(optIndex, timeout)
    timeout = timeout or 6
    local deadline = os.clock() + timeout
    local optName = "Option" .. tostring(optIndex)
    while os.clock() < deadline do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local frame = dg:FindFirstChild("Frame")
            local options = frame and frame:FindFirstChild("Options")
            if options then
                local opt = options:FindFirstChild(optName)
                local tb  = opt and opt:FindFirstChild("TextButton", true)
                if tb and tb:IsA("TextButton") then
                    pcall(function() firesignal(tb.MouseButton1Click) end)
                    task.wait(0.25)
                    return true
                end
            end
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.1)
    end
    warn("[auto diver down] click_option("..optIndex..") timed out")
    return false
end

function DiscFarm.continue_until_closed(timeout)
    timeout = timeout or 6
    local deadline = os.clock() + timeout
    while os.clock() < deadline do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if not dg then return true end
        local cc = dg:FindFirstChild("ClickContinue", true)
        if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        task.wait(0.15)
    end
    return PlayerGui:FindFirstChild("DialogueGui") == nil
end

function DiscFarm.talk_to(npcName, timeout)
    timeout = timeout or 8
    local dialogues = workspace:FindFirstChild("Dialogues")
    if not dialogues then return false end
    local npc = dialogues:FindFirstChild(npcName)
    if not npc then return false end
    local prompt = npc:FindFirstChild("ProximityPrompt", true)
    if not prompt then return false end
    pcall(function() KynInternal.firePrompt(prompt) end)
    local deadline = os.clock() + timeout
    while os.clock() < deadline do
        if PlayerGui:FindFirstChild("DialogueGui") then
            task.wait(0.2)
            return true
        end
        task.wait(0.1)
    end
    return false
end

function DiscFarm.sequence(opts)
    for _, idx in ipairs(opts) do
        if not DiscFarm.click_option(idx, 6) then return false end
    end
    return true
end

function DiscFarm.kill_boss(bossName, watchItem, timeout, alsoWatchStandMorph)
    timeout = timeout or 500
    GLOBALVAR.AutoBossTarget = bossName
    pcall(KynInternal.startAutoBoss)

    local deadline = os.clock() + timeout
    local standMorphSeen = false
    local standMorphGone = false
    local watchConn = nil
    local watchChar = nil

    local function armWatcher(bossModel)
        if watchConn then watchConn:Disconnect(); watchConn = nil end
        watchChar = bossModel
        if not alsoWatchStandMorph or not bossModel then return end

        local sm = bossModel:FindFirstChild("StandMorph")
        if sm then
            standMorphSeen = true
            watchConn = sm.AncestryChanged:Connect(function(_, parent)
                if not parent then standMorphGone = true end
            end)
        else
            watchConn = bossModel.ChildAdded:Connect(function(child)
                if child.Name == "StandMorph" then
                    standMorphSeen = true
                    if watchConn then watchConn:Disconnect(); watchConn = nil end
                    watchConn = child.AncestryChanged:Connect(function(_, parent)
                        if not parent then standMorphGone = true end
                    end)
                end
            end)
        end
    end

    local living = workspace:FindFirstChild("Living")
    local boss = living and living:FindFirstChild(bossName)
    armWatcher(boss)

    local ok, result = pcall(function()
        while os.clock() < deadline do
            if watchItem and WeatherRuntime.has_item(watchItem) then
                return true
            end

            living = workspace:FindFirstChild("Living")
            boss = living and living:FindFirstChild(bossName)
            if not boss then
                task.wait(1.5)
                return watchItem == nil or WeatherRuntime.has_item(watchItem)
            end

            if alsoWatchStandMorph and boss ~= watchChar then
                armWatcher(boss)
            end

            if alsoWatchStandMorph and standMorphSeen and standMorphGone and bossName ~= "Jotaro Kujo" then
                task.wait(1.5)
                return watchItem == nil or WeatherRuntime.has_item(watchItem)
            end

            local hum = boss:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0.15 and bossName ~= "Jotaro Kujo" then
                task.wait(1.5)
                return watchItem == nil or WeatherRuntime.has_item(watchItem)
            end

            task.wait(0.5)
        end
        return watchItem == nil or WeatherRuntime.has_item(watchItem)
    end)

    if watchConn then watchConn:Disconnect() end
    pcall(KynInternal.stopAutoBoss)
    return ok and result or false
end

function DiscFarm.learn_skills()
    local character, remote = KynInternal.get_character()
    if not remote then return false end
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", { Skill = "Vitality I",   SkillTreeType = "Character" }); task.wait()
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", { Skill = "Vitality II",  SkillTreeType = "Character" }); task.wait()
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", { Skill = "Vitality III", SkillTreeType = "Character" }); task.wait()
    KynInternal.invoke_with_timeout(remote, 5, "LearnSkill", { Skill = "Worthiness",   SkillTreeType = "Character" }); task.wait(0.3)
    return true
end

function DiscFarm.use_disc(discName, notifyTitle)
    notifyTitle = notifyTitle or "DiscFarm"
    if not WeatherRuntime.has_item(discName) then return false, "no disc" end

    GuiLib:Notify({ Title = notifyTitle, Content = "Using "..tostring(discName).."...", Duration = 3 })
    WeatherRuntime.cleanup(); task.wait(0.5)

    local alive_dl = os.clock() + 10
    while os.clock() < alive_dl do
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if c and c.Parent and h and h.Health > 15 and c:FindFirstChild("HumanoidRootPart") then break end
        task.wait(0.25)
    end

    DiscFarm.learn_skills()

    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false, "no backpack" end
    if LocalPlayer.Character then
        for _, v in ipairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("Tool") then pcall(function() v.Parent = bp end) end
        end
    end
    task.wait(0.2)

    local ok, result = pcall(KynInternal.use_skin_item, discName)
    if not ok then
        GuiLib:Notify({ Title = notifyTitle, Content = "Disc error: "..tostring(result), Type = "warning", Duration = 5 })
        return false, tostring(result)
    end
    if result ~= true then return false, "use failed" end

    local old_stand = WeatherRuntime.get_stand()
    local dl = os.clock() + 10
    while WeatherRuntime.get_stand() == old_stand and os.clock() < dl do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.1)
    end
    task.wait(3)

    if WeatherRuntime.get_stand() == old_stand then return false, "stand didn't change" end

    local skin_name = KynInternal.get_skin_name()
    pcall(KynInternal.send_skin_webhook, skin_name)
    if KynInternal.is_wanted_skin(skin_name) then return true, "wanted" end
    return true, "not wanted"
end

function WeatherRuntime.has_item(name)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild(name) then return true end
    local ch = LocalPlayer.Character
    if ch and ch:FindFirstChild(name) then return true end
    return false
end

function WeatherRuntime.stop_pilot()
    if GLOBALVAR.StopStandPilot then pcall(GLOBALVAR.StopStandPilot) end
end

function WeatherRuntime.stop_boss_farm()
    if WeatherRuntime.FarmingBoss then
        WeatherRuntime.FarmingBoss = false
        pcall(KynInternal.stopAutoBoss)
    end
end

function WeatherRuntime.cleanup()
    WeatherRuntime.stop_boss_farm()
    local character = LocalPlayer.Character
    if character then
        local re = character:FindFirstChild("RemoteEvent")
        if re then pcall(function() re:FireServer("HoldAttack", { Bool = false, Type = "m1" }) end) end
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            local bv = root:FindFirstChild("AutoBossVelocity")
            local bav = root:FindFirstChild("AutoBossAngular")
            if bv then bv:Destroy() end
            if bav then bav:Destroy() end
        end
    end
    WeatherRuntime.stop_pilot()
end

function WeatherRuntime.buy_arrows_if_needed()
    local has_arrow = WeatherRuntime.has_item("Mysterious Arrow")
    local has_lucky = WeatherRuntime.has_item("Lucky Arrow")
    if not has_arrow and not has_lucky then
        if LocalPlayer.PlayerStats.Money.Value >= 3375 then
            pcall(KynInternal.buy_arrow); task.wait(0.5)
        end
    end
end

function WeatherRuntime.ensure_stand()
    if WeatherRuntime.get_stand() ~= "None" then return true end

    if WeatherRuntime.has_item("Weather Report's Disc") then
        local ok = DiscFarm.use_disc("Weather Report's Disc", "Weather Report")
        return ok == true
    end

    if not WeatherRuntime.has_item("Mysterious Arrow") then
        if LocalPlayer.PlayerStats.Money.Value >= 3375 then
            local old = GLOBALVAR.BuyArrows
            GLOBALVAR.BuyArrows = true
            pcall(KynInternal.buy_arrow)
            GLOBALVAR.BuyArrows = old
            task.wait(0.5)
        end
        if not WeatherRuntime.has_item("Mysterious Arrow") then
            if not GLOBALVAR.ItemFarm then
                GLOBALVAR.ItemFarm = true
                KynInternal.onItemFarmToggle()
            local dl = os.clock() + 30
            while os.clock() < dl and not WeatherRuntime.has_item("Mysterious Arrow") do
                task.wait(0.5)
            end
            GLOBALVAR.ItemFarm = false
            KynInternal.onItemFarmToggle()
        end
            if not WeatherRuntime.has_item("Mysterious Arrow") then
                return false
            end
        end
    end

    local arrow = "Mysterious Arrow"
    GuiLib:Notify({ Title = "Weather Report/Diver Down", Content = "Rolling a stand...", Duration = 3 })
    DiscFarm.learn_skills()
    local ok, used = pcall(KynInternal.use_skin_item, arrow)
    if not ok or not used then return false end

    local dl = os.clock() + 8
    while WeatherRuntime.get_stand() == "None" and os.clock() < dl do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.05)
    end
    task.wait(1.5)
    return WeatherRuntime.get_stand() ~= "None"
end

function WeatherRuntime.roka_stand()
    local skin_name = KynInternal.get_skin_name()
    if KynInternal.is_wanted_skin(skin_name) == true then return false, "wanted skin equipped" end
    if WeatherRuntime.get_stand() == "None" then return true end

    local has_roka = WeatherRuntime.has_item("Rokakaka")
    local has_redeemed = WeatherRuntime.has_item("Redeemed Rokakaka")
    if not has_roka and not has_redeemed then
        if LocalPlayer.PlayerStats.Money.Value >= 11250 then
            local old = GLOBALVAR.BuyRokas
            GLOBALVAR.BuyRokas = true
            pcall(KynInternal.buy_roka)
            GLOBALVAR.BuyRokas = old
            task.wait(0.5)
        end
        if not WeatherRuntime.has_item("Rokakaka") and not WeatherRuntime.has_item("Redeemed Rokakaka") then
            if not GLOBALVAR.ItemFarm then
                GLOBALVAR.ItemFarm = true
                KynInternal.onItemFarmToggle()
            local dl = os.clock() + 30
            while os.clock() < dl
                and not WeatherRuntime.has_item("Rokakaka")
                and not WeatherRuntime.has_item("Redeemed Rokakaka") do
                task.wait(0.5)
            end
            GLOBALVAR.ItemFarm = false
            KynInternal.onItemFarmToggle()
        end
            if not WeatherRuntime.has_item("Rokakaka") and not WeatherRuntime.has_item("Redeemed Rokakaka") then
                return false, "no roka in inventory even after farming"
            end
        end
    end

    local used = false
    if WeatherRuntime.has_item("Redeemed Rokakaka") then
        local ok, result = pcall(KynInternal.use_skin_item, "Redeemed Rokakaka")
        used = ok and result == true
    else
        local ok, result = pcall(KynInternal.use_skin_item, "Rokakaka")
        used = ok and result == true
    end
    if not used then return false, "use failed" end

    local old_stand = WeatherRuntime.get_stand()
    local dl = os.clock() + 8
    while WeatherRuntime.get_stand() == old_stand and os.clock() < dl do
        local dg = PlayerGui:FindFirstChild("DialogueGui")
        if dg then
            local cc = dg:FindFirstChild("ClickContinue", true)
            if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        end
        task.wait(0.05)
    end
    task.wait(1.5)
    return WeatherRuntime.get_stand() ~= old_stand
end

function WeatherRuntime.check_wanted_result()
    local skin_name = KynInternal.get_skin_name()
    if not skin_name or skin_name == "None" then return false end
    pcall(KynInternal.send_skin_webhook, skin_name)
    if KynInternal.is_wanted_skin(skin_name) then
        if GLOBALVAR.swapslots then pcall(KynInternal.swap_slots) end
        return true, "wanted skin obtained"
    end
    return false, skin_name
end

function WeatherRuntime.farm_jotaro()
    GLOBALVAR.AutoBossTarget = "Jotaro Kujo"
    if not WeatherRuntime.FarmingBoss then
        WeatherRuntime.FarmingBoss = true
        GLOBALVAR.AutoBoss = true
        task.spawn(function()
            local ok, err = pcall(KynInternal.startAutoBoss)
            if not ok then warn("[Weather Report] Boss start failed:", err); WeatherRuntime.FarmingBoss = false end
        end)
    end
end

function WeatherRuntime.use_disc()
    if not WeatherRuntime.has_item("Weather Report's Disc") then return false end
    local ok, why = DiscFarm.use_disc("Weather Report's Disc", "Weather Report")
    return ok == true
end

function KynInternal.wr_main_loop()
    while WeatherRuntime.Running do
        task.wait(0.25)
        if global_lock then continue end
        if not GLOBALVAR.AutoWeatherReport then task.wait(0.5); continue end
        if WeatherRuntime.Busy then task.wait(0.25); continue end
        WeatherRuntime.Busy = true
        -- Weather's item acquisition needs Item Farm to remain operational.
        -- InventoryBusy already serializes inventory operations.

        local ok, err = pcall(function()
            if KynInternal.is_wanted_skin(KynInternal.get_skin_name()) then
                GuiLib:Notify({ Title = "Weather Report",
                    Content = "Wanted skin already equipped.", Duration = 3 })
                GLOBALVAR.AutoWeatherReport = false
                if GLOBALVAR.__WR_Toggle then GLOBALVAR.__WR_Toggle:SetValue(false) end
                return
            end

            if WeatherRuntime.get_stand() == "None" then
                if WeatherRuntime.has_item("Weather Report's Disc") then
                    WeatherRuntime.State = "USE_DISC"
                    if not WeatherRuntime.use_disc() then task.wait(0.5); return end
                    local wanted, msg = WeatherRuntime.check_wanted_result()
                    if wanted then
                        GuiLib:Notify({ Title = "Weather Report", Content = "Success! "..tostring(msg), Duration = 4 })
                        GLOBALVAR.AutoWeatherReport = false
                        if GLOBALVAR.__WR_Toggle then GLOBALVAR.__WR_Toggle:SetValue(false) end
                        WeatherRuntime.cleanup()
                    else
                        WeatherRuntime.State = "ROKA"
                        WeatherRuntime.roka_stand()
                    end
                    return
                end
                WeatherRuntime.State = "GET_STAND"
                if not WeatherRuntime.ensure_stand() then task.wait(0.5); return end
                return
            end

            if not WeatherRuntime.has_item("Weather Report's Disc") then
                WeatherRuntime.State = "FARM"
                WeatherRuntime.farm_jotaro()
                return
            end

            if WeatherRuntime.has_item("Weather Report's Disc") then
                WeatherRuntime.stop_boss_farm()
                WeatherRuntime.FarmingBoss = false
            end

            WeatherRuntime.State = "ROKA"
            local roka_ok, roka_err = WeatherRuntime.roka_stand()
            if not roka_ok then
                if KynInternal.is_wanted_skin(KynInternal.get_skin_name()) then
                    GuiLib:Notify({ Title = "Weather Report", Content = "Current skin is wanted.", Duration = 3 })
                    GLOBALVAR.AutoWeatherReport = false
                    if GLOBALVAR.__WR_Toggle then GLOBALVAR.__WR_Toggle:SetValue(false) end
                    WeatherRuntime.cleanup()
                else
                    warn("[Weather Report] Roka failed: "..tostring(roka_err))
                    task.wait(0.5)
                end
                return
            end

            task.wait(1)
            WeatherRuntime.State = "USE_DISC"
            if not WeatherRuntime.use_disc() then task.wait(0.5); return end
            task.wait(1)

            local wanted, msg = WeatherRuntime.check_wanted_result()
            if wanted then
                GuiLib:Notify({ Title = "Weather Report", Content = "Success! "..tostring(msg), Duration = 4 })
                GLOBALVAR.AutoWeatherReport = false
                if GLOBALVAR.__WR_Toggle then GLOBALVAR.__WR_Toggle:SetValue(false) end
                WeatherRuntime.cleanup()
            else
                WeatherRuntime.State = "FARM"
                WeatherRuntime.farm_jotaro()
            end
        end)

        DialogueBusy = false

        if not ok then warn("[Weather Report] "..tostring(err)) end
        WeatherRuntime.Busy = false
        task.wait(0.15)
    end
end

function GLOBALVAR.startWeatherReport()
    if WeatherRuntime.Running then return end
    WeatherRuntime.Running = true
    WeatherRuntime.State = "IDLE"
    DialogueBusy = false
    WeatherRuntime.Thread = task.spawn(KynInternal.wr_main_loop)
end

function GLOBALVAR.stopWeatherReport()
    WeatherRuntime.Running = false
    WeatherRuntime.Thread = nil
    DialogueBusy = false
    WeatherRuntime.cleanup()
end

function KynInternal.onWeatherReportToggle()
    if GLOBALVAR.AutoWeatherReport and not WeatherRuntime.Running then
        GLOBALVAR.startWeatherReport()
    elseif not GLOBALVAR.AutoWeatherReport and WeatherRuntime.Running then
        GLOBALVAR.stopWeatherReport()
    end
end

function KynInternal.dd_summon_stand()
    local char = LocalPlayer.Character
    if not char then return end
    local ss = char:FindFirstChild("SummonedStand")
    if ss and not ss.Value then
        local rf = char:FindFirstChild("RemoteFunction")
        if rf then
            pcall(function() rf:InvokeServer("ToggleStand", "Toggle") end)
            task.wait(0.5)
        end
    end
end

function DiverRuntime.pucci_1()
    if not LocalPlayer.Character:FindFirstChild("SummonedStand")
       or not LocalPlayer.Character:FindFirstChild("SummonedStand").Value then
        local rf = LocalPlayer.Character:FindFirstChild("RemoteFunction")
        if rf then
            pcall(function() rf:InvokeServer("ToggleStand", "Toggle") end)
        end
    end

    local alreadyOpen = PlayerGui:FindFirstChild("DialogueGui") ~= nil
    if not alreadyOpen then
        if not DiscFarm.talk_to("Pucci [Lvl. 40+]") then
            return false
        end
    end

    DiscFarm.sequence({2, 1, 1, 1, 1})
    DiscFarm.continue_until_closed(4)

    local closeDl = os.clock() + 2
    while PlayerGui:FindFirstChild("DialogueGui") and os.clock() < closeDl do
        local cc = PlayerGui.DialogueGui:FindFirstChild("ClickContinue", true)
        if cc then pcall(function() firesignal(cc.MouseButton1Click) end) end
        task.wait(0.1)
    end

    DiverRuntime.Step = "ANASUI_1"
    return true
end

function DiverRuntime.anasui_1()
    local alreadyOpen = PlayerGui:FindFirstChild("DialogueGui") ~= nil
    if not alreadyOpen then
        if not DiscFarm.talk_to("Anasui") then
            DiverRuntime.Step = "KILL_JOTARO"
            return true
        end
    end

    DiscFarm.sequence({1, 3, 1, 1})
    DiscFarm.continue_until_closed(3)
    task.wait(0.3)

    if not DiscFarm.talk_to("Anasui", 5) then
        DiverRuntime.Step = "KILL_JOTARO"
        return true
    end
    DiscFarm.sequence({1, 1})
    DiscFarm.continue_until_closed(3)

    DiverRuntime.Step = "KILL_JOTARO"
    return true
end

function DiverRuntime.anasui_2()
    if not DiscFarm.talk_to("Anasui") then return false end
    if not DiscFarm.sequence({1, 1}) then return false end
    DiscFarm.continue_until_closed(4)
    return true
end

function DiverRuntime.pucci_2()
    if not DiscFarm.talk_to("Pucci [Lvl. 40+]") then return false end
    if not DiscFarm.sequence({2, 1, 1, 1}) then return false end
    DiscFarm.continue_until_closed(4)
    return true
end

function DiverRuntime.pucci_3()
    if not DiscFarm.talk_to("Pucci [Lvl. 40+]") then return false end
    if not DiscFarm.sequence({2, 1, 1}) then return false end
    DiscFarm.continue_until_closed(3)
    task.wait(0.4)
    if not DiscFarm.talk_to("Pucci [Lvl. 40+]", 6) then return false end
    if not DiscFarm.click_option(1, 6) then return false end
    DiscFarm.continue_until_closed(3)
    return true
end

function KynInternal.dd_main_loop()
    while DiverRuntime.Running do
        task.wait(0.25)
        if global_lock then continue end
        if not GLOBALVAR.AutoDiverDown then task.wait(0.5); continue end
        if DiverRuntime.Busy then task.wait(0.25); continue end
        if not KynInternal.acquireInventory() then task.wait(0.25); continue end
        DiverRuntime.Busy = true
        DialogueBusy = true

        local ok, err = pcall(function()

            if WeatherRuntime.has_item("Anasui's Disc") and WeatherRuntime.get_stand() == "None" then
                DiverRuntime.State = "USE_DISC"
                local used, why = DiscFarm.use_disc("Anasui's Disc", "Diver Down")
                if not used then
                    warn("[Diver Down] disc use failed: "..tostring(why))
                    task.wait(1)
                    return
                end
                if why == "wanted" then
                    if GLOBALVAR.swapslots then pcall(KynInternal.swap_slots) end
                    GuiLib:Notify({ Title = "Diver Down",
                        Content = "Success! Wanted skin obtained.", Duration = 4 })
                    GLOBALVAR.AutoDiverDown = false
                    if GLOBALVAR.__DD_Toggle then GLOBALVAR.__DD_Toggle:SetValue(false) end
                    WeatherRuntime.cleanup()
                else
                    GuiLib:Notify({ Title = "Diver Down",
                        Content = "Not wanted ("..tostring(KynInternal.get_skin_name()).."), rokaing and continuing skin farm.", Duration = 3 })
                    task.wait(1)
                    WeatherRuntime.roka_stand()
                end
                return
            end

            local current_stand = WeatherRuntime.get_stand()
            if current_stand ~= "Stone Free" then
                DiverRuntime.State = "WAITING_FOR_STONE_FREE"
                DiverRuntime.Prepared = false
                task.wait(1)
                return
            end

            if not DiverRuntime.Prepared then
                DiverRuntime.State = "PREPARING"
                GuiLib:Notify({ Title = "Diver Down",
                    Content = "Resetting...", Duration = 3 })
                task.wait(2)
                KynInternal.dd_reset_player()
                task.wait(3)
                KynInternal.dd_summon_stand()
                task.wait(1)
                DiverRuntime.Prepared = true
                return
            end

            DiverRuntime.Cycle = DiverRuntime.Cycle + 1

            DiverRuntime.State = "PUCCI_1"
            if not DiverRuntime.pucci_1() then
                task.wait(1)
                return
            end

            DiverRuntime.State = "ANASUI_1"
            if not DiverRuntime.anasui_1() then
                task.wait(1)
                return
            end

            if not WeatherRuntime.has_item("Jotaro's Disc") then
                DiverRuntime.State = "KILL_JOTARO"
                GuiLib:Notify({ Title = "Diver Down",
                    Content = "Killing Jotaro Kujo for Jotaro's Disc...", Duration = 3 })
                if not DiscFarm.kill_boss("Jotaro Kujo", "Jotaro's Disc", 500) then
                    task.wait(2)
                    return
                end
                if not WeatherRuntime.has_item("Jotaro's Disc") then
                    task.wait(2)
                    return
                end
            end

            DiverRuntime.State = "ANASUI_2"
            if not DiverRuntime.anasui_2() then
                task.wait(1)
                return
            end

            DiverRuntime.State = "PUCCI_2"
            if not DiverRuntime.pucci_2() then
                task.wait(1)
                return
            end

            DiverRuntime.State = "KILL_ANASUI"
            GuiLib:Notify({ Title = "Diver Down", Content = "Killing Anasui...", Duration = 3 })
            if not DiscFarm.kill_boss("Anasui", nil, 500) then
                task.wait(2)
                return
            end
            task.wait(1)

            DiverRuntime.State = "PUCCI_3"
            if not DiverRuntime.pucci_3() then
                task.wait(1)
                return
            end

            GuiLib:Notify({ Title = "Diver Down",
                Content = "Cycle done. Checking for Anasui's Disc...", Duration = 3 })
        end)

        DialogueBusy = false

        if not ok then warn("[Diver Down] "..tostring(err)) end
        DiverRuntime.Busy = false
        KynInternal.releaseInventory()
        task.wait(0.2)
    end
end

function GLOBALVAR.startDiverDown()
    if DiverRuntime.Running then return end
    DiverRuntime.Running = true
    DiverRuntime.State = "IDLE"
    DiverRuntime.Cycle = 0
    DiverRuntime.Prepared = false
    DiverRuntime.Thread = task.spawn(KynInternal.dd_main_loop)
end

function GLOBALVAR.stopDiverDown()
    DiverRuntime.Running = false
    DiverRuntime.Thread = nil
    DiverRuntime.State = "IDLE"
    DiverRuntime.Prepared = false
    pcall(KynInternal.stopAutoBoss)
    WeatherRuntime.cleanup()
end

function KynInternal.onDiverDownToggle()
    if GLOBALVAR.AutoDiverDown and not DiverRuntime.Running then
        GLOBALVAR.startDiverDown()
    elseif not GLOBALVAR.AutoDiverDown and DiverRuntime.Running then
        GLOBALVAR.stopDiverDown()
    end
end


local Living = workspace:WaitForChild("Living")
local ESPConnection = nil
local ESPHealthConnections = {}

function KynInternal.removeESP(character)
    local conn = ESPHealthConnections[character]
    if conn then conn:Disconnect() ESPHealthConnections[character] = nil end
    for _, name in ipairs({"KynESP", "KynESPInfo"}) do
        local obj = character:FindFirstChild(name)
        if obj then obj:Destroy() end
    end
end

function KynInternal.updateESP(character)
    if not GLOBALVAR.ESP or character.Name == LocalPlayer.Name then return end
    local player = Players:FindFirstChild(character.Name)
    if not player or player.Character ~= character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return end

    if not character:FindFirstChild("KynESP") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "KynESP"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(255, 60, 60)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.65
        highlight.OutlineTransparency = 0
        highlight.Parent = character
    end

    if character:FindFirstChild("KynESPInfo") then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "KynESPInfo"
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(150, 58)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
    billboard.Parent = character

    local username = Instance.new("TextLabel")
    username.Name = "Username"
    username.BackgroundTransparency = 1
    username.Size = UDim2.new(1, 0, 0, 22)
    username.Font = Enum.Font.GothamBold
    username.TextSize = 13
    username.TextColor3 = Color3.new(1, 1, 1)
    username.TextStrokeTransparency = 0.3
    username.Text = GLOBALVAR.spoof_user and "User" or player.Name
    username.Parent = billboard

    local background = Instance.new("Frame")
    background.Name = "HealthBackground"
    background.AnchorPoint = Vector2.new(0.5, 0)
    background.Position = UDim2.new(0.5, 0, 0, 25)
    background.Size = UDim2.new(0, 116, 0, 9)
    background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    background.BorderSizePixel = 0
    background.Parent = billboard
    Instance.new("UICorner", background).CornerRadius = UDim.new(0, 4)

    local bar = Instance.new("Frame")
    bar.Name = "HealthFill"
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = Color3.fromRGB(60, 220, 100)
    bar.Size = UDim2.fromScale(1, 1)
    bar.Parent = background
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

local healthText = Instance.new("TextLabel")
healthText.Name = "HealthNumbers"
healthText.BackgroundTransparency = 1
healthText.Position = UDim2.new(0, 0, 0, 36)
healthText.Size = UDim2.new(1, 0, 0, 16)
healthText.Font = Enum.Font.GothamBold
healthText.TextSize = 12
healthText.TextColor3 = Color3.new(1, 1, 1)
healthText.TextStrokeTransparency = 0.25
healthText.TextXAlignment = Enum.TextXAlignment.Center
healthText.Parent = billboard

    local function refreshHealth()
        if not billboard.Parent then return end
healthText.Text = string.format("%d / %d",
    math.ceil(math.max(humanoid.Health, 0)),
    math.ceil(math.max(humanoid.MaxHealth, 0))
)
        local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
        bar.Size = UDim2.fromScale(fraction, 1)
        bar.BackgroundColor3 = Color3.fromRGB(
            math.floor(255 * (1 - fraction)),
            math.floor(220 * fraction),
            65
        )
    end
    refreshHealth()
    local healthConn = humanoid.HealthChanged:Connect(refreshHealth)
    local maxConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth)
    ESPHealthConnections[character] = {
        Disconnect = function()
            healthConn:Disconnect()
            maxConn:Disconnect()
        end
    }
end

function KynInternal.setESP(enabled)
    GLOBALVAR.ESP = enabled == true
    if GLOBALVAR.ESP then
        if not ESPConnection then
            ESPConnection = Living.ChildAdded:Connect(function(character)
                task.spawn(function()
                    character:WaitForChild("Head", 5)
                    character:WaitForChild("Humanoid", 5)
                    KynInternal.updateESP(character)
                end)
            end)
        end
        for _, character in ipairs(Living:GetChildren()) do
            task.spawn(function()
                character:WaitForChild("Head", 5)
                KynInternal.updateESP(character)
            end)
        end
    else
        if ESPConnection then ESPConnection:Disconnect() ESPConnection = nil end
        for _, character in ipairs(Living:GetChildren()) do
            KynInternal.removeESP(character)
        end
    end
end

function KynInternal.ui_create()
local Window = GuiLib:CreateWindow({
    Title = "Kyn",
    SubTitle = "by 839198829298393992",
    Width = 620,
    Height = 420,
    ToggleKey = Enum.KeyCode.RightShift,
    Scale = 1,
    ClosedIcon = { Enabled = true, MobileOnly = true },
})

if GLOBALVAR.UI_THEME then
    local key = tostring(GLOBALVAR.UI_THEME)
    local themea = GuiLib.Themes[key]
        or GuiLib.Themes[key:gsub("%s+", "")]
        or GuiLib.Themes[key:gsub("%s+", ""):lower()]
    if themea then
        GuiLib:SetTheme(themea)
    end
end

local Watermark = Window:CreateWatermark({
    Text = "Kyn | {fps} fps | {ping} ms",
    Position = UDim2.new(0, 12, 0, 12),
    Enabled = GLOBALVAR.watermark_enabled,
})

if Window.SetActiveFeaturesEnabled then
    Window:SetActiveFeaturesEnabled(GLOBALVAR.watermark_enabled)
end

local UI = {}

UI.ItemTab     = Window:AddTab({ Name = "Item Farm" })
UI.ItemSec     = UI.ItemTab:AddSection("Items")
UI.SellSec     = UI.ItemTab:AddSection("Selling")
UI.BuySec      = UI.ItemTab:AddSection("Auto Buy")
UI.HopSec      = UI.ItemTab:AddSection("Server")

UI.SkinTab     = Window:AddTab({ Name = "Skin Farm" })
UI.SkinMainSub = UI.SkinTab:AddSubTab("Skin")
UI.SkinArrowSub= UI.SkinTab:AddSubTab("Arrows")
UI.SkinEvoSub  = UI.SkinTab:AddSubTab("Evolution")

UI.SkinSec     = UI.SkinMainSub:AddSection("Skin Farm")
UI.ArrowSec    = UI.SkinArrowSub:AddSection("Arrows & Skins")
UI.EvoSec      = UI.SkinEvoSub:AddSection("Evolution")

UI.PvpTab      = Window:AddTab({ Name = "PvP" })
UI.PvpParrySub = UI.PvpTab:AddSubTab("Parry")
UI.PvpAimSub   = UI.PvpTab:AddSubTab("Silent Aim")
UI.PvpPilotSub = UI.PvpTab:AddSubTab("Pilot")
UI.PvpMiscSub  = UI.PvpTab:AddSubTab("Misc")

UI.PvpSec      = UI.PvpParrySub:AddSection("Auto Parry")
UI.AimSec      = UI.PvpAimSub:AddSection("Silent Aim")
UI.PilotSec    = UI.PvpPilotSub:AddSection("Stand Pilot")
UI.InvisSec    = UI.PvpMiscSub:AddSection("Misc")

UI.AutoFarmTab = Window:AddTab({ Name = "Auto Farm" })
UI.BossSec     = UI.AutoFarmTab:AddSection("Boss")

UI.MiscTab     = Window:AddTab({ Name = "Misc" })
UI.JesusSec    = UI.MiscTab:AddSection("Jesus")
UI.ESPSec      = UI.MiscTab:AddSection("ESP")
UI.SpeedSec      = UI.MiscTab:AddSection("Character")

UI.SettingsTab = Window:AddTab({ Name = "Settings" })
UI.SetMiscSub  = UI.SettingsTab:AddSubTab("Main")
UI.MiscSec       = UI.SetMiscSub:AddSection("Streamer & Webhook")
UI.AppearanceSec = UI.SetMiscSub:AddSection("Appearance")

UI.ItemSec:AddLabel("Automatically collects selected items from the ground. Prioritises higher valued items.")

KynInternal.Register("ItemFarm", UI.ItemSec:AddToggle({
    Name = "Item Farm",
    Tooltip = "Collects items based on your selection below.",
    Default = GLOBALVAR.ItemFarm,
    Callback = function(state)
        GLOBALVAR.ItemFarm = state
        KynInternal.onItemFarmToggle()
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("ItemsToGrab", UI.ItemSec:AddDropdown({
    Name = "Only grab these items",
    Values = Items,
    Multi = true,
    Default = GLOBALVAR.itemsToGrab,
    Callback = function(selectedList)
        GLOBALVAR.itemsToGrab = selectedList
        ItemFarmRuntime.SortDirty = true
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("PickupDelay", UI.ItemSec:AddSlider({
    Name = "Item Pickup Delay (ms)",
    Tooltip = "How long to wait between teleport and pickup (recommended 50).",
    Min = 31, Max = 200,
    Decimals = 0,
    Default = GLOBALVAR.pickup_delay * 100,
    Callback = function(value)
        GLOBALVAR.pickup_delay = value / 100
        KynInternal.saveSettings()
    end,
}))

UI.SellSec:AddLabel("Sells selected inventory items automatically.")

KynInternal.Register("SellAll", UI.SellSec:AddToggle({
    Name = "Auto Sell Items",
    Tooltip = "Sells items in your inventory that match the selection below.",
    Default = GLOBALVAR.sellall,
    Callback = function(state)
        GLOBALVAR.sellall = state
        KynInternal.onSellToggle()
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("ItemsToSell", UI.SellSec:AddDropdown({
    Name = "Items to Sell",
    Values = Items,
    Multi = true,
    Default = GLOBALVAR.itemsToSell,
    Callback = function(selectedList)
        GLOBALVAR.itemsToSell = selectedList
        KynInternal.saveSettings()
    end,
}))

UI.BuySec:AddLabel("Buys arrows, rokas, and lucky arrows from shops automatically.")

KynInternal.Register("BuyLucky", UI.BuySec:AddToggle({
    Name = "Automatically Buy Lucky Arrows",
    Tooltip = "Auto buys Lucky Arrows when you have enough money. (75k)",
    Default = GLOBALVAR.BuyLuckyArrows,
    Callback = function(state)
        GLOBALVAR.BuyLuckyArrows = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("BuyArrows", UI.BuySec:AddToggle({
    Name = "Automatically Buy Arrows",
    Tooltip = "Auto buys 5x Mysterious Arrows when you have enough money. (3k)",
    Default = GLOBALVAR.BuyArrows,
    Callback = function(state)
        GLOBALVAR.BuyArrows = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("BuyRokas", UI.BuySec:AddToggle({
    Name = "Automatically Buy Rokakakas",
    Tooltip = "Auto buys 5x Rokakakas when you have enough money. (11k)",
    Default = GLOBALVAR.BuyRokas,
    Callback = function(state)
        GLOBALVAR.BuyRokas = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("BuyRibs", UI.BuySec:AddToggle({
    Name = "Automatically Buy Ribcages",
    Tooltip = "Auto buys 5x Ribcages when you have enough money. (15k)",
    Default = GLOBALVAR.BuyRibs,
    Callback = function(state)
        GLOBALVAR.BuyRibs = state
        KynInternal.saveSettings()
    end,
}))

UI.HopSec:AddLabel("Automatically hops servers on an interval (60 seconds).")

KynInternal.Register("ServerHop", UI.HopSec:AddToggle({
    Name = "Server Hop",
    Tooltip = "Hops to a new server every 60 seconds.",
    Default = GLOBALVAR.hop_enabled,
    Callback = function(state)
        GLOBALVAR.hop_enabled = state
        KynInternal.saveSettings()
    end,
}))

if KynInternal.hasPremium() then

    UI.SkinSec:AddLabel("Uses arrows, rokas, lucky arrows, ribcages, and requiem arrows to roll for wanted skins or stands.")

    GLOBALVAR.Novex_SkinFarmToggle = KynInternal.Register("SkinFarm", UI.SkinSec:AddToggle({
        Name = "Skin Farm",
        Tooltip = "Automatically rolls for wanted skins/stands. If you currently have a skin equipped, roka it.",
        Default = GLOBALVAR.skin_farm,
        Callback = function(state)
            if state and KynInternal.is_skin() then
                GuiLib:Notify({
                    Title = "Kyn",
                    Content = "Roka your skin first",
                    Type = "warning",
                })
                GLOBALVAR.skin_farm = false
                GLOBALVAR.Novex_SkinFarmToggle:SetValue(false)
                return
            end
            GLOBALVAR.skin_farm = state
            if state then startSkinFarm() else stopSkinFarm() end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("WantedSkins", UI.SkinSec:AddDropdown({
        Name = "Wanted Skins Or Stands",
        Values = {
            "Xenoraptor", "Scary World", "Nether Report", "Aang", "Zeus (GOW)", "Korra", "Joe's Pride","Bloodthirster","Ghost World","Crazy Overseer","The Doorman",
            "SCP-106","Diva Down","Bondrewd","Jack-O-Platinum","Grim Reaper","Ghostface",
            "Astral Enigma","The Bunny Devil","Wispy Willow","Haunted Jack-O-Platinum",
            "Tyrant Crimson","King Crimson","King Crimson Requiem","Star Platinum",
            "Star Platinum: The World","Silver Chariot","Chariot Requiem","Gold Experience",
            "Gold Experience Requiem","Killer Queen","Stone Free","Diver Down","The World",
            "Whitesnake","Crazy Diamond","Hierophant Green","Magician's Red","Purple Haze",
            "Red Hot Chili Pepper","Sticky Fingers","The Hand","White Album","Aerosmith",
            "Anubis","Cream","Hermit Purple","Beach Boy","Mr President","Ace","Luffy Gear 4",
            "Mr. Tentacles","Asuna","Blade of The Exile","Elucidator & Dark Repulser",
            "Hollow Ace","Arlong","Neon Ascension Diamond","Thanos","Golden Frieza",
            "Shadow Killer Queen","Biblically Accurate Experience","Yuji Itadori",
            "Headhunter","Whisper","Mr. Pekin","Warhammer Titan","King of The End",
            "Comic Venom Spider-Man","Scary Monsters: The World Alternate Universe",
            "Hidden Leaf Hero","Deadeye Drifter","Spunch Bop","O5 Keycard",
            "Pillage & Plunder","Fury Nautilodaunt","Nautilodaunt"
        },
        Multi = true,
        Default = GLOBALVAR.wanted_skins,
        Callback = function(selectedList)
            GLOBALVAR.wanted_skins = selectedList
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoDiverDown", UI.SkinSec:AddToggle({
    Name = "Auto Diver Down",
    Tooltip = "Farms the Diver Down quest loop: Pucci → Anasui → kill Jotaro → Anasui → Pucci → kill Anasui → Pucci → use Anasui's Disc. Loops until it gets a wanted skin.",
    Default = GLOBALVAR.AutoDiverDown,
    Callback = function(state)
        GLOBALVAR.AutoDiverDown = state
        if state then GLOBALVAR.startDiverDown() else GLOBALVAR.stopDiverDown() end
        KynInternal.saveSettings()
    end,
}))
    GLOBALVAR.__DD_Toggle = UIRegistry["AutoDiverDown"]

    UI.ArrowSec:AddLabel("Choose which items to use and which skins/stands to keep.")

    KynInternal.Register("SelectedArrows", UI.ArrowSec:AddDropdown({
        Name = "Arrows to Use",
        Values = {
            "Lucky Arrow",
            "Mysterious Arrow",
            "Stand Arrow",
            "Rib Cage of The Saint's Corpse",
            "Redeemed Rib Cage of The Saint's Corpse",
            "Redeemed Mysterious Arrow",
            "Redeemed Lucky Arrow"
        },
        Multi = true,
        VisibleWhen = "Skin Farm",
        Default = GLOBALVAR.selectedArrows,
        Callback = function(selectedList)
            GLOBALVAR.selectedArrows = selectedList
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("OnlyLAPity", UI.ArrowSec:AddToggle({
        Name = "Only use Lucky Arrow if pity is low",
        Tooltip = "Prevents Lucky Arrow use unless pity count is above 25.",
        Default = GLOBALVAR.onlyLAwhenPityGood,
        VisibleWhen = "Skin Farm",
        Callback = function(state)
            GLOBALVAR.onlyLAwhenPityGood = state
            KynInternal.saveSettings()
        end,
    }))

    UI.EvoSec:AddLabel("Automatically evolves stands if the Requiem Arrow quest is completed.")

    KynInternal.Register("EvoSkins", UI.EvoSec:AddToggle({
        Name = "Evolve Skins",
        Tooltip = "Requires the Requiem Arrow quest to be completed or a requiem arrow in your inventory.",
        Default = GLOBALVAR.evo_skins,
        Callback = function(state)
            GLOBALVAR.evo_skins = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("EvoStands", UI.EvoSec:AddDropdown({
        Name = "Stands to Evolve",
        Values = {
            "Silver Chariot","Gold Experience","Star Platinum","King Crimson","Killer Queen"
        },
        Multi = true,
        Default = GLOBALVAR.evo_stands,
        VisibleWhen = "Evolve Skins",
        Callback = function(selectedList)
            GLOBALVAR.evo_stands = selectedList
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("SwapSlots", UI.SkinSec:AddToggle({
        Name = "Swap Slots On Wanted Skin",
        Tooltip = "Puts wanted skins into an empty slot instead of stopping.",
        Default = GLOBALVAR.swapslots,
        VisibleWhen = "Skin Farm",
        Callback = function(state)
            GLOBALVAR.swapslots = state
            KynInternal.saveSettings()
        end,
    }))

    UI.PvpSec:AddLabel("Blocks, parries, unblocks, or counters against an incoming enemy attack.")

    KynInternal.Register("AutoBlock", UI.PvpSec:AddToggle({
        Name = "Auto Block and Parry",
        Tooltip = "Automatically blocks/parries/unblocks against incoming attacks.",
        Default = GLOBALVAR.AutoBlockConfig.enabled,
        Callback = function(state)
            GLOBALVAR.AutoBlockConfig.enabled = state
            if state then KynInternal.enable_ap_childadded() else KynInternal.disable_ap_childadded() end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoBlockMinDot", UI.PvpSec:AddSlider({
        Name = "Enemy Cone Angle",
        Tooltip = "If you are inside of the enemies cone vision then it will block immediately, otherwise it will delay it to parry linger.",
        Default = (GLOBALVAR.FaceMinDot * 100),
        Min = 0, Max = 50,
        Decimals = 0,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(state)
            GLOBALVAR.FaceMinDot = (state / 100)
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoBlockStableTime", UI.PvpSec:AddSlider({
        Name = "Cone Stable Time",
        Tooltip = "How long the enemy has to be facing you for before it parries, please use lower number if high ping. Set to 0 to disable.",
        Default = (GLOBALVAR.StableTime * 100),
        Min = 0, Max = 30,
        Decimals = 0,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(state)
            GLOBALVAR.StableTime = (state / 100)
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoBarrage", UI.PvpSec:AddToggle({
        Name = "Auto Barrage",
        Tooltip = "Automatically barrage back instantly when the enemy uses a barrage.",
        Default = GLOBALVAR.BarrageBack,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(state)
            GLOBALVAR.BarrageBack = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("MoveCancel", UI.PvpSec:AddToggle({
        Name = "Auto Cancel Unblockable Moves",
        Tooltip = "Unblocks and m1s the enemy during unblockable enemy moves in an attempt to cancel them.",
        Default = GLOBALVAR.MoveCancel,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(state)
            GLOBALVAR.MoveCancel = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoCounter", UI.PvpSec:AddToggle({
        Name = "Auto Counter",
        Tooltip = "Automatically uses counter against unblockable moves.",
        Default = GLOBALVAR.AutoBlockConfig.AutoEpitaph,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(state)
            GLOBALVAR.AutoBlockConfig.AutoEpitaph = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoCounterKey", UI.PvpSec:AddDropdown({
        Name = "Auto Counter Keybind",
        Values = {"T", "Z", "X", "C", "V", "B", "G", "U", "J"},
        Default = GLOBALVAR.AutoBlockConfig.AutoEpitaphKey and GLOBALVAR.AutoBlockConfig.AutoEpitaphKey.Name or "T",
        Multi = false,
        VisibleWhen = "Auto Counter",
        Callback = function(value)
            GLOBALVAR.AutoBlockConfig.AutoEpitaphKey = Enum.KeyCode[value]
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("KeepBlocking", UI.PvpSec:AddToggle({
        Name = "Keep Blocking",
        Tooltip = "Blocks again after a parry if your F key is still held.",
        Default = GLOBALVAR.AutoBlockConfig.reblocking,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(state)
            GLOBALVAR.AutoBlockConfig.reblocking = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("AutoBlockDist", UI.PvpSec:AddSlider({
        Name = "Auto Block/Parry Distance",
        Tooltip = "Enemies attacking outside of this stud radius will be ignored.",
        Min = 5, Max = 100,
        Decimals = 0,
        Default = GLOBALVAR.AutoBlockConfig.distance or 50,
        VisibleWhen = "Auto Block and Parry",
        Callback = function(v)
            GLOBALVAR.AutoBlockConfig.distance = v
            KynInternal.saveSettings()
        end,
    }))

    UI.AimSec:AddLabel("Hooks YBA's aim system to only throw projectiles at the nearest target within the FOV circle.")

    KynInternal.Register("AccBlatant", UI.AimSec:AddToggle({
    Name = "Blatant Silent Aim",
    Tooltip = "Teleports your projectiles to your target and uses the mouse hook.",
    Default = GLOBALVAR.AccuracyBlatant,
    Callback = function(state)
        GLOBALVAR.SilentAim.setBlatant(state)

        GLOBALVAR.SilentAim.setEnabled(
            state or GLOBALVAR.SilentAimEnabled == true
        )

        GLOBALVAR.AccuracyAim.setEnabled(state)

        if state then
            KynInternal.startTargetUpdater()
        else
            KynInternal.stopTargetUpdater()
        end

        if GLOBALVAR.UpdateSACircle then
            GLOBALVAR.UpdateSACircle()
        end

        KynInternal.saveSettings()
    end,
}))

    KynInternal.Register("SilentAim", UI.AimSec:AddToggle({
    Name = "Normal Silent Aim",
    Tooltip = "Only hooks your mouse location to aim at targets.",
    Default = GLOBALVAR.SilentAimEnabled,
    Callback = function(state)
        GLOBALVAR.SilentAimEnabled = state

        GLOBALVAR.SilentAim.setEnabled(
            state or GLOBALVAR.AccuracyBlatant == true
        )

        if GLOBALVAR.UpdateSACircle then
            GLOBALVAR.UpdateSACircle()
        end

        KynInternal.saveSettings()
    end,
}))

    KynInternal.Register("SilentAimFOV", UI.AimSec:AddSlider({
        Name = "Silent Aim FOV",
        Tooltip = "Radius in pixels around your crosshair to search for targets.",
        Min = 50, Max = 600,
        Decimals = 0,
        Default = GLOBALVAR.SilentAimFOV or 150,
        Callback = function(value)
            GLOBALVAR.SilentAimFOV = value
            GLOBALVAR.SilentAim.setFOV(value)
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("SilentAimRange", UI.AimSec:AddSlider({
        Name = "Silent Aim Range",
        Tooltip = "Max stud distance to consider a target.",
        Min = 5, Max = 200,
        Decimals = 0,
        Default = GLOBALVAR.SilentAimRange or 200,
        Callback = function(value)
            GLOBALVAR.SilentAimRange = value
            GLOBALVAR.AccuracyRange = value
            if GLOBALVAR.AccuracyAim then
            GLOBALVAR.AccuracyAim.setRange(value)
            end
            GLOBALVAR.SilentAim.setRange(value)
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("SilentAimHead", UI.AimSec:AddToggle({
        Name = "Aim for Head",
        Tooltip = "Aims for the head instead of torso (honestly not worth it it makes it harder to aim).",
        Default = GLOBALVAR.SilentAimHead,
        Callback = function(state)
            GLOBALVAR.SilentAim.setAimHead(state)
            KynInternal.saveSettings()
        end,
    }))

    UI.InvisSec:AddLabel("Invisibility and other risky PvP utilities.")

    KynInternal.Register("Invis", UI.InvisSec:AddToggle({
        Name = "Invisibility",
        Tooltip = "Hides your server sided body under the map, risky because it shows your body when you ragdoll or go high up.",
        Default = GLOBALVAR.Invis,
        Callback = function(state)
            GLOBALVAR.Invis = state
            if state then KynInternal.Invisibile() else KynInternal.Uninvisible() end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("Reach", UI.InvisSec:AddToggle({
        Name = "Reach",
        Tooltip = "Moves your stand further out when you attack.",
        Default = GLOBALVAR.ReachEnabled,
        Callback = function(state)
            GLOBALVAR.ReachEnabled = state
            if state then
                KynInternal.hookStandAttachment(LocalPlayer.Character)
            else
                KynInternal.unhookStandAttachment()
            end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("ReachDistance", UI.InvisSec:AddSlider({
        Name = "Reach Amount",
        Tooltip = "How far your stand goes out (3 recommended).",
        Default = GLOBALVAR.ReachDistance,
        Min = 2, Max = 10,
        Decimals = 1,
        VisibleWhen = "Reach",
        Callback = function(state)
            GLOBALVAR.ReachDistance = state
            KynInternal.saveSettings()
        end,
    }))

end

    UI.PilotSec:AddLabel("Controls your Stand directly. Press the bind key to toggle.")

    KynInternal.Register("StandPilot", UI.PilotSec:AddToggle({
        Name = "Stand Pilot",
        Tooltip = "Attaches your camera to your Stand and controls it directly.",
        Default = GLOBALVAR.StandPilot,
        Callback = function(state)
            GLOBALVAR.StandPilot = state
            if state then GLOBALVAR.StartStandPilot() else GLOBALVAR.StopStandPilot() end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("StandSpeed", UI.PilotSec:AddSlider({
        Name = "Stand Speed",
        Tooltip = "Multiplier applied to your Stand's walk speed while piloting.",
        Min = 0.1, Max = 5,
        Decimals = 1,
        Default = GLOBALVAR.StandSpeed,
        VisibleWhen = "Stand Pilot",
        Callback = function(value)
            GLOBALVAR.StandSpeed = value
            if PilotActive and Humanoid and StandHumanoid then
                StandHumanoid.WalkSpeed = Humanoid.WalkSpeed * value
            end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("StandJump", UI.PilotSec:AddSlider({
        Name = "Stand Jump Power",
        Tooltip = "Multiplier applied to your Stand's jump power while piloting.",
        Min = 0.1, Max = 5,
        Decimals = 1,
        Default = GLOBALVAR.PilotJumpPower,
        VisibleWhen = "Stand Pilot",
        Callback = function(value)
            GLOBALVAR.PilotJumpPower = value
            if PilotActive and Humanoid and StandHumanoid then
                StandHumanoid.JumpPower = Humanoid.JumpPower * value
            end
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("HideBody", UI.PilotSec:AddToggle({
        Name = "Hide Body",
        Tooltip = "Hides your body under the map while piloting.",
        Default = GLOBALVAR.HidePilotBody,
        VisibleWhen = "Stand Pilot",
        Callback = function(state)
            GLOBALVAR.HidePilotBody = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("TeleportBody", UI.PilotSec:AddToggle({
        Name = "Teleport Body to Stand on Exit",
        Tooltip = "On un pilot, teleports your body to the Stand's position.",
        Default = GLOBALVAR.TeleportBodyToStand,
        VisibleWhen = "Stand Pilot",
        Callback = function(state)
            GLOBALVAR.TeleportBodyToStand = state
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("BodyDistance", UI.PilotSec:AddSlider({
        Name = "Body Distance",
        Tooltip = "How far below the Stand your body stays while hidden (you cant attack if its too high).",
        Min = 5, Max = 100,
        Decimals = 0,
        Default = GLOBALVAR.PilotBodyDistance,
        VisibleWhen = "Stand Pilot",
        Callback = function(value)
            GLOBALVAR.PilotBodyDistance = value
            KynInternal.saveSettings()
        end,
    }))

    KynInternal.Register("PilotKey", UI.PilotSec:AddDropdown({
        Name = "Pilot Toggle Key",
        Values = {"H", "J", "K", "L", "G", "B"},
        Default = GLOBALVAR.PilotKey,
        Multi = false,
        VisibleWhen = "Stand Pilot",
        Callback = function(value)
            GLOBALVAR.PilotKey = value
            KynInternal.saveSettings()
        end,
    }))

UI.BossSec:AddLabel("Teleports you to the boss and farms it with stand pilot.")

KynInternal.Register("AutoWeatherReport", UI.BossSec:AddToggle({
    Name = "Auto Weather Report",
    Tooltip = "Farms Jotaro Kujo until he drops a Weather Report's Disc, then rokakas your stand and uses the disc. Stops (or swaps slots) if the result is a wanted skin.",
    Default = GLOBALVAR.AutoWeatherReport,
    Callback = function(state)
        GLOBALVAR.AutoWeatherReport = state
        if state then
            GLOBALVAR.startWeatherReport()
        else
            GLOBALVAR.stopWeatherReport()
        end
        KynInternal.saveSettings()
    end,
}))

GLOBALVAR.__WR_Toggle = UIRegistry["AutoWeatherReport"]

KynInternal.Register("AutoQuest", UI.BossSec:AddToggle({
    Name = "Auto Grab Quest",
    Tooltip = "Automatically grabs the quest before killing boss when autoboss is enabled.",
    Default = GLOBALVAR.AutoQuest,
    Callback = function(state)
        GLOBALVAR.AutoQuest = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("QuestTarget", UI.BossSec:AddDropdown({
    Name = "Quest To Grab",
    Values = {
        "Abbacchio's Partner [Lvl 15+]", "DIO [Lvl. 35+]", "Darius, The Executioner [Lvl. 20+]", "Deputy Bertrude [Lvl. 10+]", "Doppio [Lvl. 30+]", "Dracula [Lvl. 20+]", "Jotaro (Heaven)", "Officer Sam [Lvl. 1+]", "William Zeppeli [Lvl. 25+]"
    },
    Default = GLOBALVAR.AutoQuestTarget,
    Multi = false,
    VisibleWhen = "Auto Grab Quest",
    Callback = function(option)
        GLOBALVAR.AutoQuestTarget = option
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("AutoBoss", UI.BossSec:AddToggle({
    Name = "Auto Farm Boss",
    Tooltip = "Auto attacks the selected boss with your Stand.",
    Default = GLOBALVAR.AutoBoss,
    Callback = function(state)
        GLOBALVAR.AutoBoss = state
        if state then KynInternal.startAutoBoss() else KynInternal.stopAutoBoss() end
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("BossTarget", UI.BossSec:AddDropdown({
    Name = "Auto Boss Target",
    Values = {
        "Anasui","Bucciarati","DIO","Diavolo","Fugo","Ghiaccio",
        "Heaven Ascension DIO","Jotaro","Jotaro Kujo","Leaky Eye Luca",
        "Pesci","Yoshikage Kira"
    },
    Default = GLOBALVAR.AutoBossTarget,
    Multi = false,
    VisibleWhen = "Auto Farm Boss",
    Callback = function(option)
        GLOBALVAR.AutoBossTarget = option
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("DistanceFromBoss", UI.BossSec:AddSlider({
    Name = "Distance From Boss",
    Tooltip = "How far over or under your body is from the boss.",
    Min = -30, Max = 30,
    Decimals = 0,
    Default = GLOBALVAR.DistanceFromBoss,
    Callback = function(value)
        GLOBALVAR.DistanceFromBoss = value
        KynInternal.saveSettings()
    end,
}))

UI.JesusSec:AddLabel("Talk to Jesus even when he isn't spawned.")

KynInternal.Register("TalkToJesus", UI.JesusSec:AddButton({
    Name = "Talk To Jesus",
    Tooltip = "Talks to jesus even if he isn't spawned.",
    Callback = function(state)
        if not workspace.Dialogues:FindFirstChild("Model") then
            local m = Instance.new("Model")
            local dval = Instance.new("StringValue")
            dval.Name = "Dialogue"
            dval.Value = "Jesus"
            dval.Parent = m
            local prompt = Instance.new("ProximityPrompt")
            prompt.Parent = m
            m.Parent = workspace.Dialogues
            fireproximityprompt(prompt)
        else
            local m = workspace.Dialogues:FindFirstChild("Model")
            if m and m:FindFirstChild("ProximityPrompt") then
                fireproximityprompt(m.ProximityPrompt)
            end
        end
    end,
}))

UI.ESPSec:AddLabel("Highlights other players through walls.")

KynInternal.Register("ESP", UI.ESPSec:AddToggle({
    Name = "Player ESP",
    Tooltip = "Highlights other players through walls.",
    Default = GLOBALVAR.ESP == true,
    Callback = function(state)
        KynInternal.setESP(state)
        KynInternal.saveSettings()
    end,
}))

UI.SpeedSec:AddLabel("Modify your character's walk speed and jump power.")

KynInternal.Register("WalkMod", UI.SpeedSec:AddToggle({
    Name = "Modify Walkspeed",
    Tooltip = "Overrides your Humanoid.WalkSpeed.",
    Default = GLOBALVAR.WalkSpeedModifier,
    Callback = function(state)
        Runtime.Humanoid = KynInternal.get_character():FindFirstChild("Humanoid")
        GLOBALVAR.WalkSpeedModifier = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("WalkSpeed", UI.SpeedSec:AddSlider({
    Name = "Walkspeed",
    Tooltip = "Target walk speed value.",
    Min = 0, Max = 500,
    Decimals = 0,
    Default = GLOBALVAR.WalkSpeedValue,
    VisibleWhen = "Modify Walkspeed",
    Callback = function(value)
        GLOBALVAR.WalkSpeedValue = value
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("JumpMod", UI.SpeedSec:AddToggle({
    Name = "Modify Jump",
    Tooltip = "Overrides your Humanoid.JumpPower.",
    Default = GLOBALVAR.JumpModifier,
    Callback = function(state)
        Runtime.Humanoid = KynInternal.get_character():FindFirstChild("Humanoid")
        GLOBALVAR.JumpModifier = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("JumpPower", UI.SpeedSec:AddSlider({
    Name = "Jump",
    Tooltip = "Target jump power value.",
    Min = 0, Max = 500,
    Decimals = 0,
    Default = GLOBALVAR.JumpValue,
    VisibleWhen = "Modify Jump",
    Callback = function(value)
        GLOBALVAR.JumpValue = value
        KynInternal.saveSettings()
    end,
}))

UI.MiscSec:AddLabel("Misc features like username spoofing and discord webhook notifications.")

KynInternal.Register("WatermarkEnabled", UI.MiscSec:AddToggle({
    Name = "Show Overlay",
    Tooltip = "Shows/hides the FPS & ping watermark and the active features panel.",
    Default = GLOBALVAR.watermark_enabled,
    Callback = function(state)
        GLOBALVAR.watermark_enabled = state
        if Watermark then
            Watermark:SetVisible(state)
        end
        if Window and Window.SetActiveFeaturesEnabled then
            Window:SetActiveFeaturesEnabled(state)
        end
        KynInternal.saveSettings()
    end,
}))

local streamerBlackout = nil
local streamerGeneration = 0
local serverInfoOriginal = setmetatable({}, { __mode = "k" })

function KynInternal.updateStreamerServerInfo()
    local hud = PlayerGui:FindFirstChild("HUD")
    local main = hud and hud:FindFirstChild("Main")
    local serverInfo = main and main:FindFirstChild("ServerInfo")
    if not serverInfo then return end

    local labels = {}
    if serverInfo:IsA("TextLabel") or serverInfo:IsA("TextButton") then
        table.insert(labels, serverInfo)
    else
        for _, obj in ipairs(serverInfo:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                table.insert(labels, obj)
            end
        end
    end
    for _, label in ipairs(labels) do
        if GLOBALVAR.spoof_user then
            if serverInfoOriginal[label] == nil then
                serverInfoOriginal[label] = label.Text
            end
            label.Text = "Kyn"
        elseif serverInfoOriginal[label] ~= nil then
            label.Text = serverInfoOriginal[label]
            serverInfoOriginal[label] = nil
        end
    end
end

function KynInternal.clearStreamerBlackout()
    streamerGeneration += 1
    if streamerBlackout then
        streamerBlackout:Destroy()
        streamerBlackout = nil
    end
end

function KynInternal.streamerRespawnBlackout()
    KynInternal.clearStreamerBlackout()
    if not GLOBALVAR.spoof_user then return end
    local generation = streamerGeneration
    local gui = Instance.new("ScreenGui")
    gui.Name = "KynStreamerRespawnBlackout"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    local cover = Instance.new("Frame")
    cover.Name = "Blackout"
    cover.Size = UDim2.fromScale(1, 1)
    cover.Position = UDim2.fromScale(0, 0)
    cover.BackgroundColor3 = Color3.new(0, 0, 0)
    cover.BorderSizePixel = 0
    cover.ZIndex = 100000
    cover.Parent = gui
    gui.Parent = PlayerGui
    streamerBlackout = gui
    task.delay(4, function()
        if generation == streamerGeneration then
            KynInternal.clearStreamerBlackout()
        end
    end)
end

KynInternal.Register("StreamerMode", UI.MiscSec:AddToggle({
    Name = "Streamer Mode",
    Tooltip = "Hides real player names in the playerlist and over their head.",
    Default = GLOBALVAR.spoof_user,
    Callback = function(state)
        GLOBALVAR.spoof_user = state
        KynInternal.toggleSpoof()
        KynInternal.updateStreamerServerInfo()
        if not state then KynInternal.clearStreamerBlackout() end
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("WebhookEnabled", UI.MiscSec:AddToggle({
    Name = "Enable Webhook",
    Tooltip = "Sends skin farm and item farm notifications to a Discord webhook.",
    Default = GLOBALVAR.webhook_enabled,
    Callback = function(state)
        GLOBALVAR.webhook_enabled = state
        KynInternal.saveSettings()
    end,
}))

KynInternal.Register("WebhookURL", UI.MiscSec:AddTextbox({
    Name = "Webhook URL",
    Tooltip = "Discord webhook URL to send notifications to.",
    Default = GLOBALVAR.webhook or "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text)
        GLOBALVAR.webhook = text
        KynInternal.saveSettings()
    end,
}))

UI.AppearanceSec:AddLabel("Choose a theme or create your own below.")

function KynInternal.color3ToHex(c)
    if not c then return "#000000" end
    return string.format("#%02x%02x%02x",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

function KynInternal.hexToColor3(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:gsub("#", ""):gsub("%s+", "")
    if #hex == 3 then
        hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
    end
    if #hex ~= 6 or not hex:match("^%x+$") then return nil end
    return Color3.fromRGB(
        tonumber(hex:sub(1,2), 16),
        tonumber(hex:sub(3,4), 16),
        tonumber(hex:sub(5,6), 16)
    )
end

local draftPalette = {
    Background = "#0f0f14",
    Sidebar    = "#131319",
    Section    = "#18181f",
    Element    = "#21212a",
    Hover      = "#2c2c37",
    Accent     = "#8b5cf6",
    Text       = "#f8f8fc",
    SubText    = "#9ba0b2",
    Border     = "#2a2a34",
}
local draftThemeName = "My Theme"

function KynInternal.listAllThemeNames()
    local names = {}
    for name in pairs(GuiLib.Themes) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function KynInternal.paletteToHex(palette)
    local out = {}
    for key in pairs(draftPalette) do
        if palette[key] then
            out[key] = KynInternal.color3ToHex(palette[key])
        end
    end
    return out
end

function KynInternal.applyDraftPreview()
    local palette = {}
    for key, hex in pairs(draftPalette) do
        local c = KynInternal.hexToColor3(hex)
        if c then palette[key] = c end
    end
    if next(palette) then
        pcall(function() GuiLib:PatchTheme(palette) end)
    end
end

function KynInternal.loadPaletteIntoBoxes(palette, themeName)
    local hexes = KynInternal.paletteToHex(palette)
    for key, hex in pairs(hexes) do
        draftPalette[key] = hex
        local box = UIRegistry["CustomColor_" .. key]
        if box and box.SetValue then
            pcall(function() box:SetValue(hex) end)
        end
    end
    if themeName then
        draftThemeName = themeName
        local nameBox = UIRegistry["CustomThemeName"]
        if nameBox and nameBox.SetValue then
            pcall(function() nameBox:SetValue(themeName) end)
        end
    end
end

KynInternal.Register("ThemeSelect", UI.AppearanceSec:AddDropdown({
    Name = "Theme",
    Values = KynInternal.listAllThemeNames(),
    Default = GLOBALVAR.UI_THEME or "Dark",
    Multi = false,
    Callback = function(value)
        local theme = GuiLib.Themes[value]
        if not theme then return end
        GuiLib:SetTheme(value)
        GLOBALVAR.UI_THEME = value
        KynInternal.loadPaletteIntoBoxes(theme, value)
        KynInternal.saveSettings()
    end,
}))

UI.AppearanceSec:AddLabel("Edit the fields below to customize the selected theme.")

KynInternal.Register("CustomThemeName", UI.AppearanceSec:AddTextbox({
    Name = "Theme Name",
    Tooltip = "Saving under an existing name overwrites it.",
    Default = draftThemeName,
    Placeholder = "My Theme",
    Callback = function(text)
        draftThemeName = text:gsub("^%s+", ""):gsub("%s+$", "")
    end,
}))

local colorKeys = {
    { key = "Background", label = "Background" },
    { key = "Sidebar",    label = "Sidebar" },
    { key = "Section",    label = "Section" },
    { key = "Element",    label = "Element" },
    { key = "Hover",      label = "Hover" },
    { key = "Accent",     label = "Accent" },
    { key = "Text",       label = "Text" },
    { key = "SubText",    label = "SubText" },
    { key = "Border",     label = "Border" },
}

for _, entry in ipairs(colorKeys) do
    KynInternal.Register("CustomColor_" .. entry.key, UI.AppearanceSec:AddTextbox({
        Name = entry.label .. " (hex)",
        Tooltip = "Example: #ff0099 or #f09",
        Default = draftPalette[entry.key],
        Placeholder = "#ffffff",
        Callback = function(text)
            if KynInternal.hexToColor3(text) then
                draftPalette[entry.key] = text
                KynInternal.applyDraftPreview()
            else
                GuiLib:Notify({
                    Title = "Invalid color",
                    Content = "Use hex like #ff0099 or #f09",
                    Duration = 3,
                })
            end
        end,
    }))
end

KynInternal.Register("CustomThemeSave", UI.AppearanceSec:AddButton({
    Name = "Save Custom Theme",
    Tooltip = "Registers the theme. Same name overwrites.",
    Callback = function()
        if not draftThemeName or draftThemeName == "" then
            GuiLib:Notify({ Title = "Missing name", Content = "Enter a theme name first", Duration = 3 })
            return
        end
        local palette = {}
        for _, entry in ipairs(colorKeys) do
            local c = KynInternal.hexToColor3(draftPalette[entry.key])
            if not c then
                GuiLib:Notify({ Title = "Invalid color", Content = entry.label .. " is not valid", Duration = 4 })
                return
            end
            palette[entry.key] = c
        end
        local ok, err = pcall(function()
            GuiLib:RegisterTheme(draftThemeName, palette)
        end)
        if ok then
            GuiLib:SetTheme(draftThemeName)
            GLOBALVAR.UI_THEME = draftThemeName
            GLOBALVAR.__customThemes = GLOBALVAR.__customThemes or {}
            GLOBALVAR.__customThemes[draftThemeName] = palette
            KynInternal.saveSettings()
            GuiLib:Notify({ Title = "Theme saved", Content = draftThemeName, Duration = 3 })
            local dd = UIRegistry["ThemeSelect"]
            if dd and dd.SetOptions then dd:SetOptions(KynInternal.listAllThemeNames()) end
        else
            GuiLib:Notify({ Title = "Failed", Content = tostring(err), Duration = 4 })
        end
    end,
}))

KynInternal.Register("CustomThemeDelete", UI.AppearanceSec:AddButton({
    Name = "Delete Custom Theme",
    Tooltip = "Only works on custom themes.",
    Callback = function()
        local current = GLOBALVAR.UI_THEME
        if not current then return end
        if GuiLib:RemoveTheme(current) then
            GLOBALVAR.__customThemes[current] = nil
            GLOBALVAR.UI_THEME = "Dark"
            GuiLib:SetTheme("Dark")
            KynInternal.loadPaletteIntoBoxes(GuiLib.Themes.Dark, "Dark")
            KynInternal.saveSettings()
            GuiLib:Notify({ Title = "Deleted", Content = "Reset to Dark", Duration = 3 })
            local dd = UIRegistry["ThemeSelect"]
            if dd and dd.SetOptions then dd:SetOptions(KynInternal.listAllThemeNames()) end
        else
            GuiLib:Notify({ Title = "Not allowed", Content = "Built-in themes cannot be deleted", Duration = 3 })
        end
    end,
}))

local startTheme = GuiLib.Themes[GLOBALVAR.UI_THEME or "Dark"] or GuiLib.Themes.Dark
KynInternal.loadPaletteIntoBoxes(startTheme, GLOBALVAR.UI_THEME or "Dark")
end

KynInternal.ui_create()

KynInternal.setESP(GLOBALVAR.ESP == true)

GLOBALVAR.SilentAim.setEnabled(
    GLOBALVAR.SilentAimEnabled == true
    or GLOBALVAR.AccuracyBlatant == true
)

GLOBALVAR.AccuracyAim.setRange(
    GLOBALVAR.AccuracyRange or 250
)

GLOBALVAR.AccuracyAim.setEnabled(
    GLOBALVAR.AccuracyBlatant == true
)

if GLOBALVAR.AccuracyBlatant then
    KynInternal.startTargetUpdater()
else
    KynInternal.stopTargetUpdater()
end

if GLOBALVAR.UpdateSACircle then
    GLOBALVAR.UpdateSACircle()
end

local function character()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function humanoid()
    local c = character()
    return c and c:FindFirstChildOfClass("Humanoid")
end

task.spawn(function()
    while true do
        task.wait(2)
        local currentCharacter = LocalPlayer.Character
local h = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")

Runtime.Humanoid = h

if not h or h.Health <= 0.15 then
    global_lock = true
    continue
end

global_lock = false

        if global_lock then continue end
        local money = LocalPlayer.PlayerStats.Money.Value
        if money >= 75000 and GLOBALVAR.BuyLuckyArrows and os.clock() - Runtime.LastLucky >= 2 then
    Runtime.LastLucky = os.clock()
    if KynInternal.buy_lucky then pcall(KynInternal.buy_lucky) end
end
        if money >= 3375 and (GLOBALVAR.BuyArrows or GLOBALVAR.BuyRokas)
            and os.clock() - Runtime.LastBuy >= 10 then
            Runtime.LastBuy = os.clock()
            local arrows, rokas, ribs = 0, 0, 0
            for _, v in ipairs(LocalPlayer:WaitForChild("Backpack", 5):GetChildren()) do
                if v.Name == "Mysterious Arrow" then arrows += 1
                elseif v.Name == "Rokakaka" then rokas += 1 
                elseif v.Name == "Rib Cage of The Saint's Corpse" then ribs += 1
                end
            end
            if rokas < 1 then pcall(KynInternal.buy_roka) end
            if arrows < 1 then pcall(KynInternal.buy_arrow) end
            if ribs < 1 then pcall(KynInternal.buy_rib) end
        end
    end
end)

task.spawn(function()
    local nextHop = os.clock() + 60
    while true do
        task.wait(1)
        if global_lock then continue end
        if GLOBALVAR.hop_enabled and os.clock() >= nextHop then
            nextHop = os.clock() + 60
            pcall(KynInternal.serverhop)
        end
    end
end)

KynInternal.onItemFarmToggle()
KynInternal.onSellToggle()
KynInternal.toggleSpoof()
KynInternal.updateStreamerServerInfo()

if KynInternal.hasPremium() then
    if GLOBALVAR.skin_farm then
        startSkinFarm()
    end

    if GLOBALVAR.AutoBlockConfig.enabled then
        KynInternal.enable_ap_childadded()
    end

    KynInternal.onWeatherReportToggle()
    KynInternal.onDiverDownToggle()
end

if GLOBALVAR.__NovexCharAddedConn then
    pcall(function() GLOBALVAR.__NovexCharAddedConn:Disconnect() end)
end

LocalPlayer.CharacterRemoving:Connect(function()
    KynInternal.disable_m1_loop()
end)

task.spawn(function()
    local since = {}
    while true do
        task.wait(2)
        local flags = {
            global_lock = global_lock,
            inv = InventoryBusy,
            sell = SellRuntime.Locked,
            skin = skin_busy,
            dlg = DialogueBusy,
        }
        for name, on in pairs(flags) do
            if on then
                since[name] = since[name] or os.clock()
            else
                since[name] = nil
            end
        end
        for name, t in pairs(since) do
            if os.clock() - t > 30 then
                warn("[watchdog] clearing stuck", name)
                global_lock, InventoryBusy, SellRuntime.Locked = false, false, false
                skin_busy, DialogueBusy = false, false
                since = {}
                break
            end
        end
        if GLOBALVAR.sellall and not SellRuntime.Running then
            warn("[watchdog] restarting Sell All")
            startSellAll()
        end
        if GLOBALVAR.skin_farm and not SkinFarm.Running then
            warn("[watchdog] restarting Skin Farm")
            startSkinFarm()
        end
    end
end)

GLOBALVAR.__NovexCharAddedConn = LocalPlayer.CharacterAdded:Connect(function(character)
    can_item_farmma = false
    global_lock, InventoryBusy, SellRuntime.Locked = false, false, false
    SkinFarm.Busy, skin_busy, localRemote = false, false, nil
    DialogueBusy = false
    can_use_arrow, can_sell = true, false
    roka_cd, wanted_cd, req_cd, skin_cd = 0, 0, 0, 0

    Character = character
    local hum = character:WaitForChild("Humanoid", 10)
    if hum then Runtime.Humanoid = hum end
    character:WaitForChild("HumanoidRootPart", 10)

    pcall(KynInternal.streamerRespawnBlackout)
    task.spawn(function()
        KynInternal.streamerRespawnBlackout()
        local hud = PlayerGui:WaitForChild("HUD", 15)
        if hud then
            local main = hud:WaitForChild("Main", 15)
            if main then main:WaitForChild("ServerInfo", 15) end
            KynInternal.updateStreamerServerInfo()
        end
    end)

    task.delay(3, function()
        can_item_farmma, can_sell = true, true
        if GLOBALVAR.sellall then
        stopSellAll()
        startSellAll()
        end
        pcall(KynInternal.refreshLocalRemote)
        if GLOBALVAR.AutoWeatherReport and not WeatherRuntime.Running then
            GLOBALVAR.startWeatherReport()
        end
        if GLOBALVAR.AutoDiverDown and not DiverRuntime.Running then
            GLOBALVAR.startDiverDown()
        end
    end)

    HUDCache.HUD = nil
    HUDCache.EquippedLabel = nil
    HUDCache.PityLabel = nil

    if PilotActive then
        KynInternal.UnPilotStand(CurrentArgs)
    end
    CurrentArgs = nil

    if KynInternal.hasPremium() and GLOBALVAR.Invis then
        task.spawn(function()
            task.wait(1)
            if KynInternal.hasPremium() and GLOBALVAR.Invis and LocalPlayer.Character == character then
                KynInternal.Invisibile()
                IsInvisibile = true
            end
        end)
    end

    if PilotEnabled then
        task.spawn(function()
            task.wait(1)
            if PilotEnabled then
                KynInternal.SetStandPilot(true)
            end
        end)
    end

    KynInternal.hookStandAttachment(character)
end)
