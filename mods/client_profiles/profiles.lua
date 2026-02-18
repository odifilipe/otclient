local settings = {}
ChangedProfile = false

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
end

-- loads settings on character login
function online()
  ChangedProfile = false

  -- startup arguments has higher priority than settings
  local profile = getProfileFromStartupArgument()
  if profile then
    setProfileOption(profile)
  end

  load()

  if not profile then
    setProfileOption(getProfileFromSettings() or "Default")
  end

  -- create main settings dir
  if not g_resources.directoryExists("/settings/") then
    g_resources.makeDir("/settings/")
  end

  -- create default profile if it doesn't exist
  local defaultProfile = "/settings/Default"
  if not g_resources.directoryExists(defaultProfile) then
    g_resources.makeDir(defaultProfile)
  end
end

function setProfileOption(profileName)
  local currentProfile = g_settings.getString('profile')
  
  if currentProfile ~= profileName then
    ChangedProfile = true
    return modules.client_options.setOption('profile', profileName)
  end

end

-- load profile name from settings
function getProfileFromSettings()
  -- settings should save per character, return if not online
  if not g_game.isOnline() then return end

  local index = g_game.getCharacterName()
  local savedData = settings[index]

  return savedData
end

-- option to launch client with hardcoded profile
function getProfileFromStartupArgument()
    local startupOptions = string.split(g_app.getStartupOptions(), " ")
    if #startupOptions < 2 then
        return false
    end

    for index, option in ipairs(startupOptions) do
        if option == "--profile" then
            local profileName = startupOptions[index + 1]
            if profileName == nil then
              return g_logger.info("Startup arguments incomplete: missing profile name.")
            end

            g_logger.info("Startup options: Forced profile: "..profileName)
            -- set value in options
            return profileName
        end
    end

    return false
end

-- returns string path ie. "/settings/Default/actionbar.json"
function getSettingsFilePath(fileNameWithFormat)
  local currentProfile = g_settings.getString('profile')
  if not currentProfile or currentProfile == "" then
     currentProfile = "Default"
  end

  return "/settings/"..currentProfile.."/"..fileNameWithFormat
end

function offline()
  onProfileChange(true)
end

-- profile change callback (called in options), saves settings & reloads given module configs
function onProfileChange(offline)
  if not offline then
    if not g_game.isOnline() then return end
  -- had to apply some delay
    scheduleEvent(collectiveReload, 100)
  end

  local currentProfile = g_settings.getString('profile')
  local index = g_game.getCharacterName()

  if index then
    settings[index] = currentProfile
    save()
  end
end

-- collection of refresh functions from different modules
function collectiveReload()
  modules.game_topbar.refresh(true)
  modules.game_actionbar.refresh(true)
  modules.game_bot.refresh()
end

-- json handlers
function load()
  local file = "/settings/profiles.json"
  if g_resources.fileExists(file) then
    local status, result = pcall(function()
        return json.decode(g_resources.readFileContents(file))
    end)
    if not status then
        return g_logger.warning(
                   "Error while reading profiles file. To fix this problem you can delete storage.json. Details: " ..
                       result)
    end
    settings = result
  end
end

function save()
  local file = "/settings/profiles.json"
  local status, result = pcall(function() return json.encode(settings, 2) end)
  if not status then
      return g_logger.warning(
                 "Error while saving profile settings. Data won't be saved. Details: " ..
                     result)
  end
  if result:len() > 100 * 1024 * 1024 then
      return g_logger.warning(
                 "Something went wrong, file is above 100MB, won't be saved")
  end
  g_resources.writeFileContents(file, result)
end
