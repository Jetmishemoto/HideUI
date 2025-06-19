
local initialized = false
local forceShowHUD = false
local uiMask_Open = false
local bountyMenu_Open = false
local startMenu_Open = false
local startSubMenu_Open = false
local startSubMenuTimer = 0
local START_SUB_MENU_TIMEOUT = 60
local equipList_Open = false
local keyboardSettings_Open = false
local photoMode_Open = false
local photoModeTimer = 0
local virtualMouseMenu_Open = false
local inCamp = false
local localMap_Open = false
local localMapCloseQueued = false
local worldMap_Open = false
local localMapFromWorldMap = false -- Flag to track if we're transitioning from world map
local gameIsPaused = false
local player_Ready = false
local itemBar_Open = false
local inTent = false
local voiceChatMenu_Open = false
local startedDialogue = false
local mapTransitioning = false
local mapTransitioningFrames = 0
local IsFinishingQuest = false

local campSoundPlayed = false



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


-- do
--     if json then
--         local file = json.load_file(configPath)
--         if file then config = file; fixConfig()
--         else json.dump_file(configPath, config) end
--     end
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

local guiTypes = {
    "app.GUI020012", "app.GUI020018", "app.GUI020016",
    "app.GUI060010", "app.GUI060011", "app.GUI020015",
    "app.GUI020004", "app.GUI020003", "app.GUI020006",
    "app.GUI020009"
}






-------------
---⌈→→hook helper←←⌉---------------
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




--------------------- Check if player is in camp at startup--------------
local function checkIfInCampStartup()
    local guiManager = sdk.get_managed_singleton("app.GUIManager")
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
        { "app.GUIManager", "requestStage", function() inCamp = false; print("Left camp") end },
----------------------------------------------------------------------------------------------------------

    ---UI Mask-------------------------------------------------------
        { "app.GUIManager", "<updatePlCommandMask>b__285_0", function()
                startSubMenu_Open = true
                startSubMenuTimer = 20
                print(startSubMenuTimer)

        end },
----------------------------------------------------------------------------------------------------------
--------
    --- Radar mask ckeck------------------------
        { "app.cGUIMapFlowOpenRadarMask", "enter", function()
            photoMode_Open = false
            print("RadarMask.enter ")
            print( "PhotoMode Closed",photoMode_Open)
        end },

    -- Pause Menu-----------------------------------------------------------
        { "app.GUI030000", "onOpen", function()
            
            startMenu_Open = true;
            keyboardSettings_Open = false;
            print("Opened pause menu")

        end },
    ---Pause Menu Close
        { "app.GUI030000", "onClose", function()
            
            uiMask_Open = false
            equipList_Open = false

            print("Closed pause menu")
            print("SubMenu Closed")

        end },
----------------------------------------------------------------------------------

    --Starting SubMenus------
        { "app.GUIManager", "instantiatePrefab", function()
            startSubMenu_Open = true
            startSubMenuTimer = START_SUB_MENU_TIMEOUT
            print("Start SubMenu Open — timer started")
            print("Start SubMenu Open")

        end },

    --Selecting submenu item?
        { "app.GUI030000", "executeItem(app.user_data.StartMenuData.ItemBase)", function()
            
            print("Start SubMenu selected")

        end },

----------------------------------------------------------------------------------
--------
    --EquipList
        { "app.GUI080001","onOpen",function()
            equipList_Open = true
            print("Opened EquipList menu")

        end },
        
-------------------------------------------------------------
---------------------
    ---Photograph Mode---------------------------------------------------
        { "app.mcPhotograph","updatePhotoModeGUIOpenCheck",function()
            photoMode_Open = true
            print("Photograph Mode Opened")
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
    -- Virtual Mouse Menus-----------------------------------------------
        { "app.GUIManager", "onSetVirtualMouse", function()
            if not virtualMouseMenu_Open then
            -- Only set to true if it wasn't already open
            virtualMouseMenu_Open = true
            print("Main virtual menu open", virtualMouseMenu_Open)
            end

        end },

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------


------------------------
    -- LocalMap---------------------------------------------------------
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

        { "app.GUIManager", "close3DMap", function()
            if mapTransitioning and virtualMouseMenu_Open then
                print("Skipping map close — mapTransitioning still active")
                localMapCloseQueued = true
                return
            end

            -- At this point, either virtualMouseMenu was cleared or it doesn't matter
            localMap_Open = false
            virtualMouseMenu_Open = false
            print("Local Map closed, options menu closed")
            
        end },
----------------------------------------------------------------------------------------------------------

    --World Map----------------------------------------------------
        { "app.GUI060102", "onOpen", function()

            worldMap_Open = true
            localMapFromWorldMap = true -- flag we're transitioning from world map
            mapTransitioning = true
            mapTransitioningFrames = 60
            startSubMenu_Open = false -- close start submenu if open
            print("World Map Opened")
        end},
        { "app.GUIManager", "isOpenReadyGUI060102", function()
            worldMap_Open = false
            if mapTransitioning then
                print("World Map closed early — forcibly ending map transition")
                mapTransitioning = false
                localMapFromWorldMap = false
                mapTransitioningFrames = 0
            end
            print("WorldMap Closed")
        end },
----------------------------------------------------------------------------------------------------------
---
    -- Item Bar---------------------------------------------------
        { "app.GUI020008", "onOpenApp", function() itemBar_Open = true; print("Item bar opened") end },
        { "app.GUI020008PartsPallet", "close", function() itemBar_Open = false; print("Item bar closed") end },
----------------------------------------------------------------------------------
---
    -- Tent-------------------------------------------------------
        { "app.GUIManager", "startTentMenu", function()

            inTent = true
            print("In Tent")

        end },
        { "app.cGUISystemModuleOpenTentMenu", "exitTent(app.FacilityMenu.TYPE)",
            function()

                inTent = false
                print("Exiting Tent")

        end },

        ----
        -- VoiceChatMenu----------------------------------------------
        { "app.GUI040001", "guiDestroy", function() voiceChatMenu_Open = false; print("Voice chat list Closed") end },
        
        -- Npc Dialogue----------------------------------------------
        -- { "app.DialogueManager", "startDialogue", function() startedDialogue = true; print("Player started dialogue") end },
    }

    ----------------------------------------------------------------------------------
    ------------→→End Hook list←←-----------------------------------------------------------------------------------------→→End Hook list←←
    ---

----------------Initialize hooks---------------
----------------------------------------------------------------------------------
for _, h in ipairs(hook_definitions) do
    hook_method(h[1], h[2], function(args)
        h[3]()
    end)
end
----------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------




-----PauseManager-----------------------------
hook_method("app.PauseManager", "onAllRequestExecuted", function(retval)

    if inTent then
        print("Don't change pause state if in tent")
        return
    end

    local pauseManager = sdk.get_managed_singleton("app.PauseManager")
    if pauseManager then
        local isPaused = pauseManager:call("get_IsPaused")
        gameIsPaused = isPaused
        print(isPaused and "PauseManager.Game paused" or "PauseManager.Game resumed")
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
    end
)
--
-- Voice Chat Menu (Controller)
--
hook_method(
    "app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList",
    "onOpen",
    function(args)
        voiceChatMenu_Open = true
        print(" Voice chat list opened (controller)")
    end
)
--------------------------------------------
---

--------
---Map Transition Logic Methods--------------------------
--------------
local function finishMapTransition()
    mapTransitioning = false
    localMapFromWorldMap = false
    print("Map transition complete — unblocking")
end

local function clearLingeringVirtualMouse()
    if not mapTransitioning and virtualMouseMenu_Open and not localMap_Open and not worldMap_Open then
        virtualMouseMenu_Open = false
        print("Cleared lingering virtualMouseMenu_Open flag")
    end
end

local function resolveConflictingMapStates()
    if localMap_Open and worldMap_Open  then
        print("Both Local and World Map are marked open! Resetting...")
        -- World map transitioned to local map, so clear world map flag
        worldMap_Open = false
    end
end

local function finalizeQueuedMapClose()
    if localMapCloseQueued then
        localMap_Open = false
        virtualMouseMenu_Open = false
        localMapCloseQueued = false
        print("Closing map after transition delay (queued)")
    end
end
---------------------------------------------





    --Detect end-of-quest
local missionManager = sdk.get_managed_singleton("app.MissionManager")
if missionManager then
    local questDirector = missionManager:call("get_QuestDirector")
    if questDirector and questDirector:call("IsFinishing") then
        IsFinishingQuest = true
        forceShowHUD = true
        print("Quest is finishing")
    end
end




---------------------------------------
------------------------
-- Main frame update-------------------------------
--------------------
re.on_frame(function()

    if not initialized then
        checkIfInCampStartup()
        initialized = true
        print("HideUI initialized",initialized)
    end


    --Wait until player is ready
        if not player_Ready then
            if getPlayer() ~= nil then
                player_Ready = true
                print("Player is ready")
            end
            return -- Don't proceed with GUI logic yet
        end

    -- if player_Ready then
    --     print("local mapOpen:", localMap_Open,
    --         " | worldMap_Open:", worldMap_Open,
    --         " | mapFromWorldMap:", mapFromWorldMap,
    --         " | mapTransitioning:", mapTransitioning,
    --         " | mapTransitioningFrames:", mapTransitioningFrames)
    -- end



    if startSubMenu_Open then
        startSubMenuTimer = startSubMenuTimer - 1
        if startSubMenuTimer <= 0 then
            startSubMenu_Open = false
            print("Start SubMenu auto-closed (timer expired)")
        end
    end




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
    -------------------------------------------------------------------------------




    --------------
    ------------State Management----------------
    -------------
        local state = nil

        if inCamp then
            state = "inCamp"
        elseif localMap_Open then
            state = "mapOpen"
        elseif worldMap_Open then
            state = "worldMap_Open"
        elseif startMenu_Open then
            state = "startmenuOpen"
        elseif startSubMenu_Open then
            state = "startSubMenu_Open"
        elseif uiMask_Open then
            state = "uiMask_Open"
        elseif equipList_Open then
            state = "equipList_Open"
        elseif keyboardSettings_Open then
            state = "keyboardSettings_Open"
        elseif photoMode_Open then
            state = "photoMode_Open"
        elseif bountyMenu_Open then
            state = "bountyMenu_Open"
        elseif gameIsPaused then
            state = "gamePaused"
        elseif itemBar_Open then
            state = "itemBar_Open"
        elseif inTent then
            state = "inTent"    
        elseif voiceChatMenu_Open then
            state = "voiceChatMenu_Open"
        elseif startedDialogue then
            state = "startedDialogue"
        else
            state = "hideUI"
        end




    local playerGUIActions = {
        inCamp = function()
        end,
        inTent = function()
        end,
        localMap_Open = function()
        end,
        worldMap_Open = function()
        end,
        gamePaused = function()
        end,
        startMenu_Open = function()
        end,
        uiMask_Open = function()
        end,
        itemBar_Open = function()
        end,
        equipList_Open = function()
        end,
        photoMode_Open = function ()
        end,
        startedDialogue = function()
        end,
        startSubMenu_Open = function()
        end,
        VoiceChatMenu_Open = function()
        end,
        virtualMouseMenuOpen = function()
        end,
        keyboardSettings_Open = function()
        end,

        hideUI = function()
            local gui_manager = sdk.get_managed_singleton("app.GUIManager")
            if not gui_manager then return end
            local set_HideUI = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceInvisible")
            if set_HideUI then
                if forceShowHUD then
                print("Hiding UI")
                end
                    forceShowHUD = false
                    set_HideUI:call(gui_manager)
                else
                    forceShowHUD = true
            end
        end
    }
        -- Call the appropriate function based on player actions
        local runPlayerActions = playerGUIActions[state]
        if runPlayerActions then runPlayerActions() end
end)
-----------------------------------
--End frame update-----------------------------------
-----------------------------------

--app.CommunicationUtil.isOpen


--app.cGUIMapController.requestOpen(app.GUIMapDef.MapViewMode, app.GUIMapDef.MapOpenType, app.FieldDef.STAGE)
--app.cGUIMapController.requestOpen
--open3DMap()

--open StartMenu
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlChatLog.checkOpenInput()
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlStartMenu.checkOpenInput()
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlBase.update(System.Boolean)

-- At Base Camp
--app.cLifeAreaInfo.update()
--app.HunterZoneController.update()
--app.GUIManager.requestLifeArea


 -----app.GUIID.ID[]
 ------↓
-- Method: Set
-- Method: Get
-- Method: Address
-- Method: GetEnumerator
-- Method: Add
-- Method: Clear
-- Method: Contains
-- Method: CopyTo
-- Method: Remove
-- Method: get_Item
-- Method: set_Item
-- Method: IndexOf
-- Method: Insert
-- Method: RemoveAt

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

--     print("🏕️ Entered camp")

--         local gui_manager = sdk.get_managed_singleton("app.GUIManager")
--     if not gui_manager then
--         print("❌ GUIManager not found")
--         return
--     end

--     -- Get GUI030000Accessor field
--     local accessor = gui_manager:get_field("<GUI030000Accessor>k__BackingField")
--     if not accessor then
--         print("❌ GUI030000Accessor field not found")
--         return
--     end

--     -- Access GUI030000 component
--     local components = accessor:get_field("Components")

--             local accessor_type = accessor:get_type_definition()
--         for i, field in ipairs(accessor_type:get_fields()) do
--             print(string.format("Field %d: %s", i, field:get_name()))
--         end-- usually something like `Array<GUIBase<...>>`
--     if not components then
--         print("❌ Could not access components from accessor")
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
--         print("❌ app.GUI030000 instance not found in accessor components")
--         return
--     end

--     -- Now invoke the sound method
--     local gui030000_type = sdk.find_type_definition("app.GUI030000")
--     local sound_method = gui030000_type and gui030000_type:get_method("callOptinalSound_ExecuteDirect()")

--     if not sound_method then
--         print("❌ Method callOptinalSound_ExecuteDirect not found")
--         return
--     end

--     -- Call it!
--     local success, err = pcall(function()
--         sound_method:call(gui030000_instance)
--     end)

--     if success then
--         print("✅ Camp enter sound played")
--     else
--         print("❌ Error playing sound:", err)
--     end

    
-- end




-------------------Functions we might want to hook
---
---  -- -- Game Pause (Specialty Guide UI)
    --     { "app.GUIManager", "onOpenSpecialtyGuideUI", function() gamePaused = true; print("Game paused") end },
    --     { "app.GUIManager", "setupEnergyGauge", function() gamePaused = false; print("Game resumed") end },







--app.cGUICommonMenu_VoiceChat.get_OpenGUIID()
--ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>.onDestroy()

--ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>.toVisible()

--app.cGUIMenuShutdownCtrl.isCutScenePlaying

--app.GUI060102.onOpen()
--app.cGUICommonMenu_ItemPouch.get_OpenGUIID

--app.GUIManager.<updatePlCommandMask>b__285_0
--app.GUIManager.getWishlistItemFlagTable



--Bounty List from pause menu
--app.GUI090800.onOpen()






--Trigger menu sound
--app.GUI030000.callOptinalSound_ExecuteDirect()
--app.GUI040001.onTriggerSoundOpen(System.Boolean)
--onOpen(app.GUIID.ID, via.gui.Control, System.Boolean, System.Int32)


----When quit and save is selected
--app.GUIManager.getNotifyWindowInfo

--UI Mask when in options menu
--app.GUIManager.<updatePlCommandMask>b__285_0

--Opening a StartSubMenu and other submenus
--app.GUIManager.instantiatePrefab

--------------------

-------------------------------------------------------------

---PauseManager Hook--

-- sdk.hook(
--     sdk.find_type_definition("app.PauseManager"):get_method("onAllRequestExecuted"),
--     function(args) -- before call (optional)
--         return sdk.PreHookResult.CALL
--     end,
--     function(retval) -- after call
--         local pauseManager = sdk.get_managed_singleton("app.PauseManager")
--         if pauseManager then
--             local isPaused = pauseManager:call("get_IsPaused")
--             gamePaused = isPaused
--             print(isPaused and "Game paused " or "Game resumed")
--         else
--             print("Could not get PauseManager")
--         end
--         return retval
--     end
-- )
