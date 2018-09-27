--РОБОТ ДЛЯ ТОРГОВЛИ НА БИРЖЕ НА СРОЧНОМ РЫНКЕ НА ОСНОВЕ ИНДИКАТОРА ПАРАБОЛИК
--ВЕРСИЯ 2.0

dofile(getScriptPath().."\\dll_RobotSAR.lua") -- файл с основными функциями

is_run = true
Timer = 3
Problem = ""

function OnInit()
	--некие действия
	TableID = AllocTable() -- будущая таблица робота
	AddColumn(TableID,1,"ПАРАМЕТРЫ",true,QTABLE_STRING_TYPE,20)
	AddColumn(TableID,2,"ЗНАЧЕНИЯ",true,QTABLE_STRING_TYPE,20)
	AddColumn(TableID,3,"КОММЕНТАРИИ",true,QTABLE_STRING_TYPE,30)
	CreateWindow(TableID)
	PutDataToTableInit()
	message("Робот запущен!",1)
end

function main()
	while is_run==true do
        Body()
	end
end

function OnTrade(TradeX)
	--действия при появлении новой сделки
end

function OnOrder(OrderX)
	--действия при появлении заявки в КВИКе
end

function OnStopOrder()
	--действия при появлении стоп-заявки
end

function OnStop()
	--действия при нажатии на "остановить"
	is_run = false
end
