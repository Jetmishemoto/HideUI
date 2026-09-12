
local _VERSION = "v3.0.1"
local re = re
local sdk = sdk
local imgui = imgui
local json = json

local initialized = false

local inCamp = false
local itemBar_Open = false
local worldMap_Open = false
local localMap_Open = false
local MapCloseQueued = false
local mapTransitioning = false
local localMapCloseQueued = false
local localMapFromWorldMap = false
local mapTransitioningFrames = 0
local worldMapFromLocalMap = false
local mapTransitionDelayFrames = 60 -- Adjust this value based on the average duration of the map transition in frames (e.g., 30 frames for ~0.5 seconds at 60fps)

local pauseMenu_Open = false
local isSharpnessLow = false
local isHealthLow = false
local healthTriggered = false
local isStaminaLow = false
local questHasStarted = false
local chatMenu_Open = false
local startSubMenu_Open = false
local actionMessage_Triggered = false
local isActiveQuest = false
local questHasEnded = false
local isWeaponSheathed = true
local weaponActionFrames = 0
local currentActionCategory = 0
local isChargingBow = false
local bowAimingFrames = 0

local frame_counter = 0

-- Placeholder flags to prevent nil errors in Quest Hook
local keyboardSettings_Open = false 
local virtualMouseMenu_Open = false

-- Timer Constants
local START_SUB_MENU_TIMEOUT = 60
local QUEST_START_UI_TIMEOUT = 280


local timers = {}
local active_controls = {}
local active_game_objects = {}
local debug_logged_colorscale = {}

-- local Cache variables ={

    -- local itemBar_GO = nil
    -- local hpBar_GO = nil
    -- local staminaBar_GO = nil
    -- local questList_GO = nil
    -- local map_GO = nil
    -- local mapRing_GO = nil      
    -- local playerNames_GO = nil  
    -- local sharpness_GO = nil    
    -- local mapIcons_GO = nil     -- app.GUI060002
    -- local mapIcons2_GO = nil    -- app.GUI060008
    -- local guiBG_GO = nil        -- app.GUI060001 
    -- local mapGround_GO = nil    -- app.GUI060008 
    -- local guiFront_GO = nil     -- app.GUI060000
    -- local worldMap_GO = nil     -- app.GUI060102
    -- local localMap_GO = nil     -- app.GUI060101 
    -- local itemList_GO = nil     -- app.GUI020200
    -- local slingerInfo_GO = nil  -- app.GUI020017
    -- local partyMemberList_GO = nil -- app.GUI020011
    -- local AimReticle = "app.GUI020019"
--}



--app.HunterCharacter.onGunnerAimAdjust(via.vec3, app.cGunnerAimAdjustParam, System.Nullable`1<via.vec3>) -- only callled when the player is aiming gun or bow

--app.HunterCharacter.doSubActionEnter(ace.ACTION_ID) -- callled when the player is using a sub action like shooting the bow

local UI_ELEMENTS = {

    -- Elements that are hidden based on health/stamina/sharpness thresholds, but still take up space (soft hide)
    { key = "hpBar",           id = "app.GUI020003", name = "Health Bar",        hide_type = "soft", logic = "health" },
    { key = "staminaBar",      id = "app.GUI020004", name = "Stamina Bar",       hide_type = "soft", logic = "stamina" },
    { key = "sharpness",       id = "app.GUI020015", name = "Sharpness",         hide_type = "soft", logic = "sharpness" },

    -- Soft Hide Elements (Hidden based on conditions, but still take up space)
    -- General UI elements that are hidden whenever the player is in camp, has a sub menu open, has the map open, or has started a quest (configurable via conditions)
    { key = "itemBar",         id = "app.GUI020006", name = "Item Bar",          hide_type = "soft", logic = "general" },
    { key = "slingerInfo",     id = "app.GUI020017", name = "Slinger Info",      hide_type = "soft", logic = "general" },
    { key = "playerNames",     id = "app.GUI020016", name = "Player Names",      hide_type = "soft", logic = "general" },
    { key = "partyMemberList", id = "app.GUI020011", name = "Party Member List", hide_type = "soft", logic = "general" },
    { key = "guiBG",           id = "app.GUI060001", name = "GUI Background",    hide_type = "soft", logic = "general" },
    { key = "guiFront",        id = "app.GUI060000", name = "GUI Front",         hide_type = "soft", logic = "general" },
    
    -- Weapon Gauges (Grouped)
    { 
        key = "weaponGauges",
        ids = { 
            "app.GUI020034", -- Charge Blade
            "app.GUI020024", -- Gunlance
            "app.GUI020027", -- Insect Glaive
            "app.GUI020029", -- Switch Axe
            "app.GUI020023", -- Long Sword
            "app.GUI020033", -- Dual Blades
            "app.GUI020030"  -- Hunting Horn
        }, 
        name = "Weapon Gauges", 
        hide_type = "soft", 
        logic = "weapon" 
    },
    
    { 
        key = "aimGauges",
        ids = { 
            "app.GUI020031", -- Bow Reticle
            "app.GUI020019", -- Gun Reticle
            "app.GUI020007"  -- Bow Coatings & Ammo Slider
        }, 
        name = "Aim UI", 
        hide_type = "soft", 
        logic = "aimUI" 
    },
    
    -- Hard Hide Elements
    { key = "questList",       id = "app.GUI020018", name = "Quest List",        hide_type = "hard", logic = "general" },
    { key = "itemList",        id = "app.GUI020200", name = "Item List",         hide_type = "hard", logic = "general" },
    { key = "minimap",         ids = {"app.GUI060010", "app.GUI060008"}, name = "Minimap", hide_type = "hard", logic = "general" },
    { key = "mapIcons",        id = "app.GUI060002", name = "Map Icons",         hide_type = "hard", logic = "general" }
}

-- ==================================
-- CONFIGURATION SYSTEM-----------
-- ===========
local config_filename = "HideUI_Config.json" -- Saves directly to reframework/data/
local config = {
    mod_enabled = true,
    fade_speed = 0.05,
    menu_close_delay = 60,
    hide_weapon_sheathed = true,
    hide_bow_charging = true,
    keep_aim_ui_visible = true,
    health_threshold = 0.75,
    stamina_threshold = 0.40,
    sharpness_threshold = 0.80,
    quest_start_timeout = 280,
    submenu_timeout = 60,
    debug_mode = false,
    ignored_elements = {} -- Stores which UI elements to NEVER hide
}

-- Populate default ignored elements
for _, el in ipairs(UI_ELEMENTS) do
    config.ignored_elements[el.key] = false
end

local function save_config()
    json.dump_file(config_filename, config)
    if config.debug_mode then log.info("[HideUI] Configuration saved.") end
end

local function load_config()
    local loaded_config = json.load_file(config_filename)
    if type(loaded_config) == "table" then
        for k, v in pairs(loaded_config) do 
            if type(v) == "table" and type(config[k]) == "table" then
                -- Safely merge nested tables (like ignored_elements)
                for sub_k, sub_v in pairs(v) do config[k][sub_k] = sub_v end
            else
                config[k] = v
            end
        end
    else
        save_config()
    end
end

load_config()
config.debug_mode = true -- Forced on for debugging

-- ===========================
-- REF UI MENU
-- ===================================

re.on_draw_ui(function()

    if imgui.tree_node("AutoHideUI->" .. _VERSION) then

        local changed, new_val = imgui.checkbox("Enable HideUI Mod", config.mod_enabled)
        if changed then
            config.mod_enabled = new_val
        end

        if imgui.button("Save Configuration") then save_config() end

        imgui.separator()

        imgui.text_colored("Threshold Settings 0 --> 100-  Set the percentage at which the respective UI element will show. ", 0xFFAAAAAA)
        imgui.text_colored("For example, if Health Threshold is set to 0.75, the health bar will always show when health is below 75 percent..", 0xFFAAAAAA)
        
        _, config.fade_speed = imgui.slider_float("UI Fade Speed", config.fade_speed, 0.01, 1.0)
        
        local changed_delay, new_delay = imgui.slider_int("Menu Wake-Up Delay (Frames)", config.menu_close_delay, 60, 300)
        if changed_delay then config.menu_close_delay = new_delay end
        
        changed, config.hide_weapon_sheathed = imgui.checkbox("Hide Weapon Gauges When Sheathed", config.hide_weapon_sheathed)
        if changed then save_config() end
        
        changed, config.hide_bow_charging = imgui.checkbox("Force Hide UI While Charging Bow", config.hide_bow_charging)
        if changed then save_config() end
        
        if config.hide_bow_charging then
            imgui.indent(20)
            changed, config.keep_aim_ui_visible = imgui.checkbox("Keep Aim UI (Reticle/Coatings) Visible", config.keep_aim_ui_visible)
            if changed then save_config() end
            imgui.unindent(20)
        end
        
        imgui.spacing()

        _, config.health_threshold = imgui.slider_float("Health Threshold", config.health_threshold, 0.0, 1.0)
        _, config.stamina_threshold = imgui.slider_float("Stamina Threshold", config.stamina_threshold, 0.0, 1.0)
        _, config.sharpness_threshold = imgui.slider_float("Sharpness Threshold", config.sharpness_threshold, 0.0, 1.0)


        imgui.separator()
        -- Dynamic Menu for Ignored Elements
        if imgui.tree_node("Ignored UI Elements (Always Visible)") then

            imgui.text_colored("Check a box to prevent the script from hiding that element.", 0xFFAAAAAA)
            imgui.spacing()
            
            if imgui.button("Check All (Ignore)") then
                for _, el in ipairs(UI_ELEMENTS) do config.ignored_elements[el.key] = true end
            end
            imgui.same_line()
            if imgui.button("Uncheck All (Hide)") then
                for _, el in ipairs(UI_ELEMENTS) do config.ignored_elements[el.key] = false end
            end
            imgui.text("▽ UI Elements ▽")
        
            for _, el in ipairs(UI_ELEMENTS) do
                local changed, val = imgui.checkbox(el.name, config.ignored_elements[el.key])
                if changed then 
                    config.ignored_elements[el.key] = val 
                end
            end
            imgui.tree_pop()
        end

        imgui.separator()
        _, config.debug_mode = imgui.checkbox("Enable Debug Logging", config.debug_mode)

        imgui.tree_pop()
    end
end)


-- ============================
-- FIND ROOT WINDOW
-- =========
local function find_gui_control_recursive(game_obj)
    if not game_obj then return nil end
    local control = game_obj:call("getComponent(System.Type)", sdk.typeof("via.gui.Control"))
    if control then return control end

    local transform = game_obj:call("get_Transform")
    if not transform then return nil end

    local child_transform = transform:call("get_Child")
    while child_transform do
        local child_obj = child_transform:call("get_GameObject")
        if child_obj then
            local found = find_gui_control_recursive(child_obj)
            if found then return found end
        end
        child_transform = child_transform:call("get_Next")
    end
    
    return nil
end

local function get_parent_root_window(control)
    if not control then return nil end
    local ret = control
    local parent = ret
    while true do
        parent = parent:call("get_Parent")
        if not parent then
            break
        end
        ret = parent
        if ret:call("get_Name") == "RootWindow" then
            break
        end
    end
    if ret and ret:call("get_Name") ~= "RootWindow" then
        return nil
    end
    return ret
end
-- ============================

-- =================
-- TIMER SYSTEM
-- ======================================
local function update_Timers()
    for name, timer in pairs(timers) do
        if timer.value > 0 then
            timer.value = timer.value - 1
            if timer.value <= 0 then
                timer.on_complete()
                timers[name] = nil
            end
        end
    end
end

local function start_Timer(name, duration, callback)
    timers[name] = { 
        value = duration, 
        on_complete = callback 
    }
end

-- ============================================
-- GRAB GAMEOBJECTS
-- ============================
local cached_scene_manager = nil
local cached_scene_manager_type = nil

local function grab_Gui_GameObject(gui_type_string)
    if not cached_scene_manager then
        cached_scene_manager = sdk.get_native_singleton("via.SceneManager")
        cached_scene_manager_type = sdk.find_type_definition("via.SceneManager")
    end
    local scene = sdk.call_native_func(cached_scene_manager, cached_scene_manager_type, "get_CurrentScene()")
    if not scene then return nil end

    local array = scene:call("findComponents(System.Type)", sdk.typeof(gui_type_string))
    if not array or array:call("get_Length") == 0 then return nil end
    
    local gui_component = array:get_Item(0)
    if gui_component then
        return { game_obj = gui_component:call("get_GameObject"), gui_base = gui_component }
    end
    return nil
end

-- =============================
-- SINGLETON & METHOD CALL HELPERS
--================

local function get_singleton(type_name)
    local singleton = sdk.get_managed_singleton(type_name)
    if not singleton then
        log.info("[HideUI] Warning: Could not get singleton:", type_name)
    end
    return singleton
end

-- 
-- Utility to call a method on a singleton and return the result, with error handling   
local function get_singleton_call(type_name, method_name)
    local singleton = get_singleton(type_name)
    if not singleton then return nil end

    local method = sdk.find_type_definition(type_name):get_method(method_name)
    if not method then
        log.info("[HideUI] Warning: Could not find method", method_name, "in", type_name)
        return nil
    end
    return method:call(singleton)
end



local function  SetHideHUD()
    local guiBaseApp = get_singleton("app.GUIBaseApp")
    if not guiBaseApp then return end

    local setHideHudMethod = sdk.find_type_definition("app.GUIBaseApp"):get_method("set_HideHud(System.Boolean)")
    if not setHideHudMethod then
        log.info("[HideUI] Warning: Could not find method set_HideHud in app.GUIBaseApp")
        return
    end

    -- Example usage: Hide the HUD
    setHideHudMethod:call(guiBaseApp, true)
end

-- No longer needed: active_game_objects and hide_GUI functions have been replaced by direct in-loop enforcement



-- =====================
-- STARTUP CHECK
-- =========================================================

-- local function checkIfInCampStartup()
--     local guiManager = get_singleton("app.GUIManager")
--     if not guiManager then return end

--     local currentStageName = guiManager:call("requestStage")
--     local playerCurrentlyInCamp = guiManager:call("requestLifeArea")

--     if playerCurrentlyInCamp then
--         inCamp = true
--         log.info("HideUI: Startup - In Camp")
--     else
--         inCamp = false
--         log.info("HideUI: Startup - Not In Camp")
--     end
-- end





local function resetAllUIStates()
    itemBar_Open = false
    worldMap_Open = false
    localMap_Open = false
    pauseMenu_Open = false
    startSubMenu_Open = false
    mapTransitioning = false
    actionMessage_Triggered = false
    chatMenu_Open = false
end

local function updateStatusCheck(character_obj, component_name, get_func, max_func, threshold)
    if component_name == "weapon" then
        local weapon = character_obj:call("get_Weapon")
        local comp = weapon and weapon:call("get_Sharpness")
        if comp then
            local ratio = comp:call(get_func) / comp:call(max_func)
            return ratio < threshold
        end
    else
        local status = character_obj:call("get_HunterStatus")
        local comp = status and status:get_field(component_name)
        if component_name == "_Health" and comp then comp = comp:get_field("<HealthMgr>k__BackingField") end
        if comp then
            local current = comp:call(get_func)
            local max = comp:call(max_func)
            if current and max and max > 0 then
                if component_name == "_Health" and current <= 0.0 then 
                    resetAllUIStates()
                    log.info("[HideUI] You died! Get it together!! → [Resetting UI states]")
                    return true 
                end
                local ratio = current / max
                return ratio <= threshold
            end
        end
    end
    return false
end


local function updateHunterStatus()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    local player = pm and pm:call("getMasterPlayer")
    local char = player and player:call("get_Character")
    
    if not char then
        isHealthLow, isStaminaLow, isSharpnessLow = false, false, false
        isWeaponSheathed = true
        return
    end

    -- Pass the already fetched 'char' object to save heavy Native Calls
    isHealthLow = updateStatusCheck(char, "_Health", "get_Health", "get_MaxHealth", config.health_threshold)
    isStaminaLow = updateStatusCheck(char, "_Stamina", "get_Stamina", "get_MaxStamina", config.stamina_threshold)
    isSharpnessLow = updateStatusCheck(char, "weapon", "get_SharpnessVal", "get_MaxSharpnessVal", config.sharpness_threshold)
    
    local in_life_area = char:call("get_IsInLifeArea")
    if in_life_area ~= nil then
        inCamp = in_life_area
    end
    
    local mm = sdk.get_managed_singleton("app.MissionManager")
    if mm then
        local currentActive = mm:call("get_IsActiveQuest")
        local currentPlaying = mm:call("get_IsPlayingQuest")
        
        -- The 60-second Quest Complete phase is exactly when the quest is Active, but not Playing!
        -- This inherently handles the 60s timer for us, and instantly drops false if the player quits.
        questHasEnded = (currentActive and not currentPlaying)

        -- If the quest fully transitions out of Active (either returned to camp after 60s, or quit early)
        if isActiveQuest == true and currentActive == false then
            resetAllUIStates()
        end
        isActiveQuest = currentActive
    end
    
    local is_weapon_on = char:call("get_IsWeaponOn")
    if is_weapon_on ~= nil then
        isWeaponSheathed = not is_weapon_on
    end
    
    if weaponActionFrames > 0 or currentActionCategory == 2 then
        isWeaponSheathed = false
    end
    
    local weapon_type = char:call("get_WeaponType")
    isChargingBow = false
    -- weapon_type == 11 is Bow, weapon_type == 12 is LBG, 13 is HBG
    if config.hide_bow_charging and (weapon_type == 11 or weapon_type == 12 or weapon_type == 13) then
        if currentActionCategory == 2 or bowAimingFrames > 0 then
            isChargingBow = true
        end
    end
end


-- ====================
-- HEALTH CHECK LOGIC
-- ====================================
local function updateHealthStatus()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return end

    local player = pm:call("getMasterPlayer")
    if not player then return end

    local character = player:call("get_Character")
    if not character then return end

    local status = character:call("get_HunterStatus")
    if not status then return end

    -- Access Health Component
    local health_comp = status:get_field("_Health")
    if not health_comp then return end

    -- Access Health Manager via Backing Field
    local health_mgr = health_comp:get_field("<HealthMgr>k__BackingField")
    if not health_mgr then return end

    local current = health_mgr:call("get_Health")
    local max = health_mgr:call("get_MaxHealth")

    if current and max and max > 0 then
        local ratio = current / max
        -- IF health is below 75%, show health UI regardless of other states
        if ratio < config.health_threshold then
            isHealthLow = true
        else
            isHealthLow = false
        end
    end
end




-- =========================================================
-- STAMINA CHECK LOGIC
-- =========================================================
local function updatesStaminaStatus()

--app.cHunterStamina
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return end

    local player = pm:call("getMasterPlayer")
    if not player then return end

    local character = player:call("get_Character")
    if not character then return end

    local status = character:call("get_HunterStatus")
    if not status then return end

    -- Access Stamina Component
    local stamina_comp = status:get_field("_Stamina")
    if not stamina_comp then return end


    local current = stamina_comp:call("get_Stamina")
    local max = stamina_comp:call("get_MaxStamina")

    if current and max and max > 0 then
        local ratio = current / max
        -- IF stamina is below 40%, show stamina UI regardless of other states
        if ratio < config.stamina_threshold then
            isStaminaLow = true
        else
            isStaminaLow = false
        end
    end
end

-- ==========================
-- SHARPNESS CHECK LOGIC
-- ==========================================
local function updateSharpnessStatus()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return end

    local player = pm:call("getMasterPlayer")
    if not player then return end

    local character = player:call("get_Character")
    if not character then return end

    -- Access Weapon Component
    local weapon_comp = character:call("get_Weapon")
    if not weapon_comp then return end

    -- Get Sharpness Component
    local sharpness_comp = weapon_comp:call("get_Sharpness")
    if not sharpness_comp then 
        isSharpnessLow = false -- Weapons like Bow/Guns don't have sharpness
        return 
    end

    local current = sharpness_comp:call("get_SharpnessVal")
    local max = sharpness_comp:call("get_MaxSharpnessVal")

    if current and max and max > 0 then
        local ratio = current / max
        -- IF sharpness is below 80%, SHOW the HUD element
        if ratio < config.sharpness_threshold then
            isSharpnessLow = true
        else
            isSharpnessLow = false
        end
    end
end



--------
---Map Transition Logic Methods--------------------------
--------------
local function finishMapTransition()
    mapTransitioning = false
    localMapFromWorldMap = false
    --print("Map transition complete — unblocking")
end

local function clearLingeringVirtualMouse()
    if not mapTransitioning and virtualMouseMenu_Open and not localMap_Open and not worldMap_Open then
        virtualMouseMenu_Open = false
        ---print("Cleared lingering virtualMouseMenu_Open flag")
    end
end

local function resolveConflictingMapStates()
    if localMap_Open and worldMap_Open  then
        --print("Both Local and World Map are marked open! Resetting...")
        -- World map transitioned to local map, so clear world map flag
        worldMap_Open = false
    end
end

local function finalizeQueuedMapClose()
    if localMapCloseQueued then
        localMap_Open = false
        virtualMouseMenu_Open = false
        localMapCloseQueued = false
        --print("Closing map after transition delay (queued)")
    end
end



-- ========
-- HOOK SYSTEM 
-- =========================
local function hook_method(type_str, method_str, callback)
    local t = sdk.find_type_definition(type_str)
    if not t then return end
    local method = t:get_method(method_str)
    if not method then return end
    sdk.hook(method, callback)
end


-- -- Quest Start
-- hook_method("app.cQuestStart", "enter", function()
--     questHasStarted = true
--     print("HideUI: Quest Started - Reinitializing Logic")

--     -- Force re-initialization to catch the camp status change
--     --initialized = false

--     start_Timer("questUI", QUEST_START_UI_TIMEOUT, function()
--         questHasStarted = false
--         inCamp = false -- Force hide after quest start timeout, as we assume player has left camp by then
--         keyboardSettings_Open = false
--         worldMap_Open = false
--         print("HideUI: Quest UI Timeout")
--     end)

--     startSubMenu_Open = false
--     virtualMouseMenu_Open = false
-- end)


-- -----------------------------
-- -----Chat menu-----------
-- ------------------------------

-- hook_method("app.GUIFlowChatLogCommunication",
-- "start(app.GUIFlowChatLogCommunication.BOOT, ace.IGUIFlowHandle)",function()

--     chatMenu_Open = true
--     print("Chat menu opened")
-- end)



-- -- SubMenus (Triggers Timer)
-- hook_method("app.GUIManager", "instantiatePrefab", function()
--     startSubMenu_Open = true
--     print("HideUI: SubMenu Event Triggered")
    
--     -- Start/Restart the timer
--     start_Timer("startSubMenu", START_SUB_MENU_TIMEOUT, function()
--         startSubMenu_Open = false
--         print("HideUI: SubMenu Timer Ended")
--     end)
-- end)

-- -- Leaving Camp 
-- hook_method("app.GUIManager", "requestStage", function()
--     inCamp = false
--     print("Event: Left camp / Stage Request")
-- end)

-- -- Entering/In Camp (Life Area check)
-- hook_method("app.GUIManager", "requestLifeArea", function(retval)

--     inCamp = true
--     print("Event: In Camp") 
-- end)


-- hook_method("app.GUI020008", "onOpenApp", function()
--     itemBar_Open = true
--     print("HideUI: Item bar opened") 
-- end)

-- hook_method("app.GUI020008PartsPallet", "close", function()
--     itemBar_Open = false
--     print("HideUI: Item bar closed")
-- end)





-- --------------
-- ---
-- --------------
-- --World Map 
-- hook_method("app.GUI060102", "onOpen", function()
--     worldMap_Open = true
--         localMapFromWorldMap = true -- flag we're transitioning from world map
--         mapTransitioning = true
--         mapTransitioningFrames = 60
--     print("HideUI: World Map Opened")
-- end)

-- hook_method("app.GUIManager", "isOpenReadyGUI060102", function()
--     worldMap_Open = false
--     if mapTransitioning then
--         --print("World Map closed early — forcibly ending map transition")
--         mapTransitioning = false
--         localMapFromWorldMap = false
--         mapTransitioningFrames = 0
--     end
-- end)

-- ---------------------------
-- -- Map transition start hook
-- --------------------------
-- ---
-- hook_method("app.cGUIMapFlowActive", "enter", function()
--     mapTransitioning = true
--     localMap_Open = true
--     mapTransitioningFrames = 60
--     print("HideUI: Local Map Flow Active - Map Transition Started")
-- end)

-- ----------
-- -- Local Map
-- ------- 
-- -- hook_method("app.GUI060000", "onOpen", function()
-- --     localMap_Open = true
-- --     print("HideUI: Local Map Opened")
-- -- end)



-- -- called when opening local map from world map, and also when opening local map directly (like from camp or quest start) 
-- --app.cGUIMapFlowActive.enter


-- hook_method("app.cGUIMapController", "requestOpen", function()
--     localMap_Open = true
--     mapTransitioning = true
--     mapTransitioningFrames = 60
--     print("HideUI: Local Map Opened")
-- end)


-- hook_method("app.cGUI060000Recommend", "onClose", function()
--     if mapTransitioning and virtualMouseMenu_Open then
--         --print("Skipping map close — mapTransitioning still active")
--         localMapCloseQueued = true
--         return
--     end

--         mapTransitioning = false
--     localMap_Open = false
--     print("HideUI: Local Map Closed via Recommend Close")
-- end)

-- -- hook_method("app.GUIManager", "close3DMap", function()
-- --     localMap_Open = false
-- --     print("HideUI: Local Map Closed via Manager")
-- -- end)

local HOOK_DEFS = {
    -- Quest Hooks
    {
        class = "app.cQuestStart", method = "enter",
        pre = function()
            questHasStarted = true
            if config.debug_mode then log.info("HideUI: Quest Started") end
            log.info("HideUI: Quest Started -> Remember no fainting..... [Resetting UI states for " .. config.quest_start_timeout .. " seconds]")
            start_Timer("questUI", config.quest_start_timeout, function()
                questHasStarted, inCamp, keyboardSettings_Open, worldMap_Open = false, false, false, false
            end)
            startSubMenu_Open, virtualMouseMenu_Open = false, false
        end
    },

    -- Menu & UI Hooks
    {
        class = "app.GUIFlowChatLogCommunication", 
        method = "start(app.GUIFlowChatLogCommunication.BOOT, ace.IGUIFlowHandle)",
        pre = function() chatMenu_Open = true 

        end
    },

   

    -- Item Bar Hooks
    { 
        class = "app.GUI020008", 
        method = "onOpenApp", 
        pre = function() itemBar_Open = true 

        end 
    },

    { 
        class = "app.GUI020008PartsPallet", 
        method = "close",
        pre = function() itemBar_Open = false 
        
        end 
    },

    
    { 
        class = "app.GUI020006", 
        method = "isItemAllSlider",
        pre = function() itemBar_Open = true end
    },

    { 
        class = "app.GUI020006", 
        method = "onClose",
        pre = function() itemBar_Open = false end
    },

    { 
        class = "app.GUI020006", 
        method = "toClose",
        pre = function() itemBar_Open = false end
    },

    -- Health Bar Trigger
    --[[
    {
        class = "app.GUI020003",
        method = "GUITriggered",
        pre = function()
            healthTriggered = true
            start_Timer("healthTrigger", config.submenu_timeout, function() healthTriggered = false end)
        end
    },
    ]]--

    -- Pause Menu Hooks


    -- hook_method("app.GUI030000", "onClose",function()
    --     pauseMenu_Open = false
    --     print("HideUI: Pause Menu Closed")
    -- end)
    {
        class = "app.GUI030000",
        method = "onOpen",
        pre = function() if config.debug_mode then log.info("HideUI: Pause Menu Opened") end
        pauseMenu_Open = true end 
    },
    {
        class = "app.GUI030000",
        method = "updateListItemSubEveryFrame(System.Int32, via.gui.SelectItem, System.Int32)",
        pre = function() 
            pauseMenu_Open = true 
            if timers and timers["pauseMenuCloseDelay"] then
                timers["pauseMenuCloseDelay"] = nil
            end
        end 
    },
    { 
        class = "app.GUI030000", 
        method = "callbackCancelTab(via.gui.Control, via.gui.SelectItem, System.UInt32)", 
        pre = function() 
            -- Delay the hide transition by config frames to prevent input block
            start_Timer("pauseMenuCloseDelay", config.menu_close_delay, function() pauseMenu_Open = false end)
        end 
    },

    -- Camp Hooks
    { 
        class = "app.GUIManager", 
        method = "requestStage", 
        pre = function() 
            inCamp = false 
            if config.debug_mode then log.info("HideUI: Left Camp") end
        end
    },

    { 
        class = "app.GUIManager", 
        method = "requestLifeArea",
        pre = function() 
            inCamp = true 
            if config.debug_mode then log.info("HideUI: Entered Camp") end
        end
    },

    -- Map Hooks
    {
        class = "app.GUI060102", 
        method = "onOpen",
        pre = function() worldMap_Open, localMapFromWorldMap, mapTransitioning, mapTransitioningFrames = true, true, true, config.menu_close_delay end
    },
    {
        class = "app.GUIManager", 
        method = "isOpenReadyGUI060102",
        pre = function()
            worldMap_Open = false
            if mapTransitioning then mapTransitioning, localMapFromWorldMap, mapTransitioningFrames = false, false, 0 end
        end
    },
    {
        class = "app.cGUIMapFlowActive", 
        method = "enter",
        pre = function() mapTransitioning, localMap_Open, mapTransitioningFrames = true, true, config.menu_close_delay end
    },
    {
        class = "app.cGUIMapController", 
        method = "requestOpen",
        pre = function() localMap_Open, mapTransitioning, mapTransitioningFrames = true, true, config.menu_close_delay end
    },
    {
        class = "app.cGUI060000Recommend", 
        method = "onClose",
        pre = function()
            if mapTransitioning and virtualMouseMenu_Open then
                localMapCloseQueued = true
                return
            end
            mapTransitioning, localMap_Open = false, false
        end
    },
    {
        class = "app.GUIManager",
        method = "sendActionMessageToGUI(app.gui_action_message.cGUIActionMessageBaseToGUI)",
        pre = function()
            actionMessage_Triggered = true
            -- Give the UI enough frames to wake up and process queued input
            start_Timer("actionMessage_WakeUp", config.menu_close_delay, function() actionMessage_Triggered = false end)
        end
    }
}

-- Execute Hook Registration
for _, def in ipairs(HOOK_DEFS) do
    local t = sdk.find_type_definition(def.class)
    if t then
        local m = t:get_method(def.method)
        if m then
            sdk.hook(m, def.pre, def.post)
        elseif config.debug_mode then
            log.info("[HideUI] Failed to hook: Method not found -> " .. def.class .. ":" .. def.method)
        end
    elseif config.debug_mode then
        log.info("[HideUI] Failed to hook: Class not found -> " .. def.class)
    end
end


------------------

local function PrintStates()
    log.info(string.format("Camp:%s|Item:%s|WMap:%s|LMap:%s|Pause:%s|Sub:%s|HP:%s|Qst:%s|Chat:%s",
        tostring(inCamp), tostring(itemBar_Open), tostring(worldMap_Open), tostring(localMap_Open),
        tostring(pauseMenu_Open), tostring(startSubMenu_Open), tostring(isHealthLow),
        tostring(questHasStarted), tostring(chatMenu_Open)))
    
end

re.on_script_reset(function()
    log.info("[HideUI] Script disabled/reset. Restoring UI visibility...")
    for _, gui in ipairs(UI_ELEMENTS) do
        local ids_to_process = gui.ids or {gui.id}
        for i, id in ipairs(ids_to_process) do
            if gui.gameObjects and gui.gameObjects[i] and gui.gameObjects[i]:call("get_Valid") then
                
                -- Restore Hard Hide properties
                if gui.hide_type == "hard" then
                    gui.gameObjects[i]:call("set_DrawSelf(System.Boolean)", true)
                    if gui.root_controls and gui.root_controls[i] then
                        pcall(function() gui.root_controls[i]:call("set_ForceInvisible(System.Boolean)", false) end)
                    end
                    if id == "app.GUI060002" then
                        gui.gameObjects[i]:call("set_UpdateSelf(System.Boolean)", true)
                    end
                end

                -- Restore Soft Hide properties
                if gui.hide_type == "soft" and gui.root_controls and gui.root_controls[i] then
                    local color = gui.root_controls[i]:call("get_ColorScale")
                    if color then
                        color.w = 1.0
                        gui.root_controls[i]:call("set_ColorScale(via.Float4)", color)
                    end
                end
                
            end
        end
    end
end)

-- MAIN -------------------------
---------------------------------------------------------
re.on_frame(function()
    
    if weaponActionFrames > 0 then
        weaponActionFrames = weaponActionFrames - 1
    end

    --PrintStates()
    if not initialized then
        initialized = true
        log.info("HideUI initialized->" .. _VERSION,initialized)
    end

    -- Initialize timers 
    if not timers then
        timers = {}
    end


    update_Timers()

    frame_counter = frame_counter + 1
    if frame_counter % 4 == 0 then
        updateHunterStatus()
    end

    if bowAimingFrames > 0 then
        bowAimingFrames = bowAimingFrames - 1
    end



    --------------
    ---3D Map Transition Logic----------------
    -------------
    if mapTransitioning then
        mapTransitioningFrames = mapTransitioningFrames - 1
        if mapTransitioningFrames <= 0 then
            finishMapTransition()
            log.info("Map transition complete — unblocking")
        end
    end



    -- Clear any leftover virtual mouse state
    clearLingeringVirtualMouse()

    -- only one map type should be open
    resolveConflictingMapStates()

    -- Handle any queued map close
    finalizeQueuedMapClose()
    -----------------------------

    -- State Debug
    --PrintStates()

    local is_menu_open =
        itemBar_Open
    or chatMenu_Open
    or localMap_Open
    or worldMap_Open
    or pauseMenu_Open
    or startSubMenu_Open

    local show_general_ui =
        inCamp
    or questHasStarted
    or questHasEnded
    or mapTransitioning
    or actionMessage_Triggered



local conditions = {
        general   = config.mod_enabled and not is_menu_open and (not show_general_ui or isChargingBow),
        health    = config.mod_enabled and not is_menu_open and (not (show_general_ui or isHealthLow or healthTriggered) or isChargingBow),
        stamina   = config.mod_enabled and not is_menu_open and (not (show_general_ui or isStaminaLow) or isChargingBow),
        sharpness = config.mod_enabled and not is_menu_open and (not (show_general_ui or isSharpnessLow) or isChargingBow),
        weapon    = config.mod_enabled and not is_menu_open and (not (show_general_ui or not config.hide_weapon_sheathed or not isWeaponSheathed) or isChargingBow),
        aimUI     = config.mod_enabled and not is_menu_open and (not (show_general_ui or not config.hide_weapon_sheathed or not isWeaponSheathed) or (isChargingBow and not config.keep_aim_ui_visible))
    }

    for _, gui in ipairs(UI_ELEMENTS) do
        -- Support either a single id or an array of ids
        local ids_to_process = gui.ids or {gui.id}
        
        -- Create table to cache game objects if it doesn't exist
        if not gui.gameObjects then gui.gameObjects = {} end
        if gui.last_hide_state == nil then gui.last_hide_state = {} end


        local should_hide = conditions[gui.logic]

        -- OVERRIDE: If the user ignored it in the config, never hide it
        if config.ignored_elements[gui.key] then
            should_hide = false 
        end

        for i, id in ipairs(ids_to_process) do
            -- If the object died (e.g. UI was rebuilt during pause menu), clear it from the cache
            if gui.gameObjects[i] and not gui.gameObjects[i]:call("get_Valid") then
                gui.gameObjects[i] = nil
                gui.last_hide_state[i] = nil
                if gui.root_controls then gui.root_controls[i] = nil end
            end
            
            -- Grab object if it isn't cached
            if not gui.gameObjects[i] then
                local data = grab_Gui_GameObject(id)
                if data then
                    gui.gameObjects[i] = data.game_obj
                    local target_go = data.game_obj
                    
                    -- Many UI elements are dynamically managed by a GUIController.
                    -- We must extract the actual target GameObject from the controller.
                    local control = nil
                    if data.gui_base then
                        -- Direct extraction using the _RootWindow field 
                        pcall(function()
                            control = data.gui_base:get_field("_RootWindow")
                        end)
                        
                        -- Fallback to controller extraction if _RootWindow isn't populated
                        if not control then
                            pcall(function()
                                local gui_ctrl = data.gui_base:call("get_GUIController")
                                if gui_ctrl then
                                    local real_gui = gui_ctrl:call("get_Component")
                                    if real_gui then
                                        local real_go = real_gui:call("get_GameObject")
                                        if real_go then target_go = real_go end
                                    end
                                end
                            end)
                        end
                    end
                    
                    if not control then
                        control = find_gui_control_recursive(target_go)
                    end
                    
                    if control then
                        gui.root_controls = gui.root_controls or {}
                        gui.root_controls[i] = get_parent_root_window(control) or control
                    end
                end
            end

            if gui.gameObjects[i] then
                local current_last_state = gui.last_hide_state[i]
                
                -- Check for state transition
                if current_last_state ~= should_hide then
                    -- Execute state transitions (Hard Hide only needs to run on transition)
                    if gui.hide_type == "hard" then
                        local draw_state = not should_hide
                        gui.gameObjects[i]:call("set_DrawSelf(System.Boolean)", draw_state)
                        if gui.root_controls and gui.root_controls[i] then
                            pcall(function() gui.root_controls[i]:call("set_ForceInvisible(System.Boolean)", should_hide) end)
                        end
                        if id == "app.GUI060002" then
                            gui.gameObjects[i]:call("set_UpdateSelf(System.Boolean)", draw_state)
                        end
                    end
                end
                gui.last_hide_state[i] = should_hide
                
                -- ALWAYS enforce soft hide (ColorScale) every frame because the engine constantly tries to override it
                if gui.hide_type == "soft" and gui.root_controls and gui.root_controls[i] then
                    local color = gui.root_controls[i]:call("get_ColorScale")
                    if color then
                        gui.current_alpha = gui.current_alpha or {}
                        
                        local current = gui.current_alpha[i] or color.w
                        local target = should_hide and 0.0 or 1.0
                        
                        if current ~= target then
                            local fade = config.fade_speed or 0.05
                            if current < target then
                                current = math.min(current + fade, target)
                            else
                                current = math.max(current - fade, target)
                            end
                            gui.current_alpha[i] = current
                        end
                        
                        color.w = current
                        gui.root_controls[i]:call("set_ColorScale(via.Float4)", color)
                    end
                end
            end
        end
    end



end)


--app.GUI030000.updateListItemSubEveryFrame(System.Int32, via.gui.SelectItem, System.Int32) call multi times when pause menu open but when we enter a sub menu the calls stopped

--app.GUI030000.callbackCancelTab(via.gui.Control, via.gui.SelectItem, System.UInt32) call when cloased main pause menu

-- NOTE: When the UI is hidden opening the local map is bugged , the input is block for some reason
-- when this is called the player want to open a menu(ie local map) its also called when closing the local map though
-- app.GUIManager.sendActionMessageToGUI(app.gui_action_message.cGUIActionMessageBaseToGUI)

-- =========================================================
-- MAIN ACTION HOOK (Weapon Attack Detection Fallback)
-- =========================================================
local action_id_type = sdk.find_type_definition("ace.ACTION_ID")
local change_action_method = sdk.find_type_definition("app.HunterCharacter")
if change_action_method then
    change_action_method = change_action_method:get_method("changeActionRequest(app.AppActionDef.LAYER, ace.ACTION_ID, System.Boolean)")
end

if change_action_method and action_id_type then
    sdk.hook(change_action_method, function(args)
        local layer = sdk.to_int64(args[3])
        local action_id = args[4]

        -- We usually only care about the base animation layer (0)
        if layer ~= 0 or not action_id then return end

        local category = sdk.get_native_field(action_id, action_id_type, "_Category")
        
        -- Cache current action category
        currentActionCategory = category

        -- Category 2 is Weapon Attacks / Combat Actions
        if category == 2 then
            -- Set weapon gauge to show for at least 180 frames (approx 3 seconds) after an attack starts
            weaponActionFrames = 180
        end
    end)
end

local on_gunner_aim = change_action_method and sdk.find_type_definition("app.HunterCharacter"):get_method("onGunnerAimAdjust(via.vec3, app.cGunnerAimAdjustParam, System.Nullable`1<via.vec3>)")
if on_gunner_aim then
    sdk.hook(on_gunner_aim, function(args)
        bowAimingFrames = 5
    end)
end



