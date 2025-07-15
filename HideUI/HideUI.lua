
local scriptEnabled = true


local initialized = false
local forceShowHUD = false
local uiMask_Open = false
local lastCanOpenPreparingWindow = false
local bountyMenu_Open = false
local startMenu_Open = false
local startSubMenu_Open = false
local startSubMenuTimer = 0
local START_SUB_MENU_TIMEOUT = 60
local equipList_Open = false
local keyboardSettings_Open = false
local photoMode_Open = false
local photoModeTimer = 0
local PHOTO_MODE_TIMEOUT = 30
local virtualMouseMenu_Open = false
local inCamp = false
local localMap_Open = false
local localMapCloseQueued = false
local worldMap_Open = false
local localMapFromWorldMap = false
local gameIsPaused = false
local player_Ready = false
local itemBar_Open = false
local inTent = false
local voiceChatMenu_Open = false
local mapTransitioning = false
local mapTransitioningFrames = 0
local questHasStarted = false
local questUI_Timer = 0
local QUEST_START_UI_TIMEOUT = 190
local questFinishing = false
local networkErrorActive = false
local chatMenu_Open = false


local startedDialogue = false
local lastDialogueState = false


local campSoundPlayed = false

local lastIsActive = nil

local font = nil
local image = nil

local manual_show_override = false



local config = {
    version = "1.0.0",
    hideUI = true, -- Default to hiding UI
    showInCamp = false, -- Default to not showing UI in camp
    showInMap = false, -- Default to not showing UI on map
    showInWorldMap = false, -- Default to not showing UI on world map
    showInMenu = false, -- Default to not showing UI when menu is open
    showInPause = false, -- Default to not showing UI when game is paused
    showInItemBar = false, -- Default to not showing UI when item bar is open
    showInTent = false, -- Default to not showing UI in tent
    showInVoiceChatMenu = false, -- Default to not showing UI when voice chat menu is open
    showInDialogue = false, -- Default to not showing UI when dialogue is started
}
-- -- Path to the config file
-- local configPath = re.get_config_dir() .. "/HideUIConfig.json"
-- local json = require("json")


local function fixConfig()
    if config.version ~= "1.0.0" then
        config.version = "1.0.0"
        json.dump_file(configPath, config)
    end
end



-------------------------
--⌈→→GUI Types←←⌉-------------------------
---------------------------------------------------------------
local gui_types = {
    PlayerHPBar = "app.GUI020003",
    PlayerStamBar = "app.GUI020004",
    ItemBarBottomRight = "app.GUI020006",
    --AmmoBar = "app.GUI020007",
    --ItemWheel = "app.GUI020008",
    TimeOfDayBottomLeft = "app.GUI020009",
    PartyNames = "app.GUI020011",
    ItemBarPopup = "app.GUI020012",
    SharpnessBar = "app.GUI020015",
    PlayerNames = "app.GUI020016",
    QuestListRight = "app.GUI020018",
    --AimReticle = "app.GUI020019",
    Map = "app.GUI060001",
    MapIcons = "app.GUI060002",
    MapPaths = "app.GUI060008",
    MapDarkRing = "app.GUI060010",
}
-------------------------------------------------------------------------------
-------------


local grabbed_guis = {}
local timers = {}

--app.GUIActionGuideParamGetter.checkCurrentAmmoToShoot_Light()
------------⌈→→hook helper←←⌉---------------
------------
local function hook_method(type_str, method_str, callback)
    local t = sdk.find_type_definition(type_str)
    if not t then
        print(" Failed to find type:", type_str)
        return
    end

    local method = t:get_method(method_str)
    if not method then
        print("Failed to find method:", method_str)
        return
    end

    sdk.hook(method, callback)
end




local function update_timers()
    for name, timer in pairs(timers) do
        if timer.value > 0 then
            timer.value = timer.value - 1
            if timer.value <= 0 then
                timer.on_complete()
                timers[name] = nil -- remove finished timer
            end
        end
    end
end


-- Start a new timer
-- name: string (unique id), duration: int (frames), callback: function
local function start_timer(name, duration, callback)
    timers[name] = {
        value = duration,
        on_complete = callback
    }
end


-- Get player
local function getPlayer()
    local playerManager = sdk.get_managed_singleton("app.PlayerManager")
    if not playerManager then return nil end
    return playerManager:call("getMasterPlayer")
end



--Grab GUI GameObject
local function grab_gui_gameobject(gui_type_string)
    local scene = sdk.call_native_func(
        sdk.get_native_singleton("via.SceneManager"),
        sdk.find_type_definition("via.SceneManager"),
        "get_CurrentScene()"
    )
    if not scene then
        print("Could not get current scene")
        return nil
    end

    local array = scene:call("findComponents(System.Type)", sdk.typeof(gui_type_string))
    local gui_component = array:get_Item(0)
    if not gui_component then
        print("Failed to get component for:", gui_type_string)
        return nil
    end

    local game_obj = gui_component:call("get_GameObject")
    if not game_obj then
        print("Failed to get GameObject for:", gui_type_string)
        return nil
    end

    return game_obj
end


--  check if communication menu is open
local function isCommunicationOpen()
    local util = sdk.find_type_definition("app.CommunicationUtil")
    if not util then return false end
    local method = util:get_method("isOpen")
    if not method then return false end
    return method:call(nil)
end

local function get_singleton(type_name)
    local singleton = sdk.get_managed_singleton(type_name)
    if not singleton then
        print("[HideUI] Warning: Could not get singleton:", type_name)
    end
    return singleton
end


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


local function get_type_definition(type_name)
    local t = sdk.find_type_definition(type_name)
    if not t then
        print("[HideUI] Warning: Could not find type definition: " .. tostring(type_name))
    end
    return t
end

local function get_gui_manager()
    local gui_manager = sdk.get_managed_singleton("app.GUIManager")
    if not gui_manager then
        print("[HideUI] Warning: Could not get app.GUIManager singleton")
    end
    return gui_manager
end



--------------------- Check if player is in camp at startup--------------
local function checkIfInCampStartup()
    local guiManager = get_singleton("app.GUIManager")
    if not guiManager then
        print("GUIManager not available at startup")
        return
    end

    local currentStageName = guiManager:call("requestStage")
    local playerCurrentlyInCamp = guiManager:call("requestLifeArea")

    if playerCurrentlyInCamp then
        inCamp = true
        print("Player already in camp on script load")
    elseif currentStageName then
        inCamp = false
        print("Player not in camp on script load")
    else
        -- Neither returned valid data
        inCamp = false
        print("Couldn't determine camp status on script load")
        print("in camp status: " .. tostring(inCamp))
    end
    
end


--------------------------
-------------------------
    --Detect end-of-quest----------------------------------------------
---------------------
--------------------
--app.cQuestStart.enter()
    local Get_QuestDirector = hook_method("app.MissionManager","get_QuestDirector")
    local Get_IsPlayingQuest = hook_method("app.MissionManager","get_IsPlayingQuest")
    local missionManager = get_singleton("app.MissionManager")
    local Get_IsActiveQuest = hook_method("app.MissionManager","get_IsActiveQuest")
-------------------------------------------------------------------------------------------------------------------------
----

-----------------
--------- Dialogue detection for Alma?----------------------------------------------
---------------------
local DialogueManager = get_singleton("app.DialogueManager")
local IsSpecificDialogue = DialogueManager
and get_type_definition("app.DialogueManager"):get_method("isOngoingSpecificSituationDialogue")



-- app.DialogueManager.endPause ---- called when the first dialogue ends when talking to alma in the field and then shows UI
--app.DialogueManager.getMainTalkerGameObject
-- app.DialogueManager.requestStart




-----PauseManager-----------------------------
hook_method("app.PauseManager", "onAllRequestExecuted",
    function(retval)

    if inTent then
        print("Don't change pause state if in tent")
        return
    end
    if questHasStarted then
        print("Don't change pause state if quest has started")
        return
    end

    local pauseManager = get_singleton("app.PauseManager")
    if pauseManager then
        local isPaused = pauseManager:call("get_IsPaused")
        gameIsPaused = isPaused
        print(isPaused and "PauseManager.Game paused" or "PauseManager.Game resumed")
        print("PauseManager.IsPaused:", isPaused)
    else
        print("Could not get PauseManager")
    end
    return retval
end)
-------------------------------------------------------------

--app.PauseManager.setRayTracePause






-- VoiceChatMenu---------------------------------------------|

-- Voice Chat Menu (Keyboard)
hook_method(
    "app.cGUICommonMenu_VoiceChat",
    "execute(app.MenuDef.ExecuteFrom, System.Object, app.cGUICommonMenuItemExecuteOptionBase, ace.IGUIFlowHandle)",
    function(args)
        voiceChatMenu_Open = true
        print("Voice chat menu executed")
    end)
--
------------------------------Voice Chat Menu (Controller)
--
hook_method(
    "app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList",
    "onOpen",
    function(args)
        voiceChatMenu_Open = true
        print(" Voice chat list opened (controller)")
    end)
--------------------------------------------
---




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



---app.GUIManager.setNetworkRequestEnd
---"app.GUI040000", onOpen?
hook_method("app.GUI040000",
"<updateCircleData>b__115_4(System.Boolean, app.NETWORK_ERROR_CODE)",
    function(args)
        local is_error = args[2] == true
        local error_code = args[3]:call("ToString")

        print("Network error callback:", is_error, error_code)

        if is_error then
            networkErrorActive = true
            print("Network error detected, locking UI transitions.")
        else
            networkErrorActive = false
            print("Network error cleared.")
        end
end)


------------------------------
-----Chat menu-----------
------------------------------
hook_method("app.GUIFlowChatLogCommunication",
"start(app.GUIFlowChatLogCommunication.BOOT, ace.IGUIFlowHandle)",
    function(args)
        chatMenu_Open = true
        print("Chat menu opened")
end)

-- hook_method("ace.GUIManager","refreshChatLog",
--     function()
--             chatMenu_Open = false
--             print("Chat menu closed")
--     end)
-------------------------------------------------
---


---@param game_obj userdata  -- REManagedObject via.GameObject
---@param state boolean      -- true = show, false = hide
local function set_gui_visibility(game_obj, state)
    if not game_obj then
        print("[HideUI] set_gui_visibility: game_obj is nil")
        return
    end

    local set_DrawSuccess = game_obj:call("set_DrawSelf(System.Boolean)", state)
    local set_UpdateSelfSuccess = game_obj:call("set_UpdateSelf(System.Boolean)", state)

    if not set_DrawSuccess or not set_UpdateSelfSuccess then
        print("[HideUI] Warning: Failed to set DrawSelf or UpdateSelf for GUI element.")
    end
end










---@param gui_types_table table<string, string>
---@return table<string, userdata>  -- grabbed_guis
local function grab_all_guis_and_hide(gui_types_table)
    local grabbed_guis = {}

    for name, type_string in pairs(gui_types_table) do
        local game_obj = grab_gui_gameobject(type_string)
        if game_obj then
            -- Hide immediately
            set_gui_visibility(game_obj, false)
            grabbed_guis[name] = game_obj
            print("[HideUI] Grabbed and hid:", name)
        else
            print("[HideUI] Failed to grab:", name)
        end
    end

    return grabbed_guis
end



---@param gui_types_table table<string, string>
---@return table<string, userdata>  -- grabbed_guis
local function grab_all_guis_and_show(gui_types_table)
    local grabbed_guis = {}

    for name, type_string in pairs(gui_types_table) do
        local game_obj = grab_gui_gameobject(type_string)
        if game_obj then
            -- Hide immediately
            set_gui_visibility(game_obj, true)
            grabbed_guis[name] = game_obj
            print("[HideUI] Grabbed and showing:", name)
        else
            print("[HideUI] Failed to grab:", name)
        end
    end

    return grabbed_guis
end




---------
---------⌈→→Hook list←←⌉------------------------------------------------------------------------------------⌈→→Hook list←←⌉--------
---------
local hook_definitions = {

    --Camp Area
        {"app.GUIManager", "requestLifeArea", function()

            inCamp = true
            grab_all_guis_and_show(gui_types)
            print("Entered camp")
            print("HUD Active")

        end },
        --Laving Camp Area
        { "app.GUIManager", "requestStage", function()

            inCamp = false
            grab_all_guis_and_hide(gui_types)
            print("Left camp")
            print("HUD Inactive")
            end },
    ----------------------------------------------------------------------------------------
    -- Radar mask ckeck------------------------ This openes whenever the normal UI is up
        { "app.cGUIMapFlowOpenRadarMask", "enter", function()
            
            keyboardSettings_Open = false;
            startMenu_Open = false;
            startedDialogue = false;
            localMap_Open = false;
            chatMenu_Open = false;
            print("RadarMask.enter ")

        end },

    -- Pause Menu-----------------------------------------------------------
        { "app.GUI030000", "onOpen", function()


            startMenu_Open = true;
            startSubMenu_Open = false;
            keyboardSettings_Open = false;
            print("Opened pause menu")

        end },
    ---Pause Menu Close
        { "app.GUI030000", "onClose", function()

            startMenu_Open =false
            uiMask_Open = false
            equipList_Open = false
            print("Closed pause menu")
            print("SubMenu Closed")

        end },
    -----------------------------
    ----------------------------------------------------------------------------------
    ------------------------------
    --Starting SubMenus------
        { "app.GUIManager", "instantiatePrefab", function()
            
            startSubMenu_Open = true
            start_timer(startSubMenuTimer,START_SUB_MENU_TIMEOUT, function()
                startSubMenu_Open = false
                startSubMenuTimer = 0
                questFinishing = false

                --print("SubMenuTimer:", startSubMenuTimer)
                print("Start SubMenu Closed — timer ended")
            end)
            --startSubMenuTimer = START_SUB_MENU_TIMEOUT
            print("Start SubMenu Open — timer started")
            print("Start SubMenu Open")

        end },

    -- --Selecting submenu item?
    --     { "app.GUI030000", "executeItem(app.user_data.StartMenuData.ItemBase)", function()

    --         print("Start SubMenu selected")
    --     end },

    ----------------------------------------------------------------------------------  
    --------
    --EquipList
        { "app.GUI080001","onOpen", function()
            
            equipList_Open = true
            print("Opened EquipList menu")

        end },
        { "app.GUI080001","onClose", function()
        
            equipList_Open = false
            print("Closed EquipList menu")

        end },



    -------------------------------------------------------------
    ---------------------
    ---Photograph Mode---------------------------------------------------
        { "app.mcPhotograph","updatePhotoModeGUIOpenCheck",function()
            
            photoMode_Open = true
                start_timer("photoMode", PHOTO_MODE_TIMEOUT, function()
                    photoMode_Open = false
                    keyboardSettings_Open = false
                    print("Photo Mode timeout — hiding UI")
            end)
                --print("Photograph Mode Opened")
        end },

    --Keyboard Settings---------------------------------------------------
        { "app.GUI030000","executeItem(app.user_data.StartMenuData.ItemBase)",function()
            
            keyboardSettings_Open = true
            print("KeyboardSettings Opened")
        end },


        ----Bounty List ----------------------------------------------------
        { "app.GUI090800", "onOpen", function()
            
            bountyMenu_Open = false; print("Closed pause menu") 

            end },
    -------------------------------------------------------------------------------
    ---
    -------------------
    -- Virtual Mouse Menus-----------------------------------------------
    --------------------
        { "app.GUIManager", "onSetVirtualMouse", function()
            
            if not virtualMouseMenu_Open then
            -- Only set to true if it wasn't already open
            virtualMouseMenu_Open = true
            --print("Main virtual menu open", virtualMouseMenu_Open)
            end

        end },
    ----------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------


    ------------------------
    -- Open LocalMap---------------------------------------------------------
        { "app.cGUIMapController", "requestOpen", function()

            mapTransitioning = true
            mapTransitioningFrames = 60

            localMap_Open = true

            if localMapFromWorldMap then
                print("Switching from World Map → Local Map")
                -- stay in world map mode until confirmed transition is done
                return
            end
            print("Local Map Opened")

        end },
    -- Closed LocalMap------------------------------
        { "app.GUIManager", "close3DMap", function()
            
            if mapTransitioning and virtualMouseMenu_Open then
                --print("Skipping map close — mapTransitioning still active")
                localMapCloseQueued = true
                return
            end

            -- At this point, either virtualMouseMenu was cleared or it doesn't matter
            localMap_Open = false
            virtualMouseMenu_Open = false
            --print("Local Map closed, options menu closed")
        
        end },
    ----------------------------------------------------------------------------------------------------------  
    ----------------
    ----------World Map----------------------------------------------------
    -----------------
        { "app.GUI060102", "onOpen", function()
            
            worldMap_Open = true
            localMapFromWorldMap = true -- flag we're transitioning from world map
            mapTransitioning = true
            mapTransitioningFrames = 60
            startSubMenu_Open = false
            --print("World Map Opened")
        end },
        { "app.GUIManager", "isOpenReadyGUI060102", function()
            
            worldMap_Open = false
            if mapTransitioning then
                --print("World Map closed early — forcibly ending map transition")
                mapTransitioning = false
                localMapFromWorldMap = false
                mapTransitioningFrames = 0
            end
            --print("WorldMap Closed")
        end },
    ----------------------------------------------------------------------------------------------------------
    ---
    -- Item Bar---------------------------------------------------
        { "app.GUI020008", "onOpenApp", function()
            
            itemBar_Open = true
            grab_all_guis_and_show(gui_types)
            print("Item bar opened")

        
        end },
        { "app.GUI020008PartsPallet", "close", function()
            
            itemBar_Open = false;
            grab_all_guis_and_hide(gui_types)
            print("Item bar closed")

        end },
    ----------------------------------------------------------------------------------
    ---
    -- Entering Tent-------------------------------------------------------
        { "app.GUIManager", "startTentMenu", function()
            inTent = true
            print("In Tent")
        end },

        --Exiting Tent
        { "app.cGUISystemModuleOpenTentMenu", "exitTent(app.FacilityMenu.TYPE)",function()
                inTent = false
                print("Exiting Tent")
        end },

        ---------
        -- VoiceChatMenu----------------------------------------------
        { "app.GUI040001", "guiDestroy", function()
        
            voiceChatMenu_Open = false; print("Voice chat list Closed") 

            end },
        -----------------------------

        -- Quest Start
        { "app.cQuestStart", "enter", function()
            
            questHasStarted = true
            start_timer("questUI", QUEST_START_UI_TIMEOUT, function()
                questHasStarted = false
                keyboardSettings_Open = false
                print("Quest UI timeout — hiding UI")
            end)
                startSubMenu_Open = false
                virtualMouseMenu_Open = false
                print("Quest Started Showing UI")
        end },
        ---------------------
        -- Quest End
        { "app.GUI020202", "onOpen", function()
            
            questHasStarted = false
            questFinishing = true
            print("Quest Ended")

        end },

        -- Player starts talking to NPC
        { "app.DialogueManager", "getMainTalkerGameObject", function()
            
            --app.DialogueManager.getMainTalkerGameObject
            startedDialogue = true
            --print("Dialogue started")
        end },
}

    ----------------------------------------------------------------------------------
    ------------→→End Hook list←←-----------------------------------------------------------------------------------------→→End Hook list←←


----------------------------------------------------------
----------------Initialize hooks---------------
----------------------------------------------------------------------------------
for _, h in ipairs(hook_definitions) do
    hook_method(h[1], h[2], function(args)
        h[3]()
    end)
end
----------------------
-------------------------------------------------------------------------------
------------------------



--Initialize grabbed_guis table
local function initialize_gui_references()
    for name, gui_type in pairs(gui_types) do
        local game_obj = grab_gui_gameobject(gui_type)
        if game_obj then
            grabbed_guis[name] = game_obj
            print("[HideUI] Grabbed:", name, "->", gui_type)
        else
            print("[HideUI] Failed to grab:", name, "->", gui_type)
        end
    end
end




----------------------------------------------------------------------------



local function printAllUIStates()
    print("<===== UI STATE DUMP =====>")
    print("uiMask_Open:             ", uiMask_Open)
    print("bountyMenu_Open:         ", bountyMenu_Open)
    print("startMenu_Open:          ", startMenu_Open)
    print("startSubMenu_Open:       ", startSubMenu_Open)
    print("startSubMenuTimer:       ", startSubMenuTimer)
    print("equipList_Open:          ", equipList_Open)
    print("keyboardSettings_Open:   ", keyboardSettings_Open)
    print("photoMode_Open:          ", photoMode_Open)
    print("photoModeTimer:          ", photoModeTimer)
    print("virtualMouseMenu_Open:   ", virtualMouseMenu_Open)
    print("inCamp:                  ", inCamp)
    print("localMap_Open:           ", localMap_Open)
    print("localMapCloseQueued:     ", localMapCloseQueued)
    print("worldMap_Open:           ", worldMap_Open)
    print("localMapFromWorldMap:    ", localMapFromWorldMap)
    print("gameIsPaused:            ", gameIsPaused)
    print("player_Ready:            ", player_Ready)
    print("itemBar_Open:            ", itemBar_Open)
    print("inTent:                  ", inTent)
    print("voiceChatMenu_Open:      ", voiceChatMenu_Open)
    print("startedDialogue:         ", startedDialogue)
    print("mapTransitioning:        ", mapTransitioning)
    print("mapTransitioningFrames:  ", mapTransitioningFrames)
    print("questHasStarted:         ", questHasStarted)
    print("<==========================>")
end

local function set_all_guis_visibility(state)
    for name, game_obj in pairs(grabbed_guis) do
        set_gui_visibility(game_obj, state)
    end
end



---------------------------------------
------------------------
-- Main frame update-------------------------------
--------------------
re.on_frame(function()
    

    if not initialized then
        checkIfInCampStartup()
        initialize_gui_references()
        initialized = true
        print("HideUI initialized",initialized)
    end

    -- Initialize timers 
    if not timers then
        timers = {}
    end
    update_timers()

    if player_Ready then
        printAllUIStates()
    end

    --Wait until player is ready----------------
    if not player_Ready then
        if getPlayer() ~= nil then
            player_Ready = true
            print("Player is ready")
        end
        return -- Don't proceed with GUI logic yet
    end





-------------------
------------ GUISubMenu Detection----------------------
--------------------
    local gui_manager = get_gui_manager()
    if gui_manager then
        local canOpenPreparingWindow = gui_manager:call("isCanOpenPreparingWindow")

        -- Detect rising edge: false -> true
        if canOpenPreparingWindow and not lastCanOpenPreparingWindow then
            startSubMenu_Open = true
            start_timer("startSubMenu", START_SUB_MENU_TIMEOUT, function()
                startSubMenu_Open = false
                startSubMenuTimer = 0
                questFinishing = false
                print("Start SubMenu Closed — timer ended")
            end)

            print("StartSubMenu detected via isCanOpenPreparingWindow")
        end

        lastCanOpenPreparingWindow = canOpenPreparingWindow

    end
------------------------------------------------------------------

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
    -------------------------------------------
    --End 3D Map Transition Logic----------------
    ----------------------------------------------- 
    ------------------------------------------------------------------


-----------------
----Quest Detection-----------------------------------
------------------
    -- Check if the quest is completed after reward screen
        if missionManager and Get_IsActiveQuest then
            local isActive = Get_IsActiveQuest:call(missionManager)
            if isActive ~= lastIsActive then
                lastIsActive = isActive
                print("MissionManager:IsActiveQuest changed :", isActive)
                if not isActive then
                    startSubMenu_Open = false
                    questFinishing = false
                    print("Quest ended or loading screen started — closing startSubMenu")
                end
            end
        end
--------------------------------------------------------------

--app.DialogueManager.<updateMainTalkPlayer>g__findNearestGossipDialogue|257_2(System.Collections.ObjectModel.ReadOnlyCollection`1<ace.cDialogueTalkPlayerBase>)
--app.DialogueManager.getActualNpcId


---------------------------------
    ---Dialogue detection----------------------
-----------------------------------
        if DialogueManager and IsSpecificDialogue then
    local isTalking = IsSpecificDialogue:call(DialogueManager)

    if isTalking ~= lastDialogueState then
        lastDialogueState = isTalking
        startedDialogue = isTalking

        if isTalking then
            print("Player started NPC dialogue")
        else
            print("Player ended NPC dialogue")

            startMenu_Open = false
            worldMap_Open = false
            localMap_Open = false
            startedDialogue = false
        end
    end
end

local currentState = "hideUI"

-- -- Emergency manual show override with "*""
-- if imgui.is_key_pressed(0x6A) then  --(*)
--     manual_show_override = not manual_show_override
--     if manual_show_override then
--         print("[HideUI] Manual override: UI forced VISIBLE (F11 toggled ON)")
--         set_all_guis_visibility(true)
--     else
--         print("[HideUI] Manual override: Returning UI control to state machine (F11 toggled OFF)")
--         -- Immediately re-sync visibility
--         if currentState == "hideUI" then
--             set_all_guis_visibility(false)
--         else
--             set_all_guis_visibility(true)
--         end
--     end
-- end
---------------------
------- State Tracking
------------------------------
        local activeStates = {}
        if inCamp then table.insert(activeStates, "inCamp") end
        if inTent then table.insert(activeStates, "inTent") end
        if uiMask_Open then table.insert(activeStates, "uiMask_Open") end
        if gameIsPaused then table.insert(activeStates, "gamePaused") end
        if itemBar_Open then table.insert(activeStates, "itemBar_Open") end
        if chatMenu_Open then table.insert(activeStates, "chatMenu_Open") end
        if worldMap_Open then table.insert(activeStates, "worldMap_Open") end
        if localMap_Open then table.insert(activeStates, "localMap_Open") end
        if questFinishing then table.insert(activeStates, "questFinished") end
        if startMenu_Open then table.insert(activeStates, "startMenu_Open") end
        if photoMode_Open then table.insert(activeStates, "photoMode_Open") end
        if equipList_Open then table.insert(activeStates, "equipList_Open") end
        if startedDialogue then table.insert(activeStates, "startedDialogue") end
        if bountyMenu_Open then table.insert(activeStates, "bountyMenu_Open") end
        if questHasStarted then table.insert(activeStates, "questHasStarted") end
        if startSubMenu_Open then table.insert(activeStates, "startSubMenu_Open") end
        if networkErrorActive then table.insert(activeStates, "networkErrorActive") end
        if voiceChatMenu_Open then table.insert(activeStates, "voiceChatMenu_Open") end
        if keyboardSettings_Open then table.insert(activeStates, "keyboardSettings_Open") end

        local statePriority = {
            "localMap_Open",
            "networkErrorActive",
            "questHasStarted",
            "chatMenu_Open",
            "startedDialogue",
            "startSubMenu_Open",
            "startMenu_Open",
            "itemBar_Open",
            "photoMode_Open",
            "questFinished",
            "gamePaused",
            "inCamp",
            "equipList_Open",
            "worldMap_Open",
            "bountyMenu_Open",
            "keyboardSettings_Open",
            "inTent",
            "voiceChatMenu_Open",
        }

        
        for _, priority in ipairs(statePriority) do
            for _, state in ipairs(activeStates) do
                if state == priority then
                    currentState = priority
                    break
                end
            end
            if currentState ~= "hideUI" then break end
        end

        -------------------------
        -- HUD Visibility Logic
        -------------------------
    if not manual_show_override then
        if currentState == "hideUI" then
        set_all_guis_visibility(false)
        else
        set_all_guis_visibility(true)
    end
end


    end)




    -----------------------------------
    --End frame update-----------------------------------
    -----------------------------------




-- re.on_draw_ui(function()
--     if imgui.begin_window("Hide UI Script") then
--         local changed, value = imgui.checkbox("Enable Script", scriptEnabled)
--         if changed then
--             scriptEnabled = value

--             if not scriptEnabled then
--                 -- When disabled, force UI VISIBLE
--                 set_all_guis_visibility(true)
--                 print("[HideUI] Script disabled via GUI, UI forced visible.")
--             else
--                 print("[HideUI] Script enabled via GUI.")
--             end
--         end

--         if scriptEnabled then
--             imgui.text_colored("Script is ACTIVE", 0.0, 1.0, 0.0, 1.0)
--         else
--             imgui.text_colored("Script is DISABLED", 1.0, 0.0, 0.0, 1.0)
--         end

--         imgui.end_window()
--     end
-- end)





    --[[ ========== Reserved -- Unused Functions ========== ]]

--local getComponent = sdk.find_type_definition('via.GameObject'):get_method('getComponent(System.Type)')
    -- local function get_gameobject_component(gameObject, componentType)
    --     return getComponent:call(gameObject, sdk.typeof(componentType))
    -- end

--app.GUI030000Accessor
---Item bar PopUP
--app.GUI020012

---QuestList on Right
--app.GUI020018

--Player names
--app.GUI020016


--MapDarkring
--app.GUI060010
--Map
--app.GUI060011

---Sharpness Bar
--app.GUI020015

--Player Stam Bar
--app.GUI020004

--Player HP Bar
--app.GUI020003

--ItemBar bottom right
--app.GUI020006

--Time of day bottomLeft
--app.GUI020009

--open StartMenu
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlChatLog.checkOpenInput()
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlStartMenu.checkOpenInput()
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlBase.update(System.Boolean)

-- At Base Camp
--app.cLifeAreaInfo.update()
--app.HunterZoneController.update()
--app.GUIManager.requestLifeArea


    -- local gm = sdk.get_managed_singleton("app.GUIManager")
    -- if not gm then
    --     return print("GUIManager not found")
    -- end

    -- local acc = gm:call("get_GUI600001Accessor","get_GUI030000Accessor")
    -- if not acc then
    --     return print("GUI600001Accessor not found")
    -- end

    -- local ids = acc:call("getNeedIDs")
    -- if not ids then
    --     return print("getNeedIDs() returned nil")
    -- end

    -- -- Try the proper List<T> method names
    -- local count = ids:call("get_Count")
    -- print("List Count:", count)

    -- for i = 0, count - 1 do
    --     local id = ids:call("get_Item", i)
    --     print("Active GUI ID:", id)
    -- end

-- local function playMenuSound()

--     print("Entered camp")

--         local gui_manager = sdk.get_managed_singleton("app.GUIManager")
--     if not gui_manager then
--         print("GUIManager not found")
--         return
--     end

--     -- Get GUI030000Accessor field
--     local accessor = gui_manager:get_field("<GUI030000Accessor>k__BackingField")
--     if not accessor then
--         print("GUI030000Accessor field not found")
--         return
--     end

--     -- Access GUI030000 component
--     local components = accessor:get_field("Components")

--             local accessor_type = accessor:get_type_definition()
--         for i, field in ipairs(accessor_type:get_fields()) do
--             print(string.format("Field %d: %s", i, field:get_name()))
--         end-- usually something like `Array<GUIBase<...>>`
--     if not components then
--         print("Could not access components from accessor")
--         return
--     end

--     -- We'll scan for GUI030000 instance
--     local gui030000_instance = nil

--     for i = 0, components:get_size() - 1 do
--         local comp = components:get_element(i)
--         if comp and comp:get_type_definition():get_full_name() == "app.GUI030000" then
--             gui030000_instance = comp
--             break
--         end
--     end

--     if not gui030000_instance then
--         print(" app.GUI030000 instance not found in accessor components")
--         return
--     end

--     -- Now invoke the sound method
--     local gui030000_type = sdk.find_type_definition("app.GUI030000")
--     local sound_method = gui030000_type and gui030000_type:get_method("callOptinalSound_ExecuteDirect()")

--     if not sound_method then
--         print("Method callOptinalSound_ExecuteDirect not found")
--         return
--     end


--     local success, err = pcall(function()
--         sound_method:call(gui030000_instance)
--     end)

--     if success then
--         print("Camp enter sound played")
--     else
--         print("Error playing sound:", err)
--     end

    
-- end

---
---  -- -- Game Pause (Specialty Guide UI)
    --     { "app.GUIManager", "onOpenSpecialtyGuideUI", function() gamePaused = true; print("Game paused") end },
    --     { "app.GUIManager", "setupEnergyGauge", function() gamePaused = false; print("Game resumed") end },


--Bounty List from pause menu
--app.GUI090800.onOpen()






--Trigger menu sound
--app.GUI030000.callOptinalSound_ExecuteDirect()
--app.GUI040001.onTriggerSoundOpen(System.Boolean)
--onOpen(app.GUIID.ID, via.gui.Control, System.Boolean, System.Int32)

