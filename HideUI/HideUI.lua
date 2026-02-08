local initialized = false

local inCamp = false
local itemBar_Open = false
local worldMap_Open = false
local localMap_Open = false
local MapCloseQueued = false
local mapTransitioning = false
local mapTransitioningFrames = 0
local mapTransitionDelayFrames = 30 -- Adjust this value based on the average duration of the map transition in frames (e.g., 30 frames for ~0.5 seconds at 60fps)
local localMapFromWorldMap = false
local worldMapFromLocalMap = false
local localMapCloseQueued = false

local pauseMenu_Open = false
local isHealthLow = false
local questHasStarted = false
local chatMenu_Open = false
local startSubMenu_Open = false


-- Placeholder flags to prevent nil errors in Quest Hook
local keyboardSettings_Open = false 
local virtualMouseMenu_Open = false

-- Timer Constants
local START_SUB_MENU_TIMEOUT = 60
local QUEST_START_UI_TIMEOUT = 280
local timers = {}


-- Cache variables
local itemBar_GO = nil
local hpBar_GO = nil
local staminaBar_GO = nil
local questList_GO = nil
local map_GO = nil
local mapRing_GO = nil      
local playerNames_GO = nil  
local sharpness_GO = nil    
local mapIcons_GO = nil     -- app.GUI060002
local mapIcons2_GO = nil    -- app.GUI060008
local guiBG_GO = nil        -- app.GUI060001 
local mapGround_GO = nil    -- app.GUI060008 
local guiFront_GO = nil     -- app.GUI060000
local worldMap_GO = nil     -- app.GUI060102
local localMap_GO = nil     -- app.GUI060101 
local itemList_GO = nil     -- app.GUI020200
local slingerInfo_GO = nil  -- app.GUI020017
local partyMemberList_GO = nil -- app.GUI020011




-- =========================================================
-- TIMER SYSTEM
-- =========================================================
local function update_timers()
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

local function start_timer(name, duration, callback)
    timers[name] = { 
        value = duration, 
        on_complete = callback 
    }
end

-- =========================================================
-- GRAB GAMEOBJECTS
-- =========================================================
local function grab_gui_gameobject(gui_type_string)
    local scene_manager = sdk.get_native_singleton("via.SceneManager")
    local scene_manager_type = sdk.find_type_definition("via.SceneManager")
    
    local scene = sdk.call_native_func(
        scene_manager,
        scene_manager_type,
        "get_CurrentScene()"
    )
    
    if not scene then return nil end

    local array = scene:call("findComponents(System.Type)", sdk.typeof(gui_type_string))
    if not array or array:call("get_Length") == 0 then return nil end
    
    local gui_component = array:get_Item(0)
    if not gui_component then return nil end

    return gui_component:call("get_GameObject")
end

-- =========================================================
-- SINGLETON & METHOD CALL HELPERS
local function get_singleton(type_name)
    local singleton = sdk.get_managed_singleton(type_name)
    if not singleton then
        print("[HideUI] Warning: Could not get singleton:", type_name)
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
        print("[HideUI] Warning: Could not find method", method_name, "in", type_name)
        return nil
    end
    return method:call(singleton)
end



-- =========================================================
-- HIDE VISUALS ONLY
-- =========================================================
local function hide_GUI(game_obj, should_hide)
    if not game_obj then return end

    local control = game_obj:call("getComponent(System.Type)", sdk.typeof("via.gui.Control"))
    
    if control then
        -- Magic Switch: Hide pixels, keep logic
        control:call("set_ForceInvisible(System.Boolean)", should_hide)
    else
        game_obj:call("set_DrawSelf(System.Boolean)", not should_hide)
    end
end

-- =========================================================
-- Use this for elements like MapRing that refuse to hide
-- =========================================================
local function hide_GUI_Hard(game_obj, should_hide)
    if not game_obj then return end

    -- logic_state: if should_hide is true, we want logic OFF (false)
    local logic_state = not should_hide

    game_obj:call("set_UpdateSelf(System.Boolean)", logic_state)
    game_obj:call("set_DrawSelf(System.Boolean)", logic_state)
end



-- =====================
-- STARTUP CHECK
-- =========================================================
local function checkIfInCampStartup()
    local guiManager = get_singleton("app.GUIManager")
    if not guiManager then return end

    local currentStageName = guiManager:call("requestStage")
    local playerCurrentlyInCamp = guiManager:call("requestLifeArea")

    if playerCurrentlyInCamp then
        inCamp = true
        print("HideUI: Startup - In Camp")
    else
        inCamp = false
        print("HideUI: Startup - Not In Camp")
    end
end






-- =========================================================
-- HEALTH CHECK LOGIC
-- =========================================================
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
        -- IF health is below 51%, SHOW the HUD
        if ratio < 0.50 then
            isHealthLow = true
        else
            isHealthLow = false
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



-- =========================================================
-- HOOK SYSTEM 
-- =========================================================
local function hook_method(type_str, method_str, callback)
    local t = sdk.find_type_definition(type_str)
    if not t then return end
    local method = t:get_method(method_str)
    if not method then return end
    sdk.hook(method, callback)
end


-- Quest Start
hook_method("app.cQuestStart", "enter", function()
    questHasStarted = true
    print("HideUI: Quest Started - Reinitializing Logic")

    -- Force re-initialization to catch the camp status change
    --initialized = false

    start_timer("questUI", QUEST_START_UI_TIMEOUT, function()
        questHasStarted = false
        inCamp = false -- Force hide after quest start timeout, as we assume player has left camp by then
        keyboardSettings_Open = false
        worldMap_Open = false
        print("HideUI: Quest UI Timeout")
    end)

    startSubMenu_Open = false
    virtualMouseMenu_Open = false
end)



-- SubMenus (Triggers Timer)
hook_method("app.GUIManager", "instantiatePrefab", function()
    startSubMenu_Open = true
    print("HideUI: SubMenu Event Triggered")
    
    -- Start/Restart the timer
    start_timer("startSubMenu", START_SUB_MENU_TIMEOUT, function()
        startSubMenu_Open = false
        print("HideUI: SubMenu Timer Ended")
    end)
end)

-- Hook: Leaving Camp 
hook_method("app.GUIManager", "requestStage", function()
    inCamp = false
    print("Event: Left camp / Stage Request")
end)

-- Hook: Entering/In Camp (Life Area check)
hook_method("app.GUIManager", "requestLifeArea", function(retval)
    -- If the game is checking LifeArea, we assume we are entering/in camp logic
    -- We can also check the return value if this was a PostHook, but PreHook is fine for intent
    inCamp = true
    print("Event: In Camp") -- Commented out to avoid spam
end)


hook_method("app.GUI020008", "onOpenApp", function()
    itemBar_Open = true
    print("HideUI: Item bar opened") 
end)

hook_method("app.GUI020008PartsPallet", "close", function()
    itemBar_Open = false
    print("HideUI: Item bar closed")
end)


-- pasue Menus
hook_method("app.GUI030000", "onOpen",function()
    pauseMenu_Open = true
    print("HideUI: Pause Menu Opened")

end)


hook_method("app.GUI030000", "onClose",function()
    pauseMenu_Open = false
    print("HideUI: Pause Menu Closed")
end)

--------------
---
--------------
--World Map 
hook_method("app.GUI060102", "onOpen", function()
    worldMap_Open = true
        localMapFromWorldMap = true -- flag we're transitioning from world map
        mapTransitioning = true
        mapTransitioningFrames = 60
    print("HideUI: World Map Opened")
end)

hook_method("app.GUIManager", "isOpenReadyGUI060102", function()
    worldMap_Open = false
    if mapTransitioning then
        --print("World Map closed early — forcibly ending map transition")
        mapTransitioning = false
        localMapFromWorldMap = false
        mapTransitioningFrames = 0
    end
end)
--------------------------

----------
-- Local Map
------- 
-- hook_method("app.GUI060000", "onOpen", function()
--     localMap_Open = true
--     print("HideUI: Local Map Opened")
-- end)



-- called when opening local map from world map, and also when opening local map directly (like from camp or quest start) 
--app.cGUIMapFlowActive.enter

hook_method("app.cGUIMapFlowActive", "enter", function()
    mapTransitioning = true
    localMap_Open = true
    mapTransitioningFrames = 60
    print("HideUI: Local Map Flow Active - Map Transition Started")
end)

hook_method("app.cGUIMapController", "requestOpen", function()
    localMap_Open = true
    mapTransitioning = true
    mapTransitioningFrames = 60
    print("HideUI: Local Map Opened")
end)


hook_method("app.cGUI060000Recommend", "onClose", function()
    if mapTransitioning and virtualMouseMenu_Open then
        --print("Skipping map close — mapTransitioning still active")
        localMapCloseQueued = true
        return
    end

        mapTransitioning = false
    localMap_Open = false
    print("HideUI: Local Map Closed via Recommend Close")
end)

-- hook_method("app.GUIManager", "close3DMap", function()
--     localMap_Open = false
--     print("HideUI: Local Map Closed via Manager")
-- end)




------------------------------
-----Chat menu-----------
------------------------------
hook_method("app.GUIFlowChatLogCommunication",
"start(app.GUIFlowChatLogCommunication.BOOT, ace.IGUIFlowHandle)",
    function(args)
        chatMenu_Open = true
        print("Chat menu opened")
end)


------------------

local function PrintStates()
    print(string.format("Camp:%s|Item:%s|WMap:%s|LMap:%s|Pause:%s|Sub:%s|HP:%s|Qst:%s|Chat:%s",
        tostring(inCamp), tostring(itemBar_Open), tostring(worldMap_Open), tostring(localMap_Open),
        tostring(pauseMenu_Open), tostring(startSubMenu_Open), tostring(isHealthLow),
        tostring(questHasStarted), tostring(chatMenu_Open)))
    
end


-- ======================
-- MAIN LOOP-------------------------
-- =========================================================
re.on_frame(function()

    -- Optional: Run the check periodically just to be safe (self-correcting)
    if not initialized then
        checkIfInCampStartup()
        initialized = true
        print("HideUI initialized",initialized)
    end

    -- Initialize timers 
    if not timers then
        timers = {}
    end
    update_timers()
    updateHealthStatus()

    --------------
    ---3D Map Transition Logic----------------
    -------------
        if mapTransitioning then
            mapTransitioningFrames = mapTransitioningFrames - 1
            if mapTransitioningFrames <= 0 then
                finishMapTransition()
                print("Map transition complete — unblocking")
            end
        end

        -- Clear any leftover virtual mouse state
        clearLingeringVirtualMouse()
        -- only one map type should be open
        resolveConflictingMapStates()
        -- Handle any queued map close
        finalizeQueuedMapClose()
    -----------------------------
    ---
    ---
    ---

    -- 1. Cache Objects (Find them if we haven't yet)
    if not map_GO then map_GO = grab_gui_gameobject("app.GUI060011") end
    if not guiBG_GO then guiBG_GO = grab_gui_gameobject("app.GUI060001") end
    if not hpBar_GO then hpBar_GO = grab_gui_gameobject("app.GUI020003") end
    if not mapRing_GO then mapRing_GO = grab_gui_gameobject("app.GUI060010") end
    if not itemBar_GO then itemBar_GO = grab_gui_gameobject("app.GUI020006") end
    if not guiFront_GO then guiFront_GO = grab_gui_gameobject("app.GUI060000") end
    if not itemList_GO then itemList_GO = grab_gui_gameobject("app.GUI020200") end
    if not mapIcons_GO then mapIcons_GO = grab_gui_gameobject("app.GUI060002") end
    if not sharpness_GO then sharpness_GO = grab_gui_gameobject("app.GUI020015") end
    if not questList_GO then questList_GO = grab_gui_gameobject("app.GUI020018") end
    if not mapIcons2_GO then mapIcons2_GO = grab_gui_gameobject("app.GUI060008") end
    if not mapGround_GO then mapGround_GO = grab_gui_gameobject("app.GUI060008") end
    if not staminaBar_GO then staminaBar_GO = grab_gui_gameobject("app.GUI020004") end
    if not playerNames_GO then playerNames_GO = grab_gui_gameobject("app.GUI020016") end
    if not slingerInfo_GO then slingerInfo_GO = grab_gui_gameobject("app.GUI020017") end
    if not partyMemberList_GO then partyMemberList_GO = grab_gui_gameobject("app.GUI020011") end

    -- State Debug
    --PrintStates()

    local show_ui = inCamp
                or itemBar_Open
                or worldMap_Open
                or localMap_Open
                or pauseMenu_Open
                or startSubMenu_Open
                or isHealthLow
                or questHasStarted
                or chatMenu_Open
                or mapTransitioning

    local should_hide_ui = not show_ui

    -- Apply Visibility
    hide_GUI_Hard(mapRing_GO, should_hide_ui)
    hide_GUI_Hard(mapGround_GO, should_hide_ui)

    hide_GUI(mapGround_GO, should_hide_ui)
    hide_GUI(itemBar_GO, should_hide_ui)
    hide_GUI(hpBar_GO, should_hide_ui)
    hide_GUI(staminaBar_GO, should_hide_ui)
    hide_GUI(map_GO, should_hide_ui)
    hide_GUI(mapRing_GO, should_hide_ui)
    hide_GUI(playerNames_GO, should_hide_ui)
    hide_GUI(sharpness_GO, should_hide_ui)
    hide_GUI(questList_GO, should_hide_ui)
    hide_GUI(mapIcons_GO, should_hide_ui)
    hide_GUI(guiBG_GO, should_hide_ui)
    hide_GUI(guiFront_GO, should_hide_ui)
    hide_GUI(itemList_GO, should_hide_ui)
    hide_GUI(slingerInfo_GO, should_hide_ui)
    hide_GUI(partyMemberList_GO, should_hide_ui)


end)