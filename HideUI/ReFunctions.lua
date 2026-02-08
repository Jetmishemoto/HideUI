

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





-------------
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


local timers = {}


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




---------
---------⌈→→Hook list←←⌉------------------------------------------------------------------------------------⌈→→Hook list←←⌉--------
---------
local hook_definitions = {

    --Camp Area
        {"app.GUIManager", "requestLifeArea", function()
            inCamp = true
            print("Entered camp")
            print("HUD Active")

        end },
        --Laving Camp Area
        { "app.GUIManager", "requestStage", function()
            inCamp = false
            print("Left camp")
            print("HUD Inactive")
            end },
    ----------------------------------------------------------------------------------------------------------
    -----------------
    ----Needs to be replaced with a better UI mask check
    ---UI submenus Mask-------------------------------------------------------
        -- { "app.GUIManager", "<updatePlCommandMask>b__285_0", function()
        --         startSubMenu_Open = true
        --         startSubMenuTimer = 20
        --         --print(startSubMenuTimer)
        -- end },
    ----------------------------------------------------------------------------------------------------------
    --------
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
        { "app.GUI090800", "onOpen", function() bountyMenu_Open = false; print("Closed pause menu") end },
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
        { "app.GUI020008", "onOpenApp", function() itemBar_Open = true; print("Item bar opened") end },
        { "app.GUI020008PartsPallet", "close", function() itemBar_Open = false; print("Item bar closed") end },
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
        { "app.GUI040001", "guiDestroy", function() voiceChatMenu_Open = false; print("Voice chat list Closed") end },
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
    ---