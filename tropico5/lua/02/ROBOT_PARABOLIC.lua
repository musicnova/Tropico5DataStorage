--����� ��� �������� �� ����� �� ������� ����� �� ������ ���������� ���������
--������ 1.0

dofile(getScriptPath().."\\dll_RobotSAR.lua") -- ���� � ��������� ���������

is_run = true
Timer = 3
Problem = ""

function OnInit()
	--����� ��������
	TableID = AllocTable() -- ������� ������� ������
	AddColumn(TableID,1,"���������",true,QTABLE_STRING_TYPE,20)
	AddColumn(TableID,2,"��������",true,QTABLE_STRING_TYPE,20)
	AddColumn(TableID,3,"�����������",true,QTABLE_STRING_TYPE,30)
	CreateWindow(TableID)
	PutDataToTableInit()
	message("����� �������!",1)
end

function main()
	while is_run==true do
        Body()
	end
end

function OnTrade(TradeX)
	--�������� ��� ��������� ����� ������
end

function OnOrder(OrderX)
	--�������� ��� ��������� ������ � �����
end

function OnStopOrder()
	--�������� ��� ��������� ����-������
end

function OnStop()
	--�������� ��� ������� �� "����������"
	is_run = false
end
