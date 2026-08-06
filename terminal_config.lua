-- Настройки компьютера магазина.
-- Адреса смотрите командой: lua /home/check_components.lua
return {
    -- Вставьте адрес МОДЕМА серверного компьютера, не адрес самого компьютера.
    serverAddress = "ВСТАВЬТЕ_АДРЕС_МОДЕМА_СЕРВЕРА",
    port = 1414,
    serverName = "Default",

    -- Типы компонентов. Обычно менять не требуется.
    modemComponent = "modem",
    pimComponent = "pim",
    meComponent = "me_interface",
    selectorComponent = "openperipheral_selector",

    -- Стороны передачи предметов относительно соответствующего компонента.
    meSide = "DOWN",
    pimSide = "UP",

    listPath = "/home/list.lua",

    -- Никнеймы администраторов терминала, при необходимости.
    admins = {"ZoziDo"},
    devOnly = false
}
