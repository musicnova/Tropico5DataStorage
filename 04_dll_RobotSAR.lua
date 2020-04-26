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
	
	--===== BEGIN DEBUG
	-- message(tostring(getParamEx(Class,Emit,"STATUS").param_type),3) => 0
	--===== END DEBUG
	
	local SessionStatus = tonumber(getParamEx(Class,Emit,"STATUS").param_value) -- NUMERIC
	-- local SessionStatus = tonumber(getParamEx(Class,Emit,"STATUS").param_image) -- STRING
    if (SessionStatus~=1) then
		Problem = "Сессия "..Emit.." на "..Class.." закрыта!" -- FIXME
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
	-- PrintDbgStr(ServerTime.."\n".."\n")

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

	Problem = ""
	local PosNow = PosNowFunc(Emit,MyAccount)
	local Signal = SignalCheck()

	if(PosNow~=0) then
		CorrectPos(PosNow,0,Emit,MyAccount,Class,FileLog,"тест функции ",20)
	end

	PutDataToTable(PosNow)
	sleep(1000)
end

function CorrectPos(posNow,posNeed,emit,acc,class,file,prevString,slip)
	local vol = posNeed - posNow
	if(vol==0) then
		return 0
	end
	local buySell = ""
	local price = 0
	local last = tonumber(getParamEx(class,emit,"LAST").param_value)
	local step = tonumber(getParamEx(class,emit,"SEC_PRICE_STEP").param_value)
	if (vol>0) then
		buySell = "B"
		price = last + slip * step
	else
		buySell = "S"
		price = last - slip * step
	end
	transaction = {
			["ACTION"] = "NEW_ORDER",
			["SECCODE"] = emit,
			["ACCOUNT"] = acc,
			["CLASSCODE"] = class,
			["OPERATION"] = buySell,
			["PRICE"] = tostring(price),
			["QUANTITY"]=tostring(math.abs(vol)),
			["TYPE"] = "L"
		}
	transaction.TRANS_ID = "123456"
	transaction.CLIENT_CODE = "РОБОТ"
	local result = sendTransaction(transaction)
	local sDataString = ""
	if (file ~= nil and file ~= "") then
		sDataString = "Отклик транзакции = "..result.."; Pos= "..tostring(posNow).."; "
	end
	for key,val in pairs(transaction) do
		sDataString = sDataString..key.."="..val.."; "
	end
	if (prevString ~= nil) then
		sDataString = prevString..sDataString
	end
	WriteToEndOfFile(file,sDataString)
	local count = 1
	sleep(100)
	for i=1,300 do
		local posNew = PosNewFunc(emit,acc)
		if(posNew==posNeed)then
			Problem = "Сделка прошла за "..tostring(count*100).."мсек"
			WriteToEndOfFile(file,Problem)
			return 1
		end
		count = count + 1
		sleep(100)
	end
	Problem = "Проблемы с транзакцией! EPIC FAIL!"
	WriteToEndOfFile(file, Problem)
	return nil
end

function RoundForStep(num,nStep)
	if(nStep==nil or num==nil) then
		return nil
	elseif (nStep==0) then
		return num
	end
	local ost=num % nStep
	if (ost < nStep/2) then
		return (math.floor(num/nStep)*nStep)
	else
		return (math.ceil(num/nStep)*nStep)
	end
end

function SignFunc(num)
	if (num>0) then
		return 1
	elseif (num<0) then
		return -1
	elseif (num==0) then
		return 0
	end
end

function SignalCheck()
    local NumOfCandlesSAR = getNumCandles(IdSAR)
	local NumOfCandlesPrice = getNumCandles(IdPriceSAR)
	if(NumOfCandlesSAR==nil or NumOfCandlesPrice==nil) then
		Problem = "нет вывода с графиков!"
		return 0
	end
	local tSAR,nSAR,_ = getCandlesByIndex(IdSAR, 0, NumOfCandlesSAR-2,2)
	local tPRICE,nPRICE,_ = getCandlesByIndex(IdPriceSAR,0,NumOfCandlesPrice-2,2)
	if (nSAR~=2 and nPRICE~=2) then
	    Problem = "нет вывода с графика!"
		return 0
	end
	if (tSAR[0].close>tPRICE[0].close and tSAR[1].close<tPRICE[1].close) then
	    return 2
	elseif (tSAR[0].close<tPRICE[0].close and tSAR[1].close>tPRICE[1].close) then
		return -2
	elseif (tSAR[1].close<tPRICE[1].close) then
		return 1
	elseif (tSAR[1].close>tPRICE[1].close) then	
		return -1
	end
	return 0
end

function PutDataToTable(posNow)
    SetCell(TableID, 3, 2, tostring(posNow))
end

function PosNowFunc(emit,account)
	local nSize = getNumberOf("futures_client_holding")
	if (nSize~=nil) then
	    for i=0,nSize-1 do
			local row = getItem ("futures_client_holding",i)
			if(row~=nil and row.sec_code==emit and row.trdaccid==account) then
			    return tonumber(row.totalnet)
			end
		end
	end
	return 0
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
