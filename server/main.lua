local UgCore = exports['ug-core']:GetCore()

local playerIdentity = {}
local alreadyRegistered = {}
local multichar = UgCore.Dependencies.MultiCharacter

local function DeleteIdentityFromDatabase(player)
    MySQL.query.await('UPDATE users SET firstName = ?, lastName = ?, dateOfBirth = ?, sex = ?, height = ?, skin = ? WHERE identifier = ?', { 
        nil, 
        nil, 
        nil, 
        nil, 
        nil, 
        nil, 
        player.identifier 
    })

    if Config.FullCharDelete then
        MySQL.update.await('UPDATE accounts SET money = 0 WHERE accountName IN (?) AND owner = ?', { 
            { 'bank_savings', 'caution' }, 
            player.identifier 
        })
        MySQL.prepare.await('UPDATE datastores SET data = ? WHERE name IN (?) AND owner = ?', { 
            '\'{}\'', 
            { 'user_ears', 'user_glasses', 'user_helmet', 'user_mask' }, 
            player.identifier 
        })
    end
end

local function DeleteIdentity(player)
    if not alreadyRegistered[player.identifier] then
        return
    end

    player.Functions.SetName(('%s %s'):format(nil, nil))
    player.Functions.SetData('firstName', nil)
    player.Functions.SetData('lastName', nil)
    player.Functions.SetData('dateOfBirth', nil)
    player.Functions.SetData('sex', nil)
    player.Functions.SetData('height', nil)
    DeleteIdentityFromDatabase(player)
end

local function SaveIdentityToDatabase(identifier, identity)
    MySQL.update.await('UPDATE users SET firstName = ?, lastName = ?, dateOfBirth = ?, sex = ?, height = ? WHERE identifier = ?', { 
        identity.firstName, 
        identity.lastName, 
        identity.dateOfBirth, 
        identity.sex, 
        identity.height, 
        identifier 
    })
end

local function CheckDOBFormat(str)
    str = tostring(str)
    if not string.match(str, '(%d%d)/(%d%d)/(%d%d%d%d)') then
        return false
    end

    local d, m, y = string.match(str, '(%d+)/(%d+)/(%d+)')

    m = tonumber(m)
    d = tonumber(d)
    y = tonumber(y)

    if ((d <= 0) or (d > 31)) or ((m <= 0) or (m > 12)) or ((y <= Config.LowestYear) or (y > Config.HighestYear)) then
        return false
    elseif m == 4 or m == 6 or m == 9 or m == 11 then
        return d < 30
    elseif m == 2 then
        if y % 400 == 0 or (y % 100 ~= 0 and y % 4 == 0) then
            return d < 29
        else
            return d < 28
        end
    else
        return d < 31
    end
end

local function FormatDate(str)
    local d, m, y = string.match(str, '(%d+)/(%d+)/(%d+)')
    local date = str

    if Config.DateFormat == "MM/DD/YYYY" then
        date = m .. "/" .. d .. "/" .. y
    elseif Config.DateFormat == "YYYY/MM/DD" then
        date = y .. "/" .. m .. "/" .. d
    end

    return date
end

local function CheckAlphanumeric(str)
    return (string.match(str, "%W"))
end

local function CheckForNumbers(str)
    return (string.match(str, "%d"))
end

local function CheckNameFormat(name)
    if not CheckAlphanumeric(name) and not CheckForNumbers(name) then
        local stringLength = string.len(name)
        return stringLength > 0 and stringLength < Config.MaxNameLength
    end

    return false
end

local function CheckSexFormat(sex)
    if not sex then
        return false
    end
    return sex == "m" or sex == "M" or sex == "f" or sex == "F"
end

local function CheckHeightFormat(height)
    local numHeight = tonumber(height) or 0
    return numHeight >= Config.MinHeight and numHeight <= Config.MaxHeight
end

local function ConvertToLowerCase(str)
    return string.lower(str)
end

local function ConvertFirstLetterToUpper(str)
    return str:gsub("^%l", string.upper)
end

local function FormatName(name)
    local loweredName = ConvertToLowerCase(name)
    return ConvertFirstLetterToUpper(loweredName)
end

if Config.UseDeferrals then
    AddEventHandler('playerConnecting', function(_, _, deferrals)
        deferrals.defer()
        local _, identifier = source, UgCore.Functions.GetIdentifier(source)
        Wait(100)

        if identifier then
            MySQL.single('SELECT firstName, lastName, dateOfBirth, sex, height FROM users WHERE identifier = ?', { identifier }, function(result)
                if result then
                    if result.firstName then
                        playerIdentity[identifier] = {
                            firstName = result.firstName,
                            lastName = result.lastName,
                            dateOfBirth = result.dateOfBirth,
                            sex = result.sex,
                            height = result.height
                        }

                        deferrals.done()
                    else
                        deferrals.presentCard(
                            [==[{"type": "AdaptiveCard","body":[{"type":"Container","items":[{"type":"ColumnSet",
                                "columns":[{"type":"Column","items":[{"type":"Input.Text","placeholder":"First Name",
                                "id":"firstname","maxLength":15},{"type":"Input.Text","placeholder":"Date of Birth (MM/DD/YYYY)",
                                "id":"dateofbirth","maxLength":10}],"width":"stretch"},{"type":"Column","width":"stretch",
                                "items":[{"type":"Input.Text","placeholder":"Last Name","id":"lastname","maxLength":15},
                                {"type":"Input.Text","placeholder":"Height (48-96 inches)","id":"height","maxLength":2}]}]},
                                {"type":"Input.ChoiceSet","placeholder":"Sex","choices":[{"title":"Male","value":"m"},
                                {"title":"Female","value":"f"}],"style":"expanded","id":"sex"}]},{"type": "ActionSet",
                                "actions": [{"type":"Action.Submit","title":"Submit"}]}],
                                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json","version":"1.0"}]==],
                            function(data)
                                if data.firstName == '' or data.lastName == '' or data.dateOfBirth == '' or data.sex ==
                                    '' or data.height == '' then
                                    deferrals.done(Languages.GetTranslation('data_incorrect'))
                                else
                                    if CheckNameFormat(data.firstName) and CheckNameFormat(data.lastName) and
                                        CheckDOBFormat(data.dateOfBirth) and CheckSexFormat(data.sex) and
                                        CheckHeightFormat(data.height) then
                                        playerIdentity[identifier] = {
                                            firstName = FormatName(data.firstName),
                                            lastName = FormatName(data.lastName),
                                            dateOfBirth = data.dateOfBirth,
                                            sex = data.sex,
                                            height = tonumber(data.height),
                                            saveToDatabase = true
                                        }

                                        deferrals.done()
                                    else
                                        deferrals.done(Languages.GetTranslation('invalid_format'))
                                    end
                                end
                            end)
                    end
                else
                    deferrals.presentCard(
                        [==[{"type": "AdaptiveCard","body":[{"type":"Container","items":[{"type":"ColumnSet","columns":[{
                            "type":"Column","items":[{"type":"Input.Text","placeholder":"First Name","id":"firstname",
                            "maxLength":15},{"type":"Input.Text","placeholder":"Date of Birth (MM/DD/YYYY)","id":"dateofbirth",
                            "maxLength":10}],"width":"stretch"},{"type":"Column","width":"stretch","items":[{"type":"Input.Text",
                            "placeholder":"Last Name","id":"lastname","maxLength":15},{"type":"Input.Text",
                            "placeholder":"Height (48-96 inches)","id":"height","maxLength":2}]}]},{"type":"Input.ChoiceSet",
                            "placeholder":"Sex","choices":[{"title":"Male","value":"m"},{"title":"Female","value":"f"}],
                            "style":"expanded","id":"sex"}]},{"type": "ActionSet","actions": [{"type":"Action.Submit",
                            "title":"Submit"}]}],"$schema": "http://adaptivecards.io/schemas/adaptive-card.json","version":"1.0"}]==],
                        function(data)
                            if data.firstName == '' or data.lastName == '' or data.dateOfBirth == '' or data.sex == '' or data.height == '' then
                                return deferrals.done(Languages.GetTranslation('data_incorrect'))
                            end
                            if not CheckNameFormat(data.firstName) then
                                return deferrals.done(Languages.GetTranslation('invalid_firstname_format'))
                            end
                            if not CheckNameFormat(data.lastName) then
                                return deferrals.done(Languages.GetTranslation('invalid_lastname_format'))
                            end
                            if not CheckDOBFormat(data.dateOfBirth) then
                                return deferrals.done(Languages.GetTranslation('invalid_dob_format'))
                            end
                            if not CheckSexFormat(data.sex) then
                                return deferrals.done(Languages.GetTranslation('invalid_sex_format'))
                            end
                            if not CheckHeightFormat(data.height) then
                                return deferrals.done(Languages.GetTranslation('invalid_height_format'))
                            end

                            playerIdentity[identifier] = {
                                firstName = FormatName(data.firstName),
                                lastName = FormatName(data.lastName),
                                dateOfBirth = FormatDate(data.dateOfBirth),
                                sex = data.sex,
                                height = tonumber(data.height),
                                saveToDatabase = true
                            }

                            deferrals.done()
                        end)
                end
            end)
        else
            deferrals.done(Languages.GetTranslation('no_identifier'))
        end
    end)

    RegisterNetEvent('ug-core:PlayerLoaded')
    AddEventHandler('ug-core:PlayerLoaded', function(_, player)
        if not playerIdentity[player.identifier] then
            return player.Functions.Kick('ug-identity', _('missing_identity'))
        end

        local currentIdentity = playerIdentity[player.identifier]
        player.Functions.SetName(('%s %s'):format(currentIdentity.firstName, currentIdentity.lastName))
        player.Functions.SetData('firstName', currentIdentity.firstName)
        player.Functions.SetData('lastName', currentIdentity.lastName)
        player.Functions.SetData('dateofbirth', currentIdentity.dateOfBirth)
        player.Functions.SetData('sex', currentIdentity.sex)
        player.Functions.SetData('height', currentIdentity.height)
        if currentIdentity.saveToDatabase then
            SaveIdentityToDatabase(player.identifier, currentIdentity)
        end

        Wait(0)
        alreadyRegistered[player.identifier] = true
        TriggerClientEvent('ug-identity:AlreadyRegistered', player.source)
        playerIdentity[player.identifier] = nil
    end)
else
    local function SetIdentity(player)
        if not alreadyRegistered[player.identifier] then
            return
        end
        local currentIdentity = playerIdentity[player.identifier]

        player.Functions.SetName(('%s %s'):format(currentIdentity.firstName, currentIdentity.lastName))
        player.Functions.SetData('firstName', currentIdentity.firstName)
        player.Functions.SetData('lastName', currentIdentity.lastName)
        player.Functions.SetData('dateofbirth', currentIdentity.dateOfBirth)
        player.Functions.SetData('sex', currentIdentity.sex)
        player.Functions.SetData('height', currentIdentity.height)
        TriggerClientEvent('ug-identity:SetPlayerData', player.source, currentIdentity)
        if currentIdentity.saveToDatabase then
            SaveIdentityToDatabase(player.identifier, currentIdentity)
        end

        playerIdentity[player.identifier] = nil
    end

    local function CheckIdentity(player)
        MySQL.single('SELECT firstName, lastName, dateOfBirth, sex, height FROM users WHERE identifier = ?', { 
            player.identifier 
        }, function(result)
            if not result then
                return TriggerClientEvent('ug-identity:ShowRegisterIdentity', player.source)
            end
            if not result.firstName then
                playerIdentity[player.identifier] = nil
                alreadyRegistered[player.identifier] = false
                return TriggerClientEvent('ug-identity:ShowRegisterIdentity', player.source)
            end

            playerIdentity[player.identifier] = {
                firstName = result.firstName,
                lastName = result.lastName,
                dateOfBirth = result.dateOfBirth,
                sex = result.sex,
                height = result.height
            }

            alreadyRegistered[player.identifier] = true
            SetIdentity(player)
        end
        )
    end

    if not multichar then
        AddEventHandler('playerConnecting', function(_, _, deferrals)
            deferrals.defer()
            local _, identifier = source, UgCore.Functions.GetIdentifier(source)
            Wait(40)

            if not identifier then
                return deferrals.done(Languages.GetTranslation('no_identifier'))
            end
            MySQL.single('SELECT firstName, lastName, dateOfBirth, sex, height FROM users WHERE identifier = ?', { 
                identifier 
            }, function(result)
                if not result then
                    playerIdentity[identifier] = nil
                    alreadyRegistered[identifier] = false
                    return deferrals.done()
                end
                if not result.firstName then
                    playerIdentity[identifier] = nil
                    alreadyRegistered[identifier] = false
                    return deferrals.done()
                end

                playerIdentity[identifier] = {
                    firstName = result.firstName,
                    lastName = result.lastName,
                    dateOfBirth = result.dateOfBirth,
                    sex = result.sex,
                    height = result.height
                }

                alreadyRegistered[identifier] = true

                deferrals.done()
            end)
        end)

        AddEventHandler('onResourceStart', function(resource)
            if resource ~= GetCurrentResourceName() then
                return
            end
            Wait(300)

            while not UgCore do Wait(0) end

            local players = UgCore.Functions.GetUgPlayers()

            for i = 1, #(players) do
                if players[i] then
                    CheckIdentity(players[i])
                end
            end
        end)

        RegisterNetEvent('ug-core:PlayerLoaded', function(_, player)
            local currentIdentity = playerIdentity[player.identifier]

            if currentIdentity and alreadyRegistered[player.identifier] then
                player.Functions.SetName(('%s %s'):format(currentIdentity.firstName, currentIdentity.lastName))
                player.Functions.SetData('firstName', currentIdentity.firstName)
                player.Functions.SetData('lastName', currentIdentity.lastName)
                player.Functions.SetData('dateofbirth', currentIdentity.dateOfBirth)
                player.Functions.SetData('sex', currentIdentity.sex)
                player.Functions.SetData('height', currentIdentity.height)
                TriggerClientEvent('ug-identity:SetPlayerData', player.source, currentIdentity)
                if currentIdentity.saveToDatabase then
                    SaveIdentityToDatabase(player.identifier, currentIdentity)
                end

                Wait(0)

                TriggerClientEvent('ug-identity:AlreadyRegistered', player.source)

                playerIdentity[player.identifier] = nil
            else
                TriggerClientEvent('ug-identity:ShowRegisterIdentity', player.source)
            end
        end)
    end

    UgCore.Callbacks.CreateCallback('ug-identity:RegisterIdentity', function(source, cb, data)
        local player = UgCore.Functions.GetPlayer(source)
        if not CheckNameFormat(data.firstName) then
            TriggerClientEvent('ug-core:Notify', source, 'Identity', Languages.GetTranslation('invalid_firstname_format'), 'error', 5000)
            return cb(false)
        end
        if not CheckNameFormat(data.lastName) then
            TriggerClientEvent('ug-core:Notify', source, 'Identity', Languages.GetTranslation('invalid_lastname_format'), 'error', 5000)
            return cb(false)
        end
        if not CheckSexFormat(data.sex) then
            TriggerClientEvent('ug-core:Notify', source, 'Identity', Languages.GetTranslation('invalid_sex_format'), 'error', 5000)
            return cb(false)
        end
        if not CheckDOBFormat(data.dateOfBirth) then
            TriggerClientEvent('ug-core:Notify', source, 'Identity', Languages.GetTranslation('invalid_dob_format'), 'error', 5000)
            return cb(false)
        end
        if not CheckHeightFormat(data.height) then
            TriggerClientEvent('ug-core:Notify', source, 'Identity', Languages.GetTranslation('invalid_height_format'), 'error', 5000)
            return cb(false)
        end
        if player then
            if alreadyRegistered[player.identifier] then
                player.Functions.Notify('Identity', Languages.GetTranslation('already_registered'), 'error', 5000)
                return cb(false)
            end

            playerIdentity[player.identifier] = {
                firstName = FormatName(data.firstName),
                lastName = FormatName(data.lastName),
                dateOfBirth = FormatDate(data.dateOfBirth),
                sex = data.sex,
                height = data.height
            }

            local currentIdentity = playerIdentity[player.identifier]

            player.Functions.SetName(('%s %s'):format(currentIdentity.firstName, currentIdentity.lastName))
            player.Functions.SetData('firstName', currentIdentity.firstName)
            player.Functions.SetData('lastName', currentIdentity.lastName)
            player.Functions.SetData('dateOfBirth', currentIdentity.dateOfBirth)
            player.Functions.SetData('sex', currentIdentity.sex)
            player.Functions.SetData('height', currentIdentity.height)
            TriggerClientEvent('ug-identity:SetPlayerData', player.source, currentIdentity)
            SaveIdentityToDatabase(player.identifier, currentIdentity)
            alreadyRegistered[player.identifier] = true
            playerIdentity[player.identifier] = nil
            return cb(true)
        end

        if not multichar then
            TriggerClientEvent('ug-core:Notify', source, 'Identity', Languages.GetTranslation('data_incorrect'), 'error', 5000)
            return cb(false)
        end

        local formattedFirstName = FormatName(data.firstName)
        local formattedLastName = FormatName(data.lastName)
        local formattedDate = FormatDate(data.dateOfBirth)

        data.firstName = formattedFirstName
        data.lastName = formattedLastName
        data.dateOfBirth = formattedDate
        local Identity = {
            firstName = formattedFirstName,
            lastName = formattedLastName,
            dateOfBirth = formattedDate,
            sex = data.sex,
            height = data.height
        }

        TriggerEvent('ug-identity:CompletedRegistration', source, data)
        TriggerClientEvent('ug-identity:SetPlayerData', source, Identity)
        cb(true)
    end)
end

if Config.EnableCommands then
    UgCore.Commands.CreateCommand('char', 'user', function (player)
        if player and player.Functions.GetName() then
            player.Functions.Notify('Identity', Languages.GetTranslation('active_character', player.Functions.GetName()), 'info', 5000)
        else
            player.Functions.Notify('Identity', Languages.GetTranslation('error_active_character'), 'error', 5000)
        end
    end, false, { help = Languages.GetTranslation('show_active_character') })

    UgCore.Commands.CreateCommand('chardel', 'user', function (player)
        if player and player.getName() then
            if Config.UseDeferrals then
                player.Functions.Kick('ug-identity', Languages.GetTranslation('deleted_identity'))
                Wait(1500)
                DeleteIdentity(player)
                player.Functions.Notify('Identity', Languages.GetTranslation('deleted_character'), 'error', 5000)
                playerIdentity[player.identifier] = nil
                alreadyRegistered[player.identifier] = false
            else
                DeleteIdentity(player)
                player.Functions.Notify('Identity', Languages.GetTranslation('deleted_character'), 'success', 5000)
                playerIdentity[player.identifier] = nil
                alreadyRegistered[player.identifier] = false
                TriggerClientEvent('ug-identity:ShowRegisterIdentity', player.source)
            end
        else
            player.Functions.Notify('Identity', Languages.GetTranslation('error_delete_character'), 'error', 5000)
        end
    end, false, { help = Languages.GetTranslation('delete_character') })
end