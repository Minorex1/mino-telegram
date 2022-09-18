local gumCore = {}

TriggerEvent("getCore",function(core)
gumCore = core
end)

inv = exports.gum_inventory:gum_inventoryApi()
gum = exports.gum_core:gumAPI()

function getRandomPostbox()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local length = 2
    local randomString = ''

    math.randomseed(os.time())

    charTable = {}
    for c in chars:gmatch "." do
        table.insert(charTable, c)
    end

    for i = 1, length do
        randomString = randomString .. charTable[math.random(1, #charTable)]
    end
    return randomString .. math.random(1000, 9999)
end

function getPostbox(charid, cb)
    exports['ghmattimysql']:execute("SELECT * FROM characters WHERE charidentifier = @chid", { ["@chid"] = charid }, function(result)
        if result ~= nil then
            cb(result[1]['postbox'])
        end
        return nil
    end)
end

function getOrGenerate(charid, cb)
    getPostbox(charid, function(s)
        local postbox = s
        if postbox == nil then
            postbox = getRandomPostbox()
            exports.ghmattimysql:execute("UPDATE characters SET postbox = @pox WHERE charidentifier = @chid", { ["@chid"] = charid, ["@pox"] = postbox }, function() cb(postbox) end)
        else
            cb(postbox)
        end
    end)
end

RegisterServerEvent("mino-telegram:check_inbox")
AddEventHandler("mino-telegram:check_inbox", function()
    local _source = source
    local User = gumCore.getUser(_source)
    local Character = User.getUsedCharacter
    getOrGenerate(Character.charIdentifier, function(postbox)
        exports.ghmattimysql:execute("SELECT * FROM telegrams WHERE recipient = @reci ORDER BY id DESC", { ['@reci'] = postbox }, function(result)
            local res = {}
            res['box'] = postbox
            res['firstname'] = Character.firstname
            res['list'] = result
            if result ~= nil then
                TriggerClientEvent("inboxlist", _source, res)
            end
        end)
    end)
end)

RegisterServerEvent("mino-telegram:SendTelegram")
AddEventHandler("mino-telegram:SendTelegram", function(data)
    local _source = source
    local User = gumCore.getUser(_source)
    local Character = User.getUsedCharacter
    local currentMoney = Character.money
    local removeMoney = Config.Pay

    if currentMoney >= removeMoney then
        getOrGenerate(Character.charIdentifier, function(postbox)
            local sentDate = os.date("%x")
            exports.ghmattimysql:execute("SELECT postbox FROM characters WHERE postbox = @pox",{["@pox"] = data.recipient}, function(result)
                if result[1] ~= nil then
                    if data.recipient == nil or data.recipient == '' and data.subject == nil or data.subject == '' then
                        TriggerClientEvent("gum_notify:notify", _source, "TELEGRAM", "You need to add a PO Box and the Subject of your message", "", 3000)  
                    else
                        local Parameters = { ['recipient'] = data.recipient, ['sender'] = postbox, ['subject'] = data.subject, ['sentTime'] = sentDate, ['message'] = data.message, ['postoffice'] = data.postoffice }
                        exports.ghmattimysql:execute("INSERT INTO telegrams ( `recipient`,`sender`,`subject`,`sentTime`,`message`,`postoffice`) VALUES ( @recipient,@sender, @subject,@sentTime,@message,@postoffice )", Parameters)
                        Character.removeCurrency(_source, 0, removeMoney)
                        TriggerClientEvent("gum_notify:notify", _source, "TELEGRAM", "Telegram have been sent for an ammount of" .. removeMoney .." ".. "cents", "", 3000)               
                    end
                else
                    TriggerClientEvent("gum_notify:notify", _source, "TELEGRAM", "The POBox you are trying to send the Telegram to, does not exist", "", 3000)
                end
            end)
        end)
    else
        TriggerClientEvent("gum_notify:notify", _source, "TELEGRAM", "you do not have enough money", "", 3000)
    end
end)

RegisterServerEvent("mino-telegram:getTelegram")
AddEventHandler("mino-telegram:getTelegram", function(tid)
    local _source = source
    local User = gumCore.getUser(_source).getUsedCharacter
    local telegram = {}
    Citizen.Wait(0)
    exports.ghmattimysql:execute("SELECT * FROM telegrams WHERE id = @id", { ['@id'] = tid }, function(result)

        if result[1] ~= nil then
            telegram['recipient'] = User.firstname
            telegram['sender'] = result[1]['sender']
            telegram['sentTime'] = result[1]['sentTime']
            telegram['subject'] = result[1]['subject']
            telegram['message'] = result[1]['message']
            exports.ghmattimysql:execute("UPDATE telegrams SET status = '1' WHERE id = @id", { ["@id"] = tid })
            TriggerClientEvent("messageData", _source, telegram)
        end
    end)
end)

RegisterServerEvent("mino-telegram:DeleteTelegram")
AddEventHandler("mino-telegram:DeleteTelegram", function(tid)
	local _source = source

    Citizen.Wait(0)
   
    exports.ghmattimysql:execute("SELECT * FROM telegrams WHERE id = @id", { ['@id'] = tid }, function(result)
        if result[1] ~= nil then
            exports.ghmattimysql:execute("DELETE FROM telegrams WHERE id = @id", { ["@id"] = tid })
            TriggerClientEvent("gum_notify:notify", _source, "TELEGRAM", "Telegram deleted.", "", 2000)
        else
            TriggerClientEvent("gum_notify:notify", _source, "TELEGRAM", "Failed to delete your message.", "", 2000)
        end
    end)
    
end)