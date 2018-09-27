function Body() --основная функция
	local ServerTime = getInfoParam("SERVERTIME")
	if(ServerTime==nil or ServerTime=="") then
		Problem = "Время сервера не получено!"
	else
		Problem = ""
	end
	SetCell(TableID,1,2,ServerTime)
	SetCell(TableID,1,3,Problem)
	PrintDbgStr(ServerTime.."\n"..tostring(count).."\n")
	count = count + 1
	sleep(1000)
end

function PutDataToTableInit()
	Clear(TableID)
	SetWindowPos(TableID,100,200,500,300)
	SetWindowCaption(TableID, "Робот параболик")
	-----
	InsertRow(TableID,-1)
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
