local UgCore = exports['ug-core']:GetCore()

local loadingScreenFinished = false
local ready = false
local guiEnabled = false
local timecycleModifier = "hud_def_blur"

RegisterNetEvent('ug-identity:AlreadyRegistered', function()
    while not loadingScreenFinished do Wait(100) end
    TriggerEvent('ug-skin:PlayerRegistered')
end)

RegisterNetEvent('ug-identity:SetPlayerData', function(data)
    SetTimeout(1, function()
        UgCore.Functions.SetPlayerData("name", ('%s %s'):format(data.firstName, data.lastName))
        UgCore.Functions.SetPlayerData('firstName', data.firstName)
        UgCore.Functions.SetPlayerData('lastName', data.lastName)
        UgCore.Functions.SetPlayerData('dateOfBirth', data.dateOfBirth)
        UgCore.Functions.SetPlayerData('sex', data.sex)
        UgCore.Functions.SetPlayerData('height', data.height)
    end)
end)

AddEventHandler('ug-core:LoadingScreenOFF', function()
    loadingScreenFinished = true
end)

RegisterNUICallback('ready', function(_, cb)
    ready = true
    cb(1)
end)

if not Config.UseDeferrals then
    function SetGuiState(state)
        SetNuiFocus(state, state)
        guiEnabled = state

        if state then
            SetTimecycleModifier(timecycleModifier)
        else
            ClearTimecycleModifier()
        end

        SendNUIMessage({ type = "enableui", enable = state })
    end

    RegisterNetEvent('ug-identity:ShowRegisterIdentity', function()
        TriggerEvent('ug-skin:ResetFirstSpawn')
        while not (ready and loadingScreenFinished) do
            if UgCore.Config.Core.Debug.Enabled then
                print('^7[ug-identity] ^5(INFO)^7: ^5Waiting for identity NUI...')
            end
            Wait(100)
        end
        if not UgCore.PlayerData.dead then SetGuiState(true) end
    end)

    RegisterNUICallback('register', function(data,cb)
        if not guiEnabled then
            return
        end

        UgCore.Callbacks.TriggerCallback('ug-identity:RegisterIdentity', function(callback)
            if not callback then
                return
            end

            UgCore.Functions.Notify(Languages.GetTranslation('thank_you_for_registering'), 'success', 5000)
            SetGuiState(false)

            if not UgCore.Dependencies.MultiCharacter then
                TriggerEvent('ug-skin:PlayerRegistered')
            end
        end, data)
        cb(1)
    end)
end