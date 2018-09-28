function Body() --основная функция
	if (Timer>0) then
		Timer = Timer - 1
		PutDataToTableTimer()
		sleep(1000)
	end

	local ServerTime = getInfoParam("SERVERTIME")
	if(ServerTime==nil or ServerTime=="") then
		Problem = "Время сервера не получено!"
		Timer = 3
		return
	else
		Problem = ""
	end
	if (IsWindowClosed(TableID)) then
		CreateWindow(TableID)
		PutDataToTableInit()
	end
	local SessionStatus = tonumber(getParamEx(Class,Emit,"STATUS").param_value) -- NUMERIC
	-- local SessionStatus2 = getParamEx(Class,Emit,"STATUS").param_image -- STRING
    if (SessionStatus~=1) then
		Problem = "Сессия закрыта!" -- FIXME
		Timer = 3
		return
	end
	
	local f_cb = function(TableID, msg, X, Y)
	if(msg==QTABLE_LBUTTONDBLCLK) then
		if(X==13 and Y==1) then
		    message("Робот работает!", 1)
		elseif(X==13 and Y==3) then
			message("Робот остановлен!", 1)
			is_run=false
		end
	end
	end
	SetTableNotificationCallback (TableID, f_cb)
	
	SetCell(TableID,1,2,ServerTime)
	SetCell(TableID,1,3,Problem)
	PrintDbgStr(ServerTime.."\n"..tostring(count).."\n")
	count = count + 1
	--=====
	
	--находим текущую позицию по инструменту
	--если переворот позы или закрытие, то нужно убрать профит (помнить прошлую позицию)
	--проверить наличие сигнала (с графика)
	--скорректировать сигнал с учетом "только лонг или только шорт"
	--сигнал ЛОНГ или ШОРТ, то нужно купить или продать
	--проверить, что мы не против показания индикатора
	--найти цену входа
	--проверить правильность профита
	--запишем текущие данные в таблицу робота
	--запомнить текущую позицию
	--все
	
	sleep(1000)
end

function PutDataToTableInit()
	Clear(TableID)
	SetWindowPos(TableID,100,200,500,300)
	SetWindowCaption(TableID, "Робот параболик")
	-----
	for i=1,13 do
		InsertRow(TableID, -1)
	end
	SetCell(TableID, 1, 1, "Время сервера =>")
	SetCell(TableID, 2, 1, "Код бумаги")
	SetCell(TableID, 3, 1, "Позиция текущая")
	SetCell(TableID, 4, 1, "Сигнал ТС")
	SetCell(TableID, 5, 1, "Лот")
	SetCell(TableID, 7, 1, "Номер счета"); SetCell(TableID, 7, 3, "Номер счета на ФОРТС")
	SetCell(TableID, 8, 1, "Код класса")
	SetCell(TableID, 13, 1, "ТЕСТ РОБОТ")
    SetColor(TableID, 13, 1, RGB(255,255,0), RGB(0,0,0), RGB(0,220,220), RGB(0,0,0))
	SetCell(TableID, 13, 3, "СТОП * РОБОТ")
    SetColor(TableID, 13, 3, RGB(255,255,0), RGB(0,0,0), RGB(0,220,220), RGB(0,0,0))
	
	local nRow,nCol = GetTableSize(TableID)
	for i=1,nRow do
		if (i % 2 == 0) then
			SetColor(TableID, i, QTABLE_NO_INDEX, RGB(220,220,220), RGB(0,0,0), RGB(0,220,220), RGB(0,0,0))
		else
			SetColor(TableID, i, QTABLE_NO_INDEX, RGB(255,255,255), RGB(0,0,0), RGB(0,220,220), RGB(0,0,0))
		end
	end
end

function PutDataToTableTimer()
	SetCell(TableID, 1, 3, Problem)
	Highlight(TableID, 1, QTABLE_NO_INDEX, RGB(0,20,255), RGB(255,255,255), 500)
end

function WriteToEndOfFile(sFile,sDataString)
    local serverTime = getInfoParam("SERVERTIME")
	local serverData = getInfoParam("TRADEDATE")
	sDataString = serverData..";"..serverTime..";"..sDataString.."\n"
	local f = io.open(sFile,"r+")
	if(f == nil) then
		f = io.open(sFile,"w")
	end
	if(f~=nil) then
		f:seek("end",0)
		f:write(sDataString)
		f:flush()
		f:close()
	end
end
