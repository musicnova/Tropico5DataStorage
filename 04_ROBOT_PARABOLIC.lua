--РОБОТ ДЛЯ ТОРГОВЛИ НА БИРЖЕ НА СРОЧНОМ РЫНКЕ НА ОСНОВЕ ИНДИКАТОРА ПАРАБОЛИК
--ВЕРСИЯ 4.1

--README https://arqatech.com/ru/products/quik/basic-sets/quik-broker-training-copy/#anchor-link
--README https://arqatech.com/ru/support/files/
dofile(getScriptPath().."\\04_dll_RobotSAR.lua") -- файл с основными функциями

FileLog = getScriptPath().."\\FileLog.txt"
is_run = true
Timer = 3
Problem = ""
Slip = 20 -- это в шагах цены. Примеры ниже:

SLIP_NEFT=0.2
SLIP_RUB_USD=20
SLIP_FOR_RTS=200

DataTable = os.date("*t", os.time())

--=====

Class = "SPBFUT"
--Emit = "BRV8"
Emit = "LKZ8"
MyAccount = "SPBFUT00a70"
IdSAR = "SAR"
IdPriceSAR = "PRICE_SAR"

function OnInit()
	--некие действия
	TableID = AllocTable() -- будущая таблица робота
	AddColumn(TableID,1,"ПАРАМЕТРЫ",true,QTABLE_STRING_TYPE,20)
	AddColumn(TableID,2,"ЗНАЧЕНИЯ",true,QTABLE_STRING_TYPE,20)
	AddColumn(TableID,3,"КОММЕНТАРИИ",true,QTABLE_STRING_TYPE,30)
	CreateWindow(TableID)
	PutDataToTableInit()
	message("Робот запущен!",1)
	WriteToEndOfFile(FileLog, "Робот запущен!")
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
	WriteToEndOfFile(FileLog, "Робот остановлен!")
end
