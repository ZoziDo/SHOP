-- ============================================================
-- RIPMARKET / OpenComputers account server (fixed standalone)
-- Local modem server; no Internet Card required.
-- Required files on this computer:
--   /home/server.lua
--   /home/server_config.lua
-- Start: server
-- Stop: Ctrl+C
-- ============================================================

local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")

local CONFIG_PATH = "/home/server_config.lua"
local configChunk, configError = loadfile(CONFIG_PATH)
if not configChunk then
    error("Не найден или поврежден " .. CONFIG_PATH .. ": " .. tostring(configError))
end

local config = configChunk()
if type(config) ~= "table" then
    error(CONFIG_PATH .. " должен возвращать таблицу настроек")
end

if not component.isAvailable("modem") then
    error("На серверном компьютере не найден модем")
end

local modem = component.modem
local port = tonumber(config.port) or 1414
local timezoneOffset = (tonumber(config.timezoneOffsetHours) or 0) * 3600
local allowAnyTerminal = config.allowAnyTerminal == true
local terminals = {}

for _, address in ipairs(config.terminals or {}) do
    terminals[address] = true
end

local function ensureDirectory(path)
    if not filesystem.exists(path) then
        local ok, reason = filesystem.makeDirectory(path)
        if not ok and not filesystem.exists(path) then
            error("Не удалось создать каталог " .. path .. ": " .. tostring(reason))
        end
    end
end

local function nowTimestamp()
    local path = "/tmp/ripmarket_time"
    local file = assert(io.open(path, "w"))
    file:write("time")
    file:close()
    return filesystem.lastModified(path) / 1000 + timezoneOffset
end

local function now(format)
    return os.date(format, nowTimestamp())
end

local function safeFileName(value)
    return tostring(value):gsub("[^%w_%-]", "_")
end

local function log(message, customFile)
    ensureDirectory("/home/logs")
    local fileName = customFile and safeFileName(customFile) or "main"
    local file, reason = io.open("/home/logs/" .. fileName .. ".log", "a")
    if not file then
        io.stderr:write("Не удалось записать лог: " .. tostring(reason) .. "\n")
        return
    end
    file:write(now("[%d.%m.%Y %H:%M:%S] ") .. tostring(message) .. "\n")
    file:close()
end

local function userPath(name)
    return "/home/users/" .. safeFileName(name) .. ".txt"
end

local function readSerializedFile(path)
    local file, reason = io.open(path, "r")
    if not file then
        return nil, reason
    end
    local raw = file:read("*a")
    file:close()
    if raw == "" then
        return nil, "empty file"
    end
    return serialization.unserialize(raw)
end

local function writeSerializedFile(path, value)
    local file, reason = io.open(path, "w")
    if not file then
        return nil, reason
    end
    file:write(serialization.serialize(value))
    file:close()
    return true
end

local function readUser(name)
    local data, reason = readSerializedFile(userPath(name))
    if not data then
        log("Ошибка чтения пользователя " .. tostring(name) .. ": " .. tostring(reason))
    end
    return data
end

local function readFeedbacks()
    local path = "/home/feedbacks.txt"
    if not filesystem.exists(path) then
        return nil
    end
    local data, reason = readSerializedFile(path)
    if not data and reason ~= "empty file" then
        log("Ошибка чтения отзывов: " .. tostring(reason))
    end
    return data
end

local function updateUser(name, changes)
    ensureDirectory("/home/users")
    local path = userPath(name)
    local merged = {}

    if filesystem.exists(path) then
        local old = readUser(name)
        if type(old) == "table" then
            for key, value in pairs(old) do
                merged[key] = value
            end
        end
    end

    for key, value in pairs(changes or {}) do
        if key == "balance" and type(value) == "table" then
            merged.balance = merged.balance or {}
            for serverName, balance in pairs(value) do
                merged.balance[serverName] = balance
            end
        else
            merged[key] = value
        end
    end

    return writeSerializedFile(path, merged)
end

local function writeFeedback(name, feedback)
    local feedbacks = readFeedbacks() or {n = 0}
    if feedbacks[name] == nil then
        feedbacks.n = (tonumber(feedbacks.n) or 0) + 1
    end
    feedbacks[name] = feedback
    return writeSerializedFile("/home/feedbacks.txt", feedbacks)
end

local function registerUser(name, serverName)
    local timestamp = now("%d.%m.%Y %H:%M:%S")
    local user = {
        balance = {[serverName] = 0},
        transactions = 0,
        lastLogin = timestamp,
        regTime = timestamp,
        banned = false,
        eula = false
    }
    local ok, reason = updateUser(name, user)
    if not ok then
        log("Ошибка регистрации " .. name .. ": " .. tostring(reason))
        return nil
    end
    log("Зарегистрирован пользователь " .. name)
    return user
end

local function login(name, serverName)
    local path = userPath(name)
    local user

    if filesystem.exists(path) then
        user = readUser(name)
    else
        user = registerUser(name, serverName)
    end

    if type(user) ~= "table" then
        return nil
    end

    user.balance = user.balance or {}
    if user.balance[serverName] == nil then
        user.balance[serverName] = 0
    end
    user.transactions = tonumber(user.transactions) or 0
    user.banned = user.banned == true
    user.eula = user.eula == true
    user.lastLogin = now("%d.%m.%Y %H:%M:%S")

    local ok = updateUser(name, user)
    if not ok then
        return nil
    end

    log("Вход пользователя " .. name)
    return user
end

local function send(address, value)
    modem.send(address, port, serialization.serialize(value))
end

local function isAllowed(address)
    return allowAnyTerminal or terminals[address] == true
end

local function handleRequest(address, rawData)
    local request, reason = serialization.unserialize(rawData)
    if type(request) ~= "table" then
        log("Некорректный запрос от " .. tostring(address) .. ": " .. tostring(reason))
        send(address, {code = 422, message = "Bad serialized request"})
        return
    end

    if not isAllowed(address) then
        log("Отклонен неизвестный терминал " .. tostring(address))
        send(address, {code = 403, message = "This modem is not whitelisted"})
        return
    end

    if request.log and type(request.log) == "table" and request.log.data then
        log(request.log.data, request.log.mPath or "terminal")
    end

    local method = request.method
    local name = request.name
    local serverName = request.server

    if type(method) ~= "string" then
        send(address, {code = 422, message = "Bad method"})
        return
    end
    if type(name) ~= "string" or name == "" then
        send(address, {code = 422, message = "Bad username"})
        return
    end
    if type(serverName) ~= "string" or serverName == "" then
        send(address, {code = 422, message = "Bad server name"})
        return
    end

    if method == "login" then
        local user = login(name, serverName)
        if user then
            send(address, {
                code = 200,
                message = "Login successfully",
                userdata = user,
                feedbacks = readFeedbacks()
            })
        else
            send(address, {code = 500, message = "Unable to login"})
        end
    elseif method == "merge" then
        if type(request.toMerge) ~= "table" then
            send(address, {code = 422, message = "toMerge is nil"})
            return
        end
        local ok, mergeReason = updateUser(name, request.toMerge)
        if ok then
            send(address, {code = 200, message = "Merged successfully"})
        else
            log("Ошибка обновления " .. name .. ": " .. tostring(mergeReason))
            send(address, {code = 500, message = "Unable to merge"})
        end
    elseif method == "feedback" then
        if type(request.feedback) ~= "string" or request.feedback == "" then
            send(address, {code = 422, message = "Bad feedback"})
            return
        end
        local ok, feedbackReason = writeFeedback(name, request.feedback)
        if ok then
            send(address, {code = 200, message = "Review submitted successfully"})
        else
            log("Ошибка записи отзыва: " .. tostring(feedbackReason))
            send(address, {code = 500, message = "Unable to save feedback"})
        end
    else
        send(address, {code = 422, message = "Bad method"})
    end
end

ensureDirectory("/home/users")
ensureDirectory("/home/logs")

if not modem.isOpen(port) and not modem.open(port) then
    error("Не удалось открыть порт " .. port)
end

print("RIPMARKET SERVER STARTED")
print("Порт: " .. port)
print("Адрес модема сервера: " .. modem.address)
print("Любой терминал разрешен: " .. tostring(allowAnyTerminal))
print("Остановка: Ctrl+C")
log("Сервер запущен на порту " .. port)

while true do
    local _, _, remoteAddress, remotePort, _, data = event.pull("modem_message")
    if remotePort == port and type(data) == "string" then
        local ok, err = pcall(handleRequest, remoteAddress, data)
        if not ok then
            log("Внутренняя ошибка обработки запроса: " .. tostring(err))
            send(remoteAddress, {code = 500, message = "Internal server error"})
        end
    end
end
