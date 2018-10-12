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

	-- if(PosNow~=0) then
	--	CorrectPos(PosNow,0,Emit,MyAccount,Class,FileLog,"тест функции ",20)
	-- end
	
	if (PosNow==0 or (PosNow~=0 and SignFunc(PosNow)~=SignFunc(PrevPos))) then -- если был переворот позиции
		DeleteAllProfits(MyAccount, Emit, Class, FileLog, "Удаление тейк-профита при перевороте или нулевой позе")
	end
	
	local Signal = SignalCheck()
	-- BEGIN OF ДОРАБОТКИ ПОД РЕЖИМЫ LONG // SHORT
	if (TradeType=="LONG") then
		Signal = math.max(Signal,0)
	elseif(TradeType=="SHORT") then
		Signal = math.min(Signal,0)
	end
	-- END OF ДОРАБОТКИ ПОД РЕЖИМЫ LONG // SHORT

	local TransCount = 0
    
	if (math.abs(Signal)==2) then 	-- ОСНОВНОЙ РЕЖИМ: РЕВЕРС
		local posNeed = SignFunc(Signal)*Lot
		-- ДЗ: проверить на nil CorrectPos, понять причины, а не тупо упасть здесь
		TransCount = TransCount + CorrectPos(PosNow,posNeed,Emit,MyAccount,Class,FileLog,"Коррекция на сигналу +-2  ",Slip)
	elseif(math.abs(Signal)==1 and SignFunc(Signal)~=SignFunc(PosNow)) then	-- ОСНОВНОЙ РЕЖИМ: РЕВЕРС
		-- Защита от дурака: трейдер поставил против робота контракта
		TransCount = TransCount + CorrectPos(PosNow,0,Emit,MyAccount,Class,FileLog,"Коррекция по сигналу +-1  ", Slip)
	-- BEGIN OF ДОРАБОТКИ ПОД РЕЖИМЫ LONG // SHORT
	elseif(TradeType=="LONG" and PosNow<0) then -- корректировки на переключении режимов
		TransCount = TransCount + CorrectPos(PosNow,0,Emit,MyAccount,Class,FileLog,"только LONG, закрытие шорта  ",Slip)
	elseif(TradeType=="SHORT" and PosNow>0) then -- корректировки на переключении режимов
		TransCount = TransCount + CorrectPos(PosNow,0,Emit,MyAccount,Class,FileLog,"только SHORT, закрытие лонга  ",Slip)
	-- END OF ДОРАБОТКИ ПОД РЕЖИМЫ LONG // SHORT
	end

	if(TransCount==0)then -- Контроль, что стоп-профиты расставлены правильно
		TransCount = TransCount + ProfitControl(PosNow,MyAccount,Emit,Class,FileLog)
	end
	
	PutDataToTable(PosNow, Signal)
	PosPrev = PosNow
	-- sleep(1000)
	if (TransCount~=0) then
		sleep(1200) -- 3000
		-- ДЗ : вместо затыкания дыр сделать четкую проверку, что произошло с нашей транзакцией
	else
		sleep(200) -- 500
	end
end

function ProfitControl(posNow,myAccount,emit,class,fileLog)
	local function fn2(param1, param2, param3)
		if (param1==acc and param2==emit and param3==class) then
			return true
		else
			return false
		end
	end
	local step = tonumber(getParamEx(class,emit,"SEC_PRICE_STEP").param_value)
	local EnterPrice = RoundForStep(EnterPriceUni(posNow,emit,class,acc),step)
	local profitPrice = EnterPrice + SignFunc(posNow) * Profit * step -- если позиция <0, то профит ниже точки входа
	local ProfCorrect = false -- нашли или нет нужный профит (если нашли, то остальные профиты надо удалять)
	local count = 0
	local index = SearchItems("stop_orders",0,getNumberOf("stop_orders")-1, fn2, "account,sec_code,class_code")
	if (index ~= nil) then
	    for i=1,#index,1 do
			local row = getItem("stop_orders",index[i])		
			local flag = bit.band(row.flags,1) -- активна или нет
			if (flag > 0) then
				-- HELP QLUA -> Структуры данных -> Стоп заявки
				-- stop_order_type  NUMBER  Вид стоп заявки. Возможные значения: 
				-- «1» – стоп-лимит; 
				-- «2» – условие по другому инструменту; 
				-- «3» – со связанной заявкой; 
				-- «6» – тейк-профит; 
				-- «7» – стоп-лимит по исполнению активной заявки; 
				-- «8» – тейк-профит по исполнению активной заявки; 
				-- «9» - тейк-профит и стоп-лимит  
				if (row.stop_order_type~=6 or ProfCorrect==true) then --если мы правильную заявку нашли или это не тип 6
					local keyNumber = row.order_num
					DeleteProfitByNumber(emit,class,keyNumber,file)
					count = count + 1
				else
					-- все поля по справке
					local qtyX = row.qty
					local profitPrice = row.condition_price
					local buySellX = row.condition -- <<4>> >= ; <<5>> <=
					local signPosX = 0
					if(buySellX == 4) then
						signPosX = -1
					elseif(buySellX == 5) then
						signPosX = 1
					end
					if(signPosX==SignFunc(posNow) and qtyX==math.abs(posNow) and profitPriceX==profitPrice) then
						-- значит мы нашли правильную заявку
						ProfCorrect = true
					else
						local keyNumber = row.order_num
						DeleteProfitByNumber(emit,class,keyNumber,file)
						count = count + 1
					end
				end
			end
		end
	end
	if (ProfCorrect == false and posNow~=0) then -- цикл пробежали и выяснили, что профита нет, значит его надо выставить
		local newProfitSpread = 30 * step -- нельзя пускать на самотек, надо найти, давайте поставим 30 шагов
		local newStopPrice = profitPrice
		local newQty = math.abs(posNow)
		local defaultOtstup = 0

     	if(posNow>0) then
			buySell = "S"
		else
			buySell = "B"
		end
		NewStopProfit(acc,emit,class,buySell,newQty,newStopPrice,defaultOtstup,newProfitSpread,file,"Функция ProfitControl()")
		count = count + 1
	end
	return count
end

function EnterPriceUni(posNow,emit,class,acc)
	if(posNow==0)then
		return 0
	end
	local function fn1(param1, param2, param3)
		if (param1==acc and param2==emit and param3==class) then
			return true
		else
			return false
		end
	end
	local index = SearchItems("trades",0,getNumberOf("trades")-1, fn1, "account,sec_code,class_code")
	local PN = posNow
	local Sum = 0
	if (index ~= nil) then
	    for i=#index,1,-1 do
			local row = getItem("trades",index[i])
			local direct = 0
			if(bit.band(row.flags,4)>0) then -- флаг покупки
				direct = -1 -- для покупки
			else
				direct = 1 -- для продажи
			end
			local price = row.price
			local qty = row.qty
			local PNnext = PN - direct*qty
			if(SignFunc(PNnext)~=SignFunc(PN))then
				Sum = Sum + direct * SignFunc(posNow) * price * math.min(qty, math.abs(PN))
				-- пример если в позе 2 контракта, а мы получили путем переворота 4 контракта,
				-- то 2 контракта ушло на закрытие позиции, а два осталось. ДЗ - понять это!!!
				return Sum / math.abs(posNow)
			else
				Sum = Sum + direct * SignFunc(posNow) * price * qty
			end
		end
	end
	-- если вход произошел вчера, то функция будет некорректно работать
	-- ДЗ доработать - из файла или из таблицы сделок по первой цене за день
	-- пока 0
	return 0
end

function DeleteAllProfits(acc, emit, class, file, prevString)
	local N = getNumberOf("stop_orders")
	local count = 0
	for i = 0,N-1 do
		local row = getItem("stop_orders")
		if(row.account==acc and row.sec_code==emit and row.class_code == class) then
			if(bit.band(row.flags,1)>0) then -- активна или нет
				local keyNumber = row.order_num
				DeleteProfitByNumber(emit, class, keyNumber, file, prevString)
				count = count + 1
			end
		end
	end
	return count
end

function DeleteProfitByNumber(emit, class, keyNumber, file, prevString)
    transaction = {["CLASSCODE"] = class,
					["SECCODE"] = emit,
					["TRANS_ID"] = "123",
					["ACTION"] = "KILL_STOP_ORDER",
					["STOP_ORDER_KEY"] = toString(keyNumber),
					["CLIENT_CODE"] = "РОБОТ"
	}
	local result = sendTransaction(transaction)
	local sDataString = ""
	if (file ~= nil or file ~= "") then
		local sDataString = "Отклик транзакции = "..result
	end
	for key,val in pairs(transaction) do
		sDataString = sDataString..key.."="..val.."; "
	end
	if(prevString~=nil) then
		sDataString = prevString..sDataString
	end
	WriteToEndOfFile(file,sDataString) -- запись в лог-файл
end

function NewStopProfit(acc, emit, class, buySell, qty, stopPrice, profitOtstup, profitSpread,file,prevString)
	transaction = {["ACCOUNT"]=acc, ["SECCODE"]=emit, ["CLASSCODE"]=class,
					["ACTION"]="NEW_STOP_ORDER",
					["STOP_ORDER_KIND"]="TAKE_PROFIT_STOP_ORDER",
					["TRANS_ID"]="1234567",
					["CLIENT_CODE"]="РОБОТ",
					["EXPIRY_DATE"]="TODAY", -- 20040706 -- "GTC" до отмены
					["OPERATION"]=buySell,
					["QUANTITY"]=sostring(qty),
					["STOPPRICE"]=sostring(stopPrice),
					["OFFSET_UNITS"]="PRICE_UNITS",
					["SPREAD_UNITS"]="PRICE_UNITS",
					["OFFSET"]=tostring(profitOtstup), -- всегда 0, чтобы сразу сработал
					["SPREAD"]=tostring(profitSpread) -- всегда 0, чтобы сразу сработал
					}
	local result = sendTransaction(transaction)
	local sDataString = ""
	if (file~=nil or file~="") then
		local sDataString = "Отклик транзакции = "..result
	end
	for key,val in pairs(transaction) do
		sDataString = sDataString..key.."="..val.."; "
	end
	if (prevString~=nil) then
		sDataString = prevString..sDataString
	end
	WriteToEndOfFile(file,sDataString) -- пишет в лог-файл
	return 1 -- =OK
end

function CorrectPos(posNow,posNeed,emit,acc,class,file,prevString,slip)
	local vol = posNeed - posNow
	if(vol==0) then
		return 0 -- когда не скорректировали
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
			return 1 -- когда скорректировали
		end
		count = count + 1
		sleep(100)
	end
	Problem = "Проблемы с транзакцией! EPIC FAIL!"
	WriteToEndOfFile(file, Problem)
	return nil  -- когда упали
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
	    return 2 -- поступил сигнал на открытие длинной позиции LONG
	elseif (tSAR[0].close<tPRICE[0].close and tSAR[1].close>tPRICE[1].close) then
		return -2 -- поступил сигнал на открытие короткой позиции SHORT
	elseif (tSAR[1].close<tPRICE[1].close) then
		return 1 -- сигнала нет, а точки параболика и цена соотносятся так, что мы в LONG
	elseif (tSAR[1].close>tPRICE[1].close) then	
		return -1-- сигнала нет, а точки параболика и цена соотносятся так, что мы в SHORT
	end
	return 0
end

function PutDataToTable(posNow, signal) -- надо сопоставлять с PutDataToTableInit()
    SetCell(TableID, 2, 2, tostring(Emit))
    SetCell(TableID, 3, 2, tostring(posNow))
    SetCell(TableID, 4, 2, tostring(signal))
    SetCell(TableID, 5, 2, tostring(Lot))
    SetCell(TableID, 7, 2, MyAccount)
    SetCell(TableID, 8, 2, Class)
    SetCell(TableID, 9, 2, TradeType)
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
	SetCell(TableID, 9, 1, "Тип сигнала")
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
