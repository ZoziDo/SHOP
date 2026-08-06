local component = require("component")
local computer=require("computer")
local event = require("event")
local term = require("term")
local shell = require("shell")
local fs = require("filesystem")
local unicode=require("unicode")
local serial = require("serialization")
local g = component.gpu
event.shouldInterrupt = function () return false end
--------------------Настройки--------------------
local WIDTH, HEIGHT = 49, 24 --Разрешение моника
local AUTOEXIT = 30 --Автовыход через n сек.
local TONE = 600 --Тональность звука
local MAX_OPERATION = 2000 --Максимальная операция
local MONEY_ITEM_ID = "CUSTOMNPCS_NPCMONEY" --Айдишник деняк
local COLOR1 = 0x00ff00 --Рамка
local COLOR2 = 0x333333 --Цвет кнопок
local SPAM = 1 --Время, в течении которого нельзя юзать комп, после выхода
-------------------------------------------------

local mid = WIDTH / 2
local summa = 0
local timeClear = 0

login = false
timer = 0
spam = false

function drawStart()
	g.setResolution(WIDTH, HEIGHT)
	sky.logo("Bankomat", COLOR1, COLOR2, WIDTH, HEIGHT)
	g.setForeground(COLOR2)
	sky.mid(WIDTH, 6, "───────────────────────────────────")
	sky.mid(WIDTH, 11, "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔")
	g.setForeground(COLOR1)
	sky.word(10, 7, "bank", COLOR2)
	sky.button(16,17,18,3,COLOR1,COLOR2, "Залогиниться")
end

function Exit()
	login = false
	summa = 0
	
	drawStart()
	
	local users={computer.users()}
    for i=1, #users do
        computer.removeUser(users[i])
    end
	spam = true
end

function drawBalance(nick)
	local balance = sky.money(nick)
	sky.mid(WIDTH, 8, "                                        ")
	g.setForeground(COLOR1)
	sky.mid(WIDTH, 8, "[ " .. balance .. " ]")
end

function Logic(w,h,nick)
	if sky.pressButton(w,h,{5,11,8,3}) then
		summa = summa + 1
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{5,14,8,3}) then
		summa = summa + 10
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{5,17,8,3}) then
		summa = summa + 100
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{38,11,8,3}) then
		summa = summa - 1
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{38,14,8,3}) then
		summa = summa - 10
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{38,17,8,3}) then
		summa = summa - 100
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{14,14,11,3}) then
		sky.mid(WIDTH, 21, "                                        ")
		timeClear = 3
		if summa == 0 then
			g.setForeground(0xff0000)
			sky.mid(WIDTH, 21, "Введите сумму")
			g.setForeground(COLOR1)
		elseif sky.checkMoney(nick, summa) then
			--sky.com("give " .. nick .. " " .. MONEY_ITEM_ID .. " " .. summa)
			
			local ostatok = sky.giveItem(nick, MONEY_ITEM_ID, summa)
			
			if ostatok == 0 then				
				sky.mid(WIDTH, 21, "Операция выполнена")
			else
				local t = "&2Инвентарь полон, &4" .. ostatok .. " &2возвращено"
				sky.com("money give " .. nick .. " " .. ostatok)
				sky.text(WIDTH/2 - (unicode.len(t)-6)/2, 21, t)
				timeClear = 5
			end
			summa = 0			
		else
			g.setForeground(0xff0000)
			sky.mid(WIDTH, 21, "Недостаточно средств")
			g.setForeground(COLOR1)
		end	
		drawBalance(nick)
		computer.beep(TONE, 0.05)
	elseif sky.pressButton(w,h,{26,14,11,3}) then
		sky.mid(WIDTH, 21, "                                        ")
		timeClear = 3
		if summa == 0 then
			g.setForeground(0xff0000)
			sky.mid(WIDTH, 21, "Введите сумму")
			g.setForeground(COLOR1)
		elseif sky.takeItem(nick, MONEY_ITEM_ID, summa) then
			sky.com("money give " .. nick .. " " .. summa)
			summa = 0
			sky.mid(WIDTH, 21, "Операция выполнена")
		else
			g.setForeground(0xff0000)
			sky.mid(WIDTH, 21, "Недостаточно средств")
			g.setForeground(COLOR1)
		end
		drawBalance(nick)
		computer.beep(TONE, 0.05)
	end
	
	if summa < 0 then
		summa = 0
	elseif summa > MAX_OPERATION then
		summa = MAX_OPERATION
	end
	
	local text = "&0Сумма: &2" .. summa .. "$"
	sky.mid(WIDTH, 12, "                    ")
	sky.text(WIDTH/2 - (unicode.len(text)-4)/2, 12, text)
end

function Login(w,h,nick)
	if (sky.pressButton(w,h,{16,17,18,3}) and not (login)) then
		computer.addUser(nick)
		login = true
		g.fill(3, 2, WIDTH-4, HEIGHT-2, " ")
		g.setForeground(COLOR2)
		sky.mid(WIDTH,4,"Добро пожаловать")
		sky.mid(WIDTH,7,"Ваш баланс:")
		g.setForeground(COLOR1)
		sky.mid(WIDTH,5,nick)
		drawBalance(nick)		
		
		sky.button(5,11,8,3,COLOR1,COLOR2,"+1")
		sky.button(5,14,8,3,COLOR1,COLOR2,"+10")
		sky.button(5,17,8,3,COLOR1,COLOR2,"+100")
		
		sky.button(38,11,8,3,COLOR1,COLOR2,"-1")
		sky.button(38,14,8,3,COLOR1,COLOR2,"-10")
		sky.button(38,17,8,3,COLOR1,COLOR2,"-100")
		
		
		sky.button(14,14,11,3,COLOR1,COLOR2,"Снять")
		sky.button(26,14,11,3,COLOR1,COLOR2,"Внести")
		
		
		sky.button(14,17,23,3,COLOR1,COLOR2,"Выход")
		computer.beep(TONE, 0.05)
	elseif (sky.pressButton(w,h,{14,17,23,3}) and login) then
		computer.beep(TONE, 0.05)
		Exit()
	end
end

function autoExit()
	timer = timer - 1
	g.setForeground(COLOR2)
	g.set(WIDTH/2 - 9, 22, "Авто выход через:")
	if timer <= 10 then
		g.setForeground(0xff0000)
	else
		g.setForeground(COLOR1)
	end
	g.set(WIDTH/2 + 9, 22, timer .. " ")
end

Exit()

while true do
	if (not spam) then
		local e,_,w,h,_,nick = event.pull(1, "touch")
		if e == "touch" then
			Login(w,h,nick)
			if (login) then
				Logic(w,h,nick)
			end
			timer = AUTOEXIT
		end
		if (login) then
			autoExit()
			if timer == 0 then	
				Exit()
			end
			if timeClear > 0 then
				timeClear = timeClear -1
				if timeClear == 0 then
					sky.mid(WIDTH, 21, "                                        ")
				end
			end
		end
	else
		os.sleep(SPAM)
		spam = false
	end
end
