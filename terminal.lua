local files = {
    {path = "/lib/json.lua", link = "https://raw.githubusercontent.com/rxi/json.lua/master/json.lua"},
    {path = "/lib/serialization.lua", link = "https://raw.githubusercontent.com/MightyPirates/OpenComputers/master-MC1.7.10/src/main/resources/assets/opencomputers/loot/openos/lib/serialization.lua"}
}

if not filesystem.exists("/lib") then
    filesystem.makeDirectory("/lib")
end

for file = 1, #files do
    if not filesystem.exists(files[file].path) then
        write(files[file].path, "w", request(files[file].link))
    end
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local me_side = "DOWN"
local pim_side = "UP"
local server = "Default"
local version, port = "modem", 1414
local serverAddress = "6fccfc0c-082c-4228-9dec-71a2185ea085"

local priceLottery = 150
local superPrize = 10000
local freeFoodCount = 16

local INFO = [[
[0x68f029]1. [0xffffff]Что это такое? Ответ — Это магазин.
[0x68f029]2. [0xffffff]Что такое Emeralds? Ответ — это валюта сервера.
[0x68f029]3. [0xffffff]Как пополнить баланс? Ответ - используя сундуки рядом    купите "деньги", затем используйте кнопку "Пополнить баланс" в магазине.
[0x68f029]4. [0xffffff]Как купить товар? Ответ — нужно выбрать товар из списка, кликнув далее ввести количество и нажать "Купить". Товар    будет добавлен в ваш инвентарь. Если эмов на счету недостаточно - товар нельзя будет купить.
[0x68f029]5. [0xffffff]За нарушение правил сервера при использовании магазина вы будете заблокированы.
]]

local pim, me, selector, tmpfs, modem = proxy("pim"), proxy("me_interface"), proxy("openperipheral_selector"), component.proxy(computer.tmpAddress())
local json, serialization = require("json"), require("serialization")
local terminal = computer.address()
local key
local moneyFingerprint = {dmg=0.0,id="customnpcs:npcMoney"}

local active = true
local guiPage = 1 
local itemScan = false
local unAuth = false
local autonomous = false

local color = {
    pattern = "%[0x(%x%x%x%x%x%x)]",
    background = 0x000000,
    pim = 0x46c8e3,

    gray = 0x303030,
    lightGray = 0x999999,
    blackGray = 0x1a1a1a,
    lime = 0x68f029,
    blackLime = 0x4cb01e,
    orange = 0xf2b233,
    blackOrange = 0xc49029,
    blue = 0x4260f5,
    blackBlue = 0x273ba1,
    red = 0xff0000
}

local pimGeometry = {
    x = 23,
    y = 7,

    "⡏⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⢹",
    "⡇              ⢸",
    "⡇              ⢸",
    "⡇              ⢸",
    "⡇              ⢸",
    "⡇              ⢸",
    "⡇              ⢸",
    "⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣸"

}

local infoList, session, items, itemsInMe, guiPath, guiVariables = {{}}, {}, {}, {}, {}, {}, {}

local function set(x, y, str, background, foreground)
    if background and gpu.getBackground() ~= background then
        gpu.setBackground(background)
    end

    if foreground and gpu.getForeground() ~= foreground then
        gpu.setForeground(foreground)
    end

    gpu.set(x or math.floor(31 - unicode.len(str) / 2), y, str)
end

local function setColorText(x, y, str, background)
    gpu.setBackground(background)
    if not x then
        x = math.floor(31 - unicode.len(str:gsub("%[%w+]", "")) / 2)
    end

    local begin = 1

    while true do
        local b, e, color = str:find(color.pattern, begin)
        local precedingString = str:sub(begin, b and (b - 1))

        if precedingString then
            gpu.set(x, y, precedingString)
            x = x + unicode.len(precedingString)
        end

        if not color then
            break
        end

        gpu.setForeground(tonumber(color, 16))
        begin = e + 1
    end
end

local function fill(x, y, w, h, symbol, background, foreground)
    if background and gpu.getBackground() ~= background then
        gpu.setBackground(background)
    end

    if foreground and gpu.getForeground() ~= foreground then
        gpu.setForeground(foreground)
    end

    gpu.fill(x, y, w, h, symbol)
end

local function clear()
    fill(1, 1, 60, 19, " ", color.background)
end

local function drawButton(button, active)
    local background, foreground = active and buttons[button].activeBackground or buttons[button].disabled and buttons[button].disabledBackground or buttons[button].background, active and buttons[button].activeForeground or buttons[button].disabled and buttons[button].disabledForeground or buttons[button].foreground
    fill(buttons[button].x, buttons[button].y, buttons[button].width, buttons[button].height, " ", background)
    set(buttons[button].textPosX, buttons[button].textPosY, buttons[button].text, background, foreground)
end

local function drawButtons()
    for button in pairs(buttons) do 
        if buttons[button].buttonIn[guiPath[#guiPath]] and not buttons[button].notVisible then
            buttons[button].active = false
            if buttons[button].withoutDraw then
                buttons[button].action(false)
            else
                drawButton(button, false)
            end
        end
    end
end

local function clickDrawButton(button)
    drawButton(button, true)
    sleep(0.01)
    drawButton(button, false)
end

local function drawPim()
    for str = 1, #pimGeometry do 
        set(pimGeometry.x, pimGeometry.y + str, pimGeometry[str], color.background, color.pim)
    end
end

local function discord()
    setColorText(12, 18, "[0x303030]По любым проблемам пишите: [0x337d11]Doggernaut", color.background) --tarcassum
end

local function outOfService(reason)
    active = false
    clear()
    set(8, 7, "Магазин не работает, приносим свои извинения за", color.background, color.lime)
    set(18, 8, "предоставленные неудобства", color.background, color.lime)
    set(23, 13, "OUT OF SERVICE!", color.background, color.red)
    if reason then
        set(nil, 16, "Причина: " .. reason, color.background, color.gray)
    end
    discord()
end

local function time(raw)
    local handle = tmpfs.open("/time", "w")
    tmpfs.write(handle, "time")
    tmpfs.close(handle)
    local timestamp = tmpfs.lastModified("/time") / 1000 + 3600 * 3 

    return raw and timestamp or os.date("%d.%m.%Y %H:%M:%S", timestamp)
end

local function log(data, name)
    local timestamp = time(true)

    local date = os.date("%d.%m.%Y", timestamp)
    local path = "/logs/" .. date .. "/"
    local days = {date .. "/", os.date("%d.%m.%Y/", timestamp - 86400), os.date("%d.%m.%Y/", timestamp - 172800), os.date("%d.%m.%Y/", timestamp - 259200)}
    local data = os.date("[%H:%M:%S]", timestamp) .. tostring(data) .. "\n"

    for day = 1, #days do 
        days[days[day]], days[day] = true, nil
    end
    if not filesystem.exists(path) then
        filesystem.makeDirectory(path)
    end

    local paths = filesystem.list("/logs/")
    for oldPath = 1, #paths do 
        local checkPath = "/logs/" .. paths[oldPath]

        if not days[paths[oldPath]] and filesystem.isDirectory(checkPath) and checkPath:match("%d+.%d+.%d+.log") then
            filesystem.remove(checkPath)
        end
    end

    if name then
        write(path .. name .. ".log", "a", data)
    else
        write(path .. "main.log", "a", data)
    end
end

local function sort(a, b)
    if type(a) ~= "table" and type(b) ~= "table" then
        return a < b
    elseif a.text then
        return a.text < b.text
    elseif a.user then
        return a.user < b.user
    end
end

local function parseInfo()
    local tag, str, symbols, skip, words, page = false, "", 0, 0, 0, 1

    for sym = 1, unicode.len(INFO) do 
        if skip > 0 then
            skip = skip - 1
        else
            local symbol = unicode.sub(INFO, sym, sym)
            
            if symbol == [[\]] and unicode.sub(INFO, sym + 1, sym + 1) == "n" then
                table.insert(infoList[page], str)
                table.insert(infoList[page], "\n")
                str, symbols, words, skip = "", 0, words + 1, 1
            elseif not ((symbols == 0 or symbols == 60) and symbol == " ") then
                if symbol == "\n" and symbols > 0 then
                    table.insert(infoList[page], str)
                    table.insert(infoList[page], "\n")
                    str, symbols, words = "", 0, words + 1
                elseif symbol == "[" then
                    tag = ""

                    if str ~= "" then
                        table.insert(infoList[page], str)
                        str = ""
                    end
                elseif symbol == "]" then
                    table.insert(infoList[page], {tonumber(tag)})
                    tag = false
                elseif tag then
                    tag = tag .. symbol 
                else 
                    if symbols == 60 then
                        table.insert(infoList[page], str)
                        table.insert(infoList[page], "\n")
                        str, symbols, words = "", 0, words + 1
                    end

                    str = str .. symbol
                    symbols = symbols + 1 
                end

                if sym == unicode.len(INFO) and str ~= "" then
                    table.insert(infoList[page], str)
                end

                if words == 13 then
                    page, words = page + 1, 0
                    infoList[page] = {}
                end
            end
        end
    end
end

local function encodeChar(chr)
    return string.format("%%%X", string.byte(chr))
end
 
local function encodeString(str)
    local out = string.gsub(str, "[^%w]", encodeChar)
    return out
end

local function downloadItems()
    local data = request("https://raw.githubusercontent.com/malificent1111/lua/main/list.lua")
    local chunk, err = load("return " .. data, "=items.lua", "t")
    if not chunk then 
        error("Неправильно сконфигурирован файл вещей! " .. err)
    else
        items = chunk()
    end

    for item = 1, #items.shop do
        if not items.shop[item].strictHash then
            for fingerprint = 1, #items.shop[item].fingerprint do
                items.shop[item].fingerprint[fingerprint].nbt_hash = nil
            end
        end
        if items.shop[item].ignoreDamage then
            for fingerprint = 1, #items.shop[item].fingerprint do
                items.shop[item].fingerprint[fingerprint].dmg = nil
            end
        end
    end
    table.sort(items.shop, sort)
end

local function pull(timeout, eventType)
    local deadline = (computer.uptime() + timeout) or 0
    repeat
        local signal = {computer.pullSignal(deadline - computer.uptime())}

        if signal and (signal[1] == eventType or not eventType) then
            return table.unpack(signal)
        end
    until computer.uptime() >= deadline
end

local function requestWithData(log, data, forceKey)
    data.key = forceKey or key
    data.server = server
    data.terminal = terminal
    data.log = log
    if version == "internet" then
        local response = request(serverAddress .. encodeString(json.encode(data)))

        if response then
            local success, decoded = pcall(json.decode, response)

            if success then
                return decoded
            end
        end
    elseif version == "modem" then
        modem.send(serverAddress, port, serialization.serialize(data))
        local response = {pull(3, "modem_message")}
        
        if response and response[3] == serverAddress and port == response[4] then
            local data, err = serialization.unserialize(response[6])

            if data then
                return data
            else
                error("Error on deserealizing message, err " .. err .. " data " .. data)
            end
        end
    else
        error("Unknown program version, need internet/modem")
    end

    return false
end

local function checkPlayer(reason)
    local name = pim.getInventoryName()

    if name ~= session.name then
        if name ~= "pim" then 
            if reason then
                log(reason, session.name)
            end

            login()
        end
    else
        return true
    end
end

local function setItemsMarket()
    for item = 1, #items.shop do
        items.shop[item].notVisibleBuy = true
        items.shop[item].notVisibleSell = true
        items.shop[item].leftCount = 0

        if items.shop[item].buyPrice then
            if items.shop[item].count <= items.shop[item].minCount then
                items.shop[item].notVisibleBuy = true
            else
                items.shop[item].notVisibleBuy = false
            end
        end
        if items.shop[item].sellPrice then
            if items.shop[item].count >= items.shop[item].maxCount then
                items.shop[item].notVisibleSell = true
            else
                items.shop[item].notVisibleSell = false
                items.shop[item].leftCount = math.floor(items.shop[item].maxCount - items.shop[item].count)
            end
        end
    end
end

local function pushItem(slot, count)
    local item = pim.getStackInSlot(slot)

    if item then
        local itemToLog = "id=" .. item.id .. "|display_name=" .. item.display_name
        if checkPlayer("Был обнаружен игрок при попытке забрать предмет: ".. itemToLog) then
            if pim.pushItem(me_side, slot, count) > 0 then
                log("Забираю предмет(" .. count .. " шт): " .. itemToLog, session.name)
                return true
            else
                log("Кончилось место в МЭ системе. Останавливаю работу...")
                outOfService("кончилось место в МЭ системе")
                return false
            end
        end
    end
end

local function findSlot()
    for slot = 1, 36 do 
        local success, err = pim.getStackInSlot(slot)

        if not success and not err then
            return slot
        elseif err then
            log("Игрок встал с PIM при поиске слота", session.name)
            return false, err
        end
    end
end

local function scanSlot(slot, raws, nbt_hash)
    local item = pim.getStackInSlot(slot)

    if item then
        for raw = 1, #raws do
            if item and (item.raw_name == raws[raw]) and (not nbt_hash or item.nbt_hash == nbt_hash) then
                return item.qty
            end
        end
    end
end

local function scanSlots(raws, nbt_hash)
    for slot = 1, 36 do 
        local count = scanSlot(slot, raws, nbt_hash)

        if count then
            return slot, count
        end
    end
end

local function getItemCount(fingerprint, needed)
    local allCount, availableItems = 0, {}

    for item = 1, #itemsInMe do 
        if itemsInMe[item].fingerprint.id == fingerprint.id and (not fingerprint.dmg or itemsInMe[item].fingerprint.dmg == fingerprint.dmg) and (not fingerprint.nbt_hash or itemsInMe[item].fingerprint.nbt_hash == fingerprint.nbt_hash) then
            if needed and (itemsInMe[item].size >= needed) then
                table.insert(availableItems, {fingerprint = itemsInMe[item].fingerprint, count = needed})
                allCount = needed
                return allCount, availableItems
            end

            if needed and (itemsInMe[item].size + allCount > needed) then
                table.insert(availableItems, {fingerprint = itemsInMe[item].fingerprint, count = itemsInMe[item].size - allCount})
                allCount = allCount + (itemsInMe[item].size - allCount)
                break
            else
                table.insert(availableItems, {fingerprint = itemsInMe[item].fingerprint, count = itemsInMe[item].size})
                allCount = allCount + itemsInMe[item].size
            end
        end
    end

    return allCount, availableItems
end

local function getAllItemCount(fingerprints, needed)
    local allCount, availableItems = 0, {}

    for item = 1, #fingerprints do
        local count, trueFingerprints = getItemCount(fingerprints[item], needed)

        if count > 0 then
            if needed and (count >= needed) then
                table.insert(availableItems, {fingerprints = trueFingerprints, count = needed})
                allCount = needed
                return allCount, availableItems
            end

            if needed and (count + allCount > needed) then
                table.insert(availableItems, {fingerprints = trueFingerprints, count = count - allCount})
                allCount = allCount + (count - allCount)
                break
            else
                table.insert(availableItems, {fingerprints = trueFingerprints, count = count})
                allCount = allCount + count
            end
        end
        if needed and allCount >= needed then
            break
        end
    end

    return allCount, availableItems
end

local function scanMe()
    itemsInMe = me.getAvailableItems()

    for item = 1, #items.shop do 
        items.shop[item].count = math.floor(getAllItemCount(items.shop[item].fingerprint))
    end

    setItemsMarket()
end

local function rawInsert(fingerprint, count)
    local slot = findSlot()
    while not slot do
        if checkPlayer() then
            alert({"Освободите любой слот"})
            slot = findSlot()
        else
            return 0, "Предмет не выдан, не было свободных слотов, " .. session.name .. " встал с PIM"
        end
    end
    local success, returnValue = pcall(me.exportItem, fingerprint, pim_side, count, slot)

    if success then
        return returnValue.size
    else
        return 0, returnValue or "Unknown error"
    end
end

local function insertItem(fingerprint, count)
    local itemToLog = "id=" .. fingerprint.id .. "|dmg=" .. tostring(fingerprint.dmg)
    local itemsInserted = 0

    if checkPlayer("Detected another player!") then
        local checkItem = me.getItemDetail(fingerprint)

        if checkItem then
            local item = checkItem.basic()
            log("Giving(" .. math.floor(count) .. " qty, all qty: " ..  math.floor(item.qty) ..") " .. itemToLog, session.name)

            if item.qty >= count then
                if count > item.max_size then
                    for i = 1, math.ceil(count / item.max_size) do
                        local stack = count > item.max_size
                        local inserted, err = rawInsert(fingerprint, stack and item.max_size or count)

                        if inserted > 0 then
                            itemsInserted = itemsInserted + inserted
                            count = stack and count - item.max_size or count
                        else
                            log("Item not given out , err " .. err, session.name)
                            break
                        end
                    end
                else
                    local inserted, err = rawInsert(fingerprint, count)

                    if inserted > 0 then
                        itemsInserted = itemsInserted + inserted
                    else
                        log("Item not given out, err " .. err, session.name)
                    end
                end
            end
        end
    end

    log("Items give out(" .. math.floor(itemsInserted) .. " qty) " .. itemToLog, session.name)
    return itemsInserted
end

local function autoInsert(fingerprint, count)
    local itemsInserted = 0
    local allCount, availableItems = getAllItemCount(fingerprint, count)

    if allCount >= count then
        for item = 1, #availableItems do
            for fingerprint = 1, #availableItems[item].fingerprints do
                local inserted = insertItem(availableItems[item].fingerprints[fingerprint].fingerprint, availableItems[item].fingerprints[fingerprint].count)

                if inserted > 0 then
                    itemsInserted = itemsInserted + inserted
                else
                    return itemsInserted
                end
            end
        end
    end

    return itemsInserted
end

local function drawBar(list)
    if lists[list].bar.active then
        fill(lists[list].bar.x, lists[list].y, 1, lists[list].height, " ", lists[list].bar.background)
        fill(lists[list].bar.x, lists[list].y + lists[list].bar.pos - 1, 1, lists[list].bar.length, lists[list].bar.symbol, lists[list].bar.activeBackground, lists[list].bar.activeForeground)
    else
        fill(lists[list].bar.x, lists[list].y, 1, lists[list].height, lists[list].bar.symbol, lists[list].bar.activeBackground, lists[list].bar.activeBackground)
    end
end

local function calculateBar(list)
    if #lists[list].scrollContent <= lists[list].height then
        lists[list].bar.active = false
    else
        lists[list].bar.length = lists[list].height / #lists[list].scrollContent * lists[list].height
        lists[list].bar.length = select(2, math.modf(lists[list].bar.length)) > .5 and math.ceil(lists[list].bar.length) or math.floor(lists[list].bar.length)
        lists[list].bar.active = true
        lists[list].bar.shift = (lists[list].height - lists[list].bar.length) / (#lists[list].scrollContent - lists[list].height)
        lists[list].bar.pos = 1
        lists[list].bar.move = false
        lists[list].bar.mousePos = false
        lists[list].bar.down = false
    end
end

local function drawContent(list, index, active, y)
    local background = active and lists[list].activeContentBackground or lists[list].contentBackground
    fill(lists[list].x, y, lists[list].width, 1, " ", background)
    set(lists[list].x, y, lists[list].scrollContent[index].text, background, active and lists[list].activeContentForeground or lists[list].contentForeground)
end

local function drawList(list)
    if #lists[list].scrollContent < lists[list].height then
        fill(lists[list].x, lists[list].y, lists[list].width, lists[list].height, " ", lists[list].background, lists[list].foreground)
    end

    if #lists[list].scrollContent > 0 then
        local counter = 1

        for i = lists[list].pos, #lists[list].scrollContent do 
            if counter <= lists[list].height then 
                drawContent(list, i, i == lists[list].scrollContent.activeIndex and true or false, counter + lists[list].y - 1)
                counter = counter + 1
            else
                break
            end
        end
    end

    drawBar(list)
end

local function scroll(list, shift)
    lists[list].pos = lists[list].pos + shift
    lists[list].bar.mousePos = lists[list].bar.mousePos and lists[list].bar.mousePos + shift
    lists[list].bar.pos = math.ceil(lists[list].bar.shift * lists[list].pos)
    drawList(list)
end

local function barMove(list, y)
    lists[list].bar.mousePos = false
    local shift = lists[list].bar.pos - y

    if y >= lists[list].y and y <= lists[list].endY then
        lists[list].bar.move = y - lists[list].y + 1
    else
        if y < lists[list].y then 
            lists[list].bar.move = 1
        else 
            lists[list].bar.move = lists[list].endY - lists[list].y + 1
        end
    end
    if lists[list].bar.move > lists[list].bar.pos then
        lists[list].bar.down = true
    end
end

local function setScrollContent(list)
    local counter = 1
    lists[list].scrollContent = {}
    lists[list].pos = 1

    if #lists[list].content > 0 then
        for content = 1, #lists[list].content do
            if not lists[list].attachedWrite or lists[list].attachedWrite and unicode.lower((lists[list].content[content].findText and lists[list].content[content].findText or lists[list].content[content].text)):match(unicode.lower(writes[lists[list].attachedWrite].input:gsub("%[+", "%%[+"))) then
                lists[list].scrollContent[counter] = lists[list].content[content]
                counter = counter + 1
            end
        end
    end

    if lists[list].bar then
        calculateBar(list)
        drawBar(list)
    end
    drawList(list)
end

local function setContent(list)
    local counter = 1
    for list in pairs(lists) do 
        lists[list].content = {}
        lists[list].scrollContent = {}
    end

    if list == "buy" then 
        for item = 1, #items.shop do
            if not items.shop[item].notVisibleBuy then
                lists[list].content[counter] = {}
                local label = unicode.sub(items.shop[item].text, 1, 32)
                local count = tostring(items.shop[item].count)
                lists[list].content[counter].findText = items.shop[item].text
                lists[list].content[counter].text = label .. string.rep(" ", 32 - unicode.len(label)) .. count .. string.rep(" ", 15 - unicode.len(count)) .. items.shop[item].buyPrice
                lists[list].content[counter].index = item
                counter = counter + 1
            end
        end
    elseif list == "sell" then
        for item = 1, #items.shop do
            if not items.shop[item].notVisibleSell then
                lists[list].content[counter] = {}
                local label = unicode.sub(items.shop[item].text, 1, 32)
                local leftCount = tostring(items.shop[item].leftCount)
                lists[list].content[counter].findText = items.shop[item].text
                lists[list].content[counter].text = label .. string.rep(" ", 32 - unicode.len(label)) .. leftCount .. string.rep(" ", 15 - unicode.len(leftCount)) .. items.shop[item].sellPrice
                lists[list].content[counter].index = item
                counter = counter + 1
            end
        end
    end

    setScrollContent(list)
end

local function cursorBlink(write, x, active)
    set(x, writes[write].y, "▁", writes[write].activeBackground, active and writes[write].cursorForeground and writes[write].cursorForeground or writes[write].activeCursorForeground)
end

local function cursor(write, active, force)
    if writes[write].cursor and (force or computer.uptime() >= writes[write].cursorTime) then
        if writes[write].len < writes[write].width then
            cursorBlink(write, writes[write].x + writes[write].len, active)
        else
            cursorBlink(write, writes[write].x + writes[write].width - 1, active)
        end

        writes[write].cursorState = active
        writes[write].cursorTime = computer.uptime() + .5
    end
end

local function inputFunction(write, char)
    if writes[write].actionOnWrite then
        writes[write].actionOnWrite(char)
    end
end

local function drawText(write, active, clear)
    if writes[write].len < writes[write].width - 1 then
        if clear then
            fill(writes[write].x, writes[write].y, writes[write].width, 1, " ", writes[write].background)
        end
        set(writes[write].x, writes[write].y, writes[write].input, active and writes[write].activeBackground or writes[write].background, active and writes[write].activeForeground or writes[write].foreground)
    else
        set(writes[write].x, writes[write].y, unicode.sub(writes[write].input, writes[write].len - writes[write].width + 2, writes[write].len), active and writes[write].activeBackground or writes[write].background, active and writes[write].activeForeground or writes[write].foreground)
    end
end

local function drawWrite(write)
    fill(writes[write].x, writes[write].y, writes[write].width, 1, " ", writes[write].background)
    if writes[write].input ~= "" then
        drawText(write, false)
    else
        set(writes[write].textPosX, writes[write].y, writes[write].text, writes[write].background, writes[write].foreground)
    end
end

local function drawGui()
    drawButtons()
    for list in pairs(lists) do
        if lists[list].listIn == guiPath[#guiPath] then
            setContent(list)
        end
    end

    for write in pairs(writes) do 
        if writes[write].writeIn == guiPath[#guiPath] and not writes[write].notVisible then
            if not writes[write].focus then
                focus.write = write
            end
            drawWrite(write)
        end
    end
end

local function inputWrite(write, char)
    local checkWrite = writes[write].number and (char >= 48 and char <= 57 and not (writes[write].strictNumber and writes[write].input == "" and char == 48)) or not writes[write].number and char >= 32

    if writes[write].actionBefore then
        if checkWrite then
            writes[write].actionBefore(char)
        end
    end

    if char == 203 and writes[write].cursor then
        if writes[write].pos - 1 ~= -1 then
            writes[write].pos = writes[write].pos - 1
        end
    elseif char == 205 and writes[write].cursor then
        if writes[write].pos + 1 ~= writes[write].border then
            writes[write].pos = writes[write].pos + 1
        end
    elseif char == 13 then
        if writes[write].actionOnEnter then 
            writes[write].actionOnEnter()
        end
        if writes[write].focus then 
            write = false
        end
    elseif checkWrite and writes[write].len + 1 ~= writes[write].border and not writes[write].onlyClear then
        local symbol = unicode.char(char)
        if writes[write].pos ~= writes[write].len then
            local beforeInput, afterInput = unicode.sub(1, writes[write].pos), unicode.sub(writes[write].pos, writes[write].len)
            writes[write].input = beforeInput .. symbol .. afterInput
        else
            writes[write].input = writes[write].input .. symbol
        end
        writes[write].len = writes[write].len + 1
        writes[write].pos = writes[write].pos + 1

        drawText(write, true)
        inputFunction(write, char)
        cursor(write, true, true)
    elseif char == 8 and writes[write].len - 1 ~= -1 then
        if writes[write].pos ~= writes[write].len then
            local beforeInput, afterInput = unicode.sub(1, writes[write].pos - 1), unicode.sub(writes[write].pos, writes[write].len)
            writes[write].input = beforeInput .. afterInput
        else
            writes[write].input = unicode.sub(writes[write].input, 1, writes[write].len - 1)
        end
        writes[write].len = writes[write].len - 1
        writes[write].pos = writes[write].pos - 1

        if writes[write].strictNumber and writes[write].input == "" then
            set(writes[write].x, writes[write].y, "0", color.activeBackground, color.activeForeground)
        end

        drawText(write, true, true)
        inputFunction(write)
        cursor(write, true, true)
    end
end

local function balance(y, account)
    fill(1, 1, 60, 1, " ", color.background)
    setColorText(nil, y, "[0x68f029]Баланс: [0xffffff]" .. session.balance .. " Emeralds", color.background)
end

local function purchase()
    local count = tonumber(writes.amount.input)

    if guiVariables[guiPath[#guiPath]].amount <= session.balance then
        log("Init buy (" .. count .. " qty in the amount of " .. guiVariables[guiPath[#guiPath]].amount .. " rip) " .. guiVariables[guiPath[#guiPath]].item.text, session.name)
        local purchased = autoInsert(guiVariables[guiPath[#guiPath]].item.fingerprint, count)

        if purchased > 0 then
            local trueAmount = purchased * guiVariables[guiPath[#guiPath]].item.buyPrice
            local msgToLog = session.name .. " buy the (" .. purchased .. " qty in the amount of " .. trueAmount .. " rip) " .. guiVariables[guiPath[#guiPath]].item.text
            log(msgToLog, session.name)
            local balanceDiff = session.balance - trueAmount
            local roundBalanceDiff = string.format("%.2f", balanceDiff)
            session.balance = (math.abs(tonumber(roundBalanceDiff)))
            --session.balance = session.balance - trueAmount
            session.transactions = session.transactions + 1
            requestWithData({data = msgToLog, mPath = "/buy.log", path = server .. "/buy"}, {method = "merge", toMerge = {balance = {[server] = session.balance}, transactions = session.transactions}, name = session.name})
        else
            log("Item not purchased", session.name)
        end
        
        scanMe()
        back()
    else
        alert({"Недостаточно средств"})
    end
end

local function returnMoney()
    local moneyQty = me.getItemDetail(moneyFingerprint).basic().qty

    local toReturn = math.floor(session.balance)

    if toReturn >= 1 and moneyQty >= toReturn then
        local totalGived = 0

        while totalGived < toReturn do
            local gived = me.exportItem(moneyFingerprint, "UP", toReturn-totalGived, 0).size
            totalGived = totalGived + gived
        end

        local balanceDiff = session.balance - totalGived
        local roundBalanceDiff = string.format("%.2f", balanceDiff)
        session.balance = (math.abs(tonumber(roundBalanceDiff)))
        --session.balance = session.balance - totalGived
        --session.balance = math.floor(session.balance * 100 + 0.05) / 100
        local msgToLog = session.name .. " took " .. totalGived .. " emeralds"

        alert({"Эмы были сняты со счёта"})
        requestWithData({data = msgToLog, mPath = "/returnedMoney.log", path = server .. "/returnedMoney"}, {method = "merge", toMerge = {balance = {[server] = session.balance}, transactions = session.transactions}, name = session.name})
    else
        alert({"Недостаточно средств на счету"})
    end
end

local function topUpBalance()
    local size = 36
    local slot = pim.getAllStacks(0)
    local totalTakenMoney = 0
    for i = 1, size do
        if slot[i] then
            if slot[i].id == moneyFingerprint.id and slot[i].dmg == moneyFingerprint.dmg then
                local takenMoney = pim.pushItem("DOWN", i, slot[i].qty)
                totalTakenMoney = totalTakenMoney + math.floor(takenMoney)
            end
        end
    end
    if totalTakenMoney > 0 then
        totalTakenMoney = math.floor(totalTakenMoney)
        session.balance = session.balance + totalTakenMoney

        alert({"Ваш счёт был пополнен"})
        local msgToLog = session.name .. " topped up balance with " .. totalTakenMoney .. " emeralds"
        requestWithData({data = msgToLog, mPath = "/topUpBalance.log", path = server .. "/topUpBalance"}, {method = "merge", toMerge = {balance = {[server] = session.balance}, transactions = session.transactions}, name = session.name})
    else
        alert({"Деньги не были найдены в инвентаре", "Вы можете купить деньги", "в сундуке рядом с магазином"})
    end    
end

local function amount(key, force)
    if key and key == "C" then
        writes.amount.input = ""
        writes.amount.len = 0
        fill(10, 7, 10, 1, " ", color.background)
        set(12, 5, "0               ", color.background, 0xffffff)
    end
    local count = tonumber(writes.amount.input)

    if writes.amount.input ~= "" then
        guiVariables[guiPath[#guiPath]].amount = count * guiVariables[guiPath[#guiPath]].item.buyPrice
        set(12, 5, tostring(guiVariables[guiPath[#guiPath]].amount) .. "       ", color.background, guiVariables[guiPath[#guiPath]].amount <= session.balance and 0xffffff or color.red)
        if force then
            set(10, 7, writes.amount.input, color.background, 0xffffff)
        end
    elseif writes.amount.input == "" or force then
        set(12, 5, "0               ", color.background, 0xffffff)
        set(10, 7, "0", color.background, 0xffffff)
    end

    if writes.amount.input ~= "" and guiVariables[guiPath[#guiPath]].amount <= session.balance and guiVariables[guiPath[#guiPath]].item.count >= count then
        if buttons.purchase.disabled then
            buttons.purchase.disabled = false
            drawButton("purchase")
        end
    else
        if not buttons.purchase.disabled then
            buttons.purchase.disabled = true
            drawButton("purchase")
        end
    end
end

local function checkCount(number)
    if guiVariables[guiPath[#guiPath]].item.count >= tonumber(writes.amount.input .. number) then
        writes.amount.onlyClear = false
    else
        writes.amount.onlyClear = true
    end
end

local function buyItem()
    balance(1)
    setColorText(2, 3, "[0x68f029]Имя предмета: [0xffffff]" .. guiVariables[guiPath[#guiPath]].item.text , color.background)
    setColorText(44, 3, "[0x68f029]Доступно: [0xffffff]" .. math.floor(guiVariables[guiPath[#guiPath]].item.count), color.background)
    setColorText(48, 5, "[0x68f029]Цена: [0xffffff]" .. guiVariables[guiPath[#guiPath]].item.buyPrice, color.background)
    set(2, 5, "На сумму:", color.background, color.lime)
    set(2, 7, "Кол-во:", color.background, color.lime)
    amount(false, true)
end

local function buy()
    buttons.nextBuy.disabled = true
    drawButton("nextBuy")
    balance(1)
    set(3, 3, "Магазин продаёт                 Кол-во         Цена", color.background, color.orange)
end

local function sellItem()
    balance(1)
    setColorText(2, 3, "[0x68f029]Имя предмета: [0xffffff]" .. guiVariables[guiPath[#guiPath]].item.text, color.background, color.lime, color.background)
    setColorText(48, 3, "[0x68f029]Цена: [0xffffff]" .. guiVariables[guiPath[#guiPath]].item.sellPrice, color.background, color.lime, color.background)
    setColorText(2, 5, "[0x68f029]Можно продать: [0xffffff]" .. guiVariables[guiPath[#guiPath]].item.leftCount, color.background)
    set(15, 7, "Сканировать на наличие предмета:", color.background, color.orange)
end

local function sell()
    buttons.nextSell.disabled = true
    drawButton("nextSell")
    set(3, 3, "Магазин покупает                Кол-во         Цена", color.background, color.orange)
    balance(1)
end

local function drawOreList()
    if guiPath[#guiPath] == "ore" then
        scanMe()
        local counter = 1
        fill(13, 9, 35, 8, " ", color.background)

        for item = 1, #items.ore do 
            local ingots = getAllItemCount(items.ore[item].fingerprint)

            if ingots > 0 then
                setColorText(nil, counter + 9, "[0x4260f5]" .. items.ore[item].text .. "([0xffffff]x" .. items.ore[item].ratio .. "[0x4260f5]): [0xffffff]" .. math.floor(ingots / items.ore[item].ratio) .. " шт", color.background)
                counter = counter + 1
            end
        end
    end
end

local function ore()
    set(18, 2, "Сканировать на наличие руды:", color.background, color.orange)
    set(20, 8, "Доступно для обработки: ", color.background, color.lime)
    drawOreList()
end

local function nextFood()
    if session.foodTime and time(true) < session.foodTime then
        buttons.getFood.disabled = true
        set(15, 5, "Вы сможете получить еду через:", color.background, color.lime) 
        set(nil, 6, os.date("%H Часов %M Минут %S Секунд", session.foodTime - time(true)), color.background, 0xffffff)
        drawButton("getFood")
    else
        buttons.getFood.disabled = false
        drawButton("getFood")
    end
end

local function getFood()
    if autoInsert(items.food, freeFoodCount) > 0 then
        log("I give out free food", session.name)
        session.foodTime = time(true) + 7200
        haveFood = true
        requestWithData(nil, {method = "merge", toMerge = {foodTime = session.foodTime}, name = session.name})
        fill(18, 7, 26, 1, " ", color.background)
        set(21, 7, "Приятного аппетита!", color.background, 0xffffff)
        nextFood()
        drawButton("getFood")
    else
        set(18, 7, "Еда кончилась, извините :(", color.background, color.lime)
    end
end

local function field(play)
    for i = 1, 30 do
        fill(15 + i, 6, 1, 5, " ", play and color.background or i % 2 == 0 and color.blackGray or color.gray) 
        if play then
            sleep(0)
        end
    end
end

local function lottery()
    balance(1)
    setColorText(nil, 3, "[0x68f029]Мгновенная беспроигрышная лотерея. Цена билета — [0xffffff]" .. priceLottery .. " [0x68f029]эмов", color.background)
    setColorText(19, 4, "[0x68f029]Супер-приз — [0xffffff]" .. superPrize .. " [0x68f029]эмов!", color.background)
    field()
end

local function playLottery()
    if session.balance >= priceLottery then
        session.balance = session.balance - priceLottery
        balance(1)
        field(true)

        local rip = math.random(50, 350)

        if math.random(3000) == 3000 then
            rip = superPrize
        else
            if rip >= 200 then
                rip = rip - (math.random(rip) + (rip >= 250 and 70 or 40))

                if rip <= 0 then
                    rip = math.random(30, 65)
                end
            end
        end
        rip = math.floor(rip)
        setColorText(nil, 8, "[0x68f029]Вы выиграли: [0xffffff]" .. rip .. " [0x68f029]эмов", color.background)
        local msgToLog = session.name .. " won the lottery " .. rip .. " rip"
        log(msgToLog, session.name)
        session.balance = session.balance + rip
        local response = requestWithData({data = msgToLog, mPath = "/lottery.log", path = server .. "/lottery"}, {method = "merge", toMerge = {balance = {[server] = session.balance}}, name = session.name})
        if not response or response.code ~= 200 then
            log("Error on updating balance " .. (response and response.message and tostring(response.message) or "no server response"), session.name)
            alert({"Внимание! Баланс не пополен,", "обратитесь к администрации!"})
        end
        sleep(.5)
        balance(1)
        fill(1, 10, 60, 1, " ", color.background)
        field()
    else
        alert({"Недостаточно средств"})
    end
end

local function account()
    setColorText(nil, 7, "[0x68f029]" .. session.name .. ":", color.background)
    balance(9)
    setColorText(nil, 10, "[0x68f029]Совершенно транзакций: [0xffffff]" .. session.transactions, color.background)
    setColorText(15, 11, "[0x68f029]Регистрация: [0xffffff]" .. session.regTime, color.background)
end

local function drawPage()
    fill(24, 16, 9, 1, " ", color.background)
    set(nil, 16, tostring(guiPage), color.background, color.blue)
end

local function drawInfo(page)
    guiPage = page
    drawPage() 

    if page == #infoList then
        buttons.nextInfo.disabled = true
        if not session.eula then
            buttons.eula.disabled = false
            drawButton("eula")
        end
        drawButton("nextInfo")
    else
        buttons.nextInfo.disabled = false
        drawButton("nextInfo")
    end
    if page ~= 1 then
        buttons.prevInfo.disabled = false
        drawButton("prevInfo")
    else
        buttons.prevInfo.disabled = true
        drawButton("prevInfo")
    end

    fill(1, 2, 60, 13, " ", color.background)
    gpu.setForeground(0xffffff)
    local x, y = 1, 2

    for word = 1, #infoList[page] do 
        if type(infoList[page][word]) == "table" then
            gpu.setForeground(infoList[page][word][1])
        else
            if infoList[page][word] == "\n" then
                x, y = 1, y + 1
            else
                gpu.set(x, y, infoList[page][word])
                x = x + unicode.len(infoList[page][word])
            end
        end
    end
end

local function info()
    set(20, 1, "Информация об магазине", color.background, color.orange)
    drawInfo(1)
end

local function drawFeedback(page)
    guiPage = page
    drawPage()

    if page == #session.feedbacks then
        buttons.nextFeedback.disabled = true
        drawButton("nextFeedback")
    else
        buttons.nextFeedback.disabled = false
        drawButton("nextFeedback")
    end
    if page ~= 1 then
        buttons.prevFeedback.disabled = false
        drawButton("prevFeedback")
    else
        buttons.prevFeedback.disabled = true
        drawButton("prevFeedback")
    end 

    local len = unicode.len(session.feedbacks[page].feedback)
    fill(1, 6, 60, 3, " ", color.background)
    set(nil, 7, session.feedbacks[page].name .. ":", color.background, color.lime)

    if len > 60 then
        for i = 1, math.ceil(len / 60) do
            set(nil, i + 7, unicode.sub(session.feedbacks[page].feedback, i * 60 - 59, i * 60), color.background, color.orange)
        end
    else
        set(nil, 8, session.feedbacks[page].feedback, color.background, color.orange)
    end
end

local function feedbacks()
    set(27, 1, "Отзывы", color.background, color.orange)
    drawPage()
    if #session.feedbacks == 0 then
        set(8, 8, "Отзывов нет. Будьте первым, кто его оставит=)", color.background, color.lime)
    else
        drawFeedback(1)
    end
end

local function acceptFeedback()
    if writes.feedback.input ~= "" then
        local msgToLog = session.name .. " left a feedback: " .. writes.feedback.input
        log(msgToLog, session.name)
        table.insert(session.feedbacks, {name = session.name, feedback = writes.feedback.input})
        table.sort(session.feedbacks, sort)
        session.feedback = true
        local response = requestWithData({data = msgToLog, mPath = "/feedbacks.log", path = server.. "/feedbacks"}, {method = "feedback", feedback = writes.feedback.input, name = session.name})
        if response and response.code == 200 then
            buttons.acceptFeedback.notVisible = true
            writes.feedback.notVisible = true
            focus.write = false
            fill(1, 2, 60, 15, " ", color.background)
            drawFeedback(1)
            drawButtons()
        else
            log("Error leaving feedback " .. (response and response.message and tostring(response.message) or "no server response"), session.name)
            alert({"Внимание! Отзыв не оставлен,", "обратитесь к администрации!"})
        end
        buttons.acceptFeedback.notVisible = true
        writes.feedback.notVisible = true
        focus.write = false
        fill(1, 2, 60, 15, " ", color.background)
        drawFeedback(1)
        drawButtons()
    end
end

local function blackList(name)
    unAuth = true
    clear()
    setColorText(nil, 7, "[0x68f029](Не)уважаемый [0xffffff]" .. name, color.background)
    set(10, 8, "Вы внесены в чёрный список этого магазина", color.background, color.lime)
    set(28, 13, "Удачи!", color.background, color.red)
    discord()
end

local function inDev(name)
    unAuth = true
    clear()
    setColorText(nil, 8, "[0x68f029]Уважаемый [0xffffff]" .. name, color.background)
    setColorText(11, 9, "[0x68f029]Этот терминал только для разработчиков!", color.background)
    discord()
end

local function insertKey()
    key = ""
    set(15, 9, "Вставьте ключ через буфер обмена", color.background, color.lime)

    while true do 
        local signal = {pull(math.huge, "clipboard")}

        if signal and admins[signal[4]] then
            key = signal[3]
            fill(1, 9, 60, 1, " ", color.background)
            set(12, 9, "Проверка ключа на действительность...")
            local response = requestWithData({data = "Тестирование ключа " .. key}, {method = "test"}, key)

            if response and response.code == 200 then
                login()
                break
            else
                fill(1, 9, 60, 1, " ", color.background)
                if not response then
                    set(19, 9, "Нет соединения с сервером", color.background, color.lime)
                else
                    set(nil, 9, tostring(response.message), color.background, color.lime)
                end
                sleep(2)
                set(15, 9, "Вставьте ключ через буфер обмена", color.background, color.lime)
            end
        end
    end
end

function alert(text, func)
    local screen = {}
    for y = 1, 7 do
        screen[y] = {}

        for x = 10, 52 do
            screen[y][x] = {gpu.get(x, y)}
        end
    end
    fill(10, 1, 42, 7, " ", color.gray)
    set(17, 1, "Подтвердите для продолжения", color.gray, 0xffffff)
    --set(10, 7, screen[7][10][1], screen[7][10][3], screen[7][10][2])
    --set(11, 7, screen[7][11][1], screen[7][11][3], screen[7][11][2])
    --set(50, 7, screen[7][50][1], screen[7][50][3], screen[7][50][2])
    --set(51, 7, screen[7][51][1], screen[7][51][3], screen[7][51][2])
    set(42, 6, "  OK  ", color.blue, 0xffffff)

    for str = 1, #text do
        set(nil, str + 2, text[str], color.gray, 0xffffff)
    end

    while true do 
        local signal = {computer.pullSignal(math.huge)}

        if signal then
            if signal[1] == "touch" then
                if signal[3] >= 42 and signal[3] <= 47 and signal[4] == 6 then
                    set(42, 6, "  OK  ", color.blackBlue, color.gray)
                    sleep(0.01)
                    if func then
                        func()
                    end
                    break
                end
            elseif signal[1] == "player_off" or signal[1] == "player_on" then
                break
            end
        end
    end

    for y = 1, 7 do 
        for x = 10, 52 do
            set(x, y, screen[y][x][1], screen[y][x][3], screen[y][x][2])
        end
    end
end

local function clearVariables(all, gui)
    for write in pairs(writes) do
        if writes[write].writeIn == gui or all then
            writes[write].input = ""
            writes[write].len, writes[write].pos = 0, 0
        end
    end
    for list in pairs(lists) do
        if lists[list].listIn == gui or all then
            lists[list].content = {}
            lists[list].scrollContent = {}
        end
    end
end

function toGui(gui, variables)
    guiPath[#guiPath + 1] = gui
    guiVariables[guiPath[#guiPath]] = variables or {}
    clear()
    drawGui()
    if guiFunctions[gui] then 
        guiFunctions[gui]()
    end
end

function back(to)
    if guiPath[#guiPath] == "buyItem" or guiPath[#guiPath] == "sellItem" or guiPath[#guiPath] == "buy" or guiPath[#guiPath] == "sell" then
        selector.setSlot(1)
    end
    clearVariables(false, guiPath[#guiPath])
    if to then 
        if to <= #guiPath then
            for i = 1, to do 
                guiVariables[guiPath[#guiPath]] = nil
                table.remove(guiPath, #guiPath)
            end
        end
    else
        guiVariables[guiPath[#guiPath]] = nil
        table.remove(guiPath, #guiPath)
    end

    focus = {button = false, list = false, write = false}
    clear()
    drawGui()
    if guiFunctions[guiPath[#guiPath]] then
        guiFunctions[guiPath[#guiPath]]()
    end
end

function login(name)
    if name then
        if not unAuth then
            if dev and admins[name] or not dev then
                local response = requestWithData(nil, {method = "login", name = name})

                if response then
                    if response.code == 200 then
                        log("Auth " .. name)

                        if response.userdata.banned then
                            blackList(name)
                            unAuth = true
                        else
                            computer.addUser(name)
                            session = {feedbacks = {}, name = name}
                            session.balance = response.userdata.balance[server]
                            session.foodTime = response.userdata.foodTime
                            session.transactions = response.userdata.transactions
                            session.lastLogin = response.userdata.lastLogin
                            session.regTime = response.userdata.regTime
                            session.eula = response.userdata.eula
                            session.banned = response.userdata.banned
                            session.feedback = false

                            if response.feedbacks then
                                session.feedbacks = {}
                                response.feedbacks.n = nil
                                for name, feedback in pairs(response.feedbacks) do
                                    session.feedbacks[#session.feedbacks + 1] = {name = name, feedback = feedback}
                                end
                                if response.feedbacks[name] then
                                    session.feedback = true
                                end
                                table.sort(session.feedbacks, sort)
                            end

                            if session.feedback then
                                buttons.acceptFeedback.notVisible = true
                                writes.feedback.notVisible = true
                            else
                                buttons.acceptFeedback.notVisible = false
                                writes.feedback.notVisible = false
                            end

                            scanMe()
                            if session.eula then
                                buttons.eula.notVisible = true
                                buttons.back.notVisible = false
                                toGui("main")
                            else
                                buttons.eula.disabled = true
                                buttons.eula.notVisible = false
                                buttons.back.notVisible = true
                                toGui("info")
                            end
                        end
                    else
                        outOfService(response.message)
                    end
                else
                    log("Auth " .. name .. " cannot be processed, server is not responding! Going offline...")
                    session = {name = name, eula = true}
                    computer.addUser(name)
                    autonomous = true
                    buttons.account.disabled = true
                    buttons.feedbacks.disabled = true
                    buttons.shop.disabled = true
                    buttons.freeFood.disabled = true
                    buttons.returnMoney.disabled = true
                    --buttons.lottery.disabled = true
                    scanMe()
                    toGui("main")
                end
            else
                inDev(name)
            end
        end
    else
        if session.name then
            log("De-auth " .. session.name)
        end
        if not admins[session.name] and session.name then
            computer.removeUser(session.name)
        end
        itemScan = false
        session.name = false
        unAuth = false
        if autonomous then
            autonomous = false
            buttons.account.disabled = false
            buttons.feedbacks.disabled = false
            buttons.shop.disabled = false
            buttons.freeFood.disabled = false
            buttons.returnMoney.disabled = false
            --buttons.lottery.disabled = false
        end
        selector.setSlot(1)
        back(#guiPath)
        clearVariables(true)

        if active then
            clear()
            setColorText(18, 2, "[0xffffff]Приветствуем на варпе [0x68f029]wim[0xffffff]!", color.background)
            setColorText(17, 5, "[0xffffff]Встаньте на [0x46c8e3]PIM[0xffffff], чтобы войти", color.background)
            discord()
            drawPim()
        end
    end
end

local function initButtons()
    for button in pairs(buttons) do 
        if buttons[button].buttonIn then
            for i = 1, #buttons[button].buttonIn do 
                buttons[button].buttonIn[buttons[button].buttonIn[i]], buttons[button].buttonIn[i] = true, nil
            end
        end

        buttons[button].x = buttons[button].x or math.floor(31 - unicode.len(buttons[button].text) / 2)
        buttons[button].width = buttons[button].width or unicode.len(buttons[button].text)
        buttons[button].textPosX = buttons[button].textPosX or math.floor(buttons[button].width / 2 - unicode.len(buttons[button].text) / 2) + buttons[button].x
        buttons[button].endX = buttons[button].x + buttons[button].width - 1
        buttons[button].endY = buttons[button].y + buttons[button].height - 1

        if not buttons[button].textPosY then
            if buttons[button].height == 1 then
                buttons[button].textPosY = buttons[button].y
            elseif buttons[button].height % 2 == 0 then
                buttons[button].textPosY = buttons[button].height / 2 - 1 + buttons[button].y
            else 
                buttons[button].textPosY = math.ceil(buttons[button].height / 2) - 1 + buttons[button].y
            end
        end
    end
end

local function initLists()
    for list in pairs(lists) do 
        if lists[list].bar then
            lists[list].scrollX = lists[list].x + lists[list].width
        end

        lists[list].scrollContent = {}
        lists[list].pos = 1
        lists[list].endX = lists[list].x + lists[list].width - 1
        lists[list].endY = lists[list].y + lists[list].height - 1
        lists[list].bar.x = lists[list].endX + 1
    end
end

local function initWrites()
    for write in pairs(writes) do
        writes[write].input = ""
        writes[write].textPosX = math.floor(writes[write].width / 2 - unicode.len(writes[write].text) / 2) + writes[write].x
        writes[write].endX = writes[write].x + writes[write].width - 1
        writes[write].len = 0
        writes[write].pos = 0
        if writes[write].cursor then
            writes[write].cursorTime = 0
            writes[write].cursorState = false
        end
    end
end




buttons = {
    --Кнопки, которые отвечаю за перемещение по менюшкам : были удалены "other", "lottery"
    back = {buttonIn = {"shop", "buyItem", "sellItem", "ore", "freeFood", "account", "info", "feedbacks", "shop"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "   Назад   ", x = 25, y = 18, width = 11, height = 1, action = function() back() end},
    backShop = {buttonIn = {"buy", "sell"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "   Назад   ", x = 31, y = 18, width = 11, height = 1, action = function() back() end},
    eula = {buttonIn = {"info"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Я прочитал и соглашаюсь со всем  ", x = 13, y = 18, width = 35, height = 1, action = function() session.eula = true buttons.eula.notVisible = true buttons.back.notVisible = false requestWithData(nil, {method = "merge", toMerge = {eula = true}, name = session.name}) toGui("main") end},
    shop = {buttonIn = {"main"}, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Магазин", x = 19, y = 5, width = 24, height = 3, action = function() toGui("shop") end},
    --other = {buttonIn = {"main"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Полезности", x = 19, y = 9, width = 24, height = 3, action = function() toGui("other") end},
    ore = {buttonIn = {"other"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Обработка руды", x = 19, y = 4, width = 24, height = 3, action = function() toGui("ore") end},
    account = {buttonIn = {"main"}, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Аккаунт", x = 19, y = 9, width = 24, height = 3, action = function() toGui("account") end},
    feedbacks = {buttonIn = {"main"}, disabledBackground = color.background, disabledForeground = color.blackLime, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Отзывы]", x = 53, y = 19, width = 8, height = 1, action = function() toGui("feedbacks") end},
    info = {buttonIn = {"main"}, disabledBackground = color.background, disabledForeground = color.blackLime, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Помощь]", x = 1, y = 19, width = 8, height = 1, action = function() toGui("info") end},
    buy = {buttonIn = {"shop"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Покупка", x = 19, y = 5,  width = 24, height = 3, action = function() toGui("buy") end},
    sell = {buttonIn = {"shop"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Пополнить баланс", x = 19, y = 9, width = 24, height = 3, action = function() topUpBalance() end},
    nextBuy = {buttonIn = {"buy"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Далее  ", x = 50, y = 18, width = 9, height = 1, action = function() buttons.purchase.disabled = true item = items.shop[lists[focus.list].scrollContent[lists[focus.list].scrollContent.activeIndex].index] toGui("buyItem", {item = item}) guiVariables[guiPath[#guiPath]].amount = 0 end},
    nextSell = {buttonIn = {"sell"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Далее  ", x = 50, y = 18, width = 9, height = 1, action = function() item = items.shop[lists[focus.list].scrollContent[lists[focus.list].scrollContent.activeIndex].index] toGui("sellItem", {item = item}) end},
    freeFood = {buttonIn = {"other"}, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Бесплатная еда", x = 19, y = 8, width = 24, height = 3, action = function() toGui("freeFood") nextFood() end},
    --lottery = {buttonIn = {"other"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Лотерея", x = 19, y = 12, width = 24, height = 3, action = function() toGui("lottery") end},
    returnMoney = {buttonIn = {"shop"}, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Вернуть деньги", x = 19, y = 13, width = 24, height = 3, action = function() returnMoney() end},
    alert = {buttonIn = {"alert"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "Назад", x = 26, y = 15, width = 9, height = 1, action = function() back() end},

    zero = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "0", x = 29, y = 15, width = 3, height = 1, action = function() inputWrite("amount", 48) end},
    one = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "1", x = 24, y = 9, width = 3, height = 1, action = function() inputWrite("amount", 49) end},
    two = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "2", x = 29, y = 9, width = 3, height = 1, action = function() inputWrite("amount", 50) end},
    three = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "3", x = 34, y = 9, width = 3, height = 1, action = function() inputWrite("amount", 51) end},
    four = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "4", x = 24, y = 11, width = 3, height = 1, action = function() inputWrite("amount", 52) end},
    five = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "5", x = 29, y = 11, width = 3, height = 1, action = function() inputWrite("amount", 53) end},
    six = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "6", x = 34, y = 11, width = 3, height = 1, action = function() inputWrite("amount", 54) end},
    seven = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "7", x = 24, y = 13, width = 3, height = 1, action = function() inputWrite("amount", 55) end},
    eight = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "8", x = 29, y = 13, width = 3, height = 1, action = function() inputWrite("amount", 56) end},
    nine = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "9", x = 34, y = 13, width = 3, height = 1, action = function() inputWrite("amount", 57) end},
    backspace = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "<", x = 24, y = 15, width = 3, height = 1, action = function() inputWrite("amount", 8) end},
    clear = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "C", x = 34, y = 15, width = 3, height = 1, action = function() amount("C") end},
    
    purchase = {buttonIn = {"buyItem"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Купить  ", x = 46, y = 18, width = 10, height = 1, action = function() purchase() end},
    getFood = {buttonIn = {"freeFood"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Получить еду", x = 19, y = 9, width = 24, height = 3, action = function() getFood() end},
    --playLottery = {buttonIn = {"lottery"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Купить билет", x = 19, y = 13, width = 24, height = 3, action = function() playLottery() end},
    
    sellScanOne = {buttonIn = {"sellItem"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "      1 слот      ", x = 22, y = 9, width = 18, height = 1, action = function(active) if active then itemScan = "one" else itemScan = false end end},
    sellScanMulti = {buttonIn = {"sellItem"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "  Весь инвентарь  ", x = 22, y = 11, width = 18, height = 1, action = function(active) if active then itemScan = "multi" else itemScan = false end end},
    oreScanOne = {buttonIn = {"ore"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "      1 слот      ", x = 22, y = 4, width = 18, height = 1, action = function(active) if active then itemScan = "one" else itemScan = false end end},
    oreScanMulti = {buttonIn = {"ore"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "  Весь инвентарь  ", x = 22, y = 6, width = 18, height = 1, action = function(active) if active then itemScan = "multi" else itemScan = false end end},

    prevInfo = {buttonIn = {"info"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "<───", x = 21, y = 16, width = 4, height = 1, action = function() drawInfo(guiPage - 1) end},
    nextInfo = {buttonIn = {"info"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "───>", x = 36, y = 16, width = 4, height = 1, action = function() drawInfo(guiPage + 1) end},
    
    acceptFeedback = {buttonIn = {"feedbacks"}, notVisible = true, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Подтвердить]", x = 24, y = 14, width = 13, height = 1, action = function() acceptFeedback() end},
    prevFeedback = {buttonIn = {"feedbacks"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "<───", x = 21, y = 16, width = 4, height = 1, action = function() drawFeedback(guiPage - 1) end},
    nextFeedback = {buttonIn = {"feedbacks"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "───>", x = 36, y = 16, width = 4, height = 1, action = function() drawFeedback(guiPage + 1) end}
}

lists = {
    buy = {listIn = "buy", background = color.blackGray, contentBackground = color.blackGray, activeContentBackground = color.gray, contentForeground = color.lime, activeContentForeground = color.lime, x = 3, y = 4, width = 55, height = 13, focus = true, clickable = true, attachedWrite = "findBuy", bar = {symbol = "█", background = color.gray, foreground = color.blackBlue, activeBackground = color.gray, activeForeground = color.blue}, content = {}, actionOnClick = function() buttons.nextBuy.disabled = false drawButton("nextBuy") selector.setSlot(1, items.shop[lists[focus.list].scrollContent[lists[focus.list].scrollContent.activeIndex].index].fingerprint[1]) end, actionOnDrop = function() buttons.nextBuy.disabled = true drawButton("nextBuy") selector.setSlot(1) end, actionOnEnter = function() if not buttons.nextBuy.disabled then buttons.nextBuy.action() end end},
    sell = {listIn = "sell", background = color.blackGray, contentBackground = color.blackGray, activeContentBackground = color.gray, contentForeground = color.lime, activeContentForeground = color.lime, x = 3, y = 4, width = 55, height = 13, focus = true, clickable = true, attachedWrite = "findSell", bar = {symbol = "█", background = color.gray, foreground = color.blackBlue, activeBackground = color.gray, activeForeground = color.blue}, content = {}, actionOnClick = function() buttons.nextSell.disabled = false drawButton("nextSell") selector.setSlot(1, items.shop[lists[focus.list].scrollContent[lists[focus.list].scrollContent.activeIndex].index].fingerprint[1]) end, actionOnDrop = function() buttons.nextSell.disabled = true drawButton("nextSell") selector.setSlot(1) end, actionOnEnter = function() if not buttons.nextSell.disabled then buttons.nextSell.action() end end}
}

guiFunctions = {
    main = function() if autonomous then set(22, 19, "[Автономный режим]", color.background, color.red) end end,
    account = account,
    buy = buy,
    buyItem = buyItem,
    sell = sell,
    sellItem = sellItem,
    ore = ore,
    --lottery = lottery,
    feedbacks = feedbacks,
    info = info
}

writes = {
    findBuy = {writeIn = "buy", background = color.gray, activeBackground = color.gray, foreground = color.lightGray, activeForeground = 0xffffff, cursorForeground = 0xffffff, activeCursorForeground = color.lightGray, text = "Поиск...", x = 3, y = 18, width = 20, border = 128, focus = true, cursor = true, actionOnWrite = function() setScrollContent("buy") buttons.nextBuy.disabled = true drawButton("nextBuy") end},
    findSell = {writeIn = "sell", background = color.gray, activeBackground = color.gray, foreground = color.lightGray, activeForeground = 0xffffff, cursorForeground = 0xffffff, activeCursorForeground = color.lightGray, text = "Поиск...", x = 3, y = 18, width = 20, border = 128, focus = true, cursor = true, actionOnWrite = function() setScrollContent("sell") buttons.nextSell.disabled = true drawButton("nextSell") end},
    feedback = {writeIn = "feedbacks", background = color.gray, activeBackground = color.gray, foreground = color.lightGray, activeForeground = 0xffffff, cursorForeground = 0xffffff, activeCursorForeground = color.lightGray, text = "Оставьте свой отзыв", x = 2, y = 12, width = 58, border = 180, focus = true, cursor = true, actionOnEnter = function() acceptFeedback() end},
    amount = {writeIn = "buyItem", background = color.background, foreground = color.background, activeBackground = color.background, activeForeground = 0xffffff, text = "", x = 10, y = 7, width = 20, border = 16, number = true, strictNumber = true, actionBefore = function(char) if char >= 32 then checkCount(unicode.char(char)) end end, actionOnWrite = function() amount() end, actionOnEnter = function() if not buttons.purchase.disabled then purchase() end end}
}

parseInfo()
downloadItems()
initButtons()
initLists()
initWrites()
if version == "internet" then
    insertKey()
elseif version == "modem" then
    modem = proxy("modem")
    if modem.open(port) or modem.isOpen(port) then
        login()
    else
        error("Невозможно открыть порт " .. port)
    end
end

while true do
    local signal = {computer.pullSignal(0)}

    if active then
        if signal[1] == "key_down" then
            if focus.write and not (writes[focus.write].input == "" and signal[3] == 8) then
                inputWrite(focus.write, signal[3], signal[5])
            elseif signal[4] == 200 or signal[4] == 208 or signal[3] == 13 then
                for list in pairs(lists) do 
                    if lists[list].listIn == guiPath[#guiPath] then
                        if signal[3] == 13 then
                            if lists[list].actionOnEnter then
                                lists[list].actionOnEnter()
                            end
                        elseif signal[4] == 208 and lists[list].scrollContent[lists[list].pos + lists[list].height] then
                            scroll(list, 1)
                        elseif signal[4] == 200 and lists[list].scrollContent[lists[list].pos - 1] then
                            scroll(list, -1) 
                        end
                    end
                end
            end
        elseif signal[1] == "touch" then
            local handled = false

            for button in pairs(buttons) do
                if not buttons[button].notVisible and (signal[3] >= buttons[button].x and signal[3] <= buttons[button].endX and signal[4] >= buttons[button].y and signal[4] <= buttons[button].endY and buttons[button].buttonIn[guiPath[#guiPath]] and not buttons[button].disabled and (buttons[button].admin and admins[signal[6]] or not buttons[button].admin)) then
                    if buttons[button].switch then
                        if buttons[button].focus then
                            focus.button = button
                        end

                        buttons[button].active = not buttons[button].active

                        if not buttons[button].withoutDraw then
                            drawButton(button, buttons[button].active)
                        end
                    elseif not buttons[button].withoutDraw then
                        clickDrawButton(button)
                    end

                    buttons[button].action(buttons[button].active)
                    handled = true
                    break
                end

                if not handled and focus.button then
                    if buttons[focus.button] then
                        buttons[focus.button].active = false

                        buttons[focus.button].action(false)
                        if not buttons[focus.button].withoutDraw then
                            drawButton(focus.button, false)
                        end
                    end

                    focus.button = false
                end
            end

            if not handled then
                for list in pairs(lists) do
                    if lists[list].listIn == guiPath[#guiPath] and lists[list].clickable then
                        if lists[list].scrollContent.activeIndex and lists[list].scrollContent.activeIndex >= lists[list].pos and not (signal[3] == lists[list].bar.x and signal[4] >= lists[list].y and signal[4] <= lists[list].endY) then
                            local index = lists[list].scrollContent.activeIndex - lists[list].pos

                            if lists[list].pos + index < lists[list].pos + lists[list].height then
                                drawContent(list, lists[list].scrollContent.activeIndex, false, index + lists[list].y)
                            end
                            if lists[list].actionOnDrop then
                                lists[list].actionOnDrop()
                            end

                            lists[list].scrollContent.activeIndex = false
                            focus.list = false
                            handled = true
                        end

                        if #lists[list].content > 0 and signal[3] >= lists[list].x and signal[3] <= lists[list].endX and signal[4] >= lists[list].y and signal[4] <= lists[list].endY then
                            focus.list = list
                            local index = lists[list].pos + (signal[4] - lists[list].y)

                            if lists[focus.list].scrollContent[index] then
                                drawContent(list, index, true, signal[4])
                                if lists[list].focus then
                                    lists[list].scrollContent.activeIndex = index
                                else
                                    sleep(.05)
                                    drawContent(list, index, false, signal[4])
                                end
                                if lists[list].actionOnClick then 
                                    lists[list].actionOnClick()
                                elseif lists[list].scrollContent[index].action then 
                                    lists[list].scrollContent[index].action()
                                end
                            end

                            handled = true
                            break
                        elseif lists[list].bar and (lists[list].bar.active and signal[3] == lists[list].bar.x and signal[4] >= lists[list].y and signal[4] <= lists[list].endY) then
                            focus.list = list
                            local startBar = lists[list].bar.pos + lists[list].y - 1
                            local endBar = startBar + lists[list].bar.length - 1

                            if signal[4] >= startBar and signal[4] <= endBar then
                                lists[list].bar.mousePos = signal[4]
                            else
                                barMove(list, signal[4])
                            end
                            break
                        end
                    end
                end
            end

            if focus.write and writes[focus.write].focus then
                if writes[focus.write].input ~= "" then 
                    drawText(focus.write, false)
                    writes[focus.write].cursorState = false
                    writes[focus.write].cursorTime = 0
                    cursor(focus.write, false, true)
                else
                    fill(writes[focus.write].x, writes[focus.write].y, writes[focus.write].width, 1, " ", writes[focus.write].background)
                    set(writes[focus.write].textPosX, writes[focus.write].y, writes[focus.write].text, writes[focus.write].background, writes[focus.write].foreground)
                end
                focus.write = false
            end

            if not focus.write then
                for write in pairs(writes) do 
                    if writes[write].writeIn == guiPath[#guiPath] and signal[3] >= writes[write].x and signal[3] <= writes[write].endX and signal[4] == writes[write].y and writes[write].focus then
                        fill(writes[write].x, writes[write].y, writes[write].width, 1, " ", writes[write].background)
                        drawText(write, true)
                        focus.write = write
                        handled = true
                        break
                    end
                end
            end
        elseif signal[1] == "scroll" then
            local handled = false

            for list in pairs(lists) do 
                if lists[list].listIn == guiPath[#guiPath] and (signal[3] >= lists[list].x and signal[3] <= lists[list].bar.x and signal[4] >= lists[list].y and signal[4] <= lists[list].endY) then
                    focus.list = list
                    handled = true
                    break
                end
            end

            if not handled then
                focus.list = false
            end

            if focus.list then
                if signal[5] == -1 and lists[focus.list].scrollContent[lists[focus.list].pos + lists[focus.list].height] then
                    scroll(focus.list, 1)
                elseif signal[5] == 1 and lists[focus.list].scrollContent[lists[focus.list].pos - 1] then
                    scroll(focus.list, -1) 
                end
            end
        elseif signal[1] == "drag" then
            if focus.list and lists[focus.list].bar and lists[focus.list].bar.active and lists[focus.list].bar.mousePos and not lists[focus.list].bar.move and signal[4] ~= lists[focus.list].bar.mousePos then
                local down = signal[4] > lists[focus.list].bar.mousePos 
                local startBar = lists[focus.list].bar.pos + lists[focus.list].y - 1
                local endBar = startBar + lists[focus.list].bar.length - 1

                if signal[4] < startBar or signal[4] > endBar then
                    barMove(focus.list, signal[4])
                elseif down and lists[focus.list].scrollContent[lists[focus.list].pos + lists[focus.list].height] then
                    scroll(focus.list, 1)
                elseif not down and lists[focus.list].scrollContent[lists[focus.list].pos - 1] then
                    scroll(focus.list, -1)
                end
            end
        elseif signal[1] == "drop" then 
            if focus.list and lists[focus.list].bar and lists[focus.list].bar.active then
                lists[focus.list].bar.move = false
                lists[focus.list].bar.down = false
            end
        elseif signal[1] == "player_on" then
            login(signal[2])
        elseif signal[1] == "player_off" then
            login()
        elseif focus.list and lists[focus.list].bar and lists[focus.list].bar.active and lists[focus.list].bar.move then
            local endBar = lists[focus.list].bar.pos + lists[focus.list].bar.length - 1

            if lists[focus.list].bar.down and lists[focus.list].bar.move == endBar or not lists[focus.list].bar.down and lists[focus.list].bar.move == lists[focus.list].bar.pos then
                lists[focus.list].bar.down = false
                lists[focus.list].bar.mousePos = lists[focus.list].y + lists[focus.list].bar.move - 1
                lists[focus.list].bar.move = false

                if lists[focus.list].bar.pos == 1 then
                    lists[focus.list].pos = 1
                    drawList(focus.list)
                elseif endBar == lists[focus.list].height then
                    lists[focus.list].pos = #lists[focus.list].scrollContent - lists[focus.list].height + 1
                    drawList(focus.list)
                end
            elseif lists[focus.list].bar.down and lists[focus.list].content[lists[focus.list].pos + lists[focus.list].height] then
                scroll(focus.list, 1)
            elseif not lists[focus.list].bar.down and lists[focus.list].content[lists[focus.list].pos - 1] then
                scroll(focus.list, -1)
            end
        elseif itemScan then
            if guiPath[#guiPath] == "sellItem" then
                local slot, count 

                if itemScan == "multi" then
                    slot, count = scanSlots(guiVariables[guiPath[#guiPath]].item.raw_name)
                else
                    slot, count = 1, scanSlot(1, guiVariables[guiPath[#guiPath]].item.raw_name)
                end
                if count and count > guiVariables[guiPath[#guiPath]].item.leftCount then
                    count = guiVariables[guiPath[#guiPath]].item.leftCount
                end

                if count and pushItem(slot, count) then
                    local addMoney = count * guiVariables[guiPath[#guiPath]].item.sellPrice
                    local msgToLog = session.name .. " selling item(" .. math.floor(count) .. " qty in the amount of" .. addMoney .. " rip) " .. guiVariables[guiPath[#guiPath]].item.text
                    log(msgToLog, session.name)
                    session.balance = session.balance + addMoney
                    session.transactions = session.transactions + 1
                    local response = requestWithData({data = msgToLog, mPath = "/sell.log", path = server .. "/sell"}, {method = "merge", toMerge = {balance = {[server] = session.balance}, transactions = session.transactions}, name = session.name})
                    if response and response.code == 200 then
                        setColorText(nil, 14, "[0x68f029]Баланс успешно пополнен на [0xffffff]" .. math.floor(addMoney) .. " [0x68f029] эмов!", color.background)
                        balance(1)
                        scanMe()
                        fill(1, 14, 60, 1, " ", color.background)
                        if guiVariables[guiPath[#guiPath]].item.count >= guiVariables[guiPath[#guiPath]].item.maxCount then
                            back()
                        else
                            guiVariables[guiPath[#guiPath]].item.leftCount = guiVariables[guiPath[#guiPath]].item.maxCount - guiVariables[guiPath[#guiPath]].item.count
                            set(17, 5, guiVariables[guiPath[#guiPath]].item.leftCount .. "       ", color.background, 0xffffff)
                        end
                    else
                        log("Error on updating balance " .. (response and response.message and tostring(response.message) or "no server response"), session.name)
                        alert({"Внимание! Баланс не пополен,", "обратитесь к администрации!"})
                    end
                end
            elseif guiPath[#guiPath] == "ore" then
                for item = 1, #items.ore do
                    local slot, count 

                    if itemScan == "multi" then
                        slot, count = scanSlots(items.ore[item].raw_name)
                    else
                        slot, count = 1, scanSlot(1, items.ore[item].raw_name)
                    end

                    if count then
                        scanMe()
                        local needIngots = math.floor(count * items.ore[item].ratio)
                        local ingots, availableIngots = getAllItemCount(items.ore[item].fingerprint, needIngots)

                        if ingots < count then
                            itemScan = false
                            drawButton("oreScanOne")
                            drawButton("oreScanMulti")
                            alert({"Недостаточно слитков, зайдите позже"}, drawOreList)
                        else
                            if pushItem(slot, 64) then
                                for ingot = 1, #availableIngots do 
                                    for fingerprint = 1, #availableIngots[ingot].fingerprints do
                                        insertItem(availableIngots[ingot].fingerprints[fingerprint].fingerprint, availableIngots[ingot].fingerprints[fingerprint].count)
                                        if active then
                                            scanMe()
                                            drawOreList()
                                        end
                                    end
                                end
                            end
                        end
                        break
                    end
                end
            end
        end

        if signal[1] ~= "player_on" and signal[1] ~= "player_off" then
            local name = pim.getInventoryName()

            if session.name ~= name and name ~= "pim" then
                login(name)
            elseif name == "pim" and session.name then
                login()
            end
        end
        if focus.write then
            cursor(focus.write, not writes[focus.write].cursorState, false)
        end
    end
end
