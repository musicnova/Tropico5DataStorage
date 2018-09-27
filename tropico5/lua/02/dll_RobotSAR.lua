function Body() --основная функция
	local ServerTime = getInfoParam("SERVERTIME")
	if(ServerTime==nil or ServerTime=="") then
		Problem = "Время сервера не получено!"
	else
		Problem = ""
	end
	SetCell(TableID,1,2,ServerTime)
	SetCell(TableID,1,3,Problem)
	sleep(1000)
end

function PutDataToTableInit()
	Clear(TableID)
	SetWindowPos(TableID,100,200,500,300)
	SetWindowCaption(TableID, "Робот параболик")
	-----
	InsertRow(TableID,-1)
end

