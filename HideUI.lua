
local forceShowHUD = false
local menuOpen = false
local inCamp = false
local mapOpen = false
local gamePaused = false
local player_ready = false
local itemBar_Open = false
local inTent = false
local VoiceChatMenu_Open = false





local function fixConfig()
    if config.version ~= "1.0.0" then
        config.version = "1.0.0"
        json.dump_file(configPath, config)
    end
end

do
    if json then
        local file = json.load_file(configPath)
        if file then config = file; fixConfig()
        else json.dump_file(configPath, config) end
    end
end
local drawFieldCache = {}


local guiTypes = {
    "app.GUI020012", "app.GUI020018", "app.GUI020016",
    "app.GUI060010", "app.GUI060011", "app.GUI020015",
    "app.GUI020004", "app.GUI020003", "app.GUI020006",
    "app.GUI020009"
}





-- Hook list for clean init
local hook_definitions = {
    -- Pause Menu
    { "app.GUI030000", "onOpen", function() menuOpen = true; print("Opened pause menu") end },
    { "app.GUI030000", "onClose", function() menuOpen = false; print("Closed pause menu") end },

    -- Camp
    { "app.GUIManager", "requestLifeArea", function() inCamp = true; forceShowHUD = false; print("Entered camp") end },
    { "app.GUIManager", "requestStage", function() inCamp = false; print("Left camp") end },

    -- Map
    { "app.cGUIMapController", "requestOpen", function() mapOpen = true; print("Map opened") end },
    { "app.GUIManager", "close3DMap", function() mapOpen = false; print("Map closed") end },

    -- Game Pause (Specialty Guide UI)
    { "app.GUIManager", "onOpenSpecialtyGuideUI", function() gamePaused = true; print("Game paused") end },
    { "app.GUIManager", "setupEnergyGauge", function() gamePaused = false; print("Game resumed") end },

    -- Item Bar
    { "app.GUI020008", "onOpenApp", function() itemBar_Open = true; print("Item bar opened") end },
    { "app.GUI020008PartsPallet", "close", function() itemBar_Open = false; print("Item bar closed") end },

    -- Tent
    { "app.GUIManager", "startTentMenu", function() inTent = true; print("In Tent") end },
    { "app.cGUISystemModuleOpenTentMenu", "exitTent(app.FacilityMenu.TYPE)", function() inTent = false; print("Exiting Tent") end },
    
    -- -- VoiceChatMenu
    { "app.cGUIMapFlowCtrl", "openRadarMaskGUI", function() VoiceChatMenu_Open = false; print("Voice chat list Closed") end },
    
}


--app.cGUIMapFlowCtrl.<>c__DisplayClass31_0.<onClose>b__2(System.Object, ace.GUIBaseCore)
--ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>.toVisible()
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList.onOpen()



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



-- VoiceChatMenu---------------------------------------------|

-- Voice Chat Menu (Keyboard)
hook_method(
    "app.cGUICommonMenu_VoiceChat",
    "execute(app.MenuDef.ExecuteFrom, System.Object, app.cGUICommonMenuItemExecuteOptionBase, ace.IGUIFlowHandle)",
    function(args)
        VoiceChatMenu_Open = true
        print("Voice chat menu executed")
    end
)

-- Voice Chat Menu (Controller)
hook_method(
    "app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList",
    "onOpen",
    function(args)
        VoiceChatMenu_Open = true
        print(" Voice chat list opened (controller)")
    end
)

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
----------------------------------------------------------
-- Hooks to detect state transitions 
----------------------------------------------------------



--------------------------------------------
re.on_frame(function()

        --Wait until player is ready
        if not player_ready then
            if getPlayer() ~= nil then
                player_ready = true
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
        if forceShowHUD then
            local gui_manager = sdk.get_managed_singleton("app.GUIManager")
            if gui_manager then
                local showHUDMethod = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceVisible")
                if showHUDMethod then
                    showHUDMethod:call(gui_manager)
                    print("HUD force-visible")
                end
            end
            return -- skip the hiding logic this frame
        end
        
        

    if not inCamp  and not mapOpen and not menuOpen and not gamePaused and not itemBar_Open and not inTent and not VoiceChatMenu_Open then
        local gui_manager = sdk.get_managed_singleton("app.GUIManager")
        if not gui_manager then return end

        local method = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceInvisible")
        if method then
            method:call(gui_manager)
        end
    end
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

local forceShowHUD = false
local menuOpen = false
local inCamp = false
local mapOpen = false
local gamePaused = false
local player_ready = false
local itemBar_Open = false
local inTent = false
local VoiceChatMenu_Open = false
local startedDialogue = false




local function fixConfig()
    if config.version ~= "1.0.0" then
        config.version = "1.0.0"
        json.dump_file(configPath, config)
    end
end

do
    if json then
        local file = json.load_file(configPath)
        if file then config = file; fixConfig()
        else json.dump_file(configPath, config) end
    end
end



local drawFieldCache = {}


local guiTypes = {
    "app.GUI020012", "app.GUI020018", "app.GUI020016",
    "app.GUI060010", "app.GUI060011", "app.GUI020015",
    "app.GUI020004", "app.GUI020003", "app.GUI020006",
    "app.GUI020009"
}





-- Hook list for clean init
local hook_definitions = {


    -- Pause Menu
        { "app.GUI030000", "onOpen", function() menuOpen = true; print("Opened pause menu") end },
        { "app.GUI030000", "onClose", function() menuOpen = false; print("Closed pause menu") end },

    -- Camp
        { "app.GUIManager", "requestLifeArea", function() inCamp = true; forceShowHUD = false; print("Entered camp") end },
        { "app.GUIManager", "requestStage", function() inCamp = false; print("Left camp") end },

    -- Map
    
        { "app.cGUIMapController", "requestOpen", function() mapOpen = true; print("Map opened") end },
        { "app.GUIManager", "close3DMap", function() mapOpen = false; print("Map closed") end },

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
        { "app.cGUIMapFlowCtrl", "openRadarMaskGUI", function() VoiceChatMenu_Open = false; print("Voice chat list Closed") end },

    -- Npc Dialogue
        { "app.DialogueManager", "startDialogue", function() startedDialogue = true; print("Player started dialogue") end },
}


--app.cGUIMapFlowCtrl.<>c__DisplayClass31_0.<onClose>b__2(System.Object, ace.GUIBaseCore)
--ace.GUIBase`2<app.GUIID.ID,app.GUIFunc.TYPE>.toVisible()
--app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList.onOpen()




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



-- VoiceChatMenu---------------------------------------------|

-- Voice Chat Menu (Keyboard)
hook_method(
    "app.cGUICommonMenu_VoiceChat",
    "execute(app.MenuDef.ExecuteFrom, System.Object, app.cGUICommonMenuItemExecuteOptionBase, ace.IGUIFlowHandle)",
    function(args)
        VoiceChatMenu_Open = true
        print("Voice chat menu executed")
    end
)

-- Voice Chat Menu (Controller)
hook_method(
    "app.cGUISystemModuleSystemInputOpenController.cGUISystemInputOpenCtrlVoiceChatList",
    "onOpen",
    function(args)
        VoiceChatMenu_Open = true
        print(" Voice chat list opened (controller)")
    end
)

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



--------------------------------------------
re.on_frame(function()

        --Wait until player is ready
        if not player_ready then
            if getPlayer() ~= nil then
                player_ready = true
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
        if forceShowHUD then
            local gui_manager = sdk.get_managed_singleton("app.GUIManager")
            if gui_manager then
                local showHUDMethod = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceVisible")
                if showHUDMethod then
                    showHUDMethod:call(gui_manager)
                    print("HUD force-visible")
                end
            end
            return -- skip the hiding logic this frame
        end

    if not inCamp  and not mapOpen and not menuOpen and not gamePaused and not itemBar_Open and not inTent and not VoiceChatMenu_Open and not startedDialogue then
        local gui_manager = sdk.get_managed_singleton("app.GUIManager")
        if not gui_manager then return end

        local method = sdk.find_type_definition("app.GUIManager"):get_method("allGUIForceInvisible")
        if method then
            method:call(gui_manager)
        end
    end
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