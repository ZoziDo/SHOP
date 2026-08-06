local component = require("component")
local event = require("event")
local unicode = require("unicode")
local filesystem = require("filesystem")
local serialization = require("serialization")
local internet = component.internet
local modem = component.modem
local port = 1414

local terminals = {
	"39f19ac0-4341-4e2f-a2ea-c62a648aaeb4"
}

for terminal = 1, #terminals do 
    terminals[terminals[terminal]], terminals[terminal] = true, nil
end 

local function checkPath(path)
	if not filesystem.exists(path) then
		filesystem.makeDirectory(path)
	end
end

local function getTime(type)
	local file = io.open("/tmp/time", "w")
	file:write("time")
	file:close() 
	local timestamp = filesystem.lastModified("/tmp/time") / 1000 + 3600 * 3

	if type == "full" then
		return os.date("%d.%m.%Y %H:%M:%S", timestamp)
	elseif type == "log" then
		return os.date("[%H:%M:%S] ", timestamp)
	elseif type == "filesystem" then
		return os.date("%d.%m.%Y", timestamp)
	elseif type == "raw" then
		return timestamp
	end
end

local function log(data, customPath)
	local timestamp = getTime("raw")
	local time = os.date("[%H:%M:%S] ", timestamp)
	local date = os.date("%d.%m.%Y", timestamp)
	checkPath("/home/logs/")
	local path = "/home/logs/" .. os.date("%d.%m.%Y", timestamp)
	checkPath(path)
	local data = time .. data

	if customPath then
		path = path .. customPath
	else
		path = path .. "/main.log"
	end
	local days = {date .. "/", os.date("%d.%m.%Y/", timestamp - 86400), os.date("%d.%m.%Y/", timestamp - 172800), os.date("%d.%m.%Y/", timestamp - 259200)}
    for day = 1, #days do 
        days[days[day]], days[day] = true, nil
    end
    for path in filesystem.list("/home/logs/") do 
        local checkPath = "/home/logs/" .. path
        if not days[path] then
			sendFile(checkPath)
            filesystem.remove(checkPath)
        end
    end

	local file = io.open(path, "a")
	file:write(data .. "\n")
	file:close()
end

local function sendFile(filePath)
	local webhook = "https://discord.com/api/webhooks/1389192392321531914/QyFsSZJ3UVTuVfu7bKBk2RHUWzAtzxT7QxEcl7BoAg-1gJ0o0FzmtTWiCHfnt4TTlYxF"

	local file = io.open(filePath, "rb")
	local content = file:read("*all")
	file:close()

	local boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

	local body =
	"--" .. boundary .. "\r\n" ..
	'Content-Disposition: form-data; name="file"; filename="file.txt"\r\n' ..
	"Content-Type: text/plain\r\n\r\n" ..
	content .. "\r\n" ..
	"--" .. boundary .. "--"

	local headers = {
		["Content-Type"] = "multipart/form-data; boundary=" .. boundary
	}

	local request = internet.request(webhook, body, headers)

	for chunk in request do
		print(chunk)
	end

	log("File sent")
end

local function readUser(name)
	local file = io.open("/home/users/" .. name .. ".txt", "r")
	local data = file:read("a")
	file:close()
	local userdata, err = serialization.unserialize(data)

	if userdata then
		return userdata
	elseif err then
		log("Error on read user, err: " .. err)
	end
end

local function readFeedbacks()
	if filesystem.exists("/home/feedbacks.txt") then
		local file = io.open("/home/feedbacks.txt", "r")
		local data = file:read("a")
		file:close()

		if data ~= "" then
			local feedbacks, err = serialization.unserialize(data)

			if feedbacks then
				return feedbacks
			elseif err then
				log("Error on read feedbacks, err: " .. err)
			end
		end
	end
end

local function updateUser(name, data)
	checkPath("/home/users/")
	local userPath = "/home/users/" .. name .. ".txt"
	local merged

	if filesystem.exists(userPath) then
		merged = readUser(name)
		for k, v in pairs(data) do merged[k] = v end
	end

	local file = io.open(userPath, "w")
	file:write(serialization.serialize(merged or data))
	file:close()
end

local function writeFeedback(name, feedback)
	local feedbacks = readFeedbacks()

	if feedbacks then
		feedbacks[name] = feedback
		feedbacks.n = feedbacks.n + 1
	else
		feedbacks = {[name] = feedback, n = 1}
	end

	if feedbacks then
		local file = io.open("/home/feedbacks.txt", "w")
		file:write(serialization.serialize(feedbacks))
		file:close()
	end
end

local function reg(name, server)
	log("Registration user " .. name)
	local time = getTime("full")
	local user = {
		balance = {
			[server] = 0
		},
        transactions = 0,
        lastLogin = time,
        regTime = time,
        banned = false,
        eula = false
	}

	updateUser(name, user)
	return user
end

local function login(name, server)
	local path = "/home/users/" .. name .. ".txt"

	if filesystem.exists(path) then
		log("User login " .. name)
		local userdata = readUser(name)

		if userdata then
			if not userdata.balance[server] then
				userdata.balance[server] = 0
			end

			userdata.lastLogin = getTime("full")
			updateUser(name, userdata)
			return userdata
		end
	else
		if reg(name, server) then
			return login(name, server)
		end
	end
end

local function send(address, data)
	modem.send(address, port, data)
end

local function responseHandler(data, address)
	log("DATA " .. data)
	local userdata, err = serialization.unserialize(data)

	if userdata then
		if terminals[address] then
			if userdata.log then
				if userdata.log.mPath and userdata.log.data then
					log(userdata.log.data, userdata.log.mPath)
				end
			end

			if userdata.method then
				if userdata.name then
					if userdata.server then
						if userdata.method == "login" then
							local success = login(userdata.name, userdata.server)

							if success then
								local responseMessage = {
									code = 200,
									message = "Login successfully",
									userdata = success,
									feedbacks = readFeedbacks()	
								}
								send(address, serialization.serialize(responseMessage))
							else
								send(address, '{code = 500, message = "Unable to login, unexpected error"}')
							end
						elseif userdata.method == "merge" then
							if userdata.toMerge then
								updateUser(userdata.name, userdata.toMerge)
								send(address, '{code = 200, message = "Merged successfully"}')
							else
								send(address, '{code = 422, message = "toMerge is nil"}')
							end
						elseif userdata.method == "feedback" then
							if userdata.feedback then
								writeFeedback(userdata.name, userdata.feedback)
								send(address, '{code = 200, message = "Review submitted successfully"}')
							else
								send(address, '{code = 422, message = "Bad feedback"}')
							end
						else
							send(address, '{code = 422, message = "Bad method"}')
						end
					else
						send(address, '{code = 422, message = "Bad server name"}')
					end
				else
					send(address, '{code = 422, message = "Bad username"}')
				end
			else
				send(address, '{code = 422, message = "Bad method"}')
			end
		else
			send(address, '{code = 422, message = "This modem is not whitelisted"}')
			local logData = "Access attempt! " .. serialization.serialize(userdata)
			log(logData)
		end
	elseif err then
		log("Unable to parse table, err: " .. err)
	end
end

local function messageHandler(event, _, address, rport, _, data)
	if port == rport then 
		responseHandler(data, address) 
	end
end

function start()
	if ripmarketIsRunning then
		io.stderr:write("Daemon is running!")
	else
		ripmarketIsRunning = true
		if modem.isOpen(port) then
			io.stderr:write("Port " .. port .. " is busy!")
		else
			if modem.open(port) then
				local success = "RipMarket started on port " .. port .. "!"
				print(success)
				log(success)
				event.listen("modem_message", messageHandler)
			else
				io.stderr:write("Unable to open port " .. port)
			end
		end
	end
end

function stop()
	if not ripmarketIsRunning then
		io.stderr:write("Daemon already stopped!")
	else
		ripmarketIsRunning = false
		modem.close(port)
		event.ignore("modem_message", messageHandler)
		print("Daemon is offline...")
		return true
	end
end

function restart()
	if stop() then
		start()
	end
end
