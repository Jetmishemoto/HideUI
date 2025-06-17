
local initialized = false
local forceShowHUD = false
local startMenu_Open = false
local virtualMouseMenuOpen = false
local campSoundPlayed = false
local inCamp = false
local mapOpen = false
local worldMap_Open = false
local gamePaused = false
local player_Ready = false
local itemBar_Open = false
local inTent = false
local voiceChatMenu_Open = false
local startedDialogue = false




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


local guiTypes = {
    "app.GUI020012", "app.GUI020018", "app.GUI020016",
    "app.GUI060010", "app.GUI060011", "app.GUI020015",
    "app.GUI020004", "app.GUI020003", "app.GUI020006",
    "app.GUI020009"
}
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




-- Hook list
local hook_definitions = {


    -- Pause Menu
        { "app.GUI030000", "onOpen", function() startMenu_Open = true; print("Opened pause menu") end },
        { "app.GUI030000", "onClose", function() startMenu_Open = false; print("Closed pause menu") end },

    -- Virtual Mouse Menus
        { "app.GUIManager", "onSetVirtualMouse", function()
            if not virtualMouseMenuOpen then
                virtualMouseMenuOpen = true
                print("Other options menu open")
            end
        end },

        {"app.GUIManager", "requestLifeArea", function()inCamp = true; print("Entered camp")end },
        { "app.GUIManager", "requestStage", function() inCamp = false; print("Left camp") end },

    -- Local Map
        { "app.cGUIMapController", "requestOpen", function() mapOpen = true; print("Map opened") end },
        { "app.GUIManager", "close3DMap", function()
            mapOpen = false
            virtualMouseMenuOpen = false -- reset here
            print("Map closed, options menu closed")
        end },

    --World Map
        { "app.GUI060102", "onOpen", function() worldMap_Open = true; print("WorldMap Open") end },
        { "app.GUI060102", "onClose", function() worldMap_Open = false; print("WorldMap Closed") end },

    -- Game Pause (Specialty Guide UI)
        { "app.GUIManager", "onOpenSpecialtyGuideUI", function() gamePaused = true; print("Game paused") end },
        { "app.GUIManager", "setupEnergyGauge", function() gamePaused = false; print("Game resumed") end },

    -- Item Bar
        { "app.GUI020008", "onOpenApp", function() itemBar_Open = true; print("Item bar opened") end },
        { "app.GUI020008PartsPallet", "close", function() itemBar_Open = false; print("Item bar closed") end },

    -- Tent
        { "app.GUIManager", "startTentMenu", function() inTent = true; print("In Tent") end },
        { "app.cGUISystemModuleOpenTentMenu", "exitTent(app.FacilityMenu.TYPE)", function() inTent = false; print("Exiting Tent") end },

    -- VoiceChatMenu
        { "app.GUI040001", "guiDestroy", function() voiceChatMenu_Open = false; print("Voice chat list Closed") end },

    -- Npc Dialogue
        { "app.DialogueManager", "startDialogue", function() startedDialogue = true; print("Player started dialogue") end },
}


-------------------Functions we might want to hook
--app.cGUICommonMenu_VoiceChat.get_OpenGUIID()
--ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>.onDestroy()

--ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>.toVisible()

--app.cGUIMenuShutdownCtrl.isCutScenePlaying

--app.GUI060102.onOpen()
--app.cGUICommonMenu_ItemPouch.get_OpenGUIID

--app.GUIManager.<updatePlCommandMask>b__285_0
--app.GUIManager.getWishlistItemFlagTable
--app.GUIBaseApp.doOnDestroyApp


--Trigger menu sound
--app.GUI030000.callOptinalSound_ExecuteDirect()
--app.GUI040001.onTriggerSoundOpen(System.Boolean)
--onOpen(app.GUIID.ID, via.gui.Control, System.Boolean, System.Int32)
--------------------


-- hook helper
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


--Initialize hooks
for _, h in ipairs(hook_definitions) do
    hook_method(h[1], h[2], function(args)
        h[3]()
    end)
end



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------




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



local function checkIfInCampStartup()
    local guiManager = sdk.get_managed_singleton("app.GUIManager")
    if not guiManager then
        print("⚠️ GUIManager not available at startup")
        return
    end

    local currentCamp = guiManager:call("requestLifeArea")
    local currentStageName = guiManager:call("requestStage")
    if currentCamp then
        inCamp = true
        print("🟢 Player already in camp on script load")
    else if currentStageName then
        inCamp = false
        print("🔵 Player not in camp on script load")
        end
    end
end








-- VoiceChatMenu---------------------------------------------|
-- couldnt find a way to hook the menu open, so we use the controller method
-- Voice Chat Menu (Keyboard)
hook_method(
    "app.cGUICommonMenu_VoiceChat",
    "execute(app.MenuDef.ExecuteFrom, System.Object, app.cGUICommonMenuItemExecuteOptionBase, ace.IGUIFlowHandle)",
    function(args)
        voiceChatMenu_Open = true
        print("Voice chat menu executed")
    end
)

-- Voice Chat Menu (Controller)
hook_method(
    "app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList",
    "onOpen",
    function(args)
        voiceChatMenu_Open = true
        print(" Voice chat list opened (controller)")
    end
)



--------------------------------------------
re.on_frame(function()


    if not initialized then
        checkIfInCampStartup()
        initialized = true
    end

   if virtualMouseMenuOpen then
        -- If virtual mouse menu is open, we want to keep the world map open
        if not worldMap_Open then
            print("World map remains open due to virtualMouseMenuOpen")
        end
        mapOpen = true
        worldMap_Open = true
        return -- Skip the rest of the logic if virtual mouse menu is open
    end


    local state = nil

    if inCamp then
        state = "inCamp"
    elseif mapOpen then
        state = "mapOpen"
    elseif worldMap_Open then
        state = "worldMap_Open"
    elseif startMenu_Open then
        state = "startmenuOpen"
    elseif gamePaused then
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


        --Wait until player is ready
        if not player_Ready then
            if getPlayer() ~= nil then
                player_Ready = true
                print("Player is ready")
            end
            return -- Don't proceed with GUI logic yet
        end



            --Detect end-of-quest
        local missionManager = sdk.get_managed_singleton("app.MissionManager")
        if missionManager then
            local questDirector = missionManager:call("get_QuestDirector")
            if questDirector and questDirector:call("IsFinishing") then
                forceShowHUD = true
                print("Quest is finishing — restoring HUD")
            end
        end

            -- Main GUI control
            --Function is not working, need to find a way to force show the HUD
        if forceShowHUD then
            local gui_manager = sdk.get_managed_singleton("app.GUIManager")
            if gui_manager then
                --Need to find the method to force show the HUD if its e
                local showHUDMethod = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceVisible")
                if showHUDMethod then
                    showHUDMethod:call(gui_manager)
                    print("HUD force-visible")
                end
            end
            return -- skip the hiding logic this frame
        end


    local actions = {
        inCamp = function()
            -- UI should remain visible in camp
        end,
        mapOpen = function()
            -- UI should remain visible on map
        end,
        worldMap_Open = function()
            -- UI should remain visible on world map
        end,
        menuOpen = function()
            -- UI should remain visible when menu is open
        end,
        gamePaused = function()
            -- UI should remain visible when game is paused
        end,
        virtualMouseMenuOpen = function()
            -- UI should remain visible when virtual mouse menu is open
        end,
        itemBar_Open = function()
            -- UI should remain visible when item bar is open
        end,
        inTent = function()
            -- UI should remain visible in tent
        end,
        VoiceChatMenu_Open = function()
            -- UI should remain visible when voice chat menu is open
        end,
        startedDialogue = function()
            -- UI should remain visible when dialogue is started
        end,
        hideUI = function()
            local gui_manager = sdk.get_managed_singleton("app.GUIManager")
            if not gui_manager then return end
            local method = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceInvisible")
            if method then
                method:call(gui_manager)
                
            end
        end
    }
        -- Call the appropriate function based on the state
        local action = actions[state]
        if action then action() end
end)
-----------------------------------
-----------------------------------
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