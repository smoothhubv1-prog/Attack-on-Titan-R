---------------------------------------------------------
-- Smooth Hub : Attack on Titan Revolution - หน้าเมนู (Lobby)
-- ฟังก์ชัน: Character Selection / Auto Join Lobby / Missions
-- ระบบเซฟ: ไฟล์เดียวต่อไอดี (SmoothHub/<UserId>/AOTR.json) เซฟอัตโนมัติทุกครั้งที่ค่าเปลี่ยน
---------------------------------------------------------
local MENU_PLACE_ID = 13379208636
local MIN_DELAY, MAX_DELAY = 5, 60 -- Join Delay (วินาที) ต่ำสุด/สูงสุด

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local IN_MENU = (game.PlaceId == MENU_PLACE_ID)

-- กันรันซ้ำ: ลูปเก่าหยุด + หน้าต่างเก่าถูกล้าง
if type(_G.SmoothHubCleanup) == "function" then pcall(_G.SmoothHubCleanup) end
local token = {}
_G.SmoothHubReplayToken = token
local function Alive() return _G.SmoothHubReplayToken == token end
local AppRef = nil
_G.SmoothHubCleanup = function()
    pcall(function() if AppRef and AppRef.Destroy then AppRef:Destroy() end end)
end

---------------------------------------------------------
-- 💾 จำการตั้งค่า (แยกตามไอดี)
---------------------------------------------------------
local Cfg = {
    Slot = 1,            -- 1=A 2=B 3=C
    AutoSelect = false,  -- เลือกตัวละครให้อัตโนมัติ
    AutoJoin = false,    -- กด Join Lobby ซ้ำตามเวลา
    JoinDelay = 10,      -- วินาที (5 - 60)
    AutoClaimMain = true,         -- Auto Claim Main Quests
    AutoClaimSide = true,         -- Auto Claim Side Quests
    AutoClaimAchievements = true, -- Auto Claim Achievements
    AutoClaimWeekly = true,       -- Auto Claim Weekly Quests
    AutoClaimDaily = true,        -- Auto Claim Daily Quests
    AutoOpenPages = true,         -- เปิดหน้า Achievements เองเมื่อเกมโชว์ป้าย ! (เหมือนผู้เล่นกดเอง)
    AutoUpgradeBlade = false,      -- Equipment: Auto Upgrade Gear (Blade)
    AutoUpgradeThunder = false,    -- Equipment: Auto Upgrade Gear (Thunder Spears)
    AutoEquipThunder = false,      -- Equipment: Auto Equip Thunder Spears
    AutoEquipBlade = false,        -- Equipment: Auto Equip Blades
    MissionSelect = "Shiganshina", -- Missions: แมพที่เลือก
    MissionObjective = "Skirmish", -- Missions: Objective ที่เลือก
    MissionDifficulty = {},        -- Missions: ความยากที่เลือก (เลือกได้หลายอัน)
    MissionModifiers = {},         -- Missions: Modifiers ที่เลือก (เลือกได้หลายอัน)
    AutoBestGrade = false,         -- Missions: Auto Select Best Grade
    AutoBoostMission = false,      -- Missions: Auto Select Boost Mission
    AutoCreateMission = false,     -- Missions: Auto Create Mission (เซฟข้ามรอบ: เปิดค้างไว้ = คอยสร้างห้องให้เอง)
    AutoStartMission = false,      -- Missions: Auto Start Missions (เซฟข้ามรอบ: เปิดค้างไว้ = กด Start ให้เอง)
    MissionLevel = "Easy (E- Grade)", -- Missions: ความยากที่ใช้สร้างห้อง (เลือก 1 อย่าง)
    MissionJoinDelay = 10,         -- Missions: Join Delay (วินาที 5 - 60)
    -- Auto Farm > Main
    AutoFarm = false,              -- Auto Farm
    AutoReload = false,            -- Auto Reload
    AutoRefills = false,           -- Auto Refills
    DamageMultiplier = false,      -- Damage Multiplier (x10)
    SafeTime = 32,                 -- Safe Time (วินาที)
    FailSafeAt = 20,               -- Fail Safe At
    AutoFailSafe = false,          -- Auto Fail Safe
    NoClip = true,                 -- No Clip: ทะลุกำแพง/ไททันตอน Auto Farm ทำงาน
    HitAllParts = true,            -- Hit All Parts: ฟันทุกชิ้นส่วนของไททัน (Eyes / แขน / ขา / Nape) ไม่ใช่แค่ Nape
    FlySpeed = 600,                -- Tween Speed: ความเร็วที่ Auto Farm บินไปหาไททัน (studs/วินาที)
    FlyHeight = 150,               -- Fly Height: ลอยสูงเหนือยอดหัวไททันกี่ studs (150 - 2000)
    AttackSpeed = 0,               -- Attack Speed: 0 = Auto, 1 = Safe, 2 = Fast, 3 = Turbo, 4 = Max
    -- Auto Farm > Game Options
    AutoRetry = false,             -- Auto Retry
    AutoLeave = false,             -- Auto Leave
    RetryAmount = 3,               -- Retry Amount
    RetryDone = 0,                 -- จำนวนครั้งที่ Retry ไปแล้วในรอบนี้ (Current Retry) รีเซ็ตเมื่ออยู่ที่ล็อบบี้/ปิดสวิตช์
    AutoLeaveWhenRetryComplete = false, -- Auto Leave When Retry Complete
}
-- ช่วงค่าของสไลเดอร์ในหมวด Auto Farm { ต่ำสุด, สูงสุด } (ปรับช่วงตรงนี้ที่เดียว)
local FARM_RANGES = {
    SafeTime = { 0, 100 },
    FailSafeAt = { 0, 100 },
    FlySpeed = { 100, 2000 },
    FlyHeight = { 150, 2000 },
    AttackSpeed = { 0, 4 },
    RetryAmount = { 1, 50 },
}

---------------------------------------------------------
-- 🔄 ตัวช่วย Reset / รีเฟรชหน้าจอ (รวมไว้ในตารางเดียว กันตัวแปรท้องถิ่นเกิน 200)
-- Defaults  = ค่าเริ่มต้นของสคริปต์ (เก็บไว้ก่อนโหลดไฟล์เซฟ)
-- Refreshers = ฟังก์ชันที่ทำให้สวิตช์/สไลเดอร์บนหน้าจอตรงกับค่าใน Cfg / HubConfig
---------------------------------------------------------
local UiSync = { Defaults = { Cfg = {}, Hub = {} }, Refreshers = {} }
for key, value in pairs(Cfg) do
    if type(value) == "table" then
        local copy = {}
        for i, item in ipairs(value) do copy[i] = item end
        UiSync.Defaults.Cfg[key] = copy
    else
        UiSync.Defaults.Cfg[key] = value
    end
end

function UiSync.Add(fn)
    UiSync.Refreshers[#UiSync.Refreshers + 1] = fn
end

-- ผูกตัวควบคุมกับค่า tbl[key] แล้วคืนตัวควบคุมเดิมกลับ (ครอบตอนสร้างได้เลย)
function UiSync.Link(control, tbl, key, extra)
    UiSync.Add(function()
        local want = tbl[key]
        if control.Value ~= want then control.Value = want end
        if extra then extra(control, want) end
    end)
    return control
end

function UiSync.Refresh()
    for _, fn in ipairs(UiSync.Refreshers) do pcall(fn) end
end

local SAVE_DIR = "SmoothHub"
local LEGACY_PATH = SAVE_DIR .. "/AOTR_Menu_" .. tostring(LocalPlayer.UserId) .. ".json" -- ไฟล์เก่าของเวอร์ชันก่อน (ใช้ย้ายค่าให้ครั้งเดียว)
local canSave = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local function ClampDelay(v)
    v = tonumber(v) or 10
    return math.clamp(math.floor(v + 0.5), MIN_DELAY, MAX_DELAY)
end

-- ใส่ค่าที่อ่านจากไฟล์ลง Cfg (เช็กชนิดทุกค่า กันไฟล์เพี้ยนทำสคริปต์พัง)
local function ApplyCfgData(data)
    if type(data) ~= "table" then return end
    if type(data.Slot) == "number" and data.Slot >= 1 and data.Slot <= 3 then Cfg.Slot = math.floor(data.Slot) end
    if data.JoinDelay ~= nil then Cfg.JoinDelay = ClampDelay(data.JoinDelay) end
    if data.MissionJoinDelay ~= nil then Cfg.MissionJoinDelay = ClampDelay(data.MissionJoinDelay) end
    for _, key in ipairs({
        "AutoSelect", "AutoJoin",
        "AutoClaimMain", "AutoClaimSide", "AutoClaimAchievements", "AutoClaimWeekly", "AutoClaimDaily", "AutoOpenPages",
        "AutoUpgradeBlade", "AutoUpgradeThunder", "AutoEquipThunder", "AutoEquipBlade",
        "AutoBestGrade", "AutoBoostMission", "AutoCreateMission", "AutoStartMission",
        "AutoFarm", "AutoReload", "AutoRefills", "DamageMultiplier", "AutoFailSafe", "NoClip", "HitAllParts",
        "AutoRetry", "AutoLeave", "AutoLeaveWhenRetryComplete",
    }) do
        if type(data[key]) == "boolean" then Cfg[key] = data[key] end
    end
    if type(data.RetryDone) == "number" and data.RetryDone == data.RetryDone and data.RetryDone >= 0 then
        Cfg.RetryDone = math.floor(data.RetryDone)
    end
    for key, range in pairs(FARM_RANGES) do
        if type(data[key]) == "number" and data[key] == data[key] then
            Cfg[key] = math.clamp(math.floor(data[key] + 0.5), range[1], range[2])
        end
    end
    -- ไฟล์เก่าเคยจำสวิตช์ Mission ไว้ในชื่อ RememberAuto... (ย้ายค่ามาให้)
    if data.AutoCreateMission == nil and type(data.RememberAutoCreate) == "boolean" then Cfg.AutoCreateMission = data.RememberAutoCreate end
    if data.AutoStartMission == nil and type(data.RememberAutoStart) == "boolean" then Cfg.AutoStartMission = data.RememberAutoStart end
    for _, key in ipairs({ "MissionSelect", "MissionObjective", "MissionLevel" }) do
        if type(data[key]) == "string" then Cfg[key] = data[key] end
    end
    for _, key in ipairs({ "MissionDifficulty", "MissionModifiers" }) do
        if type(data[key]) == "table" then
            local names = {}
            for _, v in ipairs(data[key]) do
                if type(v) == "string" then names[#names + 1] = v end
            end
            Cfg[key] = names
        end
    end
end

local function ReadLegacyCfg()
    if not canSave then return nil end
    local ok, data = pcall(function()
        if not isfile(LEGACY_PATH) then return nil end
        return HttpService:JSONDecode(readfile(LEGACY_PATH))
    end)
    if ok and type(data) == "table" then return data end
    return nil
end

-- Save() = "ค่าเปลี่ยนแล้ว ช่วยเซฟที" (รวมคำสั่งรัว ๆ เป็นครั้งเดียว)
-- ตัวเขียนไฟล์จริงคือระบบ Auto Save ตัวเดียว (ไฟล์ AOTR.json) ที่ผูกไว้ท้ายสคริปต์ผ่าน saveHook
local saveHook = nil
local saveQueued = false
local function Save()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.4, function()
        saveQueued = false
        if saveHook then pcall(saveHook) end
    end)
end

---------------------------------------------------------
-- 📁 Config: ชุดตั้งค่าตั้งชื่อเองได้ (แยกตามไอดี)
-- config ที่กำลังใช้อยู่ (Active) จะเซฟทุกการเปลี่ยนแปลงลงตัวเองอัตโนมัติ จึงไม่ต้องมีปุ่ม Overwrite
-- Autoload = config ที่จะโหลดให้ทุกครั้งตอนรันสคริปต์
---------------------------------------------------------
---------------------------------------------------------
-- ⭐ Config ค่าเริ่มต้นที่ติดมากับสคริปต์
-- ชื่อนี้ลบ/แก้ไม่ได้ และถูกสร้างใหม่จากค่าเริ่มต้นของสคริปต์ทุกครั้งที่รัน
-- DEFAULT_LOOK = หน้าตาเริ่มต้น (ธีม Dark + Accent Pink) ส่วนสวิตช์ต่าง ๆ ใช้ค่าเริ่มต้นในตาราง Cfg / HubConfig
---------------------------------------------------------
-- (เก็บไว้ในตาราง ConfigStore เพื่อไม่ให้ตัวแปรท้องถิ่นระดับบนสุดเพิ่ม กันเกิน 200)
local ConfigStore = {
    DEFAULT_NAME = "Smooth Hub | Default",
    DEFAULT_LOOK = { Theme = "Dark", Accent = "Pink", UIBlur = false, Dropshadow = true, Keybind = "B" },
}
do
    local DEFAULT_CONFIG_NAME = ConfigStore.DEFAULT_NAME
    local DEFAULT_LOOK = ConfigStore.DEFAULT_LOOK
    local PATH = SAVE_DIR .. "/AOTR_Configs_" .. tostring(LocalPlayer.UserId) .. ".json"
    local data = { Autoload = nil, Active = nil, AutoSync = true, List = {} }
    local sigs = {} -- ลายเซ็นข้อมูลที่เขียนล่าสุดของแต่ละ config (กันเขียนไฟล์ซ้ำโดยไม่จำเป็น)
    local defaultSnap = nil -- config ค่าเริ่มต้น (สร้างจากโค้ด ไม่อ่านจากไฟล์)

    local function Flush()
        if not canSave then return false end
        return (pcall(function()
            if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(SAVE_DIR) then
                makefolder(SAVE_DIR)
            end
            writefile(PATH, HttpService:JSONEncode(data))
        end))
    end

    local function CopyValue(v)
        if type(v) == "table" then
            local out = {}
            for _, item in ipairs(v) do
                if type(item) == "string" then out[#out + 1] = item end
            end
            return out
        end
        return v
    end

    function ConfigStore.Reload()
        data = { Autoload = nil, Active = nil, AutoSync = true, List = {} }
        sigs = {}
        if defaultSnap then data.List[DEFAULT_CONFIG_NAME] = defaultSnap end
        if not canSave then return end
        local ok, decoded = pcall(function()
            if not isfile(PATH) then return nil end
            return HttpService:JSONDecode(readfile(PATH))
        end)
        if ok and type(decoded) == "table" then
            if type(decoded.List) == "table" then
                for name, snap in pairs(decoded.List) do
                    if type(name) == "string" and type(snap) == "table" and name ~= DEFAULT_CONFIG_NAME then data.List[name] = snap end
                end
            end
            if type(decoded.Autoload) == "string" and data.List[decoded.Autoload] then data.Autoload = decoded.Autoload end
            if type(decoded.Active) == "string" and data.List[decoded.Active] then data.Active = decoded.Active end
            if decoded.AutoSync == false then data.AutoSync = false end
        end
    end

    function ConfigStore.Names()
        local names = {}
        for name in pairs(data.List) do names[#names + 1] = name end
        table.sort(names, function(a, b)
            if a == DEFAULT_CONFIG_NAME then return b ~= DEFAULT_CONFIG_NAME end -- ค่าเริ่มต้นอยู่บนสุดเสมอ
            if b == DEFAULT_CONFIG_NAME then return false end
            return a:lower() < b:lower()
        end)
        return names
    end
    function ConfigStore.IsDefault(name) return name == DEFAULT_CONFIG_NAME end
    function ConfigStore.Exists(name) return data.List[name] ~= nil end
    function ConfigStore.Get(name) return data.List[name] end
    function ConfigStore.Autoload() return data.Autoload end
    function ConfigStore.Active() return data.Active end
    function ConfigStore.AutoloadSnapshot() return data.Autoload and data.List[data.Autoload] or nil end

    -- เก็บสวิตช์/ตัวเลือกทั้งหมด (Cfg) + ค่าตั้งของหมวด Settings ที่เป็นตัวเลข/ข้อความ/สวิตช์ (hub)
    function ConfigStore.Snapshot(hub)
        local snap = { Cfg = {}, Hub = {} }
        for k, v in pairs(Cfg) do snap.Cfg[k] = CopyValue(v) end
        if hub then
            for k, v in pairs(hub) do
                local t = type(v)
                if t == "boolean" or t == "number" or t == "string" then snap.Hub[k] = v end
            end
        end
        -- หน้าตา (ธีม / Accent / เบลอ / เงา / ปุ่มลัด) ถ้ามีตัวอ่านค่า
        if ConfigStore.GetUI then
            local okUi, ui = pcall(ConfigStore.GetUI)
            if okUi and type(ui) == "table" then snap.UI = ui end
        end
        return snap
    end

    function ConfigStore.Put(name, snap)
        if name == DEFAULT_CONFIG_NAME then return false end -- ชื่อค่าเริ่มต้นเขียนทับไม่ได้
        data.List[name] = snap
        sigs[name] = nil
        return Flush()
    end
    function ConfigStore.Delete(name)
        if name == DEFAULT_CONFIG_NAME then return false end -- config ค่าเริ่มต้นลบไม่ได้
        data.List[name] = nil
        sigs[name] = nil
        if data.Autoload == name then data.Autoload = nil end
        if data.Active == name then data.Active = nil end
        return Flush()
    end
    function ConfigStore.SetAutoload(name)
        if name ~= nil and not data.List[name] then return false end
        data.Autoload = name
        return Flush()
    end
    function ConfigStore.SetActive(name)
        if name ~= nil and not data.List[name] then return false end
        if data.Active == name then return true end
        data.Active = name
        return Flush()
    end

    -- เซฟสถานะปัจจุบันลง config ที่กำลังใช้อยู่ (ถ้าไม่มี config ที่ใช้อยู่ = ไม่ทำอะไร)
    function ConfigStore.SyncActive(hub)
        if data.AutoSync == false then return false end -- โหมดเซฟเอง: ไม่เซฟให้อัตโนมัติ (ต้องกดปุ่ม Enter Save Config)
        local name = data.Active
        if not name or not data.List[name] then return false end
        if name == DEFAULT_CONFIG_NAME then return false end -- config ค่าเริ่มต้นเป็นแบบอ่านอย่างเดียว
        local snap = ConfigStore.Snapshot(hub)
        local okSig, sig = pcall(function() return HttpService:JSONEncode(snap) end)
        if not okSig or sigs[name] == sig then return false end
        data.List[name] = snap
        if Flush() then sigs[name] = sig return true end
        return false
    end

    -- โหมดเซฟ: true = config ที่ใช้อยู่เซฟทุกการเปลี่ยนแปลงเอง / false = เซฟเฉพาะตอนกดปุ่ม Enter Save Config
    function ConfigStore.AutoSync() return data.AutoSync ~= false end
    function ConfigStore.SetAutoSync(value)
        data.AutoSync = value and true or false
        return Flush()
    end

    -- เซฟสถานะปัจจุบันลง config ที่ใช้อยู่ "ทันที" (ปุ่ม Enter Save Config) คืน ok, ชื่อ config
    function ConfigStore.SaveActive(hub)
        local name = data.Active
        if not name or not data.List[name] then return false, nil end
        if name == DEFAULT_CONFIG_NAME then return false, name end -- config ค่าเริ่มต้นเป็นแบบอ่านอย่างเดียว
        local snap = ConfigStore.Snapshot(hub)
        data.List[name] = snap
        sigs[name] = nil
        local ok = Flush()
        if ok then
            local okSig, sig = pcall(function() return HttpService:JSONEncode(snap) end)
            if okSig then sigs[name] = sig end
        end
        return ok, name
    end

    -- เทียบเฉพาะคีย์ที่ config เก็บไว้แล้ว (คีย์ใหม่จากสคริปต์เวอร์ชันหลังไม่นับว่า "ยังไม่เซฟ")
    local function SameValue(x, y)
        if type(x) ~= type(y) then return false end
        if type(x) == "table" then
            if #x ~= #y then return false end
            for i = 1, #x do
                if x[i] ~= y[i] then return false end
            end
            return true
        end
        return x == y
    end
    local function SameMap(current, saved)
        if type(saved) ~= "table" then return true end
        for k, v in pairs(current) do
            if saved[k] ~= nil and not SameValue(v, saved[k]) then return false end
        end
        return true
    end

    -- ค่าตอนนี้ต่างจากที่เซฟไว้ใน config ที่ใช้อยู่ไหม (มีแก้แล้วยังไม่ได้เซฟ)
    function ConfigStore.IsDirty(hub)
        local name = data.Active
        local saved = name and data.List[name]
        if not saved then return false end
        local snap = ConfigStore.Snapshot(hub)
        return not (SameMap(snap.Cfg, saved.Cfg) and SameMap(snap.Hub, saved.Hub) and SameMap(snap.UI or {}, saved.UI))
    end

    function ConfigStore.ApplyCfg(snap)
        if type(snap) ~= "table" or type(snap.Cfg) ~= "table" then return end
        local saved = snap.Cfg
        for k, v in pairs(saved) do
            local cur = Cfg[k]
            if cur ~= nil and type(cur) == type(v) then
                if type(v) == "table" then
                    Cfg[k] = CopyValue(v)
                elseif k == "JoinDelay" or k == "MissionJoinDelay" then
                    Cfg[k] = ClampDelay(v)
                elseif k == "Slot" then
                    Cfg[k] = math.clamp(math.floor(v), 1, 3)
                elseif FARM_RANGES[k] and v == v then
                    Cfg[k] = math.clamp(math.floor(v + 0.5), FARM_RANGES[k][1], FARM_RANGES[k][2])
                else
                    Cfg[k] = v
                end
            end
        end
        -- config เก่าจากเวอร์ชันก่อนจำสวิตช์ Mission ไว้ในชื่อ RememberAuto...
        if saved.AutoCreateMission == nil and type(saved.RememberAutoCreate) == "boolean" then Cfg.AutoCreateMission = saved.RememberAutoCreate end
        if saved.AutoStartMission == nil and type(saved.RememberAutoStart) == "boolean" then Cfg.AutoStartMission = saved.RememberAutoStart end
    end
    function ConfigStore.ApplyHub(hub, snap)
        if type(snap) ~= "table" or type(snap.Hub) ~= "table" then return end
        for k, v in pairs(snap.Hub) do
            if hub[k] ~= nil and type(hub[k]) == type(v) then hub[k] = v end
        end
    end

    function ConfigStore.ApplyUI(snap)
        if type(snap) ~= "table" or type(snap.UI) ~= "table" then return end
        if ConfigStore.UIApplier then pcall(ConfigStore.UIApplier, snap.UI) end
    end

    -- สร้าง config ค่าเริ่มต้นจากค่าเริ่มต้นของสคริปต์ (สวิตช์ Cfg + ค่า Hub + หน้าตา)
    -- เรียกครั้งแรกตอนเริ่ม (ยังไม่มี Hub) แล้วเรียกอีกครั้งหลังรู้ค่าเริ่มต้นของ Hub
    function ConfigStore.BuildDefault(hubDefaults)
        local snap = { Cfg = {}, Hub = {}, UI = {} }
        for k, v in pairs(UiSync.Defaults.Cfg) do snap.Cfg[k] = CopyValue(v) end
        if hubDefaults then
            for k, v in pairs(hubDefaults) do
                local t = type(v)
                if t == "boolean" or t == "number" or t == "string" then snap.Hub[k] = v end
            end
        end
        for k, v in pairs(DEFAULT_LOOK) do snap.UI[k] = v end
        defaultSnap = snap
        data.List[DEFAULT_CONFIG_NAME] = snap
        sigs[DEFAULT_CONFIG_NAME] = nil
    end

    ConfigStore.BuildDefault()
    ConfigStore.Reload()
end

---------------------------------------------------------
-- โหลด UI
---------------------------------------------------------
local okLib, Cascade = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/smoothhubv1-prog/Cascade-UI-Library/refs/heads/main/Ui.luau"))()
end)
if not okLib or type(Cascade) ~= "table" then
    warn("[SmoothHub] โหลด UI ไม่สำเร็จ:", tostring(Cascade))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Smooth Hub", Text = "โหลด UI ไม่สำเร็จ (เช็คเน็ต/ลิงก์ GitHub)", Duration = 8,
        })
    end)
    return
end

local function Icon(...)
    for _, name in ipairs({ ... }) do
        if Cascade.Symbols[name] then return Cascade.Symbols[name] end
    end
    return Cascade.Symbols["boltFill"]
end

-- ผูกปุ่ม (กันกดซ้ำ 2 ครั้ง)
local function BindButton(btn, fn)
    local last = 0
    local function run()
        if os.clock() - last < 0.5 then return end
        last = os.clock()
        task.spawn(fn)
    end
    pcall(function()
        if btn.__instance then
            local obj = btn.__instance:FindFirstChildWhichIsA("TextButton", true) or btn.__instance
            obj.MouseButton1Click:Connect(run)
        end
    end)
    return run
end

---------------------------------------------------------
-- 💾 ระบบจำการตั้งค่าหมวด Settings (แยกตามไอดี)
-- เก็บไว้ที่ workspace/SmoothHub/<UserId>/AOTR.json
---------------------------------------------------------
local SettingsStore = {}
do
    local HttpService = game:GetService("HttpService")
    local owner = game:GetService("Players").LocalPlayer
    local ROOT = "SmoothHub"
    local DIR = ROOT .. "/" .. tostring(owner.UserId)

    local canSave = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    local canFolder = type(makefolder) == "function" and type(isfolder) == "function"
    local flushers = {}

    function SettingsStore.Path(fileName)
        if canFolder then
            return DIR .. "/" .. fileName .. ".json"
        end
        -- executor ที่ไม่มี makefolder: ใช้ไฟล์เดี่ยว ใส่ UserId ไว้ในชื่อไฟล์แทน
        return ROOT .. "_" .. tostring(owner.UserId) .. "_" .. fileName .. ".json"
    end

    local function ensureFolder()
        if not canFolder then return end
        pcall(function()
            if not isfolder(ROOT) then makefolder(ROOT) end
            if not isfolder(DIR) then makefolder(DIR) end
        end)
    end

    local function copy(value)
        if type(value) ~= "table" then return value end
        local out = {}
        for k, v in pairs(value) do
            out[k] = copy(v)
        end
        return out
    end

    -- ทำให้เป็นข้อมูลที่ JSON เก็บได้ (ตัด function / Instance ทิ้ง)
    local function clean(value, depth)
        depth = depth or 0
        local kind = type(value)
        if kind == "string" or kind == "boolean" then return value end
        if kind == "number" then
            if value ~= value or value == math.huge or value == -math.huge then return nil end
            return value
        end
        if kind ~= "table" or depth > 6 then return nil end

        local count, isArray = 0, true
        for k in pairs(value) do
            count = count + 1
            if type(k) ~= "number" then isArray = false end
        end
        if isArray then
            for i = 1, count do
                if value[i] == nil then
                    isArray = false
                    break
                end
            end
        end

        local out = {}
        if isArray then
            for i = 1, count do
                local c = clean(value[i], depth + 1)
                if c ~= nil then table.insert(out, c) end
            end
        else
            for k, v in pairs(value) do
                local c = clean(v, depth + 1)
                if c ~= nil then out[tostring(k)] = c end
            end
        end
        return out
    end

    -- อ่านไฟล์ของไอดีนี้ (ไม่มีไฟล์ / อ่านไม่ได้ = ตารางว่าง = ใช้ค่าเริ่มต้น)
    function SettingsStore.Load(fileName)
        if not canSave then return {} end
        local ok, data = pcall(function()
            local path = SettingsStore.Path(fileName)
            if not isfile(path) then return nil end
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(data) == "table" then return data end
        return {}
    end

    function SettingsStore.Write(fileName, data)
        if not canSave then return false end
        ensureFolder()
        local ok = pcall(function()
            writefile(SettingsStore.Path(fileName), HttpService:JSONEncode(data))
        end)
        return ok
    end

    -- เอาค่าที่เซฟไว้ (saved) ใส่ลงตาราง target
    -- รับเฉพาะ key ที่มีอยู่ในค่าเริ่มต้น และชนิดข้อมูลต้องตรงกัน (กันไฟล์เก่า/ไฟล์เพี้ยนทำสคริปต์พัง)
    function SettingsStore.Restore(target, saved)
        if type(target) ~= "table" or type(saved) ~= "table" then return end
        for key, default in pairs(target) do
            local value = saved[key]
            if value ~= nil then
                if type(default) == "table" then
                    if type(value) == "table" then
                        if next(default) == nil then
                            -- ค่าเริ่มต้นเป็นตารางว่าง (เช่น รายการที่ติ๊กเลือก) ใช้ที่เซฟไว้ทั้งก้อน
                            target[key] = copy(value)
                        else
                            SettingsStore.Restore(default, value)
                        end
                    end
                elseif type(default) == type(value) then
                    target[key] = value
                end
            end
        end
    end

    function SettingsStore.IndexOf(options, name, fallback)
        return table.find(options, name) or fallback or 1
    end

    -- ตาราง { ชื่อ = true } -> รายการ index ของตัวเลือกที่ติ๊กไว้ (ใช้กับ PopUpButton)
    function SettingsStore.IndexesFromMap(options, map)
        local out = {}
        if type(map) == "table" then
            for i, name in ipairs(options) do
                if map[name] then table.insert(out, i) end
            end
        end
        return out
    end

    -- กรองรายการ index ให้เหลือเฉพาะเลขที่ใช้ได้ (ไม่ซ้ำ และอยู่ในช่วง 1..max) โดยคงลำดับเดิม
    function SettingsStore.ValidIndexes(list, max)
        local out, seen = {}, {}
        if type(list) == "table" then
            for _, index in ipairs(list) do
                if type(index) == "number" and index >= 1 and index <= max and index % 1 == 0 and not seen[index] then
                    seen[index] = true
                    table.insert(out, index)
                end
            end
        end
        return out
    end

    -- เริ่มบันทึกอัตโนมัติ: ตรวจทุก interval วินาที ถ้าค่าเปลี่ยนจะเขียนลงไฟล์
    function SettingsStore.StartAutoSave(fileName, getData, interval)
        if flushers[fileName] then return end
        local last = nil

        local function flush()
            local ok, snapshot = pcall(function()
                return clean(getData())
            end)
            if not ok or type(snapshot) ~= "table" then return end

            local okSig, signature = pcall(function()
                return HttpService:JSONEncode(snapshot)
            end)
            if not okSig or signature == last then return end

            snapshot.SavedAt = os.time()
            snapshot.Account = owner.Name
            if SettingsStore.Write(fileName, snapshot) then
                last = signature
                if SettingsStore.OnSaved then pcall(SettingsStore.OnSaved, snapshot.SavedAt) end
            end
        end

        flushers[fileName] = flush
        task.spawn(function()
            while true do
                task.wait(interval or 1.5)
                flush()
            end
        end)
    end

    -- สั่งเซฟทันที (ไม่ต้องรอรอบถัดไป)
    function SettingsStore.Flush(fileName)
        local flush = flushers[fileName]
        if flush then pcall(flush) end
    end
end

-- โหลดค่าที่จำไว้ของไอดีนี้ (ไม่เคยเซฟ = ใช้ค่าเริ่มต้น)
local SavedData = SettingsStore.Load("AOTR")
local SavedUi = type(SavedData.UI) == "table" and SavedData.UI or {}
do -- config ที่ตั้งเป็น Autoload เก็บหน้าตาไว้ด้วย: ใช้หน้าตาของมันตั้งแต่ตอนเริ่ม
    local autoSnap = ConfigStore.AutoloadSnapshot()
    if autoSnap and type(autoSnap.UI) == "table" then
        for k, v in pairs(autoSnap.UI) do SavedUi[k] = v end
    end
end

-- โหลดค่าสวิตช์/ตัวเลือกทั้งหมด: ไฟล์ใหม่ก่อน ถ้ายังไม่มีใช้ไฟล์เก่าของเวอร์ชันก่อน (ย้ายค่าให้อัตโนมัติ)
if type(SavedData.Cfg) == "table" then ApplyCfgData(SavedData.Cfg) else ApplyCfgData(ReadLegacyCfg()) end
-- มี Autoload ไว้ = ใช้ config นั้นทุกครั้งที่เริ่ม (และถือว่ากำลังใช้ config นั้นอยู่)
if ConfigStore.AutoloadSnapshot() then
    ConfigStore.ApplyCfg(ConfigStore.AutoloadSnapshot())
    ConfigStore.SetActive(ConfigStore.Autoload())
end
Cfg.JoinDelay = ClampDelay(Cfg.JoinDelay)
Cfg.MissionJoinDelay = ClampDelay(Cfg.MissionJoinDelay)

local AccentOrder
do
---------------------------------------------------------
-- 🎨 สีพื้นหลัง UI ที่เปลี่ยนตามสี Theme Color
-- แก้รหัสสี (hex) ตรงนี้ได้เลย
-- Background = พื้นหลังหน้าต่าง, View = การ์ดของแต่ละหมวด
-- Sidebar = แถบซ้าย, Titlebar = แถบบนสุด, Menu = เมนูดรอปดาวน์
---------------------------------------------------------
local WindowTints = {
    Blue     = { Background = "#0F1722", View = "#121C2A", Sidebar = "#111B29", Titlebar = "#1D2D45", Menu = "#182436" },
    Purple   = { Background = "#1A1226", View = "#1F1630", Sidebar = "#1C1429", Titlebar = "#33214D", Menu = "#261A38" },
    Pink     = { Background = "#25121A", View = "#2C161F", Sidebar = "#281420", Titlebar = "#4A2133", Menu = "#361B28" },
    Red      = { Background = "#241211", View = "#2B1615", Sidebar = "#271413", Titlebar = "#4A2220", Menu = "#351B1A" },
    Orange   = { Background = "#241A0F", View = "#2B1F12", Sidebar = "#271C10", Titlebar = "#4A3317", Menu = "#35261A" },
    Yellow   = { Background = "#222010", View = "#292611", Sidebar = "#252210", Titlebar = "#453D16", Menu = "#322E18" },
    Green    = { Background = "#0F2016", View = "#12271A", Sidebar = "#112318", Titlebar = "#1D4029", Menu = "#1A3022" },
    Graphite = { Background = "#1C1C1E", View = "#1F1F21", Sidebar = "#202023", Titlebar = "#363636", Menu = "#2C2C2E" },
}

for accentName, tint in pairs(WindowTints) do
    pcall(function()
        local dark = Cascade.Accents[accentName].Dark
        dark.Background = Color3.fromHex(tint.Background)
        dark.View = Color3.fromHex(tint.View)
        dark.Sidebar = Color3.fromHex(tint.Sidebar)
        dark.Titlebar = Color3.fromHex(tint.Titlebar)
        dark.MenuButton = { MenuBackground = Color3.fromHex(tint.Menu) }
    end)
end

---------------------------------------------------------
-- 🌈 สีเพิ่มเติม (สร้างสีหลัก + สีพื้นหลังให้อัตโนมัติจากรหัสสีเดียว)
-- อยากเพิ่มสีใหม่ แค่เติมบรรทัด { "ชื่อสี", "#รหัสสี" } ในตารางนี้
---------------------------------------------------------
local ExtraAccents = {
    -- โทนมืด: ใส่สีพื้นหลังกำหนดเองเป็นช่องที่ 3
    { "Black", "#9A9AA0", { Background = "#000000", View = "#090909", Sidebar = "#050505", Titlebar = "#141414", Menu = "#101010" } },
    { "Midnight", "#4C6EF5", { Background = "#05080F", View = "#0A0F1A", Sidebar = "#070B14", Titlebar = "#131C30", Menu = "#0E1524" } },
    { "Sky",        "#64D2FF" },
    { "Cyan",       "#00C7E6" },
    { "Teal",       "#30B0C7" },
    { "Turquoise",  "#40E0D0" },
    { "Aqua",       "#00E5FF" },
    { "Mint",       "#63E6BE" },
    { "Emerald",    "#10B981" },
    { "Forest",     "#2E8B57" },
    { "Lime",       "#A3E635" },
    { "Neon Green", "#39FF14" },
    { "Olive",      "#8A9A2B" },
    { "Gold",       "#FFC83D" },
    { "Amber",      "#FFA726" },
    { "Sand",       "#D9B97A" },
    { "Sunset",     "#FF7A45" },
    { "Peach",      "#FF9E80" },
    { "Coral",      "#FF6F61" },
    { "Cherry",     "#E0245E" },
    { "Crimson",    "#DC143C" },
    { "Maroon",     "#A52A2A" },
    { "Rose",       "#FF5C8A" },
    { "Hot Pink",   "#FF2E93" },
    { "Magenta",    "#E040FB" },
    { "Violet",     "#8B5CF6" },
    { "Lavender",   "#B39DDB" },
    { "Indigo",     "#5E5CE6" },
    { "Ocean",      "#1E88E5" },
    { "Navy",       "#3A5BA0" },
    { "Slate",      "#7C8DA6" },
    { "Silver",     "#B0B7C3" },
    { "Brown",      "#A2845E" },
}

local function MakeAccent(name, hex, customBg)
    local main = Color3.fromHex(hex)
    local h, s, val = main:ToHSV()

    local selection = Color3.fromHSV(h, math.min(s * 1.05, 1), math.min(val * 0.78, 0.72))
    local focused = Color3.fromHSV(h, s, math.min(val * 0.88, 0.80))
    local buttonBottom = Color3.fromHSV(h, math.min(s * 1.1, 1), math.min(val * 0.6, 0.55))
    local bgS = math.min(s * 0.6, 0.55)

    local function buildSet()
        return {
            SwitchAccent = main,
            Selection = selection,
            SelectionFocused = focused,
            Toggle = { SwitchOn = main },
            Button = { FillPrimary = ColorSequence.new(focused, buttonBottom) },
        }
    end

    local dark = buildSet()
    dark.Background = Color3.fromHSV(h, bgS, 0.13)
    dark.View = Color3.fromHSV(h, bgS, 0.16)
    dark.Sidebar = Color3.fromHSV(h, bgS * 0.95, 0.15)
    dark.Titlebar = Color3.fromHSV(h, bgS * 0.85, 0.28)
    dark.MenuButton = { MenuBackground = Color3.fromHSV(h, bgS * 0.8, 0.20) }

    if customBg then
        dark.Background = Color3.fromHex(customBg.Background)
        dark.View = Color3.fromHex(customBg.View)
        dark.Sidebar = Color3.fromHex(customBg.Sidebar)
        dark.Titlebar = Color3.fromHex(customBg.Titlebar)
        dark.MenuButton = { MenuBackground = Color3.fromHex(customBg.Menu) }
    end

    Cascade.Accents[name] = {
        _id = name,
        Dark = dark,
        Light = buildSet(),
    }
end

-- Dark แบบดั้งเดิมของ Cascade: สีปุ่มฟ้าเดิม + พื้นหลังเทาเข้มเดิม
-- ต้องใส่สีพื้นหลังเดิมทับให้ครบทุกช่อง เพราะ Cascade ไม่รีเซ็ตสีเก่าให้ตอนสลับสี
-- (ถ้าไม่ใส่ จะค้างโทนสีของสีก่อนหน้า)
do
    local originalSet = function()
        return {
            SwitchAccent = Color3.fromHex("#0A84FF"),
            Selection = Color3.fromHex("#007AFF"),
            SelectionFocused = Color3.fromHex("#0A82FF"),
            Toggle = { SwitchOn = Color3.fromHex("#0A84FF") },
            Button = {
                FillPrimary = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 148, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 110, 255)),
                }),
            },
        }
    end
    local darkSet = originalSet()
    darkSet.Background = Color3.fromHex("#1C1C1E") -- พื้นหลังหน้าต่าง
    darkSet.View = Color3.fromHex("#1F1F21")       -- การ์ดของแต่ละหมวด
    darkSet.Sidebar = Color3.fromHex("#202023")    -- แถบซ้าย
    darkSet.Titlebar = Color3.fromHex("#363636")   -- แถบบนสุด
    darkSet.MenuButton = { MenuBackground = Color3.fromHex("#2C2C2E") }

    Cascade.Accents.Dark = {
        _id = "Dark",
        Dark = darkSet,
        Light = originalSet(),
    }
end

-- ลำดับสีในเมนู: สีเดิม 8 สี, Dark แบบดั้งเดิม แล้วตามด้วยสีเพิ่มเติม
AccentOrder = { "Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Graphite", "Dark" }
for _, entry in ipairs(ExtraAccents) do
    pcall(MakeAccent, entry[1], entry[2], entry[3])
    if Cascade.Accents[entry[1]] then
        table.insert(AccentOrder, entry[1])
    end
end
end

local function StyleDropdown(btn)
    pcall(function()
        local indicator = btn.__instance:FindFirstChild("PullDownIndicator")
        local img = indicator and indicator:FindFirstChild("Indicators")
        if img then
            img.Image = "rbxassetid://115187614425058"
            img.ImageColor3 = Color3.fromRGB(255, 255, 255)
            img.Size = UDim2.fromOffset(18, 18)
            img.Position = UDim2.fromScale(0.5, 0.5)
            img.AnchorPoint = Vector2.new(0.5, 0.5)
        end
    end)
end

local function CopyText(text)
    pcall(function()
        if setclipboard then setclipboard(text)
        elseif toclipboard then toclipboard(text)
        elseif syn and syn.write_clipboard then syn.write_clipboard(text)
        elseif Clipboard and Clipboard.set then Clipboard.set(text) end
    end)
end

local App = Cascade.New({
    Name = "Smooth Hub AOTR",
    WindowPill = true,
    Theme = Cascade.Themes.Dark,
    -- สีเริ่มต้น = สีที่จำไว้ (ถ้าไม่เคยตั้ง ใช้ Pink เหมือนเดิม)
    Accent = (table.find(AccentOrder, SavedUi.Theme) and Cascade.Accents[SavedUi.Theme]) or Cascade.Accents[ConfigStore.DEFAULT_LOOK.Theme] or Cascade.Accents.Pink,
})
AppRef = App

local Window = App:Window({
    Title = "Attack on Titan Revolution",
    Subtitle = "Smooth Hub",
    Resizable = true,
    Draggable = true,
    UIBlur = false
})
UiSync.Defaults.UIBlur = false
UiSync.Defaults.Dropshadow = Window.Dropshadow

---------------------------------------------------------
-- Menu (หน้าเมนู / Lobby)
---------------------------------------------------------
local MenuCategory = Cascade.Components.Section(Window, {
    Title = "Menu",
    Disclosure = false
})

local CharTab = MenuCategory:Tab({
    Title = "Menu Lobby",
    Icon = Icon("houseDoorFill", "houseFill", "personCircleFill"), -- เปลี่ยนเป็นไอคอนรูปบ้าน/ล็อบบี้ให้เหมาะสม
})


-- ───────── Status ─────────
local StatusSection = CharTab:PageSection({
    Title = "📋 Status",
    Subtitle = IN_MENU and "You are in the menu place." or "Not in the menu place - menu features are idle."
})
local StatusForm = StatusSection:Form()
local StatusRow = StatusForm:Row()
StatusRow:Left():TitleStack({ Title = "Status", Subtitle = "What the script is doing right now." })
local StatusLabel = StatusRow:Right():Label({ Text = IN_MENU and "Idle" or "N/A" })
local function SetStatus(text)
    pcall(function() StatusLabel.Text = tostring(text) end)
end

---------------------------------------------------------
-- 🎭 Character Selection (ตรรกะ)
---------------------------------------------------------
local SLOT_LETTERS = { "A", "B", "C" }
local SlotOptions = { "Slot A", "Slot B", "Slot C" }

local function TextOf(o)
    local t = o.Text or ""
    t = t:gsub("<[^>]->", "")          -- ตัด RichText tag
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    return t:upper()
end

local function IsTextObj(o)
    return o:IsA("TextLabel") or o:IsA("TextButton")
end

-- เห็นอยู่บนหน้าจอจริงไหม (ทุกชั้นต้อง Visible/Enabled)
local function IsShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

local function ToButton(o)
    if o:IsA("GuiButton") then return o end
    local cur = o.Parent
    for _ = 1, 3 do
        if not cur then break end
        if cur:IsA("GuiButton") then return cur end
        cur = cur.Parent
    end
    local p = o.Parent
    if p then return p:FindFirstChildWhichIsA("GuiButton", true) end
    return nil
end

local function FindSelectIn(container)
    for _, d in ipairs(container:GetDescendants()) do
        if IsTextObj(d) and TextOf(d) == "SELECT" and IsShown(d) then
            local b = ToButton(d)
            if b then return b end
        end
    end
    return nil
end

-- หาปุ่ม SELECT ของช่องนั้น: หาป้าย "SLOT A" แล้วไต่ขึ้นไปหากรอบที่มีปุ่ม SELECT
local function FindSlotButton(letter)
    local want = "SLOT " .. letter
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        if IsTextObj(d) and TextOf(d) == want and IsShown(d) then
            local cur = d.Parent
            for _ = 1, 6 do
                if not cur or cur == PlayerGui then break end
                local btn = FindSelectIn(cur)
                if btn then return btn end
                cur = cur.Parent
            end
        end
    end
    return nil
end

-- หน้าเลือกตัวละครยังโชว์อยู่ไหม
local function SlotScreenVisible()
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        if IsTextObj(d) and TextOf(d) == "SLOT A" and IsShown(d) then return true end
    end
    return false
end

-- กดปุ่ม: ตั้ง SelectedObject (กรอบฟ้าเหมือนกด \) แล้วส่ง Enter
-- ถ้าปุ่มยังอยู่ = Enter ไม่ติด ค่อยยิง signal ตรง ๆ เป็นตัวสำรอง
local function ActivateButton(btn)
    pcall(function() GuiService.SelectedObject = btn end)
    task.wait(0.15)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
    task.wait(1.0)
    if btn.Parent and IsShown(btn) then
        pcall(function()
            if type(firesignal) == "function" then
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            end
        end)
    end
    pcall(function()
        if GuiService.SelectedObject == btn then GuiService.SelectedObject = nil end
    end)
end

local selecting = false
local function SelectCharacter()
    if selecting then return false end
    if not IN_MENU then SetStatus("N/A") return false end
    selecting = true
    local letter = SLOT_LETTERS[Cfg.Slot] or "A"
    local btn = FindSlotButton(letter)
    local result = false
    if btn then
        SetStatus("Selecting Slot " .. letter .. "...")
        ActivateButton(btn)
        SetStatus("Selected Slot " .. letter)
        result = true
    else
        SetStatus("Slot " .. letter .. " UI not found")
    end
    selecting = false
    return result
end

---------------------------------------------------------
-- 🎭 Character Selection (UI)
---------------------------------------------------------
local CharSection = CharTab:PageSection({
    Title = "🎭 Character Selection",
    Subtitle = "Pick one slot. The script presses its SELECT button for you."
})
local CharForm = CharSection:Form()

local SlotRow = CharForm:Row()
SlotRow:Left():TitleStack({ Title = "Slot", Subtitle = "Choose which character slot to use (one at a time)." })
UiSync.Slot = SlotRow:Right():PullDownButton({
    Label = SlotOptions[Cfg.Slot],
    Options = SlotOptions,
    Value = Cfg.Slot,
    ValueChanged = function(self, index)
        if type(index) == "table" then index = index[1] end
        if type(index) ~= "number" or not SlotOptions[index] then return end
        Cfg.Slot = index
        self.Label = SlotOptions[index]
        Save()
    end
})
UiSync.Add(function()
    local i = SlotOptions[Cfg.Slot] and Cfg.Slot or 1
    UiSync.Slot.Value = i
    UiSync.Slot.Label = SlotOptions[i]
end)

local AutoSelRow = CharForm:Row()
AutoSelRow:Left():TitleStack({
    Title = "Auto Select Character",
    Subtitle = "Automatically press SELECT on the chosen slot when the screen shows up."
})
UiSync.Link(AutoSelRow:Right():Toggle({
    Value = Cfg.AutoSelect,
    ValueChanged = function(self, value)
        Cfg.AutoSelect = value and true or false
        Save()
    end
}), Cfg, "AutoSelect")

local SelNowRow = CharForm:Row()
SelNowRow:Left():TitleStack({ Title = "Select Now", Subtitle = "Press SELECT on the chosen slot once." })
local SelNowBtn = SelNowRow:Right():Button({
    Label = "Select",
    Callback = function() end
})
BindButton(SelNowBtn, SelectCharacter)

---------------------------------------------------------
-- 🚪 Auto Join Lobby (ตรรกะ)
---------------------------------------------------------
local function GetLobbyRemote()
    local ok, remote = pcall(function()
        local assets = ReplicatedStorage:WaitForChild("Assets", 5)
        local remotes = assets and assets:WaitForChild("Remotes", 5)
        return remotes and remotes:WaitForChild("GET", 5)
    end)
    return ok and remote or nil
end

local cachedRemote = nil
local lastRequestAt = 0
-- ยิงคำขอในเธรดแยก ไม่บล็อกตัวนับเวลา (InvokeServer อาจค้างรอเซิร์ฟเวอร์นาน)
local function JoinLobby()
    if not IN_MENU then SetStatus("N/A") return end
    if os.clock() - lastRequestAt < 3 then return end
    lastRequestAt = os.clock()
    task.spawn(function()
        local remote = cachedRemote
        if not remote or not remote.Parent then
            remote = GetLobbyRemote()
            cachedRemote = remote
        end
        if not remote then SetStatus("Lobby remote not found") return end
        SetStatus("Joining lobby...")
        local ok, err = pcall(function()
            return remote:InvokeServer("Functions", "Teleport", "Lobby", nil)
        end)
        SetStatus(ok and "Join request sent" or ("Join failed: " .. tostring(err)))
    end)
end

---------------------------------------------------------
-- 🚪 Auto Join Lobby (UI)
---------------------------------------------------------
local JoinSection = CharTab:PageSection({
    Title = "🚪 Auto Join Lobby",
    Subtitle = "Repeatedly requests the lobby. Delay is " .. MIN_DELAY .. " - " .. MAX_DELAY .. " seconds."
})
local JoinForm = JoinSection:Form()

local AutoJoinRow = JoinForm:Row()
AutoJoinRow:Left():TitleStack({
    Title = "Auto Join Lobby",
    Subtitle = "Send the join-lobby request every Join Delay seconds."
})
UiSync.Link(AutoJoinRow:Right():Toggle({
    Value = Cfg.AutoJoin,
    ValueChanged = function(self, value)
        Cfg.AutoJoin = value and true or false
        Save()
    end
}), Cfg, "AutoJoin")

local DelayRow = JoinForm:Row()
DelayRow:Left():TitleStack({
    Title = "Join Delay",
    Subtitle = "Seconds between requests (" .. MIN_DELAY .. " - " .. MAX_DELAY .. "). Minimum is " .. MIN_DELAY .. "s so it can't spam by accident."
})
local DelayRight = DelayRow:Right()
local DelayLabel = DelayRight:Label({ Text = Cfg.JoinDelay .. "s" })
UiSync.Link(DelayRight:Slider({
    Minimum = MIN_DELAY,
    Maximum = MAX_DELAY,
    Value = Cfg.JoinDelay,
    ValueChanged = function(self, value)
        Cfg.JoinDelay = ClampDelay(value)
        pcall(function() DelayLabel.Text = Cfg.JoinDelay .. "s" end)
        Save()
    end
}), Cfg, "JoinDelay", function(_, want)
    pcall(function() DelayLabel.Text = want .. "s" end)
end)

local CountdownRow = JoinForm:Row()
CountdownRow:Left():TitleStack({
    Title = "Next Join",
    Subtitle = "Countdown until the next join-lobby request."
})
local CountdownLabel = CountdownRow:Right():Label({ Text = "Off" })
local lastCountdownText = nil
local function SetCountdown(text)
    if text == lastCountdownText then return end
    lastCountdownText = text
    pcall(function() CountdownLabel.Text = text end)
end

local JoinNowRow = JoinForm:Row()
JoinNowRow:Left():TitleStack({ Title = "Join Now", Subtitle = "Send the join-lobby request once." })
local JoinNowBtn = JoinNowRow:Right():Button({
    Label = "Join",
    Callback = function() end
})
BindButton(JoinNowBtn, JoinLobby)

---------------------------------------------------------
-- 📊 Account Overview (เช็คสถานะบัญชี)
---------------------------------------------------------
local ReplicatedStorageSvc = game:GetService("ReplicatedStorage")

local StatusCategory = Cascade.Components.Section(Window, {
    Title = "Status",
    Disclosure = false
})
local AccountTab = StatusCategory:Tab({
    Title = "Account",
    Icon = Icon("bookmarkFill", "bookmark"),
    Selected = true -- เปิดหน้า Account Overview เป็นหน้าแรกตอนรันสคริปต์
})
local OverviewTab = AccountTab -- ใส่ Overview ในแท็บ Account ของหมวด Status
local OverviewSection = OverviewTab:PageSection({
    Title = "📊 Account Overview",
    Subtitle = "Read from your player data. N/A = this value was not found."
})
local OverviewForm = OverviewSection:Form()

-- หา Instance ใน PlayerGui ตาม path เช่น "Interface.Topbar.Main.Currencies.Gold.Amount"
local function FindGui(path)
    local cur = PlayerGui
    for seg in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

-- รวมจำนวนไอเทมที่ชื่อมีคำว่า "Shard" ในหน้า Inventory (เช่น "400 - Female Shard" ช่อง Quantity)
-- ถ้ายังไม่มี Inventory ใน GUI (ยังไม่เคยเปิดหน้านั้น) จะคืน nil = N/A
local function CountShards()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    local total = 0
    for _, c in ipairs(items:GetChildren()) do
        if c.Name:lower():find("shard", 1, true) then
            local q = 1
            local label = c:FindFirstChild("Quantity", true)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                q = tonumber((label.Text:gsub("[^%d]", ""))) or 1
            end
            total += q
        end
    end
    return total
end

-- Family ที่ใส่อยู่ จากหน้า Inventory ใน GUI
-- รูปแบบชื่อไอเทมคือ "<id> - <ชื่อ>" เช่น "502 - Leonhart" / "802 - Bozado"
-- ไอเทมประเภท Family ลงท้าย id ด้วย 02 (ดูจากรายการที่มี: 502, 802) และตัวที่ใส่อยู่จะมีกรอบ Main.Equipped เปิดอยู่
local function CurrentFamily()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    for _, c in ipairs(items:GetChildren()) do
        local id, name = c.Name:match("^(%d+)%s*%-%s*(.+)$")
        if id and tonumber(id) % 100 == 2 then
            local main = c:FindFirstChild("Main")
            local eq = main and main:FindFirstChild("Equipped")
            if eq and eq:IsA("GuiObject") and eq.Visible then
                local check = eq:FindFirstChild("Checkmark")
                local on = true
                if check and check:IsA("ImageLabel") and check.ImageTransparency >= 1 then on = false end
                if on then return name end
            end
        end
    end
    return "None"
end

-- ───────── ตรวจร่องรอย Shadow Ban (แบบอ่านอย่างเดียว ไม่ยิง Remote ไม่ส่งของ) ─────────
-- เกมไม่ได้บอกตรง ๆ ว่าโดน Shadow Ban จึงดูแค่ "ร่องรอย" 2 อย่าง:
--  1) Attribute Blacklisted / Exploiter บนตัวเรา
--  2) ป้ายข้อความ (แม้ซ่อนอยู่) ใน PlayerGui ที่มีคำว่า exploiter / shadow ban
local function AttrTrue(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local x = v:lower()
        return x == "true" or x == "yes" or x == "1"
    end
    return false
end

local hiddenLabelCache, hiddenLabelAt = nil, 0
local function FindWarningLabel()
    if os.clock() - hiddenLabelAt < 15 then return hiddenLabelCache end
    hiddenLabelAt = os.clock()
    hiddenLabelCache = false
    local n = 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        n += 1
        if n % 600 == 0 then task.wait() end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = (d.Text or ""):lower()
            if t:find("exploiter", 1, true) or t:find("shadow ban", 1, true) or t:find("shadowban", 1, true) then
                hiddenLabelCache = d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
                break
            end
        end
    end
    return hiddenLabelCache
end

-- ✅ = พบร่องรอยว่าโดน Shadow Ban / ❌ = ยังไม่พบ
-- (ใช้ ✅ แทน ✔️ เพราะ ✔️ เป็นสัญลักษณ์ธรรมดา ฟอนต์ของ Roblox วาดเป็นสีเทาตามสีข้อความ)
local function ShadowStatus()
    if FindWarningLabel() then return "✅" end
    if AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted")) then
        return "✅"
    end
    return "❌"
end

-- เทียบกับผู้เล่นคนอื่นในเซิร์ฟ: ถ้าทุกคนมีธงเหมือนกัน แปลว่าเป็นค่าปกติของเกม ไม่ได้หมายถึงเราโดนแบน
local function FlagCompare()
    local others, flagged = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            others += 1
            if AttrTrue(plr:GetAttribute("Exploiter")) or AttrTrue(plr:GetAttribute("Blacklisted")) then
                flagged += 1
            end
        end
    end
    local mine = (AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted"))) and "flagged" or "clear"
    return ("You: %s | Others flagged: %d/%d"):format(mine, flagged, others)
end

-- aliases = ชื่อที่เป็นไปได้ของค่านี้ในเกม (เทียบแบบตัวพิมพ์เล็ก ไม่สนช่องว่าง/ขีด)
local FIELDS = {
    { key = "ShadowBan", title = "🛠️ Shadow Ban", raw = true, aliases = {}, calc = ShadowStatus,
      colors = { ["✅"] = Color3.fromRGB(80, 200, 120), ["❌"] = Color3.fromRGB(235, 87, 87) } },
    { key = "FlagCompare", title = "🔍 Flag Compare", raw = true, aliases = {}, calc = FlagCompare },
    { key = "Blacklisted", title = "🚫 Blacklisted", flag = true, aliases = { "blacklisted" } },
    { key = "Exploiter", title = "⚠️ Exploiter Flag", flag = true, aliases = { "exploiter" } },
    { key = "Level",     title = "▶️ Level",    aliases = { "level", "lvl", "playerlevel" } },
    { key = "XP",        title = "📈 XP",       aliases = {}, strip = "^XP:%s*",
      gui = "Interface.Gear_Up.XP.Percentage" },
    { key = "Prestige",  title = "🔺 Prestige", aliases = { "prestige", "prestigelevel" } },
    { key = "Gold",      title = "💰 Gold",     aliases = { "gold", "coins", "money" },
      gui = "Interface.Topbar.Main.Currencies.Gold.Amount" },
    { key = "Gems",      title = "💎 Gems",     aliases = { "gems", "gem" },
      gui = "Interface.Topbar.Main.Currencies.Gems.Amount" },
    { key = "Family",    title = "⚡ Family",   aliases = { "family", "familyname", "clan" }, calc = CurrentFamily },
    { key = "Title",     title = "🏷️ Title",    aliases = { "title" }, pretty = true },
    { key = "Shards",    title = "✨ Shards",   aliases = { "shards", "shard" }, calc = CountShards },
}

for _, f in ipairs(FIELDS) do
    local row = OverviewForm:Row()
    row:Left():TitleStack({ Title = f.title })
    f.label = row:Right():Label({ Text = "..." })
    f.last = nil
end

local function NormName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end

local function Fmt(v)
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        local s = tostring(math.floor(v))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    return tostring(v)
end

local function Truthy(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "yes" or s == "1"
    end
    return false
end

-- แหล่งข้อมูลผู้เล่น: ตัว Player เอง + โฟลเดอร์ใน ReplicatedStorage ที่ชื่อ = ชื่อ/ไอดีเรา
local dataRoots = { LocalPlayer }
local lastRootScan = 0
local function ScanRoots(force)
    if not force and os.clock() - lastRootScan < 15 then return end
    lastRootScan = os.clock()
    local roots = { LocalPlayer }
    local uid = tostring(LocalPlayer.UserId)
    local n = 0
    for _, d in ipairs(ReplicatedStorageSvc:GetDescendants()) do
        n += 1
        if n % 500 == 0 then task.wait() end
        if d.Name == LocalPlayer.Name or d.Name == uid then
            table.insert(roots, d)
        end
    end
    dataRoots = roots
end

local SKIP_NAMES = { PlayerGui = true, PlayerScripts = true }

local function CollectEntries()
    local entries = {}
    local function keep(v)
        local t = type(v)
        return t == "number" or t == "string" or t == "boolean"
    end
    local function walk(inst, depth)
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if keep(v) then
                    entries[#entries + 1] = { name = k, value = v, path = inst:GetFullName() .. " @" .. k }
                end
            end
            if inst:IsA("ValueBase") then
                local ok, v = pcall(function() return inst.Value end)
                if ok and keep(v) then
                    entries[#entries + 1] = { name = inst.Name, value = v, path = inst:GetFullName() }
                end
            end
        end)
        if depth >= 6 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if not SKIP_NAMES[c.Name] then walk(c, depth + 1) end
        end
    end
    for _, root in ipairs(dataRoots) do
        if root and root.Parent then walk(root, 0) end
    end
    return entries
end

-- ค่าใต้ Boosts / Gamepasses ไม่ใช่ค่าบัญชี (เช่น Boosts.Gold = เวลาบัฟ) ข้ามไป
local function IsExcludedPath(path)
    return path:find("%.Boosts") ~= nil or path:find("%.Gamepasses") ~= nil
end

local function LookupField(entries, field)
    for _, alias in ipairs(field.aliases) do
        for _, e in ipairs(entries) do
            if NormName(e.name) == alias and not IsExcludedPath(e.path) then
                return e.value
            end
        end
    end
    return nil
end

-- อ่านข้อความจาก PlayerGui ตาม path เช่น "Interface.Topbar.Main.Currencies.Gold.Amount"
local function ReadGui(path)
    local cur = FindGui(path)
    if cur and (cur:IsA("TextLabel") or cur:IsA("TextButton")) then
        local t = (cur.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then return t end
    end
    return nil
end

-- หา TextLabel จริงข้างใน Label ของไลบรารี เพื่อตั้งสีข้อความ
local function LabelObject(label)
    local inst = label and label.__instance
    if not inst then return nil end
    if inst:IsA("TextLabel") then return inst end
    return inst:FindFirstChildWhichIsA("TextLabel", true)
end

local lastEntries = {}
local function RefreshOverview()
    ScanRoots(false)
    local entries = CollectEntries()
    lastEntries = entries
    for _, f in ipairs(FIELDS) do
        -- ช่องที่มี gui = อ่านจากตัวเลขบนจอก่อน ถ้าไม่เจอค่อยหาจาก Attribute/Value
        local v
        if f.calc then
            local okC, r = pcall(f.calc)
            if okC then v = r end
        end
        if v == nil and f.gui then v = ReadGui(f.gui) end
        if v == nil then v = LookupField(entries, f) end
        local text
        if v == nil then
            text = "N/A"
        elseif f.raw then
            text = tostring(v)
        elseif f.flag then
            text = Truthy(v) and "⚠️ Yes" or "✅ No"
        elseif f.strip then
            text = (tostring(v):gsub(f.strip, ""))
        elseif f.pretty then
            text = (tostring(v):gsub("_", " "))
        else
            text = Fmt(v)
        end
        if text ~= f.last then
            f.last = text
            pcall(function() f.label.Text = text end)
            if f.colors and f.colors[text] then
                pcall(function()
                    local obj = LabelObject(f.label)
                    if obj then obj.TextColor3 = f.colors[text] end
                end)
            end
        end
    end
end

task.spawn(function()
    while Alive() do
        pcall(RefreshOverview)
        for _ = 1, 12 do
            if not Alive() then return end
            task.wait(0.25)
        end
    end
end)

---------------------------------------------------------
-- ลูปทำงานเบื้องหลัง
---------------------------------------------------------
-- Auto Select: เจอหน้าเลือกตัวละครเมื่อไหร่ กดช่องที่เลือก (เว้น 4 วิกันกดรัว)
task.spawn(function()
    while Alive() do
        if IN_MENU and Cfg.AutoSelect and not selecting then
            if SelectCharacter() then
                for _ = 1, 16 do
                    if not Alive() then return end
                    task.wait(0.25)
                end
            end
        end
        task.wait(1)
    end
end)

-- Auto Join: ยิงทุก JoinDelay วินาที (บังคับ 5-60 ทุกรอบ) และแสดงเวลาที่เหลือ
-- นับจากเวลาที่ยิงจริง ปรับสไลเดอร์ระหว่างรอได้ทันที
-- ถ้าเปิด Auto Select อยู่และหน้าเลือกตัวละครยังโชว์ จะรอก่อน ไม่ยิง
task.spawn(function()
    local lastFire = nil
    local slotVisible, slotCheckAt = false, 0
    while Alive() do
        if not IN_MENU then
            lastFire = nil
            SetCountdown("N/A")
        elseif not Cfg.AutoJoin then
            lastFire = nil
            SetCountdown("Off")
        else
            local now = os.clock()
            if Cfg.AutoSelect then
                if now >= slotCheckAt then
                    slotVisible = SlotScreenVisible()
                    slotCheckAt = now + 1
                end
            else
                slotVisible = false
            end

            if slotVisible then
                lastFire = nil
                SetCountdown("Waiting for character select")
            else
                local delay = ClampDelay(Cfg.JoinDelay)
                -- เริ่มนับใหม่ทุกครั้ง (เพิ่งเปิดสวิตช์ / หน้าเลือกตัวละครเพิ่งหายไป) = รอให้ครบ Delay ก่อนค่อยยิง
                if not lastFire then lastFire = now end
                local remaining = lastFire + delay - now
                if remaining <= 0 then
                    SetCountdown("Joining now...")
                    lastFire = os.clock()
                    JoinLobby()
                else
                    SetCountdown(("Next join in %ds"):format(math.ceil(remaining)))
                end
            end
        end
        task.wait(0.25)
    end
end)

---------------------------------------------------------
-- In-Game (ไว้ใส่ภายหลัง)
---------------------------------------------------------
local MainCategory = Cascade.Components.Section(Window, {
    Title = "In-Game",
    Disclosure = false
})
local FarmTab = MainCategory:Tab({
    Title = "Auto Farm",
    Icon = Icon("boltFill"),
})
local AutoFarmSection = FarmTab:PageSection({
    Title = "🛠️ Main",
    Subtitle = "Core features and settings"
})

---------------------------------------------------------
-- 🌾 Auto Farm : ฟังก์ชันเปล่า (ใส่คำสั่งภายหลัง)
-- ทุกสวิตช์ / สไลเดอร์ / ปุ่ม จะเรียกฟังก์ชันใน Farm.* ด้านล่างเมื่อค่าเปลี่ยน
--   • สวิตช์   -> Farm.OnXxx(on)        on = true/false
--   • สไลเดอร์ -> Farm.OnXxx(value)     value = ตัวเลข (ปัดเป็นจำนวนเต็มแล้ว)
--   • ปุ่ม Refresh -> Farm.RefreshStreak() / Farm.RefreshRetry()
-- ค่าปัจจุบันอ่านได้จาก Cfg.AutoFarm, Cfg.SafeTime ฯลฯ (เซฟ/โหลด/Reset ให้อัตโนมัติ)
-- อัปเดตตัวเลขบนหน้าจอด้วย Farm.SetStreak(n) / Farm.SetRetry(n)
---------------------------------------------------------
local Farm = {}
_G.SmoothHubFarm = Farm -- เรียกจาก executor ได้ เช่น _G.SmoothHubFarm.DumpHud("depleted")

-- ───── Main ─────
-- Farm.OnAutoFarm(on)                        -- Auto Farm: ทำจริงแล้ว (Fly เหนือหัวไททัน) ดูส่วน "🪽 Auto Farm" ด้านล่าง
-- Farm.OnAutoReload(on)                        -- Auto Reload: ทำจริงแล้ว ดูส่วน "🔪 Auto Reload" ด้านล่าง
-- Farm.OnAutoRefills(on)                        -- Auto Refills: ทำจริงแล้ว ดูส่วน "🔧 Auto Refills" ด้านล่าง
function Farm.OnDamageMultiplier(on) end         -- Damage Multiplier (x10)
-- Farm.OnSafeTime(seconds)                    -- Safe Time: ทำจริงแล้ว ดู Farm.ApplySafeTime ด้านล่าง (อ่านค่าจาก Cfg.SafeTime ตอนทำงาน)
function Farm.OnFailSafeAt(value) end            -- Fail Safe At
function Farm.OnAutoFailSafe(on) end             -- Auto Fail Safe
function Farm.RefreshStreak() end                -- ปุ่ม Refresh ของ Current Streak (ใส่โค้ดอ่านค่าแล้วเรียก Farm.SetStreak(n))

-- ───── Game Options ─────
-- Farm.OnAutoRetry(on) / Farm.RefreshRetry()    -- Auto Retry: ทำจริงแล้ว ดูส่วน "🔁 Auto Retry" ด้านล่าง
-- Farm.OnAutoLeave(on)                          -- Auto Leave: ทำจริงแล้ว ดูส่วน "🔁 Auto Retry / Leave" ด้านล่าง
function Farm.OnRetryAmount(amount) end          -- Retry Amount
-- Farm.OnAutoLeaveWhenRetryComplete(on)         -- Auto Leave After X Matches: ทำจริงแล้ว

-- เรียกฟังก์ชันแบบปลอดภัย (error ในฟังก์ชันของคุณจะไม่ทำให้หน้าต่าง UI พัง)
function Farm.Fire(name, ...)
    local fn = Farm[name]
    if type(fn) == "function" then
        local ok, err = pcall(fn, ...)
        if not ok then warn("[SmoothHub] Farm." .. tostring(name) .. ":", err) end
    end
end

do
    local MainForm = AutoFarmSection:Form()
    if Cfg.AutoLeave and Cfg.AutoLeaveWhenRetryComplete then Cfg.AutoLeave = false end

    local function AddFarmToggle(form, title, subtitle, key, handler)
        local row = form:Row()
        row:Left():TitleStack({ Title = title, Subtitle = subtitle })
        Farm.Toggles = Farm.Toggles or {}
        Farm.Toggles[key] = UiSync.Link(row:Right():Toggle({
            Value = Cfg[key],
            ValueChanged = function(self, value)
                Cfg[key] = value and true or false
                Save()
                Farm.Fire(handler, Cfg[key])
            end
        }), Cfg, key)
    end

    -- สไลเดอร์ที่โชว์ค่าไว้ในชื่อหัวข้อ เช่น "Safe Time ( 32s )"
    local function AddFarmSlider(form, titleFor, subtitle, key, handler)
        local range = FARM_RANGES[key]
        local row = form:Row()
        local stack = row:Left():TitleStack({ Title = titleFor(Cfg[key]), Subtitle = subtitle })
        UiSync.Link(row:Right():Slider({
            Minimum = range[1],
            Maximum = range[2],
            Value = Cfg[key],
            ValueChanged = function(self, value)
                local v = math.clamp(math.floor(value + 0.5), range[1], range[2])
                Cfg[key] = v
                pcall(function() stack.Title = titleFor(v) end)
                Save()
                Farm.Fire(handler, v)
            end
        }), Cfg, key, function(_, want)
            pcall(function() stack.Title = titleFor(want) end)
        end)
    end

    -- แถวตัวเลขปัจจุบัน + ปุ่ม Refresh เช่น "Current Streak ( 0 )"
    local function AddCounterRow(form, titleFor, refreshHandler)
        local row = form:Row()
        local stack = row:Left():TitleStack({ Title = titleFor(0) })
        local run
        local btn = row:Right():Button({
            Label = "Refresh",
            Callback = function() if run then run() end end
        })
        run = BindButton(btn, function() Farm.Fire(refreshHandler) end)
        return function(n)
            pcall(function() stack.Title = titleFor(n) end)
        end
    end

    -- ───── Main ─────
    AddFarmToggle(MainForm, "Auto Farm", "Automatically completes missions.", "AutoFarm", "OnAutoFarm")
    AddFarmToggle(MainForm, "No Clip", "Pass through walls and titans while Auto Farm is on.", "NoClip", "OnNoClip")
    AddFarmToggle(MainForm, "Hit All Parts", "Also hits Eyes, Arms and Legs of each titan (then a 7s cooldown). The Nape is hit every swing with no cooldown.", "HitAllParts", "OnHitAllParts")
    AddFarmSlider(MainForm, function(v) return "Tween Speed ( " .. v .. " )" end,
        "How fast Auto Farm flies to the titans (studs per second).", "FlySpeed", "OnFlySpeed")
    AddFarmSlider(MainForm, function(v) return "Fly Height ( " .. v .. " )" end,
        "How high Auto Farm hovers above the titans' heads (studs).", "FlyHeight", "OnFlyHeight")
    local ATTACK_SPEED_NAMES = { [0] = "Auto", "Safe", "Fast", "Turbo", "Max" }
    AddFarmSlider(MainForm, function(v) return "Attack Speed ( " .. tostring(ATTACK_SPEED_NAMES[v] or v) .. " )" end,
        "Auto = starts at Max and slows down by itself if hits stop landing. 1 Safe ... 4 Max.", "AttackSpeed", "OnAttackSpeed")
    AddFarmToggle(MainForm, "Auto Reload", "Automatically reloads your blades when depleted.", "AutoReload", "OnAutoReload")
    AddFarmToggle(MainForm, "Auto Refills", "Refill at the map's refill station when your blades / thunder spears run out.", "AutoRefills", "OnAutoRefills")
    do -- แถวบอกสถานะของ Auto Refills (โชว์ค่าที่อ่านได้จาก HUD จะได้รู้ว่ามันเห็นอะไร)
        local statusRow = MainForm:Row()
        statusRow:Left():TitleStack({ Title = "Refill Status", Subtitle = "What Auto Refills reads from your HUD." })
        local statusLabel = statusRow:Right():Label({ Text = "Idle" })
        local lastText = nil
        function Farm.SetRefillStatus(text)
            text = tostring(text)
            if text == lastText then return end
            lastText = text
            pcall(function() statusLabel.Text = text end)
        end
    end
    AddFarmToggle(MainForm, "Damage Multiplier ( x10 )", "Attacking Titan with 10 times the damage carries", "DamageMultiplier", "OnDamageMultiplier")
    AddFarmSlider(MainForm, function(v) return "Safe Time ( " .. v .. "s )" end,
        "A mission can't finish sooner than this. 0 = off.", "SafeTime", "OnSafeTime")
    do -- แถวบอกสถานะของ Safe Time
        local statusRow = MainForm:Row()
        statusRow:Left():TitleStack({ Title = "Safe Time Status", Subtitle = "Auto Farm keeps 1 titan alive until the time is reached." })
        local statusLabel = statusRow:Right():Label({ Text = "Idle" })
        local lastText = nil
        function Farm.SetSafeStatus(text)
            text = tostring(text)
            if text == lastText then return end
            lastText = text
            pcall(function() statusLabel.Text = text end)
        end
    end
    do -- แถวสถิติของ Auto Farm (ดูว่าไททันกี่ตัวที่ฟันได้จริง / ฟันกี่ครั้งต่อวินาที)
        local statsRow = MainForm:Row()
        statsRow:Left():TitleStack({ Title = "Farm Stats", Subtitle = "Titans loaded / total | swings per second | speed level | kills | hit rate" })
        local statsLabel = statsRow:Right():Label({ Text = "Off" })
        local lastText = nil
        function Farm.SetStatsText(text)
            text = tostring(text)
            if text == lastText then return end
            lastText = text
            pcall(function() statsLabel.Text = text end)
        end
    end
    AddFarmSlider(MainForm, function(v) return "Fail Safe At [ " .. v .. " ]" end,
        "Adjust the fail safe.", "FailSafeAt", "OnFailSafeAt")
    Farm.SetStreak = AddCounterRow(MainForm, function(n) return "Current Streak ( " .. tostring(n) .. " )" end, "RefreshStreak")
    AddFarmToggle(MainForm, "Auto Fail Safe", "Automatically loses when the deadline is reached.", "AutoFailSafe", "OnAutoFailSafe")

    -- ───── Game Options ─────
    local OptionsSection = FarmTab:PageSection({
        Title = "⚙️ Game Options",
    })
    local OptionsForm = OptionsSection:Form()

    AddFarmToggle(OptionsForm, "Auto Retry", "Automatically Retry when completed.", "AutoRetry", "OnAutoRetry")
    AddFarmToggle(OptionsForm, "Auto Leave", "Leave to the lobby right when the match ends.", "AutoLeave", "OnAutoLeave")
    Farm.SetRetry = AddCounterRow(OptionsForm, function(n) return "Current Retry ( " .. tostring(n) .. " )" end, "RefreshRetry")
    do -- แถวบอกสถานะของ Auto Retry
        local statusRow = OptionsForm:Row()
        statusRow:Left():TitleStack({ Title = "Retry Status", Subtitle = "What Auto Retry is doing right now." })
        local statusLabel = statusRow:Right():Label({ Text = "Idle" })
        local lastText = nil
        function Farm.SetRetryStatus(text)
            text = tostring(text)
            if text == lastText then return end
            lastText = text
            pcall(function() statusLabel.Text = text end)
        end
    end
    AddFarmSlider(OptionsForm, function(v) return "Retry Amount ( " .. v .. " )" end,
        "Matches to retry before leaving (used by Auto Leave After X Matches).", "RetryAmount", "OnRetryAmount")
    AddFarmToggle(OptionsForm, "Auto Leave After X Matches",
        "Retry until the Retry Amount is reached, then leave to the lobby (needs Auto Retry). Can't be on together with Auto Leave.",
        "AutoLeaveWhenRetryComplete", "OnAutoLeaveWhenRetryComplete")
end
---------------------------------------------------------
-- 🪽 Auto Farm : Fly ไปลอยอยู่เหนือหัวไททัน (ไม่ใช้ Tween / ไม่วาป)
-- • ไททันอยู่ใน Workspace.Titans (แต่ละตัวเป็น Model: Humanoid, HumanoidRootPart, Fake.Head ...)
-- • บินด้วยความเร็ว (BodyVelocity) ค่อย ๆ เข้าหา "เหนือหัว" ไม่เปลี่ยนตำแหน่งทันที
-- • เลือกไททันที่ใกล้ที่สุดที่ยังมีชีวิต ล็อกเป้าไว้จนมันตายแล้วค่อยสลับตัวใหม่
-- • ปิดสวิตช์ / ตัวละครตาย / อยู่เมนู-ล็อบบี้ = หยุดบินและลบแรงทั้งหมด
-- • ปรับได้จาก executor: _G.SmoothHubFarm.FlyHeight / FlySpeed
---------------------------------------------------------
do
    Farm.FlyHeight = Cfg.FlyHeight -- สูงเหนือ "ยอดหัว" กี่ studs ปรับได้ที่สไลเดอร์ Fly Height (150 - 2000)
    Farm.FlySpeed = Cfg.FlySpeed -- ความเร็วบินสูงสุด (studs/วินาที) ปรับได้ที่สไลเดอร์ Tween Speed
    function Farm.OnFlySpeed(v) Farm.FlySpeed = v end
    function Farm.OnFlyHeight(v) Farm.FlyHeight = v end
    local ARRIVE_DIST = 3 -- ใกล้กว่านี้ถือว่าถึงแล้ว (ลอยนิ่ง)
    -- โหมดเคลื่อนที่: "Auto" = ลอง Fly ก่อน ถ้าขยับไม่ได้จะสลับเป็น Tween เอง | "Fly" | "Tween"
    Farm.FlyMode = "Tween" -- ค่าเริ่มต้น: เลื่อนทุกเฟรม + ล็อกนิ่ง (ไม่ตก)
    local TweenService = game:GetService("TweenService")
    local usingTween = false
    local tween, lastTweenAt = nil, 0
    local lastClock, savedPlatformStand = nil, nil
    local probePos, probeAt = nil, 0

    local RunService = game:GetService("RunService")
    local target = nil    -- Model ไททันที่ล็อกอยู่
    local bv, bg = nil, nil
    local conn = nil

    -- No Clip: ปิดการชนของทุกชิ้นส่วนตัวละครทุกเฟรมตอน Auto Farm ทำงาน (เปิด/ปิดได้ที่สวิตช์ No Clip)
    Farm.NoClipConn = nil
    function Farm.StopNoClip()
        if Farm.NoClipConn then Farm.NoClipConn:Disconnect() Farm.NoClipConn = nil end
    end
    function Farm.UpdateNoClip()
        Farm.StopNoClip()
        if not (Cfg.AutoFarm and Cfg.NoClip) then return end
        Farm.NoClipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end)
    end
    function Farm.OnNoClip(on) Farm.UpdateNoClip() end

    local function TitansFolder() return workspace:FindFirstChild("Titans") end

    local function IsAlive(titan)
        if not (titan and titan.Parent) then return false end
        -- ตายแล้ว = Humanoid ถูกลบ (เห็นจากการทดสอบ) หรือเลือด <= 0
        local hum = titan:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        return titan:FindFirstChild("HumanoidRootPart") ~= nil or titan:FindFirstChild("Fake") ~= nil
    end

    -- จุดยอดหัว: ใช้ Fake.Head ถ้ามี ไม่งั้นใช้ HumanoidRootPart
    local function HeadTopPosition(titan)
        local fake = titan:FindFirstChild("Fake")
        local head = fake and fake:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            return head.Position + Vector3.new(0, head.Size.Y / 2, 0)
        end
        local root = titan:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            return root.Position + Vector3.new(0, root.Size.Y, 0)
        end
        return nil
    end
    Farm.HeadTopPosition = HeadTopPosition

    -- โหมดเป้าหมาย: "Nape" = ไปอยู่ข้างหลังคอไททัน (ที่ฟัน) | "Head" = ลอยเหนือหัวสูง ๆ
    Farm.TargetMode = "Head"
    Farm.NapeUp = 6     -- สูงกว่าท้ายทอยกี่ studs
    Farm.NapeBack = 8   -- ถอยไปด้านหลังไททันกี่ studs

    local function FindNape(titan)
        local hb = titan:FindFirstChild("Hitboxes")
        local hit = hb and hb:FindFirstChild("Hit")
        local nape = hit and hit:FindFirstChild("Nape")
        if nape and nape:IsA("BasePart") then return nape end
        return nil
    end
    Farm.FindNape = FindNape

    -- ชิ้นส่วนที่ฟันได้ของไททัน: Titan.Hitboxes.Hit.{Eyes, LeftArm, RightArm, LeftLeg, RightLeg, Nape}
    -- ลำดับ: ส่วนอื่นก่อน แล้ว Nape เป็นอันสุดท้ายเสมอ (กันไททันตายก่อนที่จะโดนส่วนอื่นครบ)
    Farm.HitOrder = { "Eyes", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
    local function HitParts(titan)
        local hb = titan:FindFirstChild("Hitboxes")
        local hit = hb and hb:FindFirstChild("Hit")
        if not hit then return {} end
        local list, used = {}, {}
        for _, name in ipairs(Farm.HitOrder) do
            local part = hit:FindFirstChild(name)
            if part and part:IsA("BasePart") then list[#list + 1] = part used[part] = true end
        end
        for _, part in ipairs(hit:GetChildren()) do -- ชิ้นส่วนอื่นใต้ Hit ที่ไม่อยู่ในลิสต์ (เผื่อเกมเพิ่มใหม่)
            if part:IsA("BasePart") and part.Name ~= "Nape" and not used[part] then
                list[#list + 1] = part
                used[part] = true
            end
        end
        local nape = hit:FindFirstChild("Nape")
        if nape and nape:IsA("BasePart") then
            if Farm.NapeFirst then table.insert(list, 1, nape) else list[#list + 1] = nape end
        end
        return list
    end
    Farm.HitParts = HitParts

    -- ชิ้นส่วนที่จะ Register ของไททันตัวนี้ในรอบนี้ (คืน parts, ยิงส่วนอื่นด้วยไหม)
    --  • Nape ยิงทุกรอบ ไม่ติดคูลดาวน์ (ไททันต้องโดนท้ายทอยถึงจะตาย)
    --  • ส่วนอื่น (Eyes / แขน / ขา) ยิงครบทุกส่วนทีเดียว แล้วพักตามไททันแต่ละตัว Farm.PartCooldown วินาที
    --    พ้นเวลาแล้วค่อยยิงทุกส่วนอีกรอบ (ปิด Hit All Parts = Nape อย่างเดียวเหมือนเดิม)
    local PartStamp = setmetatable({}, { __mode = "k" }) -- ไททัน -> เวลาที่ยิงส่วนอื่นครั้งล่าสุด
    local function PartsFor(e)
        if Cfg.HitAllParts then
            local last = PartStamp[e.titan]
            if not last or os.clock() - last >= Farm.PartCooldown then
                local parts = HitParts(e.titan)
                if #parts > 1 then return parts, true end
            end
        end
        return { e.nape }, false
    end

    -- เลือกชิ้นส่วนจริงที่จะยิง โดยดูงบ Register ต่อการฟัน (regs = ที่ใช้ไปแล้วในรอบนี้)
    -- งบไม่พอสำหรับครบทุกส่วน -> ยิงแค่ Nape (ไม่ข้ามไททันตัวนั้น) | งบหมดจริง -> nil (หยุดเก็บเพิ่ม)
    local function PlanFor(e, regs, budget)
        local parts, withOthers = PartsFor(e)
        if regs > 0 and regs + #parts > budget then
            if regs + 1 > budget then return nil end
            parts, withOthers = { e.nape }, false
        end
        if withOthers then PartStamp[e.titan] = os.clock() end -- เริ่มนับคูลดาวน์ของส่วนอื่น
        return parts
    end

    -- จุดที่จะไปอยู่ (คืน nil ถ้าหาไม่เจอ)
    local function GoalFor(titan)
        if Farm.TargetMode == "Nape" then
            local nape = FindNape(titan)
            if nape then
                local root = titan:FindFirstChild("HumanoidRootPart")
                local back = Vector3.zero
                if root then
                    local look = root.CFrame.LookVector
                    back = -Vector3.new(look.X, 0, look.Z).Unit * Farm.NapeBack
                end
                return nape.Position + back + Vector3.new(0, Farm.NapeUp, 0)
            end
        end
        local head = HeadTopPosition(titan)
        return head and (head + Vector3.new(0, Farm.FlyHeight, 0)) or nil
    end

    local function PickNearest(myPos)
        local folder = TitansFolder()
        if not folder then return nil end
        local best, bestDist = nil, math.huge
        for _, t in ipairs(folder:GetChildren()) do
            if t:IsA("Model") and IsAlive(t) then
                local p = HeadTopPosition(t)
                if p then
                    local d = (p - myPos).Magnitude
                    if d < bestDist then best, bestDist = t, d end
                end
            end
        end
        return best
    end

    -- เลือกไททันที่รอบ ๆ มีไททันตัวอื่นเยอะที่สุด (ในรัศมี ClusterRadius) หักคะแนนตามระยะทาง
    -- ไททันที่ไกลเกินระยะโหลดของแมพ (Streaming) จะยังไม่มีชิ้นส่วนท้ายทอย = ฟันไม่ได้
    -- การไปอยู่กลางกลุ่มช่วยให้โหลดและฟันได้หลายตัวพร้อมกัน
    Farm.ClusterRadius = 300
    local function PickBest(myPos)
        local folder = TitansFolder()
        if not folder then return nil end
        local pool = {}
        for _, t in ipairs(folder:GetChildren()) do
            if t:IsA("Model") and IsAlive(t) then
                local p = HeadTopPosition(t)
                if p then pool[#pool + 1] = { t = t, p = p, d = (p - myPos).Magnitude } end
            end
        end
        local best, bestScore = nil, -math.huge
        for i, a in ipairs(pool) do
            local n = 0
            for j, b in ipairs(pool) do
                if i ~= j and (a.p - b.p).Magnitude <= Farm.ClusterRadius then n += 1 end
            end
            local score = n - a.d / 400
            if score > bestScore then best, bestScore = a.t, score end
        end
        return best
    end

    local function Cleanup()
        Farm.StopNoClip()
        if conn then conn:Disconnect() conn = nil end
        if tween then pcall(function() tween:Cancel() end) tween = nil end
        usingTween, probePos, lastClock = false, nil, nil
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and savedPlatformStand ~= nil then pcall(function() h.PlatformStand = savedPlatformStand end) end
        savedPlatformStand = nil
        if bv then pcall(function() bv:Destroy() end) bv = nil end
        if bg then pcall(function() bg:Destroy() end) bg = nil end
        target = nil
    end

    local function Step()
        if not (Cfg.AutoFarm and Alive() and Farm.CanUseHere()) then
            Cleanup()
            return
        end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum and hum.Health > 0) then
            if bv then bv.Velocity = Vector3.zero end
            return
        end

        if Cfg.NoClip and not Farm.NoClipConn then Farm.UpdateNoClip() end
        if not IsAlive(target) then target = PickBest(root.Position) or PickNearest(root.Position) end

        if not (bv and bv.Parent == root) then
            if bv then pcall(function() bv:Destroy() end) end
            bv = Instance.new("BodyVelocity")
            bv.Name = "SmoothHubFly"
            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bv.Velocity = Vector3.zero
            bv.Parent = root
        end

        local goal = target and GoalFor(target)
        if not goal then
            bv.Velocity = Vector3.zero -- ไม่มีไททัน: ลอยนิ่งรอ
            return
        end

        local delta = goal - root.Position
        local dist = delta.Magnitude

        -- ตรวจว่า Fly ขยับได้จริงไหม (Auto): ไกลกว่า 10 studs แต่ 1.5 วิผ่านไปขยับไม่ถึง 2 studs = ใช้ไม่ได้
        if Farm.FlyMode == "Auto" and not usingTween and dist > 10 then
            if not probePos then probePos, probeAt = root.Position, os.clock()
            elseif os.clock() - probeAt >= 1.5 then
                if (root.Position - probePos).Magnitude < 2 then
                    usingTween = true
                    warn("[SmoothHub] Auto Farm: Fly ขยับไม่ได้ -> สลับไปใช้ Tween")
                end
                probePos, probeAt = root.Position, os.clock()
            end
        else
            probePos = nil
        end

        if Farm.FlyMode == "Tween" or usingTween then
            -- เลื่อนทุกเฟรมเข้าหาจุดเหนือหัว พอถึงแล้วล็อกตำแหน่งนิ่งสนิท (ตามหัวไททัน) ไม่มีแรงโน้มถ่วง
            local now = os.clock()
            local dt = math.min(now - (lastClock or now), 0.1)
            lastClock = now
            if savedPlatformStand == nil then
                savedPlatformStand = hum.PlatformStand
            end
            hum.PlatformStand = true
            bv.Velocity = Vector3.zero
            local step = Farm.FlySpeed * dt
            local newPos = (dist <= step) and goal or (root.Position + delta.Unit * step)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = CFrame.new(newPos) * root.CFrame.Rotation
            return
        end

        if dist <= ARRIVE_DIST then
            -- ถึงแล้ว: ตามการเคลื่อนที่ของหัวเบา ๆ ไม่ให้หลุด
            bv.Velocity = delta * 8
        else
            -- ยิ่งใกล้ยิ่งช้าลง (ไม่พุ่งเลยเป้า)
            local speed = math.min(Farm.FlySpeed, dist * 4)
            bv.Velocity = delta.Unit * speed
        end
    end

    function Farm.OnAutoFarm(on)
        Cleanup()
        if on then
            Farm.UpdateNoClip()
            if not Farm.CanUseHere() then
                warn("[SmoothHub] Auto Farm: ไม่ทำงานในหน้าเมนู/ล็อบบี้ (จะเริ่มเมื่ออยู่ในด่าน)")
            end
            conn = RunService.Heartbeat:Connect(function()
                local ok, err = pcall(Step)
                if not ok then warn("[SmoothHub] Auto Farm:", err) end
            end)
        end
    end

    ---------------------------------------------------------
    -- ⚔️ โจมตี: ลำดับรีโมตเลียนแบบการฟันจริง (จาก Remote Spy)
    --   Attacks,Slash,true -> Hitboxes,Register,Nape,<ความเร็ว>,<เวลา> -> Attacks,Slash,false
    -- ยิงเมื่อบินถึงใกล้ท้ายทอยแล้วเท่านั้น ตัวเลขสุ่มในช่วงที่เห็นจากการฟันจริง
    ---------------------------------------------------------
    Farm.Attack = true         -- ปิดได้: _G.SmoothHubFarm.Attack = false (บินอย่างเดียว)
    Farm.PauseUntil = 0        -- Auto Reload ตั้งเวลาไว้ตอนรีโหลด: ถึงเวลานี้ลูปฟันจะหยุดชั่วคราว (หมดเวลาเอง กันค้าง)
    Farm.Slashing = false      -- true = กำลังอยู่ในท่าฟัน 1 รอบ (Auto Reload รอให้จบก่อนกด R)
    Farm.AttackRange = 10000     -- ต้องอยู่ห่างท้ายทอยไม่เกินกี่ studs ถึงจะฟัน
    Farm.AttackDelay = 0.001     -- พักระหว่างการฟันแต่ละครั้ง (วินาที)
    Farm.Kills = 0
    -- ───── ความแม่นของการฟัน (ดูได้ที่แถว Farm Stats: "hit %") ─────
    -- นับต่อไททันทุกตัวที่ฟันไปในแต่ละรอบ: เลือดลดหรือตาย = โดน / ไม่ลด = พลาด
    Farm.MissCount = setmetatable({}, { __mode = "k" }) -- ไททันตัวนี้ฟันพลาดติดกันกี่รอบ
    Farm.MissLimit = 3         -- พลาดติดกันเท่านี้ = เลื่อนไปท้ายคิว (ให้งบ Register ไปลงตัวที่โดนจริงก่อน) โดนเมื่อไหร่กลับมาปกติ
    Farm.HitStat = { hit = 0, tried = 0 }
    -- ───── วิธียิงหลายชิ้นส่วน (ให้ Farm.TestParts() ทดสอบแล้วเลือกให้ หรือตั้งเอง) ─────
    Farm.PartMode = "ByTitan"  -- "ByTitan" = ไททันทีละตัว ครบทุกส่วน | "ByPart" = รอบละชิ้นส่วน (ทุกตัวโดนส่วนเดียวกันก่อน แล้วพัก PartGap)
    Farm.PartGap = 0.03        -- (เฉพาะ ByPart) พักระหว่างรอบชิ้นส่วน (วินาที)
    Farm.PartCooldown = 7      -- Eyes/แขน/ขา ของไททันแต่ละตัว ยิงซ้ำได้ทุกกี่วินาที (Nape ไม่ติดคูลดาวน์ ยิงทุกรอบ)
    Farm.NapeFirst = false     -- true = ยิง Nape ก่อนแล้วค่อยส่วนอื่น | false = Nape ท้ายสุด
    local function PostRemote()
        local a = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
        local r = a and a:FindFirstChild("Remotes")
        return r and r:FindFirstChild("POST")
    end

    Farm.MultiHit = true       -- ฟันไททันหลายตัวในการฟันครั้งเดียว
    Farm.MaxTargets = 100       -- สูงสุดกี่ตัวต่อการฟัน 1 ครั้ง
    Farm.MultiRange = math.huge     -- เลือกเฉพาะไททันที่ห่างจากตัวเราไม่เกินกี่ studs
    Farm.MaxRegisters = 120         -- Hit All Parts: ส่ง Register ได้สูงสุดกี่ครั้งต่อการฟัน 1 ครั้ง (กันรีโมตถี่เกินจนแลค/โดนเตะ)

    -- รวมไททันที่ฟันได้: ตัวที่ล็อกอยู่ก่อน แล้วตัวอื่นที่อยู่ใกล้ที่สุดตามลำดับ
    local function CollectTargets(root, main)
        local list = {}
        local function add(t)
            local nape = FindNape(t)
            if nape and (nape.Position - root.Position).Magnitude <= Farm.MultiRange then
                list[#list + 1] = { titan = t, nape = nape, d = (nape.Position - root.Position).Magnitude }
            end
        end
        if main and IsAlive(main) then add(main) end
        if Farm.MultiHit then
            local others = {}
            local folder = TitansFolder()
            for _, t in ipairs(folder and folder:GetChildren() or {}) do
                if t ~= main and t:IsA("Model") and IsAlive(t) then
                    local nape = FindNape(t)
                    if nape then
                        local d = (nape.Position - root.Position).Magnitude
                        if d <= Farm.MultiRange then others[#others + 1] = { titan = t, nape = nape, d = d } end
                    end
                end
            end
            table.sort(others, function(x, y)
                local mx = (Farm.MissCount[x.titan] or 0) >= Farm.MissLimit and 1 or 0
                local my = (Farm.MissCount[y.titan] or 0) >= Farm.MissLimit and 1 or 0
                if mx ~= my then return mx < my end -- ตัวที่ฟันพลาดติด ๆ ไปท้ายคิว
                return x.d < y.d
            end)
            for _, o in ipairs(others) do
                if #list >= Farm.MaxTargets then break end
                list[#list + 1] = o
            end
        end
        return list
    end

    -- วิธีฟันหลายตัว (ตั้งเองได้ หรือให้ Farm.TestMulti() ทดสอบแล้วเลือกให้):
    --   "Batch"      = Slash true > Register ทุกตัว (เว้นเฟรม) > Slash false  (แบบเดิม)
    --   "Burst"      = Slash true > Register ทุกตัวติดกันไม่เว้น > Slash false
    --   "Sequential" = ฟันแยกทีละตัว: (Slash true > Register > Slash false) ต่อไททันแต่ละตัว
    Farm.MultiMode = "Batch"

    function Farm.Reg(post, e, part)
        post:FireServer("Hitboxes", "Register", part or e.nape,
            85 + math.random() * 90,       -- ช่วงที่เห็น: 88 - 171
            0.14 + math.random() * 0.19)   -- ช่วงที่เห็น: 0.15 - 0.32
    end

    -- ───── ความเร็วการฟัน (preset) ─────
    -- windup  = รอหลัง Slash true ก่อนส่ง Register     release = รอหลัง Register ก่อน Slash false
    -- gap     = พักก่อนเริ่มฟันรอบใหม่               perTarget = เว้น 1 เฟรมต่อไททัน 1 ตัว (แบบเดิม) / false = ยิงติดกัน
    -- maxTargets = จำกัดจำนวนไททันต่อการฟัน 1 ครั้ง (กันส่งรีโมตถี่เกินจนแลค/โดนเตะ ยิ่งฟันถี่ยิ่งจำกัดเข้ม)
    -- Safe = เท่าของเดิม | Auto (Attack Speed = 0) = เริ่มที่ Max แล้วลดระดับเองถ้าไม่มีไททันโดนดาเมจ
    Farm.Presets = {
        { name = "Safe",  windup = 0.35, release = 0.60, gap = 0.40, perTarget = true,  maxTargets = 100 },
        { name = "Fast",  windup = 0.20, release = 0.30, gap = 0.10, perTarget = false, maxTargets = 100 },
        { name = "Turbo", windup = 0.10, release = 0.15, gap = 0.02, perTarget = false, maxTargets = 60 },
        { name = "Max",   windup = 0.04, release = 0.06, gap = 0,    perTarget = false, maxTargets = 40 },
    }
    Farm.Level = #Farm.Presets -- ระดับที่ใช้อยู่ (โหมด Auto ปรับให้เอง)
    function Farm.OnAttackSpeed(v)
        if v == 0 then Farm.Level = #Farm.Presets end -- เปลี่ยนเป็น Auto = เริ่มจาก Max ใหม่
    end

    local function Slash(post, list, p)
        -- งบ Register ต่อการฟัน (ใช้เมื่อเปิด Hit All Parts) ไททันตัวไหนงบไม่พอให้ครบทุกส่วนจะยิงแค่ Nape
        -- (Nape ยิงทุกรอบเสมอ ส่วนอื่นติดคูลดาวน์ Farm.PartCooldown ต่อไททัน 1 ตัว)
        local budget = Cfg.HitAllParts and Farm.MaxRegisters or math.huge
        local regs = 0
        if Farm.MultiMode == "Sequential" then -- ตั้งเองได้ (ฟันแยกทีละตัว) ไม่ขึ้นกับ preset
            for _, e in ipairs(list) do
                if e.titan.Parent and e.nape.Parent then
                    local parts = PlanFor(e, regs, budget)
                    if not parts then break end
                    regs += #parts
                    post:FireServer("Attacks", "Slash", true)
                    task.wait(0.05 + math.random() * 0.05)
                    for _, part in ipairs(parts) do
                        if part.Parent then Farm.Reg(post, e, part) end
                    end
                    task.wait(0.1 + math.random() * 0.05)
                    post:FireServer("Attacks", "Slash", false)
                    task.wait(0.05)
                end
            end
            return
        end
        post:FireServer("Attacks", "Slash", true)
        task.wait(p.windup * (1 + math.random() * 0.15))
        if Cfg.HitAllParts and Farm.PartMode == "ByPart" then
            -- รอบละชิ้นส่วน: ทุกตัวโดนส่วนเดียวกันก่อน พัก PartGap แล้วค่อยส่วนถัดไป (Nape ท้ายสุด/ก่อนตาม NapeFirst)
            local plan, rounds = {}, 0
            for _, e in ipairs(list) do
                if e.titan.Parent and e.nape.Parent then
                    local parts = PlanFor(e, regs, budget)
                    if not parts then break end
                    regs += #parts
                    plan[#plan + 1] = parts
                    rounds = math.max(rounds, #parts)
                end
            end
            for round = 1, rounds do
                for _, parts in ipairs(plan) do
                    local part = parts[round]
                    if part and part.Parent then Farm.Reg(post, nil, part) end
                end
                if round < rounds and Farm.PartGap > 0 then task.wait(Farm.PartGap) end
            end
        else
            for _, e in ipairs(list) do
                if e.titan.Parent and e.nape.Parent then
                    local parts = PlanFor(e, regs, budget)
                    if not parts then break end
                    regs += #parts
                    for _, part in ipairs(parts) do
                        if part.Parent then Farm.Reg(post, e, part) end
                    end
                    if p.perTarget then task.wait() end
                end
            end
        end
        task.wait(p.release * (1 + math.random() * 0.15))
        post:FireServer("Attacks", "Slash", false)
    end

    ---------------------------------------------------------
    -- 🧪 ทดสอบว่าวิธีไหนโดนไททันหลายตัวได้จริง
    -- ใช้: ปิด Auto Farm ก่อน แล้วรัน  _G.SmoothHubFarm.TestMulti()
    -- ต้องมีไททันที่ยังไม่ตายอย่างน้อย 9 ตัว (วิธีละ 3 ตัว) ไม่ต้องอยู่ใกล้
    -- ฟันตามสวิตช์ Hit All Parts (เปิด = ทุกชิ้นส่วน Nape ท้ายสุด / ปิด = Nape อย่างเดียว)
    -- จบแล้วจะพิมพ์ผลใน Console (F9) และตั้ง Farm.MultiMode เป็นวิธีที่ดีที่สุดให้
    ---------------------------------------------------------
    -- ฟันทุกชิ้นส่วนของไททันตัวนี้ (ตามสวิตช์ Hit All Parts: ปิด = Nape อย่างเดียว) ใช้ชุดเดียวกับตอนฟาร์มจริง
    local function RegAll(post, e)
        for _, part in ipairs(PartsFor(e)) do
            if part.Parent then Farm.Reg(post, e, part) end
        end
    end

    function Farm.TestMulti()
        task.spawn(function()
            if Cfg.AutoFarm then print("[SmoothHub] ปิด Auto Farm ก่อนทดสอบ") return end
            local post = PostRemote()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not (post and root) then print("[SmoothHub] ไม่พบ POST remote หรือตัวละคร") return end

            local pool = {}
            local folder = TitansFolder()
            for _, t in ipairs(folder and folder:GetChildren() or {}) do
                if t:IsA("Model") and IsAlive(t) then
                    local nape = FindNape(t)
                    local hum = t:FindFirstChildOfClass("Humanoid")
                    if nape and hum then
                        pool[#pool + 1] = { titan = t, nape = nape, hum = hum, d = (nape.Position - root.Position).Magnitude }
                    end
                end
            end
            table.sort(pool, function(x, y) return x.d < y.d end)
            if #pool < 9 then
                print(("[SmoothHub] ต้องมีไททันอย่างน้อย 9 ตัว (ตอนนี้ %d)"):format(#pool))
                return
            end

            local groups = { { pool[1], pool[2], pool[3] }, { pool[4], pool[5], pool[6] }, { pool[7], pool[8], pool[9] } }
            for _, g in ipairs(groups) do
                for _, e in ipairs(g) do e.hp0 = e.hum.Health end
            end
            local function Hurt(g) -- (ตาย, โดนดาเมจ) จาก 3 ตัว
                local dead, hurt = 0, 0
                for _, e in ipairs(g) do
                    if not IsAlive(e.titan) then dead += 1 hurt += 1
                    elseif e.hum.Health < e.hp0 then hurt += 1 end
                end
                return dead, hurt
            end

            -- A: Batch
            post:FireServer("Attacks", "Slash", true)
            task.wait(0.35)
            for _, e in ipairs(groups[1]) do RegAll(post, e) task.wait() end
            task.wait(0.55)
            post:FireServer("Attacks", "Slash", false)
            task.wait(2)
            local aDead, aHurt = Hurt(groups[1])

            -- B: Burst
            post:FireServer("Attacks", "Slash", true)
            task.wait(0.35)
            for _, e in ipairs(groups[2]) do RegAll(post, e) end
            task.wait(0.55)
            post:FireServer("Attacks", "Slash", false)
            task.wait(2)
            local bDead, bHurt = Hurt(groups[2])

            -- C: Sequential
            for _, e in ipairs(groups[3]) do
                post:FireServer("Attacks", "Slash", true)
                task.wait(0.07)
                RegAll(post, e)
                task.wait(0.12)
                post:FireServer("Attacks", "Slash", false)
                task.wait(0.05)
            end
            task.wait(2)
            local cDead, cHurt = Hurt(groups[3])

            print(("[SmoothHub] ผลทดสอบ (จาก 3 ตัว)  A Batch: ตาย %d / โดน %d  |  B Burst: ตาย %d / โดน %d  |  C Sequential: ตาย %d / โดน %d")
                :format(aDead, aHurt, bDead, bHurt, cDead, cHurt))

            local best, bestScore = Farm.MultiMode, -1
            for _, r in ipairs({ { "Batch", aDead * 10 + aHurt }, { "Burst", bDead * 10 + bHurt }, { "Sequential", cDead * 10 + cHurt } }) do
                if r[2] > bestScore then best, bestScore = r[1], r[2] end
            end
            Farm.MultiMode = best
            print("[SmoothHub] ตั้ง Farm.MultiMode =", best, "(ตั้งเองได้: _G.SmoothHubFarm.MultiMode = \"Sequential\")")
        end)
    end

    ---------------------------------------------------------
    -- 🧪 ทดสอบวิธียิงหลายชิ้นส่วนว่าวิธีไหนโดนมากสุด (ฟันไม่โดนบางครั้ง = ลองรันตัวนี้)
    -- ใช้: ปิด Auto Farm ก่อน แล้วรัน  _G.SmoothHubFarm.TestParts()
    -- ต้องมีไททันที่โหลดแล้วและยังไม่ตายอย่างน้อย 8 ตัว (ใช้ 4 วิธี วิธีละ 2 ตัว / ถ้ามี 12 ตัวขึ้นไปวิธีละ 3 ตัว)
    --   A = Nape อย่างเดียว | B = ทุกส่วนทีละตัว Nape ท้ายสุด | C = ทุกส่วนรอบละชิ้นส่วน | D = ทุกส่วนทีละตัว Nape ก่อน
    -- จบแล้วพิมพ์ผลใน Console (F9) และตั้ง Farm.PartMode / Farm.NapeFirst เป็นวิธีที่ดีที่สุดให้ (B / C / D)
    ---------------------------------------------------------
    function Farm.TestParts()
        task.spawn(function()
            if Cfg.AutoFarm then print("[SmoothHub] ปิด Auto Farm ก่อนทดสอบ") return end
            local post = PostRemote()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not (post and root) then print("[SmoothHub] ไม่พบ POST remote หรือตัวละคร") return end

            local pool = {}
            local folder = TitansFolder()
            for _, t in ipairs(folder and folder:GetChildren() or {}) do
                if t:IsA("Model") and IsAlive(t) then
                    local nape = FindNape(t)
                    local hum = t:FindFirstChildOfClass("Humanoid")
                    if nape and hum then
                        pool[#pool + 1] = { titan = t, nape = nape, hum = hum, d = (nape.Position - root.Position).Magnitude }
                    end
                end
            end
            table.sort(pool, function(x, y) return x.d < y.d end)
            local size = (#pool >= 12) and 3 or 2
            if #pool < size * 4 then
                print(("[SmoothHub] ต้องมีไททันที่โหลดแล้วอย่างน้อย %d ตัว (ตอนนี้ %d)"):format(size * 4, #pool))
                return
            end
            local groups = {}
            for g = 1, 4 do
                groups[g] = {}
                for k = 1, size do
                    local e = pool[(g - 1) * size + k]
                    e.hp0 = e.hum.Health
                    groups[g][k] = e
                end
            end
            local function Hurt(g) -- (ตาย, โดนดาเมจ)
                local dead, hurt = 0, 0
                for _, e in ipairs(g) do
                    if not IsAlive(e.titan) then dead += 1 hurt += 1
                    elseif e.hum.Health < e.hp0 then hurt += 1 end
                end
                return dead, hurt
            end
            local function Swing(g, fire)
                post:FireServer("Attacks", "Slash", true)
                task.wait(0.35)
                fire(g)
                task.wait(0.55)
                post:FireServer("Attacks", "Slash", false)
                task.wait(2)
                return Hurt(g)
            end
            local function ByTitan(g)
                for _, e in ipairs(g) do
                    for _, part in ipairs(HitParts(e.titan)) do
                        if part.Parent then Farm.Reg(post, e, part) end
                    end
                    task.wait()
                end
            end
            local function ByPart(g)
                local lists, rounds = {}, 0
                for i, e in ipairs(g) do
                    lists[i] = HitParts(e.titan)
                    rounds = math.max(rounds, #lists[i])
                end
                for round = 1, rounds do
                    for i = 1, #g do
                        local part = lists[i][round]
                        if part and part.Parent then Farm.Reg(post, nil, part) end
                    end
                    task.wait(Farm.PartGap)
                end
            end

            local savedFirst = Farm.NapeFirst
            local aD, aH = Swing(groups[1], function(g) for _, e in ipairs(g) do Farm.Reg(post, e) task.wait() end end)
            Farm.NapeFirst = false
            local bD, bH = Swing(groups[2], ByTitan)
            local cD, cH = Swing(groups[3], ByPart)
            Farm.NapeFirst = true
            local dD, dH = Swing(groups[4], ByTitan)
            Farm.NapeFirst = savedFirst

            print(("[SmoothHub] ผลทดสอบ (วิธีละ %d ตัว)  A Nape อย่างเดียว: ตาย %d / โดน %d  |  B ทุกส่วน(Nape ท้าย): ตาย %d / โดน %d  |  C รอบละชิ้นส่วน: ตาย %d / โดน %d  |  D ทุกส่วน(Nape ก่อน): ตาย %d / โดน %d")
                :format(size, aD, aH, bD, bH, cD, cH, dD, dH))

            local best, bestScore = "B", bD * 10 + bH
            for _, r in ipairs({ { "C", cD * 10 + cH }, { "D", dD * 10 + dH } }) do
                if r[2] > bestScore then best, bestScore = r[1], r[2] end
            end
            if best == "C" then Farm.PartMode, Farm.NapeFirst = "ByPart", false
            elseif best == "D" then Farm.PartMode, Farm.NapeFirst = "ByTitan", true
            else Farm.PartMode, Farm.NapeFirst = "ByTitan", false end
            print("[SmoothHub] ตั้ง Farm.PartMode =", Farm.PartMode, "| Farm.NapeFirst =", Farm.NapeFirst)
            if aD * 10 + aH >= bestScore then
                print("[SmoothHub] Nape อย่างเดียวโดนไม่น้อยกว่าทุกส่วน -> ลองปิดสวิตช์ Hit All Parts ดู (ไม่ได้ปิดให้เอง)")
            end
        end)
    end

    ---------------------------------------------------------
    -- ⏱️ Safe Time: ด่านต้องไม่จบเร็วกว่าที่คนจริงทำได้
    -- นับจากตอนเห็นไททันตัวแรกของด่าน ก่อนครบเวลาที่ตั้งไว้จะ "เก็บไททันไว้ 1 ตัว" ไม่ฟัน
    -- (ด่านที่ต้องฆ่าไททันให้หมดจึงจบไม่ได้) ครบเวลาแล้วค่อยฟันตัวสุดท้าย
    -- หมายเหตุ: ถ้าเปิด Auto Farm กลางด่าน จะนับเวลาจากตอนที่เปิด
    ---------------------------------------------------------
    Farm.MatchStart = nil
    Farm.LastAliveAt = nil
    Farm.Reserve = nil
    local NEW_MATCH_GAP = 30 -- ไม่เห็นไททันเลยนานเท่านี้ = ด่านใหม่ นับเวลาใหม่

    function Farm.ApplySafeTime(list)
        local setStatus = Farm.SetSafeStatus or function() end
        local alive = {}
        local folder = TitansFolder()
        for _, t in ipairs(folder and folder:GetChildren() or {}) do
            if t:IsA("Model") and IsAlive(t) then alive[#alive + 1] = t end
        end
        local now = os.clock()
        if #alive > 0 then
            Farm.MatchStart = Farm.MatchStart or now
            Farm.LastAliveAt = now
        elseif Farm.LastAliveAt and now - Farm.LastAliveAt > NEW_MATCH_GAP then
            Farm.MatchStart, Farm.Reserve = nil, nil
        end

        local want = Cfg.SafeTime or 0
        if want <= 0 then
            Farm.Reserve = nil
            setStatus("Off")
            return list
        end
        if not Farm.MatchStart then
            Farm.Reserve = nil
            setStatus("Waiting for titans")
            return list
        end
        local elapsed = now - Farm.MatchStart
        if elapsed >= want then
            Farm.Reserve = nil
            setStatus(("Time reached (%ds) - finishing allowed"):format(want))
            return list
        end

        -- ยังไม่ครบเวลา: เก็บไททันไว้ 1 ตัวที่จะไม่ฟัน (เลือกตัวไกลสุด แล้วใช้ตัวเดิมต่อเนื่อง)
        if not (Farm.Reserve and IsAlive(Farm.Reserve)) then
            Farm.Reserve = nil
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local bestDist = -1
            for _, t in ipairs(alive) do
                local p = HeadTopPosition(t)
                local d = (p and root) and (p - root.Position).Magnitude or 0
                if d > bestDist then Farm.Reserve, bestDist = t, d end
            end
        end
        local out = {}
        for _, e in ipairs(list) do
            if e.titan ~= Farm.Reserve then out[#out + 1] = e end
        end
        setStatus(("Holding 1 titan: %ds / %ds"):format(math.floor(elapsed), want))
        return out
    end

    -- ───── ลูปโจมตี ─────
    -- ทุกครั้งที่ฟัน จะจดเลือดของไททันไว้ แล้วตรวจย้อนหลังหลังผ่านไป 0.9 วิ (รอให้เลือดอัปเดตมาถึงฝั่งเรา)
    -- โหมด Auto: ฟันไม่โดนสักตัว 4 รอบติด = ลดระดับ | โดนต่อเนื่อง 25 รอบ (และผ่าน 20 วิ) = ลองเพิ่มระดับ
    local counted = setmetatable({}, { __mode = "k" })
    local function Snapshot(list, level)
        local items = {}
        for _, e in ipairs(list) do
            local hum = e.titan:FindFirstChildOfClass("Humanoid")
            if hum then items[#items + 1] = { titan = e.titan, hum = hum, hp0 = hum.Health } end
        end
        return { t = os.clock(), level = level, items = items }
    end
    local function Judge(g) -- true = มีไททันโดนดาเมจหรือตายอย่างน้อย 1 ตัว
        local hit = false
        local S = Farm.HitStat
        for _, it in ipairs(g.items) do
            local alive = IsAlive(it.titan)
            local damaged = (not alive) or it.hum.Health < it.hp0
            S.tried += 1
            if damaged then
                S.hit += 1
                hit = true
                Farm.MissCount[it.titan] = 0
                if not alive and not counted[it.titan] then counted[it.titan] = true Farm.Kills += 1 end
            else
                Farm.MissCount[it.titan] = (Farm.MissCount[it.titan] or 0) + 1
            end
        end
        if S.tried > 300 then S.tried, S.hit = S.tried / 2, S.hit / 2 end -- ให้ตัวเลขสะท้อนช่วงหลัง ๆ
        return hit
    end

    task.spawn(function()
        local pending = {}
        local missStreak, hitStreak, lastChange = 0, 0, os.clock()
        local cycles, statsAt, statsCycles = 0, os.clock(), 0
        local lastReason = nil
        while Alive() do
          local okTick, errTick = pcall(function()
            -- Auto Reload กำลังรีโหลดอยู่: หยุดฟันชั่วคราว (ใบมีดหมดก็ฟันไม่โดนอยู่แล้ว)
            -- และทิ้งรอบที่ฟันค้างไว้ ไม่นับว่า "ฟันไม่โดน" จะได้ไม่โดนลดระดับความเร็วเองในโหมด Auto
            if os.clock() < (Farm.PauseUntil or 0) then
                pending = {}
                missStreak, hitStreak = 0, 0
                task.wait(0.05)
                return
            end
            local want = Cfg.AttackSpeed or 0
            if want >= 1 then Farm.Level = math.clamp(want, 1, #Farm.Presets) end
            local p = Farm.Presets[Farm.Level] or Farm.Presets[#Farm.Presets]
            local now = os.clock()

            -- ตรวจผลรอบก่อน ๆ
            local keep = {}
            for _, g in ipairs(pending) do
                if now - g.t >= 0.9 then
                    local hit = Judge(g)
                    if want == 0 and g.level == Farm.Level then -- นับเฉพาะรอบที่ฟันด้วยระดับปัจจุบัน
                        if hit then hitStreak += 1 missStreak = 0 else missStreak += 1 hitStreak = 0 end
                        if missStreak >= 4 and Farm.Level > 1 then
                            Farm.Level -= 1
                            missStreak, hitStreak, lastChange = 0, 0, now
                        elseif hitStreak >= 25 and Farm.Level < #Farm.Presets and now - lastChange > 20 then
                            Farm.Level += 1
                            missStreak, hitStreak, lastChange = 0, 0, now
                        end
                    end
                else
                    keep[#keep + 1] = g
                end
            end
            pending = keep

            local attacked = false
            if Cfg.AutoFarm and Farm.Attack and Farm.CanUseHere() then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local post = PostRemote()
                local list = (root and post) and CollectTargets(root, target) or {}
                local found = #list
                list = Farm.ApplySafeTime(list)
                if not post then lastReason = "POST remote not found"
                elseif not root then lastReason = "No character"
                elseif found == 0 then lastReason = "No hittable titan nearby"
                elseif #list == 0 then lastReason = "Holding last titan (Safe Time)"
                else lastReason = nil end
                if p.maxTargets and #list > p.maxTargets then
                    for i = #list, p.maxTargets + 1, -1 do list[i] = nil end
                end
                if #list > 0 then
                    attacked = true
                    pending[#pending + 1] = Snapshot(list, Farm.Level)
                    Farm.Slashing = true
                    local ok, err = pcall(Slash, post, list, p)
                    Farm.Slashing = false
                    if not ok then warn("[SmoothHub] Auto Farm attack:", err) end
                    cycles += 1
                    task.wait(p.gap)
                end
            elseif not Cfg.AutoFarm and Farm.SetSafeStatus then
                Farm.SetSafeStatus("Auto Farm is off")
            end
            if not attacked then task.wait(0.1) end

            -- สถิติบนหน้าจอ (อัปเดตวินาทีละครั้ง)
            now = os.clock()
            if now - statsAt >= 1 and Farm.SetStatsText then
                local perSec = (cycles - statsCycles) / (now - statsAt)
                statsAt, statsCycles = now, cycles
                if Cfg.AutoFarm and Farm.CanUseHere() then
                    local total, alive = 0, 0
                    local folder = TitansFolder()
                    for _, t in ipairs(folder and folder:GetChildren() or {}) do
                        if t:IsA("Model") then
                            total += 1
                            if IsAlive(t) and FindNape(t) then alive += 1 end
                        end
                    end
                    local preset = Farm.Presets[Farm.Level]
                    local S = Farm.HitStat
                    local pct = S.tried > 0 and math.floor(S.hit / S.tried * 100 + 0.5) or 0
                    Farm.SetStatsText(("%d/%d | %.1f/s | %s%s | K%d | hit %d%%%s"):format(
                        alive, total, perSec, preset and preset.name or "?", want == 0 and " (auto)" or "", Farm.Kills, pct,
                        lastReason and (" | " .. lastReason) or ""))
                else
                    Farm.SetStatsText(Cfg.AutoFarm and "Not in a mission" or "Off")
                end
            end
          end)
          if not okTick then
              warn("[SmoothHub] Auto Farm loop error:", errTick)
              task.wait(1)
          end
        end
    end)

    -- เปิดค้างไว้จากการเซฟ: เริ่มเองเมื่อสคริปต์โหลด
    if Cfg.AutoFarm then task.defer(Farm.OnAutoFarm, true) end
end
---------------------------------------------------------
-- 🔪 Auto Reload
-- วิธีรีโหลด: จำลองกดปุ่ม R (VirtualInputManager) ซ้ำจนใบมีดกลับมา และหยุดฟันของ Auto Farm ชั่วคราวระหว่างรีโหลด
-- • ไม่ทำงานในหน้าเมนู / ล็อบบี้ (นอกนั้นทำงานได้)
-- • ไม่ยิงรัว: ต้องเห็นจากหน้าจอ (HUD) ว่าใบมีดหมดจริงและหมดต่อเนื่องสักครู่ถึงจะยิง
--   มีคูลดาวน์ และหลังยิงจะเช็คซ้ำว่าใบมีดกลับมาจริงไหม ถ้าไม่กลับจะรอนานขึ้นเรื่อย ๆ (กันเปลืองชุดใบมีด)
-- • "3 / 3" ที่ HUD = จำนวนชุดใบมีดที่เปลี่ยนได้ ถ้าอ่านเจอว่าเหลือ 0 จะไม่ยิง
-- • การอ่านว่า "ใบมีดหมดไหม" อยู่ที่ Farm.IsBladeDepleted() (คืน true / false / nil)
--   อ่านจาก HUD จริงของเกม (Blades.Bar.Gradient.Offset) ถ้าอ่านไม่ได้จะไม่ยิงเลย
--   และเซฟรายงาน HUD ให้ 1 ครั้ง (ไฟล์ SmoothHub_hud_<ชื่อ>.txt + คลิปบอร์ด)
--   เรียกเองได้จาก executor: _G.SmoothHubFarm.DumpHud("ชื่อ") / _G.SmoothHubFarm.ReadBladeFraction()
---------------------------------------------------------
do
    local LOBBY_PLACE_ID = 14916516914
    local CHECK_INTERVAL = 0.25 -- เช็คหน้าจอทุกกี่วินาที
    local CONFIRM_TIME = 0.5    -- ต้องหมดต่อเนื่องกี่วินาทีถึงจะยิง (กันอ่านพลาดช่วงแอนิเมชัน)
    local BASE_COOLDOWN = 3     -- คูลดาวน์ขั้นต่ำหลังยิงแต่ละครั้ง
    local MAX_COOLDOWN = 30     -- ถ้ายิงแล้วใบมีดไม่กลับ คูลดาวน์จะเพิ่มเท่าตัวจนถึงค่านี้
    local VERIFY_WAIT = 2.0     -- รอหลังยิงก่อนเช็คว่าใบมีดกลับมาหรือยัง (เผื่อแอนิเมชัน Reload)
    local CALL_TIMEOUT = 8
    local EMPTY_FRACTION = 0.02 -- แถบเหลือไม่เกินเท่านี้ = ถือว่าหมด

    Farm.Debug = false -- true = พิมพ์ผลการยิงทุกครั้งใน console

    function Farm.CanUseHere()
        return not IN_MENU and game.PlaceId ~= LOBBY_PLACE_ID
    end

    local function Interface()
        return PlayerGui:FindFirstChild("Interface") or PlayerGui
    end

    local function RelPath(obj)
        local names, cur = {}, obj
        while cur and cur ~= PlayerGui and cur ~= game do
            table.insert(names, 1, cur.Name)
            cur = cur.Parent
        end
        return table.concat(names, ".")
    end

    local function IsShown(obj)
        local cur = obj
        while cur and cur ~= PlayerGui do
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            if cur:IsA("ScreenGui") and not cur.Enabled then return false end
            cur = cur.Parent
        end
        return true
    end

    -- ───── ตัวเลข "3 / 3" (จำนวนชุดใบมีดที่เหลือ / ทั้งหมด) ─────
    local setsLabel, setsSearchAt = nil, 0
    local function FindSetsLabel()
        if setsLabel and setsLabel.Parent then return setsLabel end
        setsLabel = nil
        if os.clock() - setsSearchAt < 3 then return nil end -- ค้นหน้าจอไม่ถี่เกินไป
        setsSearchAt = os.clock()
        local best, bestScore = nil, -1
        for _, d in ipairs(Interface():GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:match("^%s*%d+%s*/%s*%d+%s*$") then
                local path = RelPath(d):lower()
                local score = 0
                if path:find("blade") then score += 2 end
                if path:find("hud") then score += 1 end
                if IsShown(d) then score += 1 end
                if score > bestScore then best, bestScore = d, score end
            end
        end
        setsLabel = best
        return setsLabel
    end

    local function ReadSets()
        local label = FindSetsLabel()
        local cur = label and label.Text:match("^%s*(%d+)%s*/%s*%d+%s*$")
        return cur and tonumber(cur) or nil
    end
    Farm.ReadSets = ReadSets -- ใช้ร่วมกับ Auto Refills

    -- ───── แถบความทนของใบมีด (ได้ชื่อจริงจากรายงาน HUD ของเกม) ─────
    -- Interface.HUD.Main.Top.7.Blades.Bar.Gradient  (UIGradient ใต้ CanvasGroup "Bar")
    -- แถบถูกตัดด้วย Gradient.Offset.X: ใบมีดเต็ม = 1.00 | ใบมีดหมด = -0.15 (ค่าที่วัดได้จริง 2 สถานะ)
    local EMPTY_OFFSET, FULL_OFFSET = -0.15, 1.0
    local gradObj, gradSearchAt = nil, 0
    local function FindBladeGradient()
        if gradObj and gradObj.Parent then return gradObj end
        gradObj = nil
        local label = FindSetsLabel() -- Blades.Sets ("1 / 3") -> พ่อของมันคือกรอบ Blades
        local blades = label and label.Parent
        if not blades then return nil end
        if os.clock() - gradSearchAt < 3 then return nil end
        gradSearchAt = os.clock()
        local bar = blades:FindFirstChild("Bar", true)
        gradObj = bar and bar:FindFirstChildWhichIsA("UIGradient")
        return gradObj
    end

    -- 0 = ใบมีดหมด ... 1 = เต็ม (nil = อ่านไม่ได้ / HUD ใบมีดไม่ได้แสดงอยู่ เช่น กำลังถือ Thunder Spears)
    function Farm.ReadBladeFraction()
        local grad = FindBladeGradient()
        if not grad or not IsShown(grad) then return nil end
        local x = grad.Offset.X
        return math.clamp((x - EMPTY_OFFSET) / (FULL_OFFSET - EMPTY_OFFSET), 0, 1)
    end

    -- คืน true = ใบมีดหมดจริง | false = ยังมีอยู่ | nil = อ่านหน้าจอไม่ได้ (จะไม่ยิง)
    function Farm.IsBladeDepleted()
        local fraction = Farm.ReadBladeFraction()
        if fraction == nil then return nil end
        return fraction <= EMPTY_FRACTION
    end

    -- ───── รายงาน HUD (ไว้ส่งให้เขียนตัวตรวจจับให้ตรงเกม) ─────
    local function DumpHud(reason)
        local lines = { ("=== SmoothHub HUD report | %s | PlaceId %s"):format(tostring(reason), tostring(game.PlaceId)) }
        local function walk(d, depth, maxDepth)
            local info = {}
            if d:IsA("GuiObject") then
                info[#info + 1] = "vis=" .. tostring(d.Visible)
                info[#info + 1] = ("size=%.2f,%d|%.2f,%d"):format(d.Size.X.Scale, d.Size.X.Offset, d.Size.Y.Scale, d.Size.Y.Offset)
                info[#info + 1] = ("abs=%.0fx%.0f"):format(d.AbsoluteSize.X, d.AbsoluteSize.Y)
                info[#info + 1] = ("bg=%.0f,%.0f,%.0f/t%.2f"):format(d.BackgroundColor3.R * 255, d.BackgroundColor3.G * 255, d.BackgroundColor3.B * 255, d.BackgroundTransparency)
            end
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                info[#info + 1] = ("img=%s col=%.0f,%.0f,%.0f/t%.2f"):format(tostring(d.Image), d.ImageColor3.R * 255, d.ImageColor3.G * 255, d.ImageColor3.B * 255, d.ImageTransparency)
            end
            if d:IsA("UIGradient") then
                info[#info + 1] = ("offset=%.2f,%.2f"):format(d.Offset.X, d.Offset.Y)
            end
            if d:IsA("TextLabel") or d:IsA("TextButton") then info[#info + 1] = 'text="' .. d.Text .. '"' end
            lines[#lines + 1] = string.rep("  ", depth) .. d.Name .. " [" .. d.ClassName .. "] " .. table.concat(info, " ")
            if depth >= maxDepth then return end
            for _, child in ipairs(d:GetChildren()) do walk(child, depth + 1, maxDepth) end
        end
        setsSearchAt = 0
        local label = FindSetsLabel()
        if label then
            lines[#lines + 1] = "sets label: " .. RelPath(label) .. ' text="' .. label.Text .. '"'
            local root = label
            for _ = 1, 4 do
                if root.Parent and root.Parent ~= PlayerGui then root = root.Parent end
            end
            lines[#lines + 1] = "--- tree from: " .. RelPath(root)
            walk(root, 0, 6)
        else
            lines[#lines + 1] = "sets label: NOT FOUND (no text like '3 / 3')"
        end
        lines[#lines + 1] = "--- names containing blade/durab/reload/sword/steel"
        for _, d in ipairs(Interface():GetDescendants()) do
            local n = d.Name:lower()
            if n:find("blade") or n:find("durab") or n:find("reload") or n:find("sword") or n:find("steel") then
                lines[#lines + 1] = RelPath(d) .. " [" .. d.ClassName .. "]"
            end
        end
        local text = table.concat(lines, "\n")
        if #text > 40000 then text = text:sub(1, 40000) .. "\n...(truncated)" end
        local fileName = "SmoothHub_hud_" .. tostring(reason):gsub("[^%w]", "_") .. ".txt"
        local saved = type(writefile) == "function" and pcall(writefile, fileName, text)
        local copied = false
        if type(setclipboard) == "function" then copied = pcall(setclipboard, text)
        elseif type(toclipboard) == "function" then copied = pcall(toclipboard, text) end
        warn(("[SmoothHub] HUD report (%s) -> ไฟล์:%s คลิปบอร์ด:%s"):format(
            tostring(reason), saved and fileName or "x", copied and "ok" or "x"))
    end
    Farm.DumpHud = DumpHud -- เรียกเองได้: Farm.DumpHud("manual")

    -- ───── รีโหลด: กดปุ่ม R จำลอง ซ้ำจนใบมีดกลับมา ─────
    -- (เดิมใช้ GET:InvokeServer("Blades","Reload") แต่เกมไม่ยอมรับ ทดสอบแล้วกด R ได้ผลจริง)
    -- ลำดับ: หยุดฟัน -> รอท่าฟันรอบล่าสุดจบ -> กด R -> รอดูผลสูงสุด TRY_WAIT วิ -> ยังหมดอยู่ก็กดซ้ำ
    local MAX_TRIES = 6   -- กด R ได้สูงสุดกี่ครั้งต่อการรีโหลด 1 รอบ
    local TRY_WAIT = 1.2  -- หลังกด R รอดูผลกี่วินาที (เช็คทุก 0.1 วิ) ก่อนกดซ้ำ
    -- เมนู Roblox (กด ESC) เปิดอยู่ หรือกำลังพิมพ์ในช่องแชท/ช่องข้อความ = ห้ามกด R
    -- (ในเมนู Roblox ปุ่ม R = Respawn ถ้ากดไปจะรีเซ็ตตัวละคร และเกมก็ไม่รับ R รีโหลดอยู่ดี)
    local UserInputService = game:GetService("UserInputService")
    local function InputBlocked()
        local okMenu, menuOpen = pcall(function() return GuiService.MenuIsOpen end)
        if okMenu and menuOpen then return true end
        local okBox, box = pcall(function() return UserInputService:GetFocusedTextBox() end)
        return okBox and box ~= nil
    end

    local function PressR()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
    end

    -- คืน true = ใบมีดกลับมาแล้ว | false = ไม่สำเร็จ (พร้อมข้อความบอกจำนวนครั้งที่กด)
    local function InvokeReload()
        -- 1) หยุดฟัน (ตั้งเวลาหมดอายุเองไว้ กันค้างถ้าเธรดนี้พัง) แล้วรอท่าฟันรอบล่าสุดจบ
        Farm.PauseUntil = os.clock() + 15
        local t0 = os.clock()
        while Farm.Slashing and os.clock() - t0 < 2 do task.wait(0.05) end
        task.wait(0.2) -- ให้เซิร์ฟเวอร์รับ "Slash false" ก่อน

        -- 2) กด R จนกว่าใบมีดจะกลับมา (เช็คก่อนกดทุกครั้ง จะได้ไม่กดตอนใบมีดยังไม่หมด)
        local tries, restored, blocked = 0, false, false
        while tries < MAX_TRIES and Cfg.AutoReload and Alive() do
            local okRead, depleted = pcall(Farm.IsBladeDepleted)
            if not okRead or depleted == nil then break end -- อ่านหน้าจอไม่ได้ = ไม่กด
            if InputBlocked() then blocked = true break end  -- เมนู/ช่องพิมพ์เปิดอยู่ = หยุด ไม่กด R
            if depleted == false then restored = true break end
            local sets = ReadSets()
            if sets ~= nil and sets <= 0 then break end     -- ไม่มีชุดสำรองให้เปลี่ยนแล้ว
            tries += 1
            pcall(PressR)
            local t1 = os.clock()
            while os.clock() - t1 < TRY_WAIT do
                task.wait(0.1)
                local ok2, d2 = pcall(Farm.IsBladeDepleted)
                if ok2 and d2 == false then restored = true break end
            end
            if restored then break end
        end

        -- 3) ฟันต่อ
        Farm.PauseUntil = 0
        return restored, blocked and "blocked" or ("tries=%d"):format(tries)
    end

    local lowSince = nil     -- เวลาที่เริ่มเห็นว่าใบมีดหมด
    local cooldown = BASE_COOLDOWN
    local nextAllowedAt = 0
    local reloading = false
    local reported = false   -- ส่งรายงาน HUD ไปแล้วหรือยัง (ต่อการเปิดสวิตช์ 1 ครั้ง)

    function Farm.OnAutoReload(on)
        Farm.PauseUntil = 0
        lowSince = nil
        cooldown = BASE_COOLDOWN
        nextAllowedAt = 0
        reported = false
        if on and not Farm.CanUseHere() then
            warn("[SmoothHub] Auto Reload: ไม่ทำงานในหน้าเมนู/ล็อบบี้ (จะเริ่มทำงานเมื่ออยู่ในด่าน)")
        end
    end

    task.spawn(function()
        while Alive() do
            task.wait(CHECK_INTERVAL)
            if not (Cfg.AutoReload and Farm.CanUseHere()) or reloading or InputBlocked() then
                lowSince = nil
            else
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local okRead, depleted = pcall(Farm.IsBladeDepleted)
                    if not okRead then depleted = nil end
                    if depleted == nil then
                        lowSince = nil
                        if not reported then
                            reported = true
                            pcall(DumpHud, "auto")
                        end
                    elseif depleted then
                        lowSince = lowSince or os.clock()
                        local sets = ReadSets()
                        local noSetsLeft = sets ~= nil and sets <= 0
                        if os.clock() - lowSince >= CONFIRM_TIME and os.clock() >= nextAllowedAt and not noSetsLeft then
                            reloading = true
                            task.spawn(function()
                                local okCall, ok, result = pcall(InvokeReload)
                                if not okCall then ok, result = false, ok Farm.PauseUntil = 0 end
                                if Farm.Debug then print("[SmoothHub] Auto Reload:", ok, result) end
                                task.wait(0.3) -- InvokeReload เช็คผลเองแล้ว รอแค่ให้ HUD นิ่ง
                                local okRead2, still = pcall(Farm.IsBladeDepleted)
                                if okRead2 and still and result ~= "blocked" then
                                    -- ยิงแล้วใบมีดยังหมดอยู่ = ไม่สำเร็จ / เกมไม่ยอม -> รอนานขึ้นเรื่อย ๆ
                                    cooldown = math.min(cooldown * 2, MAX_COOLDOWN)
                                    warn(("[SmoothHub] Auto Reload: ยิงแล้วใบมีดยังไม่กลับ (ผล=%s) รอ %ds ก่อนลองใหม่"):format(tostring(result), cooldown))
                                end
                                nextAllowedAt = os.clock() + cooldown
                                lowSince = nil
                                reloading = false
                            end)
                        end
                    else
                        lowSince = nil
                        cooldown = BASE_COOLDOWN -- ใบมีดปกติ = รอบก่อนสำเร็จ รีเซ็ตคูลดาวน์
                    end
                else
                    lowSince = nil
                end
            end
        end
    end)
end

---------------------------------------------------------
-- 🔧 Auto Refills
-- Remote (จาก Remote Spy): ReplicatedStorage.Assets.Remotes.POST:FireServer("Attacks", "Reload", <Refill ของด่าน>)
--   ตำแหน่ง Refill ของแต่ละด่านอยู่ในตาราง REFILL_BY_PLACE (จากไฟล์ที่ส่งมา ครบ 8 ด่าน)
-- เหมือน Auto Reload: อ่านจากหน้าจอ (HUD) ว่า "หมดจริง" ถึงจะยิง
--  • ถือดาบ : แถบความทนหมด และชุดสำรองเหลือ 0 (เช่น 0 / 6) จึงรีโหลดต่อไม่ได้แล้ว ถึงจะ Refill
--  • ถือหอก : ตัวเลขหอกบน HUD เหลือ 0
--  • ต้องหมดต่อเนื่อง 1.5 วินาที + มีคูลดาวน์ ยิงแล้วเช็คว่ากลับมาจริงไหม ไม่กลับก็รอนานขึ้นเรื่อย ๆ (สูงสุด 60 วินาที)
-- ไม่ใช้ได้ในหน้าเมนู / ล็อบบี้
---------------------------------------------------------
do
    local CHECK_INTERVAL = 0.5
    local CONFIRM_TIME = 1.5
    local BASE_COOLDOWN = 8
    local MAX_COOLDOWN = 60
    local VERIFY_WAIT = 2.5

    -- path = ทางไปยังโฟลเดอร์ใน workspace | index = ลำดับลูกที่ Remote Spy จับได้ (GetChildren()[index].Refill)
    local REFILL_BY_PLACE = {
        [13379349730]     = { name = "Shiganshina", path = { "Unclimbable", "Props", "HQ" }, index = 268 },
        [14012874501]     = { name = "Trost",       path = { "Unclimbable", "Props", "HQ" }, index = 285 },
        [13904207646]     = { name = "Outskirts",   path = { "Climbable", "_Walls", "Gate" }, index = 48 },
        [14638336319]     = { name = "Forest",      path = { "Unclimbable", "Camps", "Camp" }, index = 37 },
        [15220308770]     = { name = "Utgard",      path = { "Climbable", "Utgard" }, index = 45 },
        [17688739434]     = { name = "Docks",       path = { "Unclimbable", "World", "Buildings", "Hanger" }, index = 19 },
        [15824912319]     = { name = "Stohess",     path = { "Unclimbable", "Props", "HQ" }, index = 342 },
        [126678335159530] = { name = "Chapel",      path = { "Unclimbable", "Reloads" }, index = 2 },
    }

    local function IsShownGui(obj)
        local cur = obj
        while cur and cur ~= PlayerGui do
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            if cur:IsA("ScreenGui") and not cur.Enabled then return false end
            cur = cur.Parent
        end
        return true
    end

    local function PosOf(o)
        if o:IsA("BasePart") then return o.Position end
        if o:IsA("Model") then
            local ok, p = pcall(function() return o:GetPivot().Position end)
            return ok and p or nil
        end
        local part = o:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end

    -- Refill ที่ใกล้ตัวที่สุดใต้ root (ใช้เมื่อลำดับลูกไม่ตรงกับตอนจับ หรือเจอด่านที่ไม่รู้จัก)
    local function NearestRefill(root)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local best, bestDist = nil, math.huge
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            n += 1
            if n % 1500 == 0 then task.wait() end
            if d.Name == "Refill" then
                local pos = PosOf(d)
                local dist = (pos and hrp) and (pos - hrp.Position).Magnitude or math.huge
                if not best or dist < bestDist then best, bestDist = d, dist end
            end
        end
        return best
    end

    local refillCache = nil
    local function ResolveRefill()
        if refillCache and refillCache.Parent then return refillCache end
        refillCache = nil
        local info = REFILL_BY_PLACE[game.PlaceId]
        if info then
            local container = workspace
            for _, seg in ipairs(info.path) do
                container = container and container:FindFirstChild(seg)
            end
            if container then
                local child = container:GetChildren()[info.index]
                local refill = child and child:FindFirstChild("Refill")
                if refill then
                    refillCache = refill -- ตรงกับที่ Remote Spy จับได้ จำไว้ใช้ซ้ำ
                    return refill
                end
                if Farm.Debug then print("[SmoothHub] Auto Refills: ลำดับลูกไม่ตรง ใช้ Refill ที่ใกล้ที่สุดแทน") end
                return NearestRefill(container) -- ไม่จำ (ขึ้นกับตำแหน่งผู้เล่น)
            end
        end
        return NearestRefill(workspace)
    end

    local postRemote = nil
    local function FireRefill(target)
        if not postRemote or not postRemote.Parent then
            local ok, r = pcall(function()
                return game:GetService("ReplicatedStorage").Assets.Remotes:WaitForChild("POST", 5)
            end)
            postRemote = ok and r or nil
        end
        if not postRemote then return false, "remote not found" end
        return pcall(function() postRemote:FireServer("Attacks", "Reload", target) end)
    end

    -- ตัวเลขหอกบน HUD (ถ้าเกมมีแสดง เช่น "2 / 2" ใต้ชื่อ Spear / Thunder)
    local spearLabel, spearScanAt = nil, 0
    local function ReadSpears()
        if spearLabel and spearLabel.Parent then
            if not IsShownGui(spearLabel) then return nil end
            local cur = spearLabel.Text:match("^%s*(%d+)%s*/%s*%d+%s*$")
            return cur and tonumber(cur) or nil
        end
        spearLabel = nil
        if os.clock() - spearScanAt < 5 then return nil end
        spearScanAt = os.clock()
        local root = PlayerGui:FindFirstChild("Interface") or PlayerGui
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:match("^%s*%d+%s*/%s*%d+%s*$") then
                local names, cur = {}, d
                while cur and cur ~= PlayerGui do
                    names[#names + 1] = cur.Name:lower()
                    cur = cur.Parent
                end
                local path = table.concat(names, ".")
                if path:find("spear", 1, true) or path:find("thunder", 1, true) then
                    spearLabel = d
                    break
                end
            end
        end
        return nil
    end

    local lowSince, cooldown, nextAllowedAt, busy = nil, BASE_COOLDOWN, 0, false
    local warnedSpear = false

    function Farm.OnAutoRefills(on)
        lowSince, cooldown, nextAllowedAt = nil, BASE_COOLDOWN, 0
        warnedSpear = false
        if on and not Farm.CanUseHere() then
            warn("[SmoothHub] Auto Refills: ไม่ทำงานในหน้าเมนู/ล็อบบี้ (จะเริ่มทำงานเมื่ออยู่ในด่าน)")
        end
    end

    -- คืนข้อความว่าอะไรหมด (nil = ยังไม่หมด / อ่านไม่ได้ จะไม่ยิง)
    local function WhatIsEmpty()
        local okB, depleted = pcall(Farm.IsBladeDepleted)
        if okB and depleted ~= nil then
            -- HUD ดาบแสดงอยู่ = กำลังถือดาบ: หมดจริงต้องแถบหมด + ชุดสำรอง 0
            local sets = Farm.ReadSets and Farm.ReadSets() or nil
            if depleted and sets ~= nil and sets <= 0 then return "blades" end
            return nil
        end
        -- HUD ดาบไม่แสดง = น่าจะถือหอก
        local spears = ReadSpears()
        if spears ~= nil and spears <= 0 then return "thunder spears" end
        if spears == nil and not spearLabel and Cfg.AutoRefills and not warnedSpear and os.clock() - spearScanAt > 4 then
            warnedSpear = true
            warn("[SmoothHub] Auto Refills: อ่านจำนวน Thunder Spears จาก HUD ไม่ได้ (ยังไม่เจอตัวเลขที่มีคำว่า spear/thunder) " ..
                "ตอนถือหอกให้รัน _G.SmoothHubFarm.DumpHud(\"spears\") แล้วส่งรายงานมา จะได้ทำตัวอ่านหอกให้ตรงเกม")
        end
        return nil
    end

    -- เช็คว่ายิงแล้วของกลับมาจริงไหม
    local function IsRestored(kind)
        if kind == "blades" then
            local ok, depleted = pcall(Farm.IsBladeDepleted)
            local sets = Farm.ReadSets and Farm.ReadSets() or nil
            return ok and depleted == false or (sets ~= nil and sets > 0)
        end
        local spears = ReadSpears()
        return spears ~= nil and spears > 0
    end

    local function Status(text)
        if Farm.SetRefillStatus then Farm.SetRefillStatus(text) end
    end

    -- ข้อความบอกค่าที่อ่านได้จาก HUD ตอนนี้
    local function Describe()
        local fraction = Farm.ReadBladeFraction and Farm.ReadBladeFraction() or nil
        if fraction ~= nil then
            local sets = Farm.ReadSets and Farm.ReadSets() or nil
            return ("Blades: bar %d%% | sets %s"):format(math.floor(fraction * 100 + 0.5), sets ~= nil and tostring(sets) or "?")
        end
        local spears = ReadSpears()
        if spears ~= nil then return "Spears: " .. tostring(spears) end
        return "HUD not readable (blades hidden / spear counter not found)"
    end

    -- ───── ไว้ทดสอบจาก executor ─────
    -- _G.SmoothHubFarm.RefillDebug() = พิมพ์ค่าที่อ่านได้ + Refill ที่หาเจอ (ไม่ยิง)
    -- _G.SmoothHubFarm.RefillNow()   = ยิง Refill ทันที 1 ครั้ง (ไม่สนว่าหมดหรือยัง) แล้วพิมพ์ผล
    function Farm.RefillDebug()
        local okB, depleted = pcall(Farm.IsBladeDepleted)
        local target = ResolveRefill()
        print("[SmoothHub] Refill debug | place:", game.PlaceId,
            "| blade depleted:", okB and tostring(depleted) or "error",
            "| sets:", tostring(Farm.ReadSets and Farm.ReadSets()),
            "| spears:", tostring(ReadSpears()),
            "| target:", target and target:GetFullName() or "NOT FOUND")
        return target
    end

    function Farm.RefillNow()
        local target = ResolveRefill()
        if not target then
            warn("[SmoothHub] RefillNow: หา Refill ไม่เจอ (PlaceId " .. tostring(game.PlaceId) .. ")")
            return false
        end
        local ok, err = FireRefill(target)
        print("[SmoothHub] RefillNow ->", target:GetFullName(), ok, err)
        return ok
    end

    task.spawn(function()
        while Alive() do
            task.wait(CHECK_INTERVAL)
            if not Cfg.AutoRefills then
                lowSince = nil
                Status("Off")
            elseif not Farm.CanUseHere() then
                lowSince = nil
                Status("Not available in the lobby / menu")
            elseif busy then
                -- กำลังยิง/ตรวจผลอยู่ (สถานะถูกตั้งโดยเธรดนั้น)
            else
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not (hum and hum.Health > 0) then
                    lowSince = nil
                    Status("Waiting for your character")
                else
                    local kind = WhatIsEmpty()
                    if not kind then
                        lowSince = nil
                        Status(Describe())
                    elseif os.clock() < nextAllowedAt then
                        Status(("%s empty - next try in %ds"):format(kind, math.ceil(nextAllowedAt - os.clock())))
                    else
                        lowSince = lowSince or os.clock()
                        if os.clock() - lowSince < CONFIRM_TIME then
                            Status(kind .. " empty - confirming...")
                        else
                            busy = true
                            task.spawn(function()
                                local target = ResolveRefill()
                                if not target then
                                    Status("Refill station not found on this map")
                                    warn("[SmoothHub] Auto Refills: หา Refill ของด่านนี้ไม่เจอ (PlaceId " .. tostring(game.PlaceId) .. ")")
                                    cooldown = math.min(cooldown * 2, MAX_COOLDOWN)
                                else
                                    Status("Refilling " .. kind .. "...")
                                    local ok, err = FireRefill(target)
                                    if Farm.Debug then print("[SmoothHub] Auto Refills:", kind, ok, err, target:GetFullName()) end
                                    task.wait(VERIFY_WAIT)
                                    if IsRestored(kind) then
                                        cooldown = BASE_COOLDOWN
                                        Status("Refilled " .. kind)
                                    else
                                        -- ยิงแล้วไม่กลับ = เซิร์ฟเวอร์ไม่ยอม (เช่นอยู่ไกลจากจุด Refill) -> รอนานขึ้นเรื่อย ๆ
                                        cooldown = math.min(cooldown * 2, MAX_COOLDOWN)
                                        Status(("Refill sent but %s not restored (try again in %ds)"):format(kind, cooldown))
                                        warn(("[SmoothHub] Auto Refills: ยิงแล้ว %s ยังไม่กลับ (อาจต้องอยู่ใกล้จุด Refill) รอ %ds ก่อนลองใหม่ | target: %s")
                                            :format(kind, cooldown, target:GetFullName()))
                                    end
                                end
                                nextAllowedAt = os.clock() + cooldown
                                lowSince = nil
                                busy = false
                            end)
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------
-- 🔁 Auto Retry / 🚪 Auto Leave   (ทำงานบนหน้า MISSION COMPLETED)
-- Remote (จาก Remote Spy):
--   Retry : ReplicatedStorage.Assets.Remotes.GET:InvokeServer("Functions", "Retry", "Add")   = โหวต RETRY
--   Leave : ReplicatedStorage.Assets.Remotes.POST:FireServer("Functions", "Teleport")        = กลับล็อบบี้
-- ออกแบบให้ยิง Remote น้อยที่สุด:
--  • ระหว่างเล่นไม่ยิงอะไรเลย แค่อ่านหน้าจอในเครื่อง
--  • ยิงเมื่อ "เห็นหน้า MISSION COMPLETED ค้างอยู่" และเห็นปุ่มที่ต้องกดจริง (RETRY / LEAVE) เท่านั้น
--  • รอบละ 1 ครั้งต่อหนึ่งหน้า ถ้าหน้ายังค้างหลังรอ ค่อยลองซ้ำได้อีก 1 ครั้งแล้วหยุด
-- ลำดับความสำคัญเมื่อด่านจบ:
--  1) Auto Leave เปิด            -> ออกทันที (ไม่ Retry)
--  2) Auto Retry เปิด            -> Retry ต่อเรื่อยๆ ไม่จำกัดจำนวน
--     ถ้าเปิด Auto Leave After X Matches ด้วย -> Retry จนครบ Retry Amount แล้วออกไปล็อบบี้
--  Auto Leave กับ Auto Leave After X Matches เปิดพร้อมกันไม่ได้ (เปิดอันหนึ่ง อีกอันจะปิดเอง)
---------------------------------------------------------
do
    local LOBBY_PLACE_ID = 14916516914
    local CHECK_INTERVAL = 1.0     -- เช็คหน้าจอทุกกี่วินาที (ไม่มี Remote)
    local SCAN_INTERVAL = 2.0      -- ถ้ายังไม่รู้ว่าป้ายอยู่ตรงไหน ค้นหน้าจอใหม่ไม่ถี่กว่านี้
    local CONFIRM_TIME = 1.5       -- หน้า MISSION COMPLETED ต้องค้างโชว์ต่อเนื่องก่อนยิง (ให้ปุ่มพร้อม)
    local GONE_TIME = 3.0          -- หน้าหายไปนานเท่านี้ = ด่านใหม่เริ่มแล้ว รีเซ็ตสถานะของหน้า
    local MAX_RETRY_TRIES = 2      -- Retry สูงสุดกี่ครั้งต่อหนึ่งหน้า
    local RETRY_GAP = 10           -- ยิง Retry แล้วหน้ายังค้าง รอเท่านี้ก่อนลองซ้ำ
    local MAX_LEAVE_TRIES = 2      -- Leave สูงสุดกี่ครั้งต่อหนึ่งหน้า
    local LEAVE_GAP = 12           -- ยิง Leave แล้วหน้ายังค้าง รอเท่านี้ก่อนลองซ้ำ (เผื่อเทเลพอร์ตช้า)
    local CALL_TIMEOUT = 8

    local function Status(text)
        if Farm.SetRetryStatus then Farm.SetRetryStatus(text) end
    end

    local function CanUseHere()
        return not IN_MENU and game.PlaceId ~= LOBBY_PLACE_ID
    end

    local function CleanText(o)
        local t = (o.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        return t
    end

    local function IsShownGui(obj)
        local cur = obj
        while cur and cur ~= PlayerGui do
            if cur:IsA("GuiObject") and not cur.Visible then return false end
            if cur:IsA("ScreenGui") and not cur.Enabled then return false end
            cur = cur.Parent
        end
        return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
    end

    -- หาป้าย "MISSION COMPLETED" (จำตำแหน่งไว้ ไม่ต้องค้นทั้งหน้าจอทุกวินาที)
    local titleLabel, scanAt = nil, 0
    local function FindCompleteTitle()
        if titleLabel and titleLabel.Parent then
            return IsShownGui(titleLabel) and titleLabel or nil
        end
        titleLabel = nil
        if os.clock() - scanAt < SCAN_INTERVAL then return nil end
        scanAt = os.clock()
        local n = 0
        for _, d in ipairs(PlayerGui:GetDescendants()) do
            n += 1
            if n % 800 == 0 then task.wait() end
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and CleanText(d):upper() == "MISSION COMPLETED" then
                titleLabel = d
                return IsShownGui(d) and d or nil
            end
        end
        return nil
    end

    -- หาข้อความปุ่มในหน้าเดียวกับป้าย (ไต่ขึ้นไปหากรอบที่มีข้อความขึ้นต้นตาม pattern เช่น "^RETRY" / "^LEAVE")
    local function FindButtonText(title, pattern)
        local cur = title.Parent
        for _ = 1, 8 do
            if not cur or cur == PlayerGui then break end
            for _, d in ipairs(cur:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and CleanText(d):upper():match(pattern) and IsShownGui(d) then
                    return d
                end
            end
            cur = cur.Parent
        end
        return nil
    end

    local getRemote = nil
    local function FireRetry()
        if not getRemote or not getRemote.Parent then getRemote = GetLobbyRemote() end
        if not getRemote then return false, "remote not found" end
        local rem = getRemote
        local done, ok, res = false, false, nil
        task.spawn(function()
            ok, res = pcall(function() return rem:InvokeServer("Functions", "Retry", "Add") end)
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < CALL_TIMEOUT do task.wait(0.1) end
        if not done then return false, "timeout" end
        return ok, res
    end

    -- Leave ใช้ RemoteEvent (POST) ยิงแล้วไม่รอคำตอบ
    local postRemote = nil
    local function FireLeave()
        if not postRemote or not postRemote.Parent then
            local ok, r = pcall(function()
                return game:GetService("ReplicatedStorage").Assets.Remotes:WaitForChild("POST", 5)
            end)
            postRemote = ok and r or nil
        end
        if not postRemote then return false, "remote not found" end
        return pcall(function() postRemote:FireServer("Functions", "Teleport") end)
    end

    function Farm.RefreshRetry()
        if Farm.SetRetry then Farm.SetRetry(Cfg.RetryDone) end
    end

    function Farm.ResetRetry()
        Cfg.RetryDone = 0
        Save()
        Farm.RefreshRetry()
    end

    -- ปิดสวิตช์ Auto Retry = จบรอบ รีเซ็ตตัวนับ (ตอนเริ่มสคริปต์ที่เซฟไว้เป็นปิดอยู่แล้วไม่กระทบค่าเดิม)
    function Farm.OnAutoRetry(on)
        if not on and Cfg.RetryDone ~= 0 then Farm.ResetRetry() end
    end

    -- Auto Leave กับ Auto Leave After X Matches เปิดพร้อมกันไม่ได้: เปิดอันไหน อีกอันถูกปิดให้เอง
    local function TurnOffOther(key)
        if Cfg[key] then
            Cfg[key] = false
            Save()
            local ctl = Farm.Toggles and Farm.Toggles[key]
            if ctl then pcall(function() ctl.Value = false end) end
        end
    end
    function Farm.OnAutoLeave(on)
        if on then TurnOffOther("AutoLeaveWhenRetryComplete") end
    end
    function Farm.OnAutoLeaveWhenRetryComplete(on)
        if on then TurnOffOther("AutoLeave") end
    end

    -- อยู่ล็อบบี้/เมนู = จบสาย Retry แล้ว
    if not CanUseHere() and Cfg.RetryDone ~= 0 then
        Cfg.RetryDone = 0
        Save()
    end
    Farm.RefreshRetry()

    task.spawn(function()
        local seenSince, goneSince = nil, nil
        local tries, lastTry, counted = 0, 0, false
        local leaveTries, lastLeave = 0, 0
        local screenMode = nil -- "leave" = หน้านี้ตัดสินใจจะออกแล้ว ห้าม Retry ซ้ำบนหน้านี้

        local function ResetScreenState()
            seenSince, goneSince = nil, nil
            tries, lastTry, counted = 0, 0, false
            leaveTries, lastLeave = 0, 0
            screenMode = nil
        end

        local function DoLeave(title, why)
            screenMode = "leave"
            if leaveTries >= MAX_LEAVE_TRIES or (leaveTries > 0 and os.clock() - lastLeave < LEAVE_GAP) then
                Status("Leave sent - waiting for the game")
                return
            end
            if not FindButtonText(title, "^LEAVE") then
                Status("Leave button not found")
                return
            end
            leaveTries += 1
            lastLeave = os.clock()
            Status("Leaving... (" .. why .. ")")
            local ok, err = FireLeave()
            if Farm.Debug then print("[SmoothHub] Leave fired:", ok, err) end
            if ok then
                Status("Leave sent (" .. why .. ")")
                if Cfg.RetryDone ~= 0 then Farm.ResetRetry() end -- จบสาย Retry แล้ว
            else
                Status("Leave failed: " .. tostring(err))
            end
        end

        -- ข้อความนับรอบ: เปิด Auto Leave After X Matches = นับ x/จำนวนที่ตั้ง, ไม่เปิด = เล่นต่อไม่จำกัด
        local function Progress(done)
            if Cfg.AutoLeaveWhenRetryComplete then
                return ("%d/%d"):format(done, Cfg.RetryAmount)
            end
            return tostring(done) .. " / endless"
        end

        local function DoRetry(title)
            if tries >= MAX_RETRY_TRIES or (tries > 0 and os.clock() - lastTry < RETRY_GAP) then
                Status("Retry sent - waiting for the game")
                return
            end
            local btn = FindButtonText(title, "^RETRY")
            if not btn then
                Status("Retry button not found")
                return
            end
            local have, need = CleanText(btn):match("(%d+)%s*/%s*(%d+)")
            have, need = tonumber(have), tonumber(need)
            if have and need and have >= need then
                Status("Retry vote already in")
                tries = MAX_RETRY_TRIES -- โหวตครบแล้ว ไม่ยิงอีก
                return
            end
            tries += 1
            lastTry = os.clock()
            Status("Retrying... (" .. Progress(Cfg.RetryDone + (counted and 0 or 1)) .. ")")
            local ok, r = FireRetry()
            if Farm.Debug then print("[SmoothHub] Retry fired:", ok, r) end
            if ok then
                if not counted then
                    counted = true
                    Cfg.RetryDone += 1
                    Save()
                    Farm.RefreshRetry()
                end
                Status("Retry sent (" .. Progress(Cfg.RetryDone) .. ")")
            else
                Status("Retry failed: " .. tostring(r))
            end
        end

        while Alive() do
            task.wait(CHECK_INTERVAL)

            if not (Cfg.AutoRetry or Cfg.AutoLeave or Cfg.AutoLeaveWhenRetryComplete) then
                ResetScreenState()
                Status("Off")
            elseif not CanUseHere() then
                ResetScreenState()
                Status("Not available in the lobby / menu")
            else
                local title = FindCompleteTitle()
                if not title then
                    -- ไม่เห็นหน้า MISSION COMPLETED: รอให้หายนานพอค่อยรีเซ็ต (กันป้ายกะพริบ)
                    goneSince = goneSince or os.clock()
                    if os.clock() - goneSince >= GONE_TIME then ResetScreenState() end
                    if not seenSince then
                        if Cfg.AutoRetry then
                            Status("Waiting for the mission to finish (" .. Progress(Cfg.RetryDone) .. ")")
                        else
                            Status("Waiting for the mission to finish")
                        end
                    end
                else
                    goneSince = nil
                    seenSince = seenSince or os.clock()
                    if os.clock() - seenSince < CONFIRM_TIME then
                        Status("Mission completed - preparing")
                    elseif screenMode == "leave" or Cfg.AutoLeave then
                        DoLeave(title, "Auto Leave")
                    elseif Cfg.AutoRetry then
                        -- จำกัดจำนวนรอบเฉพาะตอนเปิด Auto Leave After X Matches เท่านั้น ไม่งั้น Retry ต่อไปเรื่อยๆ
                        if Cfg.AutoLeaveWhenRetryComplete and Cfg.RetryDone >= Cfg.RetryAmount then
                            DoLeave(title, ("after %d matches"):format(Cfg.RetryAmount))
                        else
                            DoRetry(title)
                        end
                    else
                        Status("Auto Leave After X Matches needs Auto Retry")
                    end
                end
            end
        end
    end)
end

local AutoQuestTab = MainCategory:Tab({
    Title = "Auto Quest",
    Icon = Icon("scrollFill", "checklist"),
})
local AutoQuestSection = AutoQuestTab:PageSection({
    Title = "🛠️ Auto Quest",
    Subtitle = "Core features and settings"
})

---------------------------------------------------------
-- Lobby (Lobby / Progression / Skill Trees / Perks)
---------------------------------------------------------
local LobbyCategory = Cascade.Components.Section(Window, {
    Title = "Lobby",
    Disclosure = false
})

local LobbyTab = LobbyCategory:Tab({
    Title = "Lobby",
    Icon = Icon("cubeFill", "shippingboxFill", "cube"),
})
-- ───────── Auto Claim ─────────
-- อ่านจากหน้า Quests / Achievements ของเกมเอง: ปุ่ม Claim ที่เกม "โชว์ขึ้นมา" = เกมถือว่ารับได้แล้วจริง ๆ
-- (เกมซ่อนข้อมูลผู้เล่นไว้ executor เอื้อมไม่ถึง แต่หน้าจอ UI อ่านได้)
-- เจอปุ่ม Claim ที่โชว์อยู่ -> ยิง Remote ตัวเดียวกับที่ปุ่มของเกมใช้ ไม่เดา tag/id เอง
-- ข้อจำกัด: หน้า UI จะอัปเดตตอนที่ "เปิดหน้า/เลือกหมวด" ในเกมเท่านั้น
do
    local ClaimSection = LobbyTab:PageSection({
        Title = "🎁 Auto Claim",
        Subtitle = "Claims rewards the game shows as ready. Open the Quests / Achievements page to refresh them."
    })
    local ClaimForm = ClaimSection:Form()

    local ClaimStatusRow = ClaimForm:Row()
    ClaimStatusRow:Left():TitleStack({ Title = "Claim Status", Subtitle = "Rewards claimed since the script started." })
    local ClaimStatusLabel = ClaimStatusRow:Right():Label({ Text = "Idle" })
    local function SetClaimStatus(text)
        pcall(function() ClaimStatusLabel.Text = tostring(text) end)
    end

    local function AddClaimToggle(title, subtitle, key)
        local row = ClaimForm:Row()
        row:Left():TitleStack({ Title = title, Subtitle = subtitle })
        UiSync.Link(row:Right():Toggle({
            Value = Cfg[key],
            ValueChanged = function(self, value)
                Cfg[key] = value and true or false
                Save()
            end
        }), Cfg, key)
    end

    AddClaimToggle("Auto Claim Main Quests", "Automatically claim the main quests.", "AutoClaimMain")
    AddClaimToggle("Auto Claim Side Quests", "Automatically claim the side quests.", "AutoClaimSide")
    AddClaimToggle("Auto Claim Achievements", "Automatically claim achievements.", "AutoClaimAchievements")
    AddClaimToggle("Auto Claim Weekly Quests", "Automatically claim the weekly quests.", "AutoClaimWeekly")
    AddClaimToggle("Auto Claim Daily Quests", "Automatically claim the daily quests.", "AutoClaimDaily")
    AddClaimToggle("Auto Open Pages", "When the game shows the red ! on the Achievements icon, open that page, claim, then close it (like a player).", "AutoOpenPages")

    local SCAN_INTERVAL = 5       -- อ่านหน้าจอทุกกี่วินาที (อ่านอย่างเดียว เบามาก)
    local CLAIM_RETRY = 300       -- ปุ่มเดิมที่ยิงไปแล้ว (สำเร็จหรือไม่) รอกี่วินาทีค่อยยิงซ้ำ
    local CLAIM_GAP = 1.2         -- เว้นช่วงระหว่างแต่ละคำขอ
    local CLAIM_MAX_PER_RUN = 25  -- รับได้สูงสุดกี่รายการต่อรอบ
    local BLIND_DAILY_INTERVAL = 300 -- Daily แบบไม่ดูหน้าจอ ยิงได้ทุกกี่วินาที

    local claimRemote = nil
    local function GetClaimRemote()
        if claimRemote and claimRemote.Parent then return claimRemote end
        claimRemote = GetLobbyRemote()
        return claimRemote
    end

    -- หมวดของเควสต์ -> สวิตช์ที่คุมมัน (หมวดอื่น เช่น Spears / Battlepass / Regiment ไม่แตะ)
    local QUEST_TOGGLE = {
        Main = "AutoClaimMain",
        Side = "AutoClaimSide",
        Weekly = "AutoClaimWeekly",
        Daily = "AutoClaimDaily",
    }

    local function Interface()
        return PlayerGui:FindFirstChild("Interface")
    end

    -- ───── อ่านปุ่ม Claim ในหน้า Quests ─────
    -- โค้ดเกม: การ์ดเควสต์ -> Inner.Claim (โชว์เมื่อรับได้) -> Button ที่ตั้ง Attribute Tag/Category ไว้
    -- (ตั้งเฉพาะการ์ดที่ Claim.Visible = true จึงตรงกับ "เสร็จแล้วแต่ยังไม่รับ" ตามที่เกมตัดสิน)
    local function ScanQuestCards()
        local out = {}
        local quests = Interface() and Interface():FindFirstChild("Quests")
        if not quests then return out end
        for _, d in ipairs(quests:GetDescendants()) do
            if d.Name == "Button" and d:IsA("GuiObject") then
                local ok, info = pcall(function()
                    local claim = d.Parent
                    if not (claim and claim.Name == "Claim" and claim.Visible) then return nil end
                    local tag, category = d:GetAttribute("Tag"), d:GetAttribute("Category")
                    if tag == nil or category == nil then return nil end
                    return { tag = tostring(tag), category = tostring(category), inst = d }
                end)
                if ok and info then out[#out + 1] = info end
            end
        end
        return out
    end

    -- ───── อ่านปุ่ม CLAIM ในหน้า Achievements ─────
    -- โค้ดเกม: List.Inner -> รายการชื่อ = index -> Inner.A_State (โชว์เมื่อรับ/ใส่ได้) ข้อความ "CLAIM" = ยังไม่รับ
    local function ScanAchievementItems()
        local out = {}
        local iface = Interface()
        local ach = iface and iface:FindFirstChild("Achievements")
        local list = ach and ach:FindFirstChild("List")
        list = list and list:FindFirstChild("Inner")
        if not list then return out end
        for _, item in ipairs(list:GetChildren()) do
            local ok, info = pcall(function()
                local id = tonumber(item.Name)
                if not id or id == 99 then return nil end -- 99 = รางวัลเสร็จครบหมวด (ไม่ทำ)
                local inner = item:FindFirstChild("Inner")
                local state = inner and inner:FindFirstChild("A_State")
                local title = state and state:FindFirstChild("Title")
                if state and state.Visible and title and title.Text == "CLAIM" then
                    return { id = id, inst = item }
                end
                return nil
            end)
            if ok and info then out[#out + 1] = info end
        end
        return out
    end

    -- ───── ยิงคำขอรับรางวัล ─────
    -- จำปุ่มที่ยิงไปแล้ว (key = ตัวปุ่มใน UI) เกมสร้างการ์ดใหม่ทุกครั้งที่เปิดหน้า ปุ่มใหม่จึงยิงได้ทันที
    local lastTry = setmetatable({}, { __mode = "k" })
    local function Due(inst)
        return os.clock() - (lastTry[inst] or -math.huge) >= CLAIM_RETRY
    end

    -- คืน true ถ้าเซิร์ฟเวอร์ตอบรับ (ค่าแรกที่ตอบกลับไม่ใช่ nil)
    local function ClaimOne(inst, ...)
        lastTry[inst] = os.clock()
        local remote = GetClaimRemote()
        if not remote then return false end
        local args = table.pack(...)
        local ok, r1 = pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end)
        return ok and r1 ~= nil
    end

    local totals = { Main = 0, Side = 0, Weekly = 0, Daily = 0, Ach = 0 }
    local function RefreshClaimStatus()
        SetClaimStatus(("Main %d · Side %d · Weekly %d · Daily %d · Ach %d"):format(
            totals.Main, totals.Side, totals.Weekly, totals.Daily, totals.Ach))
    end

    local function RunScan()
        if not Interface() then SetClaimStatus("Waiting for the game UI...") return end
        local done, tried = 0, 0

        -- เควสต์
        local wantQuests = Cfg.AutoClaimMain or Cfg.AutoClaimSide or Cfg.AutoClaimWeekly or Cfg.AutoClaimDaily
        if wantQuests then
            for _, c in ipairs(ScanQuestCards()) do
                local toggle = QUEST_TOGGLE[c.category]
                if toggle and Cfg[toggle] and Alive() and tried < CLAIM_MAX_PER_RUN and Due(c.inst) then
                    tried += 1
                    if ClaimOne(c.inst, "Functions", "Quest", c.tag, c.category) then
                        totals[c.category] += 1
                        done += 1
                    end
                    task.wait(CLAIM_GAP)
                end
            end
        end

        -- Achievements
        if Cfg.AutoClaimAchievements then
            for _, a in ipairs(ScanAchievementItems()) do
                if Cfg.AutoClaimAchievements and Alive() and tried < CLAIM_MAX_PER_RUN and Due(a.inst) then
                    tried += 1
                    if ClaimOne(a.inst, "S_Achievements", "Claim", a.id) then
                        totals.Ach += 1
                        done += 1
                    end
                    task.wait(CLAIM_GAP)
                end
            end
        end

        if done > 0 or tried > 0 then RefreshClaimStatus() end
    end

    -- Daily แบบไม่ดูหน้าจอ (pattern จาก Remote Spy: "Daily 1..3") ยิงไม่บ่อย และเซิร์ฟเวอร์เป็นคนตัดสินเอง
    local lastBlindDaily = -math.huge
    local function RunBlindDaily()
        if not Cfg.AutoClaimDaily then return end
        if os.clock() - lastBlindDaily < BLIND_DAILY_INTERVAL then return end
        lastBlindDaily = os.clock()
        local remote = GetClaimRemote()
        if not remote then return end
        for i = 1, 3 do
            if not (Alive() and Cfg.AutoClaimDaily) then return end
            local ok, r1 = pcall(function()
                return remote:InvokeServer("Functions", "Quest", "Daily " .. i, "Daily")
            end)
            if ok and r1 ~= nil then totals.Daily += 1 end
            task.wait(CLAIM_GAP)
        end
        RefreshClaimStatus()
    end


    -- ───── เปิดหน้าเองเมื่อเกมโชว์ป้าย (เหมือนผู้เล่นกดเอง) ─────
    -- Achievements: ป้าย Topbar.Main.Icons.Achievements.New (เกมอัปเดตเอง ไม่ต้องเปิดหน้า)
    -- Quests: ป้าย New บนการ์ดหมวด (Quests.Main.Quests.<การ์ด>.Inner.Title.New) การ์ดมีอยู่แม้หน้าปิด
    -- ป้ายอาจค้างอยู่ได้ (แค่ "ของใหม่ที่ยังไม่ได้ดู") จึงเปิดเฉพาะตอนป้าย "เพิ่งขึ้น" ป้ายดับแล้วค่อยรีเซ็ต
    local OPEN_COOLDOWN = 60
    local opening = false
    local lastAchOpen, lastQuestOpen = -math.huge, -math.huge
    local handledAch = {} -- หมวด Achievement ที่จัดการไปแล้ว (ป้ายของหมวดดับแล้วค่อยรีเซ็ต)
    local handledCards = {}
    -- การ์ดหมวดเควสต์ -> หมวดที่คุมด้วยสวิตช์ (Q_1 = MAIN QUESTS ยืนยันจากหน้าจอ) ตัวอื่นยังไม่รู้
    local CARD_CATEGORY = { Q_1 = "Main", Q_2 = "Side" } -- Q_1 ยืนยันแล้ว, Q_2 = Side (อนุมานจากป้ายที่ขึ้นหลังเล่นจบ ยังรอยืนยัน)

    local function WantQuests()
        return Cfg.AutoClaimMain or Cfg.AutoClaimSide or Cfg.AutoClaimWeekly or Cfg.AutoClaimDaily
    end

    local function OnScreen(obj)
        local cam = workspace.CurrentCamera
        if not cam then return true end
        local c = obj.AbsolutePosition + obj.AbsoluteSize / 2
        local v = cam.ViewportSize
        return c.X >= 0 and c.Y >= 0 and c.X <= v.X and c.Y <= v.Y
    end

    -- หน้าเปิดอยู่ไหม (Visible + โปร่งใสไม่เต็ม + อยู่ในจอ) ดูผลจริงได้ที่ปุ่ม Copy Claim Debug
    local function PageOpen(page)
        if not page then return false end
        local ok, res = pcall(function()
            if not IsShown(page) then return false end
            if page:IsA("CanvasGroup") and page.GroupTransparency >= 0.95 then return false end
            return OnScreen(page)
        end)
        return ok and res or false
    end

    local function AchPage()
        local iface = Interface()
        return iface and iface:FindFirstChild("Achievements")
    end
    local function QuestsPage()
        local iface = Interface()
        return iface and iface:FindFirstChild("Quests")
    end
    local function AchOpen() return PageOpen(AchPage()) end
    local function QuestsOpen() return PageOpen(QuestsPage()) end

    local function AchBadgeOn()
        local b = FindGui("Interface.Topbar.Main.Icons.Achievements.New")
        return b ~= nil and b:IsA("GuiObject") and b.Visible
    end

    -- การ์ดหมวดเควสต์ + ป้าย New + ปุ่ม Interact
    local function QuestCategoryCards()
        local out = {}
        local q = QuestsPage()
        local main = q and q:FindFirstChild("Main")
        local cats = main and main:FindFirstChild("Quests")
        if not cats then return out end
        for _, c in ipairs(cats:GetChildren()) do
            if c:IsA("CanvasGroup") then
                local ok, info = pcall(function()
                    local inner = c:FindFirstChild("Inner")
                    local title = inner and inner:FindFirstChild("Title")
                    local flag = title and title:FindFirstChild("New")
                    return {
                        name = c.Name,
                        new = (flag ~= nil and flag:IsA("GuiObject") and flag.Visible) and true or false,
                        interact = inner and inner:FindFirstChild("Interact"),
                    }
                end)
                if ok and info then out[#out + 1] = info end
            end
        end
        return out
    end

    -- การ์ดเควสต์ย่อยที่เกมสร้างในแผง Details (เปลี่ยนเมื่อกดเลือกหมวดอื่น)
    local function DetailKey()
        local q = QuestsPage()
        local main = q and q:FindFirstChild("Main")
        local d = main and main:FindFirstChild("Details")
        local p = d and d:FindFirstChild("Quests")
        local n, first = 0, nil
        if p then
            for _, k in ipairs(p:GetChildren()) do
                if k:IsA("CanvasGroup") then
                    n += 1
                    first = first or k
                end
            end
        end
        return n, first
    end

    local function QuestsCloseButton()
        local q = QuestsPage()
        local c = q and q:FindFirstChild("Close")
        if not c then return nil end
        if c:IsA("GuiButton") then return c end
        return c:FindFirstChildWhichIsA("GuiButton", true)
    end

    -- กดปุ่มเหมือนผู้เล่น (กรอบฟ้า + Enter) แล้วเช็คผลทุก 0.25 วิ
    -- ไม่ติดค่อยยิง signal ให้ "ครั้งเดียว" (กันกดซ้ำจนหน้าเด้งเปิด-ปิด)
    local function PressUntil(btn, doneFn, timeout)
        pcall(function() GuiService.SelectedObject = btn end)
        task.wait(0.15)
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)
        local t0 = os.clock()
        local fired = false
        while os.clock() - t0 < (timeout or 3) do
            task.wait(0.25)
            if doneFn() then break end
            if not fired and os.clock() - t0 > 1.2 then
                fired = true
                pcall(function()
                    if type(firesignal) == "function" then
                        firesignal(btn.MouseButton1Click)
                        firesignal(btn.Activated)
                    end
                end)
            end
        end
        pcall(function()
            if GuiService.SelectedObject == btn then GuiService.SelectedObject = nil end
        end)
        return doneFn()
    end

    -- ───── Achievements 2 ชั้น: รายการหมวด (ชื่อข้อความ + Interact + Icon.New) -> รายการในหมวด (ชื่อเป็นเลข) ─────
    local function AchList()
        local ach = AchPage()
        local l = ach and ach:FindFirstChild("List")
        return l and l:FindFirstChild("Inner")
    end

    -- อยู่ในหมวดอยู่ไหม (มีรายการชื่อเป็นเลข = อยู่ชั้นใน)
    local function AchInCategoryView()
        local list = AchList()
        if not list then return false end
        for _, c in ipairs(list:GetChildren()) do
            if tonumber(c.Name) then return true end
        end
        return false
    end

    local function AchCategories()
        local out = {}
        local list = AchList()
        if not list then return out end
        for _, item in ipairs(list:GetChildren()) do
            if item:IsA("GuiObject") and not tonumber(item.Name) then
                local box = item:FindFirstChild("Inner")
                local icon = box and box:FindFirstChild("Icon")
                local nw = icon and icon:FindFirstChild("New")
                local interact = item:FindFirstChild("Interact")
                if box and icon and interact and interact:IsA("GuiButton") then
                    out[#out + 1] = {
                        name = item.Name,
                        new = (nw ~= nil and nw:IsA("GuiObject") and nw.Visible) and true or false,
                        interact = interact,
                    }
                end
            end
        end
        return out
    end

    -- ปุ่มลูกศรมุมขวาบน: ถอยออกจากหมวด (หรือปิดหน้า ถ้าอยู่ชั้นรายการหมวดแล้ว)
    local function AchBack(doneFn)
        local close = FindGui("Interface.Achievements.Top.Achievements_Close")
        if not (close and close:IsA("GuiButton")) then return false end
        PressUntil(close, doneFn, 3)
        return true
    end
    local function BackedOut() return (not AchOpen()) or (not AchInCategoryView()) end

    local function AutoOpenAchievements()
        if opening then return end
        if not (Cfg.AutoOpenPages and Cfg.AutoClaimAchievements) then return end
        if not AchBadgeOn() then handledAch = {} return end
        if AchOpen() and AchInCategoryView() then return end -- ผู้เล่นกำลังดูในหมวดอยู่ ไม่แย่งหน้าจอ

        local todo = 0
        for _, c in ipairs(AchCategories()) do
            if c.new then
                if not handledAch[c.name] then todo += 1 end
            else
                handledAch[c.name] = nil
            end
        end
        if todo == 0 then return end
        if os.clock() - lastAchOpen < OPEN_COOLDOWN then return end
        local icon = FindGui("Interface.Topbar.Main.Icons.Achievements")
        if not (icon and icon:IsA("GuiButton") and IsShown(icon)) then return end

        opening = true
        lastAchOpen = os.clock()
        local ok, err = pcall(function()
            local wasOpen = AchOpen()
            SetClaimStatus("Achievement badge! Opening page...")

            local function EnsureOpen()
                if not AchOpen() then PressUntil(icon, AchOpen, 3) end
                local t0 = os.clock()
                while os.clock() - t0 < 3 and #AchCategories() == 0 and not AchInCategoryView() do task.wait(0.3) end
                return AchOpen()
            end

            if not EnsureOpen() then
                SetClaimStatus("Achievements page did not open")
                return
            end

            for _ = 1, 5 do
                if not (Alive() and Cfg.AutoOpenPages and Cfg.AutoClaimAchievements) then break end
                -- เปิดมาแล้วอยู่ในหมวด (เกมจำหน้าล่าสุด) -> ถอยออกมาที่รายการหมวดก่อน
                if AchInCategoryView() then
                    AchBack(BackedOut)
                    task.wait(0.4)
                end
                if not EnsureOpen() then break end

                local nextCat = nil
                for _, c in ipairs(AchCategories()) do
                    if c.new and not handledAch[c.name] then nextCat = c break end
                end
                if not nextCat then break end

                handledAch[nextCat.name] = true
                PressUntil(nextCat.interact, AchInCategoryView, 3)
                task.wait(0.6)
                RunScan()
                AchBack(BackedOut)
                task.wait(0.4)
            end

            -- ปิดหน้ากลับ (เฉพาะกรณีที่สคริปต์เป็นคนเปิดเอง)
            if not wasOpen and AchOpen() then
                if AchInCategoryView() then
                    AchBack(BackedOut)
                    task.wait(0.4)
                end
                if AchOpen() then
                    AchBack(function() return not AchOpen() end)
                end
            end
        end)
        opening = false
        if not ok then SetClaimStatus("Auto open failed: " .. tostring(err)) end
    end

    local function AutoOpenQuests()
        if opening then return end
        if not (Cfg.AutoOpenPages and WantQuests()) then return end
        local todo = {}
        for _, c in ipairs(QuestCategoryCards()) do
            if c.new then
                local cat = CARD_CATEGORY[c.name]
                local wanted
                if cat then wanted = Cfg[QUEST_TOGGLE[cat]] else wanted = WantQuests() end
                if wanted and not handledCards[c.name] then todo[#todo + 1] = c end
            else
                handledCards[c.name] = nil
            end
        end
        if #todo == 0 then return end
        if os.clock() - lastQuestOpen < OPEN_COOLDOWN then return end
        local topBtn = FindGui("Interface.Topbar.Main.Categories.Quests.Interact")
        if not (topBtn and topBtn:IsA("GuiButton") and IsShown(topBtn)) then return end

        opening = true
        lastQuestOpen = os.clock()
        local ok, err = pcall(function()
            local wasOpen = QuestsOpen()
            SetClaimStatus("Quest badge! Opening page...")
            if not wasOpen then
                PressUntil(topBtn, QuestsOpen, 3)
            end
            if not QuestsOpen() then
                SetClaimStatus("Quests page did not open")
                return
            end
            task.wait(0.5)
            for _, c in ipairs(todo) do
                if not (Alive() and Cfg.AutoOpenPages) then break end
                handledCards[c.name] = true
                if c.interact and c.interact.Parent then
                    local n0, f0 = DetailKey()
                    PressUntil(c.interact, function()
                        local n1, f1 = DetailKey()
                        return n1 > 0 and (n1 ~= n0 or f1 ~= f0)
                    end, 3)
                    task.wait(0.6)
                    RunScan()
                end
            end
            if not wasOpen and QuestsOpen() then
                local close = QuestsCloseButton()
                if close then
                    PressUntil(close, function() return not QuestsOpen() end, 3)
                else
                    SetClaimStatus("Quests page left open (close button not found)")
                end
            end
        end)
        opening = false
        if not ok then SetClaimStatus("Auto open failed: " .. tostring(err)) end
    end

    task.spawn(function()
        while Alive() do
            pcall(RunScan) -- อ่านปุ่ม Claim ที่โชว์อยู่ก่อน (หน้าปิดอยู่ก็อาจมีปุ่มค้างจากรอบก่อน)
            pcall(AutoOpenAchievements)
            pcall(AutoOpenQuests)
            pcall(RunBlindDaily)
            task.wait(SCAN_INTERVAL)
        end
    end)

    -- 🔒 โหมดนักพัฒนา: ปุ่ม Copy Claim Debug ซ่อนไว้ (เปลี่ยนเป็น true เฉพาะตอนต้องดีบักเอง ก่อนปล่อยให้คนอื่นใช้ต้องเป็น false)
    local DEV_MODE = false
    if DEV_MODE then
    -- ปุ่มดีบัก: อ่านอย่างเดียว ไม่ยิง Remote
    -- บอกว่าสคริปต์เห็นอะไรในหน้า Quests / Achievements บ้าง และโครงสร้างปุ่มหมวด (ไว้ทำเปิดหน้าอัตโนมัติ)
    local DebugRow = ClaimForm:Row()
    DebugRow:Left():TitleStack({
        Title = "Copy Claim Debug",
        Subtitle = "Open the Quests page and click through its categories, then Achievements, then press Copy."
    })
    local DebugBtn = DebugRow:Right():Button({ Label = "Copy", Callback = function() end })
    BindButton(DebugBtn, function()
        local lines = {}
        local function add(s) lines[#lines + 1] = tostring(s) end
        local function childNames(inst, limit)
            local parts = {}
            if inst then
                for _, c in ipairs(inst:GetChildren()) do parts[#parts + 1] = c.Name .. ":" .. c.ClassName end
            end
            table.sort(parts)
            if limit and #parts > limit then
                local n = #parts
                parts = { table.unpack(parts, 1, limit) }
                parts[#parts + 1] = ("...(+%d)"):format(n - limit)
            end
            return table.concat(parts, ", ")
        end

        local iface = Interface()
        add("Interface found: " .. tostring(iface ~= nil))
        if iface then
            add("Interface children: " .. childNames(iface, 60))

            local q = iface:FindFirstChild("Quests")
            add("Interface.Quests found: " .. tostring(q ~= nil))
            if q then
                add("Quests children: " .. childNames(q, 30))
                local main = q:FindFirstChild("Main")
                add("Quests.Main children: " .. childNames(main, 30))
                local cats = main and main:FindFirstChild("Quests")
                if cats then
                    for _, c in ipairs(cats:GetChildren()) do
                        if c:IsA("CanvasGroup") then
                            local newFlag = "?"
                            pcall(function() newFlag = tostring(c.Inner.Title.New.Visible) end)
                            local interact = c:FindFirstChild("Inner") and c.Inner:FindFirstChild("Interact")
                            add(("  category card %s | New(claimable)=%s | Interact=%s"):format(
                                c.Name, newFlag, interact and interact.ClassName or "none"))
                        end
                    end
                end
                local details = main and main:FindFirstChild("Details")
                local cardsParent = details and details:FindFirstChild("Quests")
                local nCards = 0
                if cardsParent then
                    for _, c in ipairs(cardsParent:GetChildren()) do
                        if c:IsA("CanvasGroup") then nCards += 1 end
                    end
                end
                add("Quest cards currently built: " .. nCards)
                local found = ScanQuestCards()
                add("Claim buttons showing in Quests: " .. #found)
                for _, c in ipairs(found) do add(("  tag=%s category=%s"):format(c.tag, c.category)) end
            end

            local ach = iface:FindFirstChild("Achievements")
            add("Interface.Achievements found: " .. tostring(ach ~= nil))
            if ach then
                add("Achievements children: " .. childNames(ach, 30))
                local list = ach:FindFirstChild("List") and ach.List:FindFirstChild("Inner")
                add("Achievement items built: " .. (list and #list:GetChildren() or 0))
                local items = ScanAchievementItems()
                add("CLAIM items showing in Achievements: " .. #items)
                for i = 1, math.min(#items, 15) do add("  id " .. items[i].id) end
            end

            local newIcon = FindGui("Interface.Topbar.Main.Icons.Achievements.New")
            add("Topbar Achievements 'New' flag: " .. (newIcon and tostring(newIcon.Visible) or "n/a"))

            -- ป้ายแจ้งเตือน "New" ทุกอันบนแถบบน (เกมอัปเดตเองโดยไม่ต้องเปิดหน้า) ไว้ใช้เป็นตัวบอกว่ามีของรอรับ
            local topbar = iface:FindFirstChild("Topbar")
            if topbar then
                add("Topbar children: " .. childNames(topbar, 20))
                local mainBar = topbar:FindFirstChild("Main")
                add("Topbar.Main children: " .. childNames(mainBar, 40))
                local icons = mainBar and mainBar:FindFirstChild("Icons")
                add("Topbar.Main.Icons children: " .. childNames(icons, 40))
                for _, d in ipairs(topbar:GetDescendants()) do
                    if d.Name == "New" and d:IsA("GuiObject") then
                        add(("  badge %s | Visible=%s"):format(d:GetFullName():gsub("^.-Interface%.", ""), tostring(d.Visible)))
                    end
                end
            end

            -- โครงสร้างด้านบนของหน้า Achievements (ปุ่มเลือกหมวด)
            local function tree(inst, depth, maxDepth, out, limit)
                if depth > maxDepth or #out >= limit then return end
                for _, c in ipairs(inst:GetChildren()) do
                    if #out >= limit then return end
                    out[#out + 1] = string.rep("  ", depth) .. c.Name .. ":" .. c.ClassName
                    tree(c, depth + 1, maxDepth, out, limit)
                end
            end
            if ach and ach:FindFirstChild("Top") then
                local out = {}
                tree(ach.Top, 1, 3, out, 60)
                add("Achievements.Top tree:")
                for _, l in ipairs(out) do add(l) end
            end
        end

        -- ───── ข้อมูลเพิ่มสำหรับทำ "เปิดหน้าเอง" (อ่านอย่างเดียว) ─────
        do
            local iface2 = Interface()
            if iface2 then
                add("Achievements page open (script's view): " .. tostring(AchOpen()))
                local ach2 = iface2:FindFirstChild("Achievements")
                if ach2 and ach2:IsA("CanvasGroup") then
                    add(("Achievements.Visible=%s GroupTransparency=%.2f"):format(tostring(ach2.Visible), ach2.GroupTransparency))
                end
                -- ปุ่มทั้งหมดบนแถบบน + ป้ายแจ้งเตือน
                local topbar2 = iface2:FindFirstChild("Topbar")
                if topbar2 then
                    add("Topbar buttons:")
                    for _, d in ipairs(topbar2:GetDescendants()) do
                        if d:IsA("GuiButton") then
                            add(("  %s | %s | shown=%s"):format(d:GetFullName():gsub("^.-Interface%.", ""), d.ClassName, tostring(IsShown(d))))
                        end
                    end
                    local cats = topbar2:FindFirstChild("Main") and topbar2.Main:FindFirstChild("Categories")
                    if cats then
                        add("Topbar.Main.Categories tree:")
                        local out2 = {}
                        local function walk(inst, depth)
                            if depth > 3 or #out2 >= 60 then return end
                            for _, c in ipairs(inst:GetChildren()) do
                                if #out2 >= 60 then return end
                                out2[#out2 + 1] = string.rep("  ", depth) .. c.Name .. ":" .. c.ClassName
                                walk(c, depth + 1)
                            end
                        end
                        walk(cats, 1)
                        for _, l in ipairs(out2) do add(l) end
                    end
                end
                -- ป้าย "New" ที่ "กำลังโชว์" อยู่ทั่ว Interface ตอนนี้ (ใช้หาว่าเควสต์/อย่างอื่นมีป้ายตรงไหน)
                add("Visible 'New' badges in Interface:")
                local nShown = 0
                for _, d in ipairs(iface2:GetDescendants()) do
                    if d.Name == "New" and d:IsA("GuiObject") and d.Visible and nShown < 40 then
                        nShown += 1
                        add("  " .. d:GetFullName():gsub("^.-Interface%.", ""))
                    end
                end
                if nShown == 0 then add("  (none)") end
            end
        end

        -- ───── รายละเอียดสถานะของแต่ละ Achievement + ปุ่มปิดหน้า Quests ─────
        do
            local iface3 = Interface()
            local ach3 = iface3 and iface3:FindFirstChild("Achievements")
            local list3 = ach3 and ach3:FindFirstChild("List")
            local inner3 = list3 and list3:FindFirstChild("Inner")
            if inner3 then
                add("Achievement items (name | A_State.Visible | A_State.Title | Icon.New):")
                local n = 0
                for _, item in ipairs(inner3:GetChildren()) do
                    if n >= 25 then break end
                    n += 1
                    local box = item:FindFirstChild("Inner")
                    local st = box and box:FindFirstChild("A_State")
                    local ttl = st and st:FindFirstChild("Title")
                    local icon = box and box:FindFirstChild("Icon")
                    local nw = icon and icon:FindFirstChild("New")
                    add(("  %s | state=%s | text=%s | new=%s"):format(
                        item.Name,
                        st and tostring(st.Visible) or "n/a",
                        ttl and tostring(ttl.Text) or "n/a",
                        nw and tostring(nw.Visible) or "n/a"))
                end
            end
            local q3 = iface3 and iface3:FindFirstChild("Quests")
            if q3 then
                add("Quests page open (script's view): " .. tostring(QuestsOpen()))
                add("Quests.Close tree:")
                local out3 = {}
                local function walk3(inst, depth)
                    if depth > 3 or #out3 >= 30 then return end
                    for _, c in ipairs(inst:GetChildren()) do
                        if #out3 >= 30 then return end
                        out3[#out3 + 1] = string.rep("  ", depth) .. c.Name .. ":" .. c.ClassName
                        walk3(c, depth + 1)
                    end
                end
                local closeF = q3:FindFirstChild("Close")
                if closeF then walk3(closeF, 1) end
                for _, l in ipairs(out3) do add(l) end
            end
        end

        -- ───── หน้า Achievements มี 2 ชั้น: รายการหมวด (ชื่อข้อความ) -> รายการในหมวด (ชื่อเป็นเลข) ─────
        -- ดูโครงสร้างของหมวดที่มีป้าย New เพื่อหาว่าต้องกดตรงไหนถึงเข้าหมวด
        pcall(function()
            local iface4 = Interface()
            local ach4 = iface4 and iface4:FindFirstChild("Achievements")
            if not ach4 then return end
            local top4 = ach4:FindFirstChild("Top")
            add("Achievements view (script's view): " .. (AchInCategoryView() and "inside a category" or "category list"))
            for _, nm in ipairs({ "Category", "Title" }) do
                local lbl = top4 and top4:FindFirstChild(nm)
                if lbl and lbl:IsA("TextLabel") then
                    add(("Achievements.Top.%s text: %s"):format(nm, lbl.Text))
                end
            end
            local lst4 = ach4:FindFirstChild("List")
            local list4 = lst4 and lst4:FindFirstChild("Inner")
            if not list4 then return end
            local shown = 0
            for _, item in ipairs(list4:GetChildren()) do
                local box = item:FindFirstChild("Inner")
                local icon = box and box:FindFirstChild("Icon")
                local nw = icon and icon:FindFirstChild("New")
                if nw and nw:IsA("GuiObject") and nw.Visible and shown < 2 then
                    shown += 1
                    add("Flagged achievement category tree: " .. item.Name)
                    local out4 = {}
                    local function walk4(inst, depth)
                        if depth > 3 or #out4 >= 40 then return end
                        for _, c in ipairs(inst:GetChildren()) do
                            if #out4 >= 40 then return end
                            out4[#out4 + 1] = string.rep("  ", depth) .. c.Name .. ":" .. c.ClassName
                                .. (c:IsA("GuiButton") and " [BUTTON]" or "")
                            walk4(c, depth + 1)
                        end
                    end
                    walk4(item, 1)
                    for _, l in ipairs(out4) do add(l) end
                end
            end
        end)

        local text = table.concat(lines, "\n")
        local copied = false
        if type(setclipboard) == "function" then copied = pcall(setclipboard, text)
        elseif type(toclipboard) == "function" then copied = pcall(toclipboard, text) end
        local saved = false
        if type(writefile) == "function" then saved = pcall(writefile, "SmoothHub_claimdebug.txt", text) end
        SetClaimStatus(copied and "Debug copied" or (saved and "Debug saved to file" or "Copy/save not supported"))
    end)
    end -- DEV_MODE
end

-- ───────── Equipment ─────────
-- ยิง Remote ตัวเดียวกับที่ปุ่มของเกมใช้ (ค่าที่ส่งมาจากที่คุณจับมาจากเกมเอง):
--   Upgrade All (Blade) : GET:InvokeServer("S_Equipment", "Upgrade", { Blade_Durability, ODM_*, Crit_* })
--   Upgrade All (TS)    : GET:InvokeServer("S_Equipment", "Upgrade", { Blast_Radius, TS_*, Crit_* })
--   Equip               : GET:InvokeServer("S_Equipment", "Weapon", "Spears" | "Blades")
do
    local BLADE_STATS = { "Blade_Durability", "ODM_Gas", "Crit_Damage", "ODM_Control", "ODM_Speed", "Crit_Chance", "ODM_Range", "ODM_Damage" }
    local THUNDER_STATS = { "Blast_Radius", "TS_Damage", "TS_Gas", "TS_Range", "TS_Control", "Crit_Chance", "Crit_Damage", "TS_Speed" }

    local UPGRADE_INTERVAL = 10   -- วินาที: กด Upgrade All ซ้ำทุกกี่วินาที (เซิร์ฟเวอร์เป็นคนตัดสินว่าจ่ายไหวไหม)
    local UPGRADE_GAP = 1.5       -- เว้นช่วงระหว่าง Blade กับ Thunder Spears ถ้าเปิดทั้งคู่
    local EQUIP_AFTER_SPAWN = 3   -- วินาทีที่รอหลังเกิดใหม่ก่อน Auto Equip
    local CALL_TIMEOUT = 8        -- รอเซิร์ฟเวอร์ตอบได้นานสุดกี่วินาที

    local EquipSection = LobbyTab:PageSection({
        Title = "⚔️ Equipment",
        Subtitle = "Automatically upgrade and equip your Blade, ODM gear and Thunder Spears."
    })
    local EquipForm = EquipSection:Form()

    -- แถวสถานะ
    local EquipStatusRow = EquipForm:Row()
    EquipStatusRow:Left():TitleStack({ Title = "Equipment Status", Subtitle = "Result of the last request." })
    local EquipStatusLabel = EquipStatusRow:Right():Label({ Text = "Idle" })
    local function SetEquipStatus(text)
        pcall(function() EquipStatusLabel.Text = tostring(text) end)
    end

    local equipRemote = nil
    local function GetEquipRemote()
        if equipRemote and equipRemote.Parent then return equipRemote end
        equipRemote = GetLobbyRemote()
        return equipRemote
    end

    -- ยิงคำขอในเธรดแยกและรอผลสูงสุด CALL_TIMEOUT วินาที (InvokeServer อาจค้างถ้าเซิร์ฟเวอร์ไม่ตอบ)
    local function Invoke(...)
        local remote = GetEquipRemote()
        if not remote then return false, "remote not found" end
        local args = table.pack(...)
        local done, ok, result = false, false, nil
        task.spawn(function()
            ok, result = pcall(function()
                return remote:InvokeServer(table.unpack(args, 1, args.n))
            end)
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < CALL_TIMEOUT do task.wait(0.1) end
        if not done then return false, "timeout" end
        return ok, result
    end

    local function UpgradeAll(statList, label)
        local ok, r = Invoke("S_Equipment", "Upgrade", table.clone(statList))
        SetEquipStatus(ok and (label .. " upgrade sent") or (label .. " upgrade failed: " .. tostring(r)))
        return ok
    end

    local function EquipWeapon(kind, label)
        local ok, r = Invoke("S_Equipment", "Weapon", kind)
        SetEquipStatus(ok and (label .. " equip sent") or (label .. " equip failed: " .. tostring(r)))
        return ok
    end

    -- สวิตช์ Equip Blade / Thunder Spears เลือกได้อย่างเดียว (ถ้าเปิดอันหนึ่ง อีกอันจะปิดเอง)
    local toggles = {}
    local function AddEquipToggle(title, subtitle, key, onChange)
        local row = EquipForm:Row()
        row:Left():TitleStack({ Title = title, Subtitle = subtitle })
        toggles[key] = UiSync.Link(row:Right():Toggle({
            Value = Cfg[key],
            ValueChanged = function(self, value)
                Cfg[key] = value and true or false
                Save()
                if onChange then onChange(Cfg[key]) end
            end
        }), Cfg, key)
    end

    local function TurnOff(key)
        if Cfg[key] then
            Cfg[key] = false
            Save()
            pcall(function() toggles[key].Value = false end)
        end
    end

    AddEquipToggle("Auto Upgrade Gear ( Blade )", "Automatically upgrade BLADE & ODM.", "AutoUpgradeBlade", nil)
    AddEquipToggle("Auto Upgrade Gear ( Thunder Spears )", "Automatically upgrade thunder spears.", "AutoUpgradeThunder", nil)
    AddEquipToggle("Auto Equip Blade", "Automatically equip blades.", "AutoEquipBlade", function(on)
        if on then
            TurnOff("AutoEquipThunder")
            task.spawn(EquipWeapon, "Blades", "Blade")
        end
    end)
    AddEquipToggle("Auto Equip Thunder Spears", "Automatically equip thunder spears.", "AutoEquipThunder", function(on)
        if on then
            TurnOff("AutoEquipBlade")
            task.spawn(EquipWeapon, "Spears", "Thunder Spears")
        end
    end)

    -- Auto Upgrade: ยิง Upgrade All ทุก UPGRADE_INTERVAL วินาทีตอนสวิตช์เปิดอยู่
    task.spawn(function()
        local lastBlade, lastThunder = 0, 0
        while Alive() do
            if Cfg.AutoUpgradeBlade and os.clock() - lastBlade >= UPGRADE_INTERVAL then
                lastBlade = os.clock()
                UpgradeAll(BLADE_STATS, "Blade")
                task.wait(UPGRADE_GAP)
            end
            if Alive() and Cfg.AutoUpgradeThunder and os.clock() - lastThunder >= UPGRADE_INTERVAL then
                lastThunder = os.clock()
                UpgradeAll(THUNDER_STATS, "Thunder Spears")
                task.wait(UPGRADE_GAP)
            end
            task.wait(1)
        end
    end)

    -- Auto Equip: ยิงตอนเปิดสวิตช์ (ด้านบน) และหลังเกิดใหม่ทุกครั้ง ไม่ยิงซ้ำรัว ๆ
    -- (ไม่แน่ใจว่าเซิร์ฟเวอร์ตีความคำสั่ง Equip เป็น "ตั้งเป็นอันนี้" หรือ "สลับ" จึงไม่วนยิงซ้ำ)
    local spawnConn
    spawnConn = LocalPlayer.CharacterAdded:Connect(function()
        if not Alive() then spawnConn:Disconnect() return end
        task.delay(EQUIP_AFTER_SPAWN, function()
            if not Alive() then return end
            if Cfg.AutoEquipThunder then
                EquipWeapon("Spears", "Thunder Spears")
            elseif Cfg.AutoEquipBlade then
                EquipWeapon("Blades", "Blade")
            end
        end)
    end)
end

local ProgressionTab = LobbyCategory:Tab({
    Title = "Progression",
    Icon = Icon("chartBarFill", "chartBarXaxis", "chartLineUptrendXyaxis"),
})
ProgressionTab:PageSection({
    Title = "📈 Progression",
    Subtitle = "Core features and settings"
})

local SkillTreesTab = LobbyCategory:Tab({
    Title = "Skill Trees",
    Icon = Icon("bookPagesFill", "bookFill", "book"),
})
SkillTreesTab:PageSection({
    Title = "🌳 Skill Trees",
    Subtitle = "Core features and settings"
})

local PerksTab = LobbyCategory:Tab({
    Title = "Perks",
    Icon = Icon("sparkles", "sparkle", "starFill"),
})
PerksTab:PageSection({
    Title = "✨ Perks",
    Subtitle = "Core features and settings"
})

---------------------------------------------------------
-- Game Mode (Missions / Wave Mode / Raid Mode)
---------------------------------------------------------
local GameModeCategory = Cascade.Components.Section(Window, {
    Title = "Game Mode",
    Disclosure = false
})

local MissionsTab = GameModeCategory:Tab({
    Title = "Missions",
    Icon = Icon("listClipboardFill", "clipboardFill", "checklist"),
})
-- ───────── Mission Settings ─────────
-- ตอนนี้เป็นตัวเลือก + สวิตช์ + เซฟค่าไว้ใน Cfg (ตรรกะเลือก/เข้าแมพจริง ยังไม่ได้ผูก)
-- ⚠️ รายชื่อตัวเลือกด้านล่างเป็นค่าตั้งต้นที่ผมใส่ให้ ยังไม่ได้ตรวจกับในเกม แก้ชื่อให้ตรงกับเกมได้ตรงนี้เลย
local MISSION_OPTIONS    = { "Shiganshina", "Trost", "Outskirts", "Forest", "Utgard", "Docks", "Stohess", "Chapel" }
local OBJECTIVE_OPTIONS  = { "Skirmish" } -- เว้นไว้ก่อน: ยังไม่ได้จับ Objective อื่นจากเกม
-- ชื่อที่โชว์ใน UI (ชื่อที่ส่งให้เซิร์ฟเวอร์ = คำแรก เช่น "Easy")
local DIFFICULTY_OPTIONS = { "Easy (E- Grade)", "Normal (E+ Grade)", "Hard (D+ Grade)", "Severe (B- Grade)", "Aberrant (A- Grade)" }
local MODIFIER_OPTIONS   = { "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple" }

do
    local MissionsSection = MissionsTab:PageSection({
        Title = "📜 Mission Settings",
        Subtitle = "Pick the mission, objective, difficulty and modifiers for your room."
    })
    local MissionForm = MissionsSection:Form()

    -- หมวดแยก: ปุ่มสร้าง/เริ่มห้องอัตโนมัติ (อยู่กลางระหว่าง Mission Settings กับ Advance Missions)
    local AutoMissionSection = MissionsTab:PageSection({
        Title = "🤖 Auto Mission",
        Subtitle = "Create your room first, then turn on Auto Start."
    })
    local AutoMissionForm = AutoMissionSection:Form()

    -- แถวแรกสุด: ดูสถานะล่าสุดได้ทันทีว่าสร้างห้องถูกหรือยัง
    local MissionStatusRow = MissionForm:Row()
    MissionStatusRow:Left():TitleStack({ Title = "Mission Status", Subtitle = "Current step and last result." })
    local MissionStatusLabel = MissionStatusRow:Right():Label({ Text = "Idle" })
    local STATUS_RED = Color3.fromRGB(255, 69, 58)
    local statusDefaultColor = nil
    pcall(function()
        local o = LabelObject(MissionStatusLabel)
        if o then statusDefaultColor = o.TextColor3 end
    end)
    -- isError = true -> ข้อความสีแดง (ข้อความปกติจะกลับเป็นสีเดิม)
    local function SetMissionStatus(text, isError)
        pcall(function() MissionStatusLabel.Text = tostring(text) end)
        pcall(function()
            local o = LabelObject(MissionStatusLabel)
            if not o then return end
            if isError then
                o.TextColor3 = STATUS_RED
            elseif statusDefaultColor then
                o.TextColor3 = statusDefaultColor
            end
        end)
    end

    -- ปิดสวิตช์ Auto Create (ใช้ตอนกด Leave หรือเปลี่ยนด่าน/ความยาก/Modifiers ที่ทำให้ห้องเดิมไม่ตรงแล้ว)
    -- สวิตช์ที่เปิดอยู่ระหว่างสร้างห้อง = ขั้นตอนถัดไปจะหยุดเอง
    local missionToggles = {}

    -- ตั้งสวิตช์บนหน้าจอด้วยโค้ด (ค่าใน Cfg เปลี่ยนตามเอง เพราะสวิตช์ผูกกับ Cfg อยู่แล้ว)
    local function SetMissionToggle(key, value)
        pcall(function() missionToggles[key].Value = value end)
    end

    -- ปิด Auto Create (ใช้เมื่อกด Leave / สร้างห้องไม่สำเร็จ / ความยากยังล็อกอยู่)
    local function ResetAutoCreate(reason, quiet)
        if not Cfg.AutoCreateMission then return end
        Cfg.AutoCreateMission = false
        Save()
        SetMissionToggle("AutoCreateMission", false)
        if not quiet and reason then SetMissionStatus("Auto Create off (" .. tostring(reason) .. ")") end
    end

    -- เปลี่ยนด่าน/ความยาก/Modifiers ตอน Auto Create เปิดอยู่ = สร้างห้องใหม่ให้ตรงค่าใหม่ (รอ 1.5 วิ กันกดรัว)
    local missionRecreateAt = nil
    local function RequestRecreate()
        if Cfg.AutoCreateMission then missionRecreateAt = os.clock() + 1.5 end
    end

    -- ───── ตรวจว่ามีห้องที่เราเป็นหัวหน้าอยู่จริงไหม (ใช้ล็อก Auto Start / Join Delay) ─────
    -- ห้องอยู่ที่ ReplicatedStorage.Missions (โค้ดเกมใช้ที่เดียวกัน) แต่ละห้องมีลูกชื่อ Leader ที่ .Value = ชื่อหัวหน้า
    -- และจำห้องที่สคริปต์เพิ่งสร้างไว้ด้วย (createdRoom) เผื่อโฟลเดอร์ไม่ตรง
    local createdRoom = nil
    local function MyRoomObject()
        local folder = ReplicatedStorage:FindFirstChild("Missions")
        if not folder then return nil end
        for _, room in ipairs(folder:GetChildren()) do
            local leader = room:FindFirstChild("Leader")
            if leader and leader:IsA("ValueBase") and leader.Value == LocalPlayer.Name then
                return room
            end
        end
        return nil
    end
    local function HasRoom()
        if createdRoom and createdRoom.Parent ~= nil then return true end
        return MyRoomObject() ~= nil
    end
    local missionStacks = {} -- key -> { stack = TitleStack, text = คำอธิบายเดิม } ใช้เปลี่ยนคำอธิบายเป็นสีแดง

    -- กันค่าที่เซฟไว้เพี้ยน (ชื่อที่ไม่มีในรายการ)
    local function KeepValid(options, value, fallback)
        return table.find(options, value) and value or fallback
    end
    local function KeepValidList(options, list)
        local out, seen = {}, {}
        if type(list) == "table" then
            for _, name in ipairs(list) do
                if table.find(options, name) and not seen[name] then
                    seen[name] = true
                    out[#out + 1] = name
                end
            end
        end
        return out
    end
    Cfg.MissionSelect = KeepValid(MISSION_OPTIONS, Cfg.MissionSelect, MISSION_OPTIONS[1])
    Cfg.MissionObjective = KeepValid(OBJECTIVE_OPTIONS, Cfg.MissionObjective, OBJECTIVE_OPTIONS[1])
    Cfg.MissionLevel = KeepValid(DIFFICULTY_OPTIONS, Cfg.MissionLevel, DIFFICULTY_OPTIONS[1])
    Cfg.MissionModifiers = KeepValidList(MODIFIER_OPTIONS, Cfg.MissionModifiers)

    -- เลือกได้ 1 อย่าง (Select Mission / Select Objective)
    local function AddSingleSelect(title, subtitle, options, key)
        local row = MissionForm:Row()
        row:Left():TitleStack({ Title = title, Subtitle = subtitle })
        local btn = row:Right():PullDownButton({
            Label = Cfg[key],
            Options = options,
            Value = table.find(options, Cfg[key]) or 1,
            ValueChanged = function(self, index)
                if options[index] then
                    Cfg[key] = options[index]
                    self.Label = options[index]
                    Save()
                    RequestRecreate()
                end
            end
        })
        StyleDropdown(btn)
        UiSync.Add(function()
            local i = table.find(options, Cfg[key]) or 1
            btn.Value = i
            btn.Label = options[i]
        end)
    end

    -- เลือกได้หลายอย่าง (Select Difficulty / Select Modifiers)
    -- ใช้ PopUpButton (ติ๊กได้หลายข้อ) ถ้าไลบรารีไม่รองรับ จะถอยไปใช้แบบเลือกทีละอัน
    local function AddMultiSelect(title, subtitle, options, key)
        local row = MissionForm:Row()
        row:Left():TitleStack({ Title = title, Subtitle = subtitle })

        local function apply(value)
            local indexes = type(value) == "table" and value or { value }
            local names = {}
            for _, index in ipairs(SettingsStore.ValidIndexes(indexes, #options)) do
                names[#names + 1] = options[index]
            end
            Cfg[key] = names
            Save()
            RequestRecreate()
        end

        local current = {}
        for i, name in ipairs(options) do
            if table.find(Cfg[key], name) then current[#current + 1] = i end
        end

        local ok, btn = pcall(function()
            return row:Right():PopUpButton({
                Options = options,
                Maximum = #options, -- ต้องกำหนดเกิน 1 ไลบรารีถึงจะเป็นโหมดติ๊กได้หลายอัน (ไม่ใส่ = เลือกได้ทีละอัน)
                Value = current,
                ValueChanged = function(self, value) apply(value) end
            })
        end)
        if not ok or not btn then
            btn = row:Right():PullDownButton({
                Label = Cfg[key][1] or "None",
                Options = options,
                Value = table.find(options, Cfg[key][1]) or 1,
                ValueChanged = function(self, index)
                    apply(index)
                    self.Label = options[index] or "None"
                end
            })
        end
        StyleDropdown(btn)
        UiSync.Add(function()
            if ok then
                local picked = {}
                for i, name in ipairs(options) do
                    if table.find(Cfg[key], name) then picked[#picked + 1] = i end
                end
                btn.Value = picked
            else
                local i = table.find(options, Cfg[key][1]) or 1
                btn.Value = i
                btn.Label = options[i]
            end
        end)
    end

    local function AddMissionToggle(title, subtitle, key, form, onChange)
        local row = (form or MissionForm):Row()
        missionStacks[key] = { stack = row:Left():TitleStack({ Title = title, Subtitle = subtitle }), text = subtitle }
        missionToggles[key] = UiSync.Link(row:Right():Toggle({
            Value = Cfg[key],
            ValueChanged = function(self, value)
                Cfg[key] = value and true or false
                Save()
                if onChange then onChange(Cfg[key]) end
            end
        }), Cfg, key)
    end

    -- สวิตช์ Auto Create / Auto Start เซฟลงไฟล์เหมือนสวิตช์อื่น แล้วเปิดค้างไว้ให้ตอนรันสคริปต์ใหม่ (ไม่ต้องกดซ้ำ)
    local initializing = true -- ช่วงสร้างหน้าจอ: ถ้าไลบรารียิง ValueChanged ตอนตั้งค่าเริ่มต้น จะไม่ไปสร้างห้องทับ
    local CreateRoomOnce -- (กำหนดค่าด้านล่าง)

    AddSingleSelect("Select Mission", "Choose the mission.", MISSION_OPTIONS, "MissionSelect")
    AddSingleSelect("Select Objective", "Only Skirmish for now.", OBJECTIVE_OPTIONS, "MissionObjective")
    AddSingleSelect("Select Difficulty", "Difficulty used when creating the room.", DIFFICULTY_OPTIONS, "MissionLevel")
    AddMultiSelect("Select Modifiers", "Tick the Modifiers to apply after creating.", MODIFIER_OPTIONS, "MissionModifiers")
    AddMissionToggle("Auto Create Mission", "Keeps a room ready with these settings. Remembered next time.", "AutoCreateMission", AutoMissionForm, function(on)
        if on and not initializing then missionRecreateAt = os.clock() end
    end)
    AddMissionToggle("Auto Start Missions", "Starts the mission in your room. Remembered next time.", "AutoStartMission", AutoMissionForm)

    -- ───── Join Delay / สถานะ ─────
    local MissionDelayRow = AutoMissionForm:Row()
    local delaySubtitle = "Seconds between starts (" .. MIN_DELAY .. " - " .. MAX_DELAY .. ")."
    missionStacks.JoinDelay = {
        stack = MissionDelayRow:Left():TitleStack({ Title = "Join Delay", Subtitle = delaySubtitle }),
        text = delaySubtitle,
    }
    local MissionDelayRight = MissionDelayRow:Right()
    local MissionDelayLabel = MissionDelayRight:Label({ Text = Cfg.MissionJoinDelay .. "s" })
    UiSync.Link(MissionDelayRight:Slider({
        Minimum = MIN_DELAY,
        Maximum = MAX_DELAY,
        Value = Cfg.MissionJoinDelay,
        ValueChanged = function(self, value)
            Cfg.MissionJoinDelay = ClampDelay(value)
            pcall(function() MissionDelayLabel.Text = Cfg.MissionJoinDelay .. "s" end)
            Save()
        end
    }), Cfg, "MissionJoinDelay", function(_, want)
        pcall(function() MissionDelayLabel.Text = want .. "s" end)
    end)

    local MissionCountRow = AutoMissionForm:Row()
    MissionCountRow:Left():TitleStack({ Title = "Next Mission", Subtitle = "Countdown to the next start." })
    local MissionCountLabel = MissionCountRow:Right():Label({ Text = "Off" })
    local lastCountText = nil
    local function SetMissionCountdown(text)
        if text == lastCountText then return end
        lastCountText = text
        pcall(function() MissionCountLabel.Text = text end)
    end

    local function RefreshRoomGate() return HasRoom() end

    -- ───── ตรรกะ: สร้างห้อง (Create) แล้วเริ่ม (Start) ─────
    -- ค่าที่ส่งมาจาก Remote Spy ของคุณ:
    --   GET:InvokeServer("S_Missions", "Create", { Difficulty = "Easy", Type = "Missions", Objective = "Skirmish", Name = "Shiganshina" })
    --   GET:InvokeServer("S_Missions", "Start")
    local LOBBY_PLACE_ID = 14916516914
    local ON_LOBBY_PLACE = (game.PlaceId == LOBBY_PLACE_ID)
    local CALL_TIMEOUT = 8
    local START_GAP = 1.5 -- รอหลัง Create ก่อนสั่ง Start

    local missionRemote = nil
    local function MissionInvoke(...)
        if not missionRemote or not missionRemote.Parent then
            missionRemote = GetLobbyRemote()
        end
        if not missionRemote then return false, "remote not found" end
        local remote = missionRemote
        local args = table.pack(...)
        local done, ok, result = false, false, nil
        task.spawn(function()
            ok, result = pcall(function()
                return remote:InvokeServer(table.unpack(args, 1, args.n))
            end)
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < CALL_TIMEOUT do task.wait(0.1) end
        if not done then return false, "timeout" end
        return ok, result
    end

    local missionBusy = false
    local MODIFY_GAP = 0.17 -- เว้นช่วงระหว่าง Modify แต่ละอัน

    -- ออกจากห้อง (GET:InvokeServer("S_Missions", "Leave")) ใช้ตอนสร้างห้องผิด และก่อนสร้างห้องใหม่ทุกรอบ
    local function LeaveRoom(silent)
        if not ON_LOBBY_PLACE then
            if not silent then SetMissionStatus("Not in the lobby place") end
            return false
        end
        local ok, r = MissionInvoke("S_Missions", "Leave")
        if not silent then
            SetMissionStatus(ok and "Leave sent" or ("Leave failed: " .. tostring(r)))
        end
        return ok
    end

    -- จากโค้ดเกม (Missions.Create_Creation): Create ตอบกลับเป็น "วัตถุห้อง" (StringValue) ที่ .Value = ความยากที่เซิร์ฟเวอร์ตั้งให้จริง
    -- ถ้าเลือกความยากที่ยังไม่ปลดล็อก เซิร์ฟเวอร์จะลดให้เอง (เช่น เลือก Hard แต่ห้องได้ Normal) จึงเทียบ .Value กับที่เลือกได้เลย
    local function RoomServerDifficulty(room)
        if typeof(room) ~= "Instance" then return nil end
        local okV, value = pcall(function() return room.Value end)
        if okV and type(value) == "string" then return value end
        return nil
    end

    -- Auto Create: สร้างห้องครั้งเดียวทันทีที่เปิดสวิตช์ (Leave > Create > Modify) ไม่ Start และไม่รอ Join Delay
    -- ปิดสวิตช์ระหว่างขั้นตอน = หยุดก่อนขั้นตอนถัดไป
    CreateRoomOnce = function()
        if not ON_LOBBY_PLACE then SetMissionStatus("Not in the lobby place") return false end
        if missionBusy then SetMissionStatus("Busy - turn Auto Create off and on again") return false end
        missionBusy = true

        local function Off()
            if Cfg.AutoCreateMission then return false end
            SetMissionStatus("Stopped (Auto Create turned off)")
            missionBusy = false
            return true
        end

        local mapName = Cfg.MissionSelect
        local difficulty = (Cfg.MissionLevel or ""):match("^(%S+)") or "Easy"

        -- ออกจากห้องเก่า (ถ้ามี) ก่อน (Modify เป็นการสลับ จึงไม่ควรยิงซ้ำในห้องเดิม)
        SetMissionStatus("Leaving old room...")
        LeaveRoom(true)
        task.wait(0.6)
        if Off() then return false end

        SetMissionStatus(("Creating %s (%s)..."):format(mapName, difficulty))
        local ok, r = MissionInvoke("S_Missions", "Create", {
            Difficulty = difficulty,
            Type = "Missions",
            Objective = Cfg.MissionObjective,
            Name = mapName,
        })
        if not ok then
            SetMissionStatus("Create failed: " .. tostring(r), true)
            missionBusy = false
            return false
        end
        if Off() then return false end

        -- เกมคืน nil เมื่อสร้างไม่สำเร็จ (Create_Creation: ถ้า nil จะไม่ทำอะไรต่อ)
        if r == nil or r == false then
            ResetAutoCreate(nil, true)
            SetMissionStatus("Create refused (no room returned)", true)
            missionBusy = false
            return false
        end

        -- เช็กความยากที่เซิร์ฟเวอร์ตั้งให้จริง ไม่ตรงที่เลือก = ยังไม่ปลดล็อก -> แจ้งสีแดงทันที ไม่ไปขั้น Modifiers
        -- ไม่แอบเปลี่ยนความยากให้เอง และออกจากห้องที่ได้ความยากผิดไป (กัน Auto Start เริ่มห้องผิดโดยไม่ตั้งใจ)
        local actual = RoomServerDifficulty(r)
        if actual and actual ~= difficulty then
            LeaveRoom(true)
            ResetAutoCreate(nil, true)
            SetMissionStatus(Cfg.MissionLevel .. " is locked", true)
            missionBusy = false
            return false
        end

        createdRoom = (typeof(r) == "Instance") and r or createdRoom

        -- Modifiers: ยิง S_Missions / Modify / <ชื่อ> ทีละอันตามที่ติ๊กไว้ (ลำดับตามรายการ)
        local picked = {}
        for _, name in ipairs(MODIFIER_OPTIONS) do
            if table.find(Cfg.MissionModifiers, name) then picked[#picked + 1] = name end
        end
        for i, name in ipairs(picked) do
            SetMissionStatus(("Modifier %d/%d: %s"):format(i, #picked, name))
            local okM, rM = MissionInvoke("S_Missions", "Modify", name)
            if not okM then
                SetMissionStatus("Modify failed (" .. name .. "): " .. tostring(rM), true)
                missionBusy = false
                return false
            end
            task.wait(MODIFY_GAP)
            if Off() then return false end
        end

        SetMissionStatus(("Room created: %s / %s"):format(mapName, difficulty))
        missionBusy = false
        return true
    end

    -- Auto Start: กด Start ในห้องที่อยู่ (ทำซ้ำทุก Join Delay ตราบที่เปิดสวิตช์)
    local function StartMission()
        if not ON_LOBBY_PLACE then SetMissionStatus("Not in the lobby place") return false end
        if missionBusy then return false end
        missionBusy = true
        SetMissionStatus("Starting mission...")
        local ok, r = MissionInvoke("S_Missions", "Start")
        SetMissionStatus(ok and "Start sent" or ("Start failed: " .. tostring(r)), not ok)
        missionBusy = false
        return ok
    end

    -- ปุ่ม Leave Room: ใช้เวลาสร้างห้องผิด
    local MissionLeaveRow = AutoMissionForm:Row()
    MissionLeaveRow:Left():TitleStack({ Title = "Leave Room", Subtitle = "Leave the current mission room." })
    local MissionLeaveBtn = MissionLeaveRow:Right():Button({ Label = "Leave", Callback = function() end })
    BindButton(MissionLeaveBtn, function()
        -- ออกจากห้อง = ห้องที่สร้างไว้ใช้ไม่ได้แล้ว: ปิด Auto Create (ถ้ากำลังสร้างอยู่จะหยุดเอง) แล้วค่อยออก
        ResetAutoCreate("left the room")
        task.spawn(function()
            local t0 = os.clock()
            while missionBusy and os.clock() - t0 < 10 do task.wait(0.1) end
            if missionBusy then SetMissionStatus("Busy - try again in a moment") return end
            LeaveRoom(false)
        end)
    end)

    -- ───── Auto Create: คอยดูแลให้มีห้องเสมอ (ตอนเปิดสวิตช์ / เปลี่ยนค่า / ห้องหาย / รันสคริปต์ใหม่) ─────
    task.spawn(function()
        local readyAt = os.clock() + 4 -- รอให้ล็อบบี้โหลดก่อน (ตอนรันสคริปต์ใหม่)
        local fails, nextTry = 0, 0
        while Alive() do
            task.wait(0.5)
            local now = os.clock()
            if ON_LOBBY_PLACE and Cfg.AutoCreateMission and not missionBusy and now >= readyAt then
                local need = false
                if missionRecreateAt and now >= missionRecreateAt then
                    missionRecreateAt = nil
                    need = true
                elseif now >= nextTry and not HasRoom() then
                    need = true
                end
                if need then
                    if CreateRoomOnce() then
                        fails = 0
                        nextTry = os.clock() + 20 -- กันสร้างซ้ำรัว ๆ ถ้าตรวจห้องไม่เจอ
                    elseif Cfg.AutoCreateMission then
                        fails += 1
                        nextTry = os.clock() + 8
                        if fails >= 3 then
                            fails = 0
                            ResetAutoCreate(nil, true)
                            SetMissionStatus("Auto Create stopped (failed 3 times)", true)
                        end
                    end
                end
            end
        end
    end)

    -- ───── Auto Start: รอให้มีห้อง แล้วกด Start ทุก Join Delay (สวิตช์ไม่เด้งปิดเอง) ─────
    task.spawn(function()
        local lastFire = nil
        while Alive() do
            local hasRoom = HasRoom()
            if not ON_LOBBY_PLACE then
                lastFire = nil
                SetMissionCountdown("Wrong place")
            elseif not Cfg.AutoStartMission then
                lastFire = nil
                SetMissionCountdown("Off")
            elseif not hasRoom then
                lastFire = nil
                SetMissionCountdown("Waiting for room...")
            else
                local now = os.clock()
                local delay = ClampDelay(Cfg.MissionJoinDelay)
                if not lastFire then lastFire = now end
                local remaining = lastFire + delay - now
                if remaining <= 0 then
                    SetMissionCountdown("Starting now...")
                    StartMission()
                    lastFire = os.clock() -- แล้วค่อยเริ่มนับ Join Delay ใหม่จาก "ตอนจบรอบ"
                else
                    SetMissionCountdown(("Next mission in %ds"):format(math.ceil(remaining)))
                end
            end
            task.wait(0.25)
        end
    end)

    -- ───── Advance Missions (หมวดแยก อยู่ล่าง Mission Settings) ─────
    local AdvMissionsSection = MissionsTab:PageSection({
        Title = "🚀 Advance Missions",
        Subtitle = "Auto-pick the best grade or boost mission."
    })
    local AdvMissionsForm = AdvMissionsSection:Form()
    AddMissionToggle("Auto Select Best Grade", "Not active yet.", "AutoBestGrade", AdvMissionsForm)
    AddMissionToggle("Auto Select Boost Mission", "Not active yet.", "AutoBoostMission", AdvMissionsForm)

    -- ───── ตอนรันสคริปต์: สวิตช์ที่เคยเปิดไว้ยังเปิดค้างอยู่และทำงานต่อเอง ─────
    if not canSave then
        SetMissionStatus("Can't save settings (executor has no file access)", true)
    elseif Cfg.AutoCreateMission or Cfg.AutoStartMission then
        if ON_LOBBY_PLACE then
            SetMissionStatus("Resuming your saved Auto switches...")
        else
            SetMissionStatus("Saved Auto switches will run in the lobby place")
        end
    end
    task.delay(2, function() initializing = false end)
end

local WaveModeTab = GameModeCategory:Tab({
    Title = "Wave Mode",
    Icon = Icon("waveformCircleFill", "waveform", "tornado"),
})
WaveModeTab:PageSection({
    Title = "🌊 Wave Mode",
    Subtitle = "Core features and settings"
})

local RaidModeTab = GameModeCategory:Tab({
    Title = "Raid Mode",
    Icon = Icon("diamondFill", "shieldFill", "flameFill"),
})
RaidModeTab:PageSection({
    Title = "⚔️ Raid Mode",
    Subtitle = "Core features and settings"
})

---------------------------------------------------------
-- Misc (Webhook)
---------------------------------------------------------
local MiscCategory = Cascade.Components.Section(Window, {
    Title = "Misc",
    Disclosure = false
})

local WebhookTab = MiscCategory:Tab({
    Title = "Webhook",
    Icon = Icon("paperplaneFill", "paperplane", "bellFill"),
})
WebhookTab:PageSection({
    Title = "🔔 Webhook",
    Subtitle = "Core features and settings"
})


---------------------------------------------------------
-- Settings (Advanced / Server / Windows) - อยู่ล่างสุด
---------------------------------------------------------
do
local HOP_PLACE_ID = game.PlaceId
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------
-- ค่าตั้งของหมวด Settings
---------------------------------------------------------
local HubConfig = {
    InfiniteJump = false,
    AntiAFK = true,
    AutoRejoin = true,
    AntiAdmin = true,
    AutoExecute = false,
    EnableFPSLock = false,
    FPSLimit = 144,
}
for key, value in pairs(HubConfig) do UiSync.Defaults.Hub[key] = value end
ConfigStore.BuildDefault(UiSync.Defaults.Hub) -- config ค่าเริ่มต้นครบทุกค่าแล้ว
SettingsStore.Restore(HubConfig, SavedData.Hub)
ConfigStore.ApplyHub(HubConfig, ConfigStore.AutoloadSnapshot())

-- ───── Auto Execute: ให้สคริปต์รันต่อเองหลังเทเลพอร์ต (Server Hop / Rejoin / ย้ายแมพ) ─────
-- ใช้ queue_on_teleport ของ executor (ไม่ใช่ทุกตัวที่มี) คิวไว้ 1 ครั้งต่อการเทเลพอร์ต
-- สคริปต์ที่รันใหม่จะคิวต่อให้เองตอนเริ่ม (ถ้าสวิตช์ยังเปิดอยู่) จึงทำงานต่อเนื่อง
-- ตัวที่ถูกคิวไว้จะเช็กไฟล์เซฟก่อนรัน ถ้าปิดสวิตช์ไปแล้วจะไม่รัน
local AUTOEXEC_URL = "https://raw.githubusercontent.com/smoothhubv1-prog/Attack-on-Titan-R/refs/heads/main/Ui.lua"
local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

local AUTOEXEC_LOCK = "SmoothHub/AutoExec.lock" -- กันตัวที่คิวไว้รันซ้ำในเซิร์ฟเวอร์เดียวกัน
local AUTOEXEC_LOG = "SmoothHub/AutoExec.log" -- บันทึกสั้นๆ ว่าคิวทำงานไหม (ไว้ไล่หาสาเหตุถ้ารันต่อไม่ติด)
local function AutoExecLog(text)
    pcall(function()
        if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("SmoothHub") then
            makefolder("SmoothHub")
        end
        local line = tostring(os.time()) .. " place=" .. tostring(game.PlaceId) .. " " .. text .. "\n"
        if type(appendfile) == "function" then
            appendfile(AUTOEXEC_LOG, line)
        elseif type(writefile) == "function" then
            writefile(AUTOEXEC_LOG, line)
        end
    end)
end

local function QueueAutoExecute()
    if type(queueTeleport) ~= "function" then
        AutoExecLog("queue_on_teleport not supported by this executor")
        return false
    end
    -- ตัวที่ถูกคิวไว้: รอเกมโหลด -> เช็กว่าสวิตช์ยังเปิดอยู่ -> โหลดสคริปต์ (ลองใหม่ได้ 5 ครั้ง) -> เขียนผลลงบันทึก
    local payload = string.format([[
        local LOG = %q
        local LOCK = %q
        local function log(text)
            pcall(function()
                if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("SmoothHub") then makefolder("SmoothHub") end
                local line = tostring(os.time()) .. " place=" .. tostring(game.PlaceId) .. " [queued] " .. text .. "\n"
                if type(appendfile) == "function" then appendfile(LOG, line)
                elseif type(writefile) == "function" then writefile(LOG, line) end
            end)
        end
        log("started")
        if not game:IsLoaded() then game.Loaded:Wait() end
        local Players = game:GetService("Players")
        while not Players.LocalPlayer do task.wait() end

        local run = true
        pcall(function()
            if type(isfile) == "function" and isfile(%q) then
                local data = game:GetService("HttpService"):JSONDecode(readfile(%q))
                if type(data) == "table" and type(data.Hub) == "table" and data.Hub.AutoExecute == false then run = false end
            end
        end)
        if not run then log("skipped (Auto Execute is off)") return end

        -- กันรันซ้ำ: เซิร์ฟเวอร์เดิม (JobId เดียวกัน) ที่เพิ่งรันไปไม่ถึง 20 วินาที = ข้าม
        local jobId = tostring(game.JobId)
        pcall(function()
            if jobId ~= "" and type(isfile) == "function" and isfile(LOCK) then
                local id, t = tostring(readfile(LOCK)):match("^(.-)|(%%d+)$")
                if id == jobId and t and os.time() - tonumber(t) < 20 then run = false end
            end
        end)
        if not run then log("skipped (already started in this server)") return end
        pcall(function() writefile(LOCK, jobId .. "|" .. tostring(os.time())) end)

        local src, err
        for i = 1, 5 do
            local ok, res = pcall(function() return game:HttpGet(%q) end)
            if ok and type(res) == "string" and #res > 0 then src = res break end
            err = res
            task.wait(1)
        end
        if not src then log("download failed: " .. tostring(err)) return end
        local fn, cerr = loadstring(src)
        if not fn then log("compile failed: " .. tostring(cerr)) return end
        local ok, rerr = pcall(fn)
        log(ok and "script started" or ("script error: " .. tostring(rerr)))
    ]], AUTOEXEC_LOG, AUTOEXEC_LOCK, SettingsStore.Path("AOTR"), SettingsStore.Path("AOTR"), AUTOEXEC_URL)
    local ok, err = pcall(queueTeleport, payload)
    AutoExecLog(ok and "queued" or ("queue failed: " .. tostring(err)))
    return ok
end

local function ApplyAutoExecute(on)
    if on then
        SettingsStore.Flush("AOTR") -- เซฟค่าที่เปิดทันที ตัวที่คิวไว้จะอ่านไฟล์นี้ก่อนรัน
        QueueAutoExecute()
    elseif type(clear_teleport_queue) == "function" then
        pcall(clear_teleport_queue)
    end
end
if HubConfig.AutoExecute then QueueAutoExecute() end

-- คิวใหม่ทุกครั้งที่ "เริ่มเทเลพอร์ต" (รวมที่เกมสั่งจากเซิร์ฟเวอร์ เช่นตอนเข้าด่าน)
-- executor บางตัวล้างคิวเก่าตอนย้ายแมพ หรือไม่ยิงคิวที่ตั้งไว้ล่วงหน้า การคิวตอนเทเลพอร์ตเริ่มจะแก้ตรงนี้
if type(queueTeleport) == "function" then
    local lastQueuedAt = 0
    pcall(function()
        LocalPlayer.OnTeleport:Connect(function(state)
            if not Alive() or not HubConfig.AutoExecute then return end
            if os.clock() - lastQueuedAt < 5 then return end
            lastQueuedAt = os.clock()
            AutoExecLog("teleport started (" .. tostring(state) .. ") - re-queue")
            if type(clear_teleport_queue) == "function" then pcall(clear_teleport_queue) end
            QueueAutoExecute()
        end)
    end)
end

local function HopServer()
    pcall(function()
        local servers = {}
        local req = game:HttpGet("https://games.roblox.com/v1/games/" .. HOP_PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100")
        local body = HttpService:JSONDecode(req)
        if body and body.data then
            for _, sv in ipairs(body.data) do
                if type(sv) == "table" and sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                    table.insert(servers, sv.id)
                end
            end
        end
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(HOP_PLACE_ID, servers[math.random(1, #servers)], LocalPlayer)
        else
            TeleportService:Teleport(HOP_PLACE_ID, LocalPlayer)
        end
    end)
end

---------------------------------------------------------
-- หมวด Settings : Advanced / Server / Windows
---------------------------------------------------------
local SettingsCategory = Cascade.Components.Section(Window, {
    Title = "Settings\u{200B}", -- อักขระไร้เสียงต่อท้าย กัน Roblox แปลเป็น "การตั้งค่า"
    Disclosure = false
})

-- ═════════ Advanced ═════════
local AdvancedTab, ServerTab, SettingsTab, ConfigTab -- (กำหนดค่าในบล็อกด้านล่าง เพื่อลดจำนวนตัวแปรท้องถิ่น)
do
AdvancedTab = SettingsCategory:Tab({
    Title = "Advanced",
    Icon = Icon("gearshapeFill", "gearshape")
})

local AdvSection = AdvancedTab:PageSection({
    Title = "⚙️ Advanced Settings",
    Subtitle = "Configure advanced player modifications and tools.",
})
local AdvForm = AdvSection:Form()

local function AddToggle(form, title, subtitle, key, onChange)
    local row = form:Row()
    row:Left():TitleStack({ Title = title, Subtitle = subtitle })
    UiSync.Link(row:Right():Toggle({
        Value = HubConfig[key],
        ValueChanged = function(self, value)
            HubConfig[key] = value and true or false
            if onChange then onChange(value) end
        end
    }), HubConfig, key)
end

AddToggle(AdvForm, "Infinite Jump", "Allow your character to jump infinitely in the air.", "InfiniteJump")
AddToggle(AdvForm, "Anti-AFK", "Prevent being kicked out of the game due to inactivity.", "AntiAFK")
AddToggle(AdvForm, "Auto Rejoin", "Automatically rejoin the game if disconnected or kicked.", "AutoRejoin")
AddToggle(AdvForm, "Anti Admin", "Automatically server hop if an admin joins the game.", "AntiAdmin")
AddToggle(AdvForm,
    "Auto Execute",
    type(queueTeleport) == "function" and "Run the script again after teleporting or rejoining a server."
        or "Not supported by your executor.",
    "AutoExecute",
    ApplyAutoExecute)

-- ───── FPS Lock : ล็อกเฟรมเรตให้ใช้งานได้จริง ─────
-- 1) ใช้ฟังก์ชันล็อก FPS ของ executor ถ้ามี (setfpscap / set_fps_cap / ...)
-- 2) ถ้า executor ไม่มี -> ใช้ตัวจำกัดในสคริปต์ (หน่วงท้ายทุกเฟรม) ล็อกได้ถึง 240 FPS
--    (ตัวนี้กิน CPU ระหว่างรอ แต่ทำให้เฟรมเรตไม่เกินค่าที่ตั้งได้จริง)
-- 3) แถว "Current FPS" แสดง FPS ที่วัดได้จริง ดูได้เลยว่าล็อกทำงานไหม
-- เรียกเองจาก executor ได้: _G.SmoothHubFarm.Fps.Apply() / .Measured / .Mode
local Fps = {}
Farm.Fps = Fps
do
    local RunService = game:GetService("RunService")
    local SOFT_MAX = 240 -- ตัวจำกัดในสคริปต์ใช้ได้ถึงค่านี้ (สูงกว่านี้ต้องพึ่ง executor)

    local candidates = {
        setfpscap, set_fps_cap, setfps,
        syn and syn.set_fps_cap, fluxus and fluxus.set_fps_cap,
    }
    local names = { "setfpscap", "set_fps_cap", "setfps", "syn.set_fps_cap", "fluxus.set_fps_cap" }
    local native, nativeName = nil, nil
    for i = 1, 5 do
        if type(candidates[i]) == "function" then native, nativeName = candidates[i], names[i] break end
    end
    Fps.Native = nativeName -- ชื่อฟังก์ชันที่ executor มี (nil = ไม่มี)

    local function DesiredOn() return HubConfig.EnableFPSLock and true or false end
    local function DesiredLimit() return math.clamp(math.floor(tonumber(HubConfig.FPSLimit) or 144), 1, 9999) end

    Fps.Mode = "off"      -- off | native | software | unsupported
    Fps.Measured = 0      -- FPS ที่วัดได้จริง
    local applied = { on = DesiredOn(), limit = DesiredLimit() }

    -- ตัวจำกัดในสคริปต์: รอให้ครบเวลาต่อเฟรมก่อนจบ RenderStepped
    local softConn = nil
    local function StopSoft()
        if softConn then softConn:Disconnect() softConn = nil end
    end
    local function StartSoft(limit)
        StopSoft()
        local frameTime = 1 / limit
        local last = os.clock()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not Alive() then conn:Disconnect() return end
            local target = last + frameTime
            while os.clock() < target do end
            last = os.clock()
        end)
        softConn = conn
    end

    function Fps.Apply()
        local on, limit = DesiredOn(), DesiredLimit()
        StopSoft()
        if on then
            if native then
                pcall(native, limit)
                Fps.Mode = "native"
            elseif limit >= 9999 then
                Fps.Mode = "off" -- Unlimited = ไม่ต้องจำกัด
            elseif limit <= SOFT_MAX then
                StartSoft(limit)
                Fps.Mode = "software"
            else
                Fps.Mode = "unsupported"
            end
        else
            if native then pcall(native, 9999) end
            Fps.Mode = "off"
        end
        applied.on, applied.limit = on, limit
    end

    -- เรียกทุกวินาที: ถ้าค่าถูกเปลี่ยน (เช่น สลับ Config) ให้ apply ใหม่ / ถ้าเกมรีเซ็ตเพดาน ให้ย้ำค่าเดิม
    function Fps.Reassert()
        local on, limit = DesiredOn(), DesiredLimit()
        if on ~= applied.on or limit ~= applied.limit then
            Fps.Apply()
        elseif on and Fps.Mode == "native" then
            pcall(native, limit)
        end
    end

    -- วัด FPS จริงทุก 0.5 วินาที
    local frames, lastT = 0, os.clock()
    local counter
    counter = RunService.RenderStepped:Connect(function()
        if not Alive() then counter:Disconnect() return end
        frames += 1
    end)
    task.spawn(function()
        while Alive() do
            task.wait(0.5)
            local now = os.clock()
            local dt = now - lastT
            if dt > 0 then Fps.Measured = frames / dt end
            frames, lastT = 0, now
            if Fps.OnUpdate then pcall(Fps.OnUpdate, Fps.Measured, Fps.Mode, Fps.Native) end
        end
    end)

    if DesiredOn() then Fps.Apply() end -- เปิดล็อกไว้ในไฟล์เซฟ = ใช้ทันทีตอนโหลด
end

local FpsSection = AdvancedTab:PageSection({
    Title = "🖥️ FPS",
    Subtitle = "Limit the frame rate of the game."
})
local FpsForm = FpsSection:Form()

AddToggle(FpsForm, "Enable FPS Lock", "Toggle frame rate limiting on or off.", "EnableFPSLock", function(value)
    Fps.Apply()
end)

local FpsMenuRow = FpsForm:Row()
FpsMenuRow:Left():TitleStack({
    Title = "FPS Limit Preset",
    Subtitle = "Choose target frame rate limit."
})
local fpsOptions = { "15 FPS", "30 FPS", "60 FPS", "120 FPS", "144 FPS", "240 FPS", "500 FPS", "1000 FPS", "9999 (Unlimited)" }
local fpsValues = { 15, 30, 60, 120, 144, 240, 500, 1000, 9999 }
local fpsDefaultIndex = table.find(fpsValues, HubConfig.FPSLimit) or 5

local FpsBtn = FpsMenuRow:Right():PullDownButton({
    Label = fpsOptions[fpsDefaultIndex],
    Options = fpsOptions,
    Value = fpsDefaultIndex,
    ValueChanged = function(self, index)
        local target = fpsValues[index]
        HubConfig.FPSLimit = target
        self.Label = fpsOptions[index]
        if HubConfig.EnableFPSLock then Fps.Apply() end
    end
})
StyleDropdown(FpsBtn)
UiSync.Add(function()
    local i = table.find(fpsValues, HubConfig.FPSLimit) or 5
    FpsBtn.Value = i
    FpsBtn.Label = fpsOptions[i]
end)

-- แถวแสดง FPS ที่วัดได้จริง + สถานะการล็อก
local FpsStatusRow = FpsForm:Row()
local FpsStatusStack = FpsStatusRow:Left():TitleStack({
    Title = "Current FPS ( -- )",
    Subtitle = "Measured live so you can see whether the lock is working."
})
Fps.OnUpdate = function(fps, mode, nativeName)
    local text
    if mode == "native" then
        text = "Locked at " .. tostring(HubConfig.FPSLimit) .. " FPS using " .. tostring(nativeName) .. "."
    elseif mode == "software" then
        text = "Locked at " .. tostring(HubConfig.FPSLimit) .. " FPS by the built-in limiter (your executor has no FPS cap function)."
    elseif mode == "unsupported" then
        text = "Can't lock above 240 FPS: your executor has no FPS cap function."
    else
        text = "Lock is off." .. (nativeName and (" Executor supports " .. nativeName .. ".") or " Executor has no FPS cap function (built-in limiter will be used up to 240 FPS).")
    end
    pcall(function()
        FpsStatusStack.Title = "Current FPS ( " .. tostring(math.floor(fps + 0.5)) .. " )"
        FpsStatusStack.Subtitle = text
    end)
end

end

-- ═════════ Server ═════════
do
ServerTab = SettingsCategory:Tab({
    Title = "Server",
    Icon = Icon("globe", "network")
})

local ServerInfoSection = ServerTab:PageSection({
    Title = "🌐 Server Information",
    Subtitle = "Display current server details and identifiers."
})
local ServerInfoForm = ServerInfoSection:Form()

local GameIdRow = ServerInfoForm:Row()
GameIdRow:Left():TitleStack({ Title = "GameId", Subtitle = "The unique ID of this game universe." })
GameIdRow:Right():Label({ Text = tostring(game.GameId) })

local PlaceIdRow = ServerInfoForm:Row()
PlaceIdRow:Left():TitleStack({ Title = "PlaceId", Subtitle = "The specific place ID of this server instance." })
PlaceIdRow:Right():Label({ Text = tostring(game.PlaceId) })

local ServerActionSection = ServerTab:PageSection({
    Title = "💾 Server Actions",
    Subtitle = "Quick tools to copy identifiers or switch servers."
})
local ServerActionForm = ServerActionSection:Form()

local function AddAction(form, title, subtitle, fn)
    local row = form:Row()
    row:Left():TitleStack({ Title = title, Subtitle = subtitle })
    local run
    local btn = row:Right():Button({
        Label = "Execute",
        Callback = function() if run then run() end end
    })
    run = BindButton(btn, fn)
end

AddAction(ServerActionForm, "Copy JobId", "Copy current JobId to clipboard for friends to join.", function()
    CopyText(tostring(game.JobId))
end)

AddAction(ServerActionForm, "Rejoin Server", "Go back to the main world (this map can't be rejoined directly).", function()
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\nRejoining...")
            task.wait()
        end
        TeleportService:Teleport(HOP_PLACE_ID, LocalPlayer)
    end)
end)

AddAction(ServerActionForm, "Server Hop", "Teleport to a different server to find a new one.", HopServer)

end

-- ═════════ Windows ═════════
SettingsTab = SettingsCategory:Tab({
    Title = "Windows",
    Icon = Icon("macwindow", "sliderHorizontal3")
})

local ColorSection = SettingsTab:PageSection({
    Title = "🎨 Customs Color",
    Subtitle = "Customize the appearance and visual style of the interface."
})
local ColorForm = ColorSection:Form()
local ColorRow = ColorForm:Row()
ColorRow:Left():TitleStack({
    Title = "Theme Color",
    Subtitle = "The whole palette, not just light or dark."
})

local colorOptions = AccentOrder
local colorMaps = {}
for index, accentName in ipairs(colorOptions) do
    colorMaps[index] = Cascade.Accents[accentName]
end

local DEFAULT_ACCENT = ConfigStore.DEFAULT_LOOK.Theme -- ธีมเริ่มต้น
local FOLLOW_THEME = "Theme Default"
local CurrentThemeName = table.find(AccentOrder, SavedUi.Theme) and SavedUi.Theme or DEFAULT_ACCENT
local CurrentAccentName = (SavedUi.Accent == FOLLOW_THEME or table.find(AccentOrder, SavedUi.Accent)) and SavedUi.Accent or ConfigStore.DEFAULT_LOOK.Accent
local ACCENT_ONLY_KEYS = { "SwitchAccent", "Selection", "SelectionFocused", "Toggle", "Button" }

local function BuildFinalAccent()
    local base = Cascade.Accents[CurrentThemeName]
    if not base then return nil end
    if CurrentAccentName == FOLLOW_THEME then return base end

    local pick = Cascade.Accents[CurrentAccentName]
    if not pick then return base end

    local combined = { _id = "SmoothHubCustom" }
    for _, mode in ipairs({ "Dark", "Light" }) do
        local set = {}
        for key, value in pairs(base[mode] or {}) do
            set[key] = value
        end
        for _, key in ipairs(ACCENT_ONLY_KEYS) do
            if pick[mode] and pick[mode][key] ~= nil then
                set[key] = pick[mode][key]
            end
        end
        combined[mode] = set
    end

    Cascade.Accents.SmoothHubCustom = combined
    return combined
end

local function ApplyAppearance()
    local finalAccent = BuildFinalAccent()
    if not finalAccent then return end

    App.Accent = finalAccent
    pcall(function()
        if App.SetTheme then
            App:SetTheme(finalAccent)
        elseif Window.RefreshTheme then
            Window:RefreshTheme()
        end
    end)

    task.spawn(function()
        Window.Maximized = not Window.Maximized
        task.wait()
        Window.Maximized = not Window.Maximized

        for _, tab in ipairs({ CharTab, AccountTab, FarmTab, AutoQuestTab, LobbyTab, ProgressionTab, SkillTreesTab, PerksTab, MissionsTab, WaveModeTab, RaidModeTab, WebhookTab, AdvancedTab, ServerTab, SettingsTab, ConfigTab }) do
            if tab.Selected then
                tab.Selected = false
                task.wait()
                tab.Selected = true
                break
            end
        end
    end)
end

local ThemeColorBtn = ColorRow:Right():PullDownButton({
    Label = CurrentThemeName,
    Options = colorOptions,
    Value = table.find(colorOptions, CurrentThemeName) or 1,
    ValueChanged = function(self, index)
        if colorOptions[index] and colorMaps[index] then
            CurrentThemeName = colorOptions[index]
            self.Label = colorOptions[index]
            ApplyAppearance()
        end
    end
})
StyleDropdown(ThemeColorBtn)

local AccentRow = ColorForm:Row()
AccentRow:Left():TitleStack({
    Title = "Accent Color",
    Subtitle = "Only changes icons, switches and buttons. The background stays the same."
})
local accentOptions = { FOLLOW_THEME }
for _, accentName in ipairs(AccentOrder) do
    table.insert(accentOptions, accentName)
end
local AccentColorBtn = AccentRow:Right():PullDownButton({
    Label = CurrentAccentName,
    Options = accentOptions,
    Value = table.find(accentOptions, CurrentAccentName) or 1,
    ValueChanged = function(self, index)
        if accentOptions[index] then
            CurrentAccentName = accentOptions[index]
            self.Label = accentOptions[index]
            ApplyAppearance()
        end
    end
})
StyleDropdown(AccentColorBtn)

-- ถ้าเคยตั้ง Accent Color ไว้ ให้ใช้ทันที (สี Theme ถูกใช้ตั้งแต่ตอนสร้างหน้าต่างแล้ว)
if CurrentAccentName ~= FOLLOW_THEME then
    ApplyAppearance()
end

local BlurSection = SettingsTab:PageSection({
    Title = "✨ Windows Effects",
    Subtitle = "Manage special visual styles for your script window."
})
local BlurForm = BlurSection:Form()

-- ใช้ค่า Blur / Shadow ที่จำไว้ (ต้องตั้งก่อนสร้างสวิตช์ เพราะสวิตช์อ่านค่าจาก Window)
if type(SavedUi.UIBlur) == "boolean" then Window.UIBlur = SavedUi.UIBlur end
if type(SavedUi.Dropshadow) == "boolean" then Window.Dropshadow = SavedUi.Dropshadow end

local BlurRow = BlurForm:Row()
BlurRow:Left():TitleStack({
    Title = "Blur Effect",
    Subtitle = "Enable frosted glass blur effect behind the window."
})
UiSync.Blur = BlurRow:Right():Toggle({
    Value = Window.UIBlur,
    ValueChanged = function(self, value) Window.UIBlur = value end
})

local ShadowRow = BlurForm:Row()
ShadowRow:Left():TitleStack({
    Title = "Shadows Effect",
    Subtitle = "Enable smooth dropshadow around the script window."
})
UiSync.Shadow = ShadowRow:Right():Toggle({
    Value = Window.Dropshadow,
    ValueChanged = function(self, value) Window.Dropshadow = value end
})

local InputSection = SettingsTab:PageSection({
    Title = "⌨️ Input",
    Subtitle = "The shortcut that hides and shows the window."
})
local InputForm = InputSection:Form()
local HotkeyRow = InputForm:Row()
HotkeyRow:Left():TitleStack({
    Title = "Minimize Hotkey",
    Subtitle = "Press to hide or show the window."
})
local currentKeybind = Enum.KeyCode.LeftAlt
pcall(function() currentKeybind = Enum.KeyCode[ConfigStore.DEFAULT_LOOK.Keybind] or Enum.KeyCode.LeftAlt end)
if type(SavedUi.Keybind) == "string" then
    pcall(function()
        local savedKey = Enum.KeyCode[SavedUi.Keybind]
        if savedKey then currentKeybind = savedKey end
    end)
end

UiSync.Hotkey = HotkeyRow:Right():KeybindField({
    Value = currentKeybind,
    ValueChanged = function(self, newKey) currentKeybind = newKey end,
    BindPressed = function(self, key, inputComplete, gameProcessedEvent)
        if inputComplete and not gameProcessedEvent then
            Window.Minimized = not Window.Minimized
        end
    end
})

-- ═════════ Config ═════════
ConfigTab = SettingsCategory:Tab({
    Title = "Config",
    Icon = Icon("folderBadgeGearshape", "folderFill", "folder")
})

do
    local ConfigSection = ConfigTab:PageSection({
        Title = "📁 Configuration",
        Subtitle = "Save your switches under a name (e.g. FarmBoss). Press Enter Save Config to store your changes into the config in use."
    })
    local ConfigForm = ConfigSection:Form()

    local typedName = ""
    local selectedName = nil
    local currentOptions = { "---" }
    local ListBtn
    local RefreshList

    local function AddRow(title, subtitle)
        local row = ConfigForm:Row()
        row:Left():TitleStack({ Title = title, Subtitle = subtitle })
        return row:Right()
    end

    local function AddButtonRow(title, subtitle, label, fn, state)
        local right = AddRow(title, subtitle)
        local props = { Label = label, Callback = function() end }
        if state then props.State = state end
        local ok, btn = pcall(function() return right:Button(props) end)
        if not ok then
            props.State = nil
            btn = right:Button(props)
        end
        BindButton(btn, fn)
        return btn
    end

    local StatusLabel = AddRow("Status", "Result of the last action."):Label({
        Text = canSave and "Ready" or "Can't save files"
    })
    local function SetCfgStatus(text)
        pcall(function() StatusLabel.Text = tostring(text) end)
    end

    local ActiveLabel, AutoloadLabel
    local function UpdateActiveLabel()
        pcall(function()
            local name = ConfigStore.Active()
            if not name then ActiveLabel.Text = "none" return end
            local dirty = ConfigStore.IsDirty(HubConfig)
            if ConfigStore.IsDefault(name) then
                -- config ค่าเริ่มต้นเซฟทับไม่ได้ ถ้ามีการแก้จะขึ้น (modified) ให้ดูเฉย ๆ
                ActiveLabel.Text = dirty and (name .. "  (modified)") or name
            else
                -- โหมดเซฟเอง: ถ้ามีการแก้ที่ยังไม่ได้กด Enter Save Config จะมีคำว่า (unsaved) ต่อท้ายชื่อ
                ActiveLabel.Text = dirty and (name .. "  (unsaved)") or name
            end
        end)
    end
    local function UpdateAutoloadLabel()
        pcall(function() AutoloadLabel.Text = ConfigStore.Autoload() or "none" end)
    end

    -- ชื่อ config: ตัดอักขระต้องห้ามออก รองรับภาษาไทย ยาวสุด 40 ตัวอักษร (ตัดตามตัวอักษร ไม่ตัดกลางตัว)
    local function CleanName(text)
        local t = tostring(text or "")
        t = t:gsub('[%c/\\:*?"<>|]', "")
        t = t:gsub("^%s+", "")
        t = t:gsub("%s+$", "")
        if #t == 0 or not utf8.len(t) then return nil end
        if utf8.len(t) > 40 then t = t:sub(1, utf8.offset(t, 41) - 1) end
        return t
    end

    -- ใช้หน้าตาจาก config: ธีม / Accent / เบลอ / เงา / ปุ่มลัดซ่อนหน้าต่าง (ค่าที่ไม่มีหรือใช้ไม่ได้จะข้าม)
    local function ApplyLook(ui)
        if type(ui) ~= "table" then return end
        local lookChanged = false
        if table.find(AccentOrder, ui.Theme) and ui.Theme ~= CurrentThemeName then
            CurrentThemeName = ui.Theme
            lookChanged = true
        end
        if (ui.Accent == FOLLOW_THEME or table.find(AccentOrder, ui.Accent)) and ui.Accent ~= CurrentAccentName then
            CurrentAccentName = ui.Accent
            lookChanged = true
        end
        pcall(function()
            local ti = table.find(colorOptions, CurrentThemeName) or 1
            ThemeColorBtn.Value = ti
            ThemeColorBtn.Label = colorOptions[ti]
        end)
        pcall(function()
            local ai = table.find(accentOptions, CurrentAccentName) or 1
            AccentColorBtn.Value = ai
            AccentColorBtn.Label = accentOptions[ai]
        end)
        if lookChanged then pcall(ApplyAppearance) end
        if type(ui.UIBlur) == "boolean" then
            pcall(function()
                Window.UIBlur = ui.UIBlur
                UiSync.Blur.Value = ui.UIBlur
            end)
        end
        if type(ui.Dropshadow) == "boolean" then
            pcall(function()
                Window.Dropshadow = ui.Dropshadow
                UiSync.Shadow.Value = ui.Dropshadow
            end)
        end
        if type(ui.Keybind) == "string" then
            pcall(function()
                local key = Enum.KeyCode[ui.Keybind]
                if key then
                    currentKeybind = key
                    UiSync.Hotkey.Value = key
                end
            end)
        end
    end
    ConfigStore.UIApplier = ApplyLook
    ConfigStore.GetUI = function()
        return {
            Theme = CurrentThemeName,
            Accent = CurrentAccentName,
            UIBlur = Window.UIBlur and true or false,
            Dropshadow = Window.Dropshadow and true or false,
            Keybind = currentKeybind and currentKeybind.Name or "LeftAlt",
        }
    end

    -- ชื่อ config ที่ใช้อยู่ (เลือก/โหลด/สร้าง config แล้วชื่อจะขึ้นตรงนี้) + ปุ่มเซฟ
    ActiveLabel = AddRow("Config in use", "The config you picked or created. Your changes belong to this config."):Label({ Text = "none" })

    local AutoSyncToggle = AddRow("Auto-save into config", "ON: every change is saved into the config in use by itself. OFF: only when you press Enter Save Config."):Toggle({
        Value = ConfigStore.AutoSync(),
        ValueChanged = function(self, value)
            value = value and true or false
            if value == ConfigStore.AutoSync() then return end
            ConfigStore.SetAutoSync(value)
            if value then ConfigStore.SyncActive(HubConfig) end
            UpdateActiveLabel()
            SetCfgStatus(value and "Auto-save is ON" or "Auto-save is OFF - use Enter Save Config")
        end
    })

    AddButtonRow("Enter Save Config", "Save the current switches into the config in use.", "Save", function()
        local name = ConfigStore.Active()
        if not name then SetCfgStatus("No config in use - Create or Load one first") return end
        if ConfigStore.IsDefault(name) then SetCfgStatus("Default config is read-only - Create your own config") return end
        if not canSave then SetCfgStatus("Executor can't save files") return end
        local ok = ConfigStore.SaveActive(HubConfig)
        UpdateActiveLabel()
        SetCfgStatus(ok and ("Saved to: " .. name) or "Save failed")
    end)

    -- ชื่อ config
    AddRow("Config name", "Type a name, then press Create."):TextField({
        Placeholder = "Config name",
        Value = "",
        TextChanged = function(self, text) typedName = text end,
        ValueChanged = function(self, value) typedName = value end,
    })

    AddButtonRow("Create config", "Save the current switches under the name above and start using it.", "Create", function()
        local name = CleanName(typedName)
        if not name then SetCfgStatus("Type a config name first") return end
        if ConfigStore.Exists(name) then SetCfgStatus("That name already exists - pick another name") return end
        if not canSave then SetCfgStatus("Executor can't save files") return end
        ConfigStore.SyncActive(HubConfig) -- เซฟ config เดิมที่ใช้อยู่ให้เรียบร้อยก่อน
        local ok = ConfigStore.Put(name, ConfigStore.Snapshot(HubConfig))
        if ok then ConfigStore.SetActive(name) end
        RefreshList(name)
        UpdateActiveLabel()
        SetCfgStatus(ok and ("Created: " .. name) or "Save failed")
    end)

    -- รายการ config
    local ListRow = ConfigForm:Row()
    ListRow:Left():TitleStack({ Title = "Config list", Subtitle = "Choose a saved config." })
    ListBtn = ListRow:Right():PullDownButton({
        Label = "---",
        Options = currentOptions,
        Value = 1,
        ValueChanged = function(self, index)
            local name = currentOptions[index]
            selectedName = (index and index > 1) and name or nil
            self.Label = name or "---"
        end
    })
    StyleDropdown(ListBtn)

    RefreshList = function(keepName)
        local opts = { "---" }
        for _, n in ipairs(ConfigStore.Names()) do opts[#opts + 1] = n end
        currentOptions = opts
        local idx = (keepName and table.find(opts, keepName)) or 1
        selectedName = idx > 1 and opts[idx] or nil
        pcall(function()
            ListBtn.Options = opts
            ListBtn.Value = idx
            ListBtn.Label = opts[idx]
        end)
    end

    AddButtonRow("Load config", "Switch to the selected config and apply its switches.", "Load", function()
        if not selectedName then SetCfgStatus("Select a config first") return end
        local snap = ConfigStore.Get(selectedName)
        if not snap then SetCfgStatus("Config not found - press Refresh list") return end
        local dropped = ConfigStore.Active() ~= nil and not ConfigStore.AutoSync() and ConfigStore.IsDirty(HubConfig)
        ConfigStore.SyncActive(HubConfig) -- โหมดเซฟเอง = ไม่ทำอะไร / โหมดเซฟอัตโนมัติ = เซฟ config เดิมให้ก่อนสลับ
        ConfigStore.SetActive(selectedName)
        ConfigStore.ApplyCfg(snap)
        ConfigStore.ApplyHub(HubConfig, snap)
        Save()
        UiSync.Refresh() -- สวิตช์/สไลเดอร์บนหน้าจอเปลี่ยนตามทันที ไม่ต้องรันสคริปต์ใหม่
        ConfigStore.ApplyUI(snap) -- หน้าตา: ธีม / Accent / เบลอ / เงา / ปุ่มลัด
        UpdateActiveLabel()
        SetCfgStatus("Loaded: " .. selectedName .. (dropped and "  (unsaved changes dropped)" or ""))
    end)

    AddButtonRow("Delete config", "Delete the selected config.", "Delete", function()
        if not selectedName then SetCfgStatus("Select a config first") return end
        local name = selectedName
        if ConfigStore.IsDefault(name) then SetCfgStatus("The default config can't be deleted") return end
        ConfigStore.Delete(name)
        RefreshList(nil)
        UpdateActiveLabel()
        UpdateAutoloadLabel()
        SetCfgStatus("Deleted: " .. name)
    end)

    AddButtonRow("Refresh list", "Reload the saved configs from file.", "Refresh", function()
        ConfigStore.Reload()
        RefreshList(selectedName)
        UpdateActiveLabel()
        UpdateAutoloadLabel()
        pcall(function() AutoSyncToggle.Value = ConfigStore.AutoSync() end)
        SetCfgStatus("List refreshed")
    end)

    AddButtonRow("Set as autoload", "Load the selected config automatically every time the script starts.", "Set", function()
        if not selectedName then SetCfgStatus("Select a config first") return end
        local ok = ConfigStore.SetAutoload(selectedName)
        UpdateAutoloadLabel()
        SetCfgStatus(ok and ("Autoload: " .. selectedName) or "Save failed")
    end)

    AddButtonRow("Reset autoload", "Stop loading a config automatically.", "Reset", function()
        ConfigStore.SetAutoload(nil)
        UpdateAutoloadLabel()
        SetCfgStatus("Autoload reset")
    end)

    AutoloadLabel = AddRow("Current autoload config", "Loaded when the script starts."):Label({ Text = "none" })
    UpdateAutoloadLabel()
    UpdateActiveLabel()
    RefreshList(ConfigStore.Active())

    -- โหมดเซฟเอง: เช็คทุกวินาทีว่ามีการแก้ที่ยังไม่เซฟไหม แล้วอัปเดตป้ายชื่อ config
    task.spawn(function()
        while Alive() do
            if not ConfigStore.AutoSync() then UpdateActiveLabel() end
            task.wait(1)
        end
    end)

    -- รีเซ็ตทุกอย่างกลับเป็นค่าเริ่มต้นของสคริปต์ (config ที่เซฟไว้ไม่ถูกลบ)
    function UiSync.ResetAll()
        ConfigStore.SyncActive(HubConfig)
        ConfigStore.SetActive(nil) -- กัน Reset ไปทับ config ที่กำลังใช้อยู่
        UpdateActiveLabel()
        for key, value in pairs(UiSync.Defaults.Cfg) do
            if type(value) == "table" then
                local copy = {}
                for i, item in ipairs(value) do copy[i] = item end
                Cfg[key] = copy
            else
                Cfg[key] = value
            end
        end
        for key, value in pairs(UiSync.Defaults.Hub) do HubConfig[key] = value end
        Save()
        UiSync.Refresh()

        -- FPS: ใช้ค่าเริ่มต้นทันที (ปิดล็อก = ไม่จำกัด)
        pcall(Farm.Fps.Apply)

        -- หน้าตา: ธีม / สี / เบลอ / เงา / ปุ่มลัดซ่อนหน้าต่าง (ชุดเดียวกับ Config ค่าเริ่มต้น)
        ApplyLook(ConfigStore.DEFAULT_LOOK)
    end

    local resetArmedAt = 0
    AddButtonRow("Reset to defaults", "Set every switch, slider and the window look back to the default values (same as \"Smooth Hub | Default\"). Saved configs are NOT deleted.", "Reset", function()
        -- กดครั้งแรก = ขอยืนยัน กดอีกครั้งภายใน 5 วินาที = รีเซ็ตจริง
        if os.clock() - resetArmedAt > 5 then
            resetArmedAt = os.clock()
            SetCfgStatus("Press Reset again within 5s to confirm")
            return
        end
        resetArmedAt = 0
        UiSync.ResetAll()
        SetCfgStatus("Everything is back to the default values")
    end, "Destructive")


    -- ค่าเปลี่ยนเมื่อไหร่ ให้เซฟลง config ที่ใช้อยู่ด้วย (ตัวเซฟอัตโนมัติเรียกให้)
    SettingsStore.OnSaved = function()
        ConfigStore.SyncActive(HubConfig)
    end
end

---------------------------------------------------------
-- 💾 เริ่มบันทึกอัตโนมัติ: ค่าเปลี่ยนเมื่อไหร่ จะเซฟลงไฟล์ของไอดีนี้เอง
---------------------------------------------------------
SettingsStore.StartAutoSave("AOTR", function()
    return {
        Cfg = Cfg,
        Hub = HubConfig,
        UI = {
            Theme = CurrentThemeName,
            Accent = CurrentAccentName,
            UIBlur = Window.UIBlur,
            Dropshadow = Window.Dropshadow,
            Keybind = currentKeybind and currentKeybind.Name or "LeftAlt",
        },
    }
end)

-- Save() ทั่วสคริปต์ = สั่งให้ Auto Save เขียนไฟล์ทันที
saveHook = function()
    SettingsStore.Flush("AOTR")
    ConfigStore.SyncActive(HubConfig)
end

---------------------------------------------------------
-- ระบบเบื้องหลังของหมวด Settings
---------------------------------------------------------
-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Alive() and HubConfig.InfiniteJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Alive() and HubConfig.AntiAFK then
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)

-- Auto Rejoin (ตอนเด้งออก/โดนเตะ)
pcall(function()
    local errorPrompt = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui", true)
    if errorPrompt then
        errorPrompt.ChildAdded:Connect(function(child)
            if child.Name == "promptOverlay" then
                task.wait(1)
                if Alive() and HubConfig.AutoRejoin then
                    TeleportService:Teleport(HOP_PLACE_ID, LocalPlayer)
                end
            end
        end)
    end
end)

-- Anti Admin
local function CheckAdmin(player)
    if player == LocalPlayer or not HubConfig.AntiAdmin then return end
    pcall(function()
        if player:GetRankInGroup(game.CreatorId) >= 250 or player.UserId == game.CreatorId then
            HopServer()
        end
    end)
end
Players.PlayerAdded:Connect(function(player) if Alive() then CheckAdmin(player) end end)
task.spawn(function()
    while Alive() do
        task.wait(3)
        if HubConfig.AntiAdmin then
            for _, player in ipairs(Players:GetPlayers()) do
                CheckAdmin(player)
            end
        end
    end
end)

-- FPS Lock (ย้ำค่าเรื่อย ๆ เผื่อเกมรีเซ็ต)
task.spawn(function()
    while Alive() do
        pcall(Farm.Fps.Reassert)
        task.wait(1)
    end
end)
end

---------------------------------------------------------
-- 🏝️ แจ้งเตือนตอนโหลดสคริปต์เสร็จ (สไตล์ Dynamic Island แบบ Now Playing)
-- ไหลลงมาจากขอบจอ -> ขยายเป็นการ์ด -> เนื้อหาไล่ขึ้นทีละส่วน -> เก็บกลับแล้วเลื่อนขึ้นหายไป
---------------------------------------------------------
task.spawn(function()
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")

    -- 🖼️ โลโก้ค่าย: ใส่อย่างใดอย่างหนึ่ง (ไม่ใส่ทั้งคู่ = ใช้ตัว S แทน)
    --  1) LOGO_ASSET_ID = เลข ID ของรูป (ต้องเป็น Image ID ที่อัปโหลดบน Roblox แล้ว) เช่น 123456789
    --  2) LOGO_URL = ลิงก์ไฟล์รูป .png บน GitHub (ต้องใช้ executor ที่มี getcustomasset)
    local LOGO_ASSET_ID = nil
    local LOGO_URL = nil

    local function ResolveLogo()
        if LOGO_ASSET_ID then return "rbxassetid://" .. tostring(LOGO_ASSET_ID) end
        if LOGO_URL and type(getcustomasset) == "function" and type(writefile) == "function" then
            local ok, asset = pcall(function()
                local path = "SmoothHub/logo.png"
                if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("SmoothHub") then
                    makefolder("SmoothHub")
                end
                writefile(path, game:HttpGet(LOGO_URL))
                return getcustomasset(path)
            end)
            if ok and asset then return asset end
        end
        return nil
    end
    local logoImage = ResolveLogo()

    pcall(function()
        local old = parent:FindFirstChild("SmoothHubIsland")
        if old then old:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "SmoothHubIsland"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local okParent = pcall(function() gui.Parent = parent end)
    if not okParent or not gui.Parent then gui.Parent = PlayerGui end

    local BLUE = Color3.fromHex("#0A84FF")
    local VIOLET = Color3.fromHex("#5E5CE6")
    local GRAY = Color3.fromRGB(150, 150, 158)

    -- ขนาด: จอแคบ (มือถือ) ให้การ์ดแคบลงและสูงขึ้นนิดหน่อย
    local viewport = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
    local fullW = math.min(400, viewport.X - 24)
    local fullH = fullW < 380 and 132 or 118
    local smallW, smallH = 110, 32
    local TOP = 12

    local function tw(obj, time, props, style, dir)
        local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        t:Play()
        return t
    end

    -- ───── ตัวแคปซูล ─────
    local pill = Instance.new("Frame")
    pill.Name = "Pill"
    pill.AnchorPoint = Vector2.new(0.5, 0)
    pill.Position = UDim2.new(0.5, 0, 0, -smallH - 8) -- เริ่มอยู่นอกจอด้านบน
    pill.Size = UDim2.fromOffset(smallW, smallH)
    pill.BackgroundColor3 = Color3.new(0, 0, 0)
    pill.BackgroundTransparency = 1
    pill.BorderSizePixel = 0
    pill.ClipsDescendants = true
    pill.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, smallH / 2)
    corner.Parent = pill

    -- ขอบเรืองแสงไล่สีฟ้า-ม่วง (หมุนช้าๆ ตอนแสดง)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Transparency = 1
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Parent = pill
    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, BLUE),
        ColorSequenceKeypoint.new(0.5, VIOLET),
        ColorSequenceKeypoint.new(1, BLUE),
    })
    strokeGrad.Parent = stroke

    local function newGroup(name)
        local g = Instance.new("CanvasGroup")
        g.Name = name
        g.BackgroundTransparency = 1
        g.Size = UDim2.fromOffset(fullW, fullH)
        g.Position = UDim2.fromOffset(0, 10)
        g.GroupTransparency = 1
        g.Parent = pill
        return g
    end
    local headGroup = newGroup("Head")
    local barGroup = newGroup("Bar")

    -- ───── ส่วนบน: ไอคอน + ชื่อ + ข้อความ + คลื่นเสียง ─────
    local icon = Instance.new("Frame")
    icon.Size = UDim2.fromOffset(52, 52)
    icon.Position = UDim2.fromOffset(18, 16)
    icon.BackgroundColor3 = BLUE
    icon.BorderSizePixel = 0
    icon.Parent = headGroup
    do
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 13) c.Parent = icon
        if logoImage then
            -- โลโก้ค่าย: เต็มช่องไอคอน มุมมนตามกรอบ
            icon.BackgroundTransparency = 1
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.Image = logoImage
            img.ScaleType = Enum.ScaleType.Crop
            img.Parent = icon
            local ic = Instance.new("UICorner") ic.CornerRadius = UDim.new(0, 13) ic.Parent = img
        else
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new(BLUE, VIOLET)
            g.Rotation = 45
            g.Parent = icon
            local letter = Instance.new("TextLabel")
            letter.BackgroundTransparency = 1
            letter.Size = UDim2.fromScale(1, 1)
            letter.Font = Enum.Font.GothamBlack
            letter.Text = "S"
            letter.TextSize = 28
            letter.TextColor3 = Color3.new(1, 1, 1)
            letter.Parent = icon
        end
    end
    local iconScale = Instance.new("UIScale")
    iconScale.Scale = 0.5
    iconScale.Parent = icon

    local textW = fullW - 82 - 70
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(82, 17)
    title.Size = UDim2.fromOffset(textW, 20)
    title.Font = Enum.Font.GothamBold
    title.Text = "Smooth Hub"
    title.TextSize = 17
    title.TextColor3 = BLUE
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = headGroup

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(82, 39)
    sub.Size = UDim2.fromOffset(textW, 36)
    sub.Font = Enum.Font.GothamMedium
    sub.RichText = true
    sub.TextWrapped = true
    sub.TextSize = 13
    sub.TextColor3 = Color3.fromRGB(215, 215, 222)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextYAlignment = Enum.TextYAlignment.Top
    -- แดง = ชื่อสคริปต์, เขียว = ชื่อค่าย
    sub.Text = 'Loaded <font color="#FF453A">Attack on Titan script</font> by <font color="#30D158">Smooth Hub</font> successfully'
    sub.Parent = headGroup

    local wave = Instance.new("Frame")
    wave.BackgroundTransparency = 1
    wave.Size = UDim2.fromOffset(34, 28)
    wave.Position = UDim2.fromOffset(fullW - 20 - 34, 24)
    wave.Parent = headGroup
    local bars = {}
    for i = 1, 5 do
        local b = Instance.new("Frame")
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Position = UDim2.fromOffset(3 + (i - 1) * 7, 14)
        b.Size = UDim2.fromOffset(3, 8)
        b.BackgroundColor3 = BLUE
        b.BorderSizePixel = 0
        b.Parent = wave
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = b
        bars[i] = b
    end

    -- ───── ส่วนล่าง: แถบความคืบหน้า + แถวสถานะ ─────
    local trackY = fullH - 40
    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(18, trackY)
    track.Size = UDim2.fromOffset(fullW - 36, 4)
    track.BackgroundColor3 = Color3.fromRGB(58, 58, 64)
    track.BorderSizePixel = 0
    track.Parent = barGroup
    do
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = track
    end
    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.new(1, 1, 1)
    fill.BorderSizePixel = 0
    fill.Parent = track
    do
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = fill
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(BLUE, VIOLET)
        g.Parent = fill
    end

    local footL = Instance.new("TextLabel")
    footL.BackgroundTransparency = 1
    footL.Position = UDim2.fromOffset(18, trackY + 10)
    footL.Size = UDim2.fromOffset((fullW - 36) * 0.7, 16)
    footL.Font = Enum.Font.Gotham
    footL.Text = "Attack on Titan Revolution"
    footL.TextSize = 11
    footL.TextColor3 = GRAY
    footL.TextXAlignment = Enum.TextXAlignment.Left
    footL.Parent = barGroup

    local footR = Instance.new("TextLabel")
    footR.BackgroundTransparency = 1
    footR.AnchorPoint = Vector2.new(1, 0)
    footR.Position = UDim2.fromOffset(fullW - 18, trackY + 10)
    footR.Size = UDim2.fromOffset((fullW - 36) * 0.3, 16)
    footR.Font = Enum.Font.GothamBold
    footR.Text = "Ready"
    footR.TextSize = 11
    footR.TextColor3 = Color3.fromHex("#30D158")
    footR.TextXAlignment = Enum.TextXAlignment.Right
    footR.Parent = barGroup

    -- ───── ลูปเอฟเฟกต์ที่เคลื่อนไหวตลอดตอนแสดง (คลื่นเสียง + ขอบหมุน) ─────
    local running = true
    local loopConn
    loopConn = RunService.Heartbeat:Connect(function()
        if not running or not gui.Parent then
            if loopConn then loopConn:Disconnect() end
            return
        end
        local t = os.clock()
        for i, b in ipairs(bars) do
            local h = 6 + 18 * (0.5 + 0.5 * math.sin(t * 6.5 + i * 1.35))
            b.Size = UDim2.fromOffset(3, h)
        end
        strokeGrad.Rotation = (t * 70) % 360
    end)

    local function finish()
        running = false
        pcall(function() if loopConn then loopConn:Disconnect() end end)
        pcall(function() gui:Destroy() end)
    end

    -- ───── เริ่มโชว์ ─────
    -- 1) แคปซูลเล็กไหลลงมาจากขอบจอ
    tw(pill, 0.6, { Position = UDim2.new(0.5, 0, 0, TOP), BackgroundTransparency = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(stroke, 0.6, { Transparency = 0.6 })
    task.wait(0.55)
    if not Alive() then finish() return end

    -- 2) ขยายเป็นการ์ด (มุมโค้งเปลี่ยนจากแคปซูลเป็นการ์ดพร้อมกัน)
    tw(pill, 0.8, { Size = UDim2.fromOffset(fullW, fullH) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(corner, 0.8, { CornerRadius = UDim.new(0, 34) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(stroke, 0.8, { Transparency = 0.15 })

    -- 3) เนื้อหาไล่ขึ้นทีละส่วน
    task.wait(0.3)
    tw(headGroup, 0.55, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(iconScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    task.wait(0.2)
    tw(barGroup, 0.55, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(fill, 1.7, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

    -- 4) ค้างไว้ให้อ่าน
    task.wait(3.2)

    -- 5) เก็บกลับ: เนื้อหาจางลงก่อน -> การ์ดหุบเป็นแคปซูล -> เลื่อนขึ้นหายไปนอกจอ
    tw(barGroup, 0.3, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.wait(0.08)
    tw(headGroup, 0.3, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    tw(iconScale, 0.3, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.wait(0.28)
    tw(pill, 0.7, { Size = UDim2.fromOffset(smallW, smallH) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    tw(corner, 0.7, { CornerRadius = UDim.new(0, smallH / 2) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    tw(stroke, 0.7, { Transparency = 0.6 })
    task.wait(0.75)
    tw(pill, 0.5, { Position = UDim2.new(0.5, 0, 0, -smallH - 8), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tw(stroke, 0.4, { Transparency = 1 })
    task.wait(0.55)
    finish()
end)
