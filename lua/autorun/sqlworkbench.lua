if (SERVER and SQLWorkbench and SQLWorkbench.MySQL and SQLWorkbench.MySQL.Connections) then
	for _,connection in pairs(SQLWorkbench.MySQL.Connections) do
		connection:disconnect()
	end
end

SQLWorkbench = {}

SQLWorkbench.COLOR = {}
SQLWorkbench.COLOR.BLACK = Color(0,0,0)
SQLWorkbench.COLOR.WHITE = Color(255,255,255)
SQLWorkbench.COLOR.RED = Color(255,0,0)
SQLWorkbench.COLOR.GREEN = Color(0,255,0)
SQLWorkbench.COLOR.BLUE = Color(0,0,255)
SQLWorkbench.COLOR.YELLOW = Color(255,255,0)
SQLWorkbench.COLOR.GOLD = Color(232,150,0)
SQLWorkbench.COLOR.LIGHT_BLUE = Color(0,255,255)

SQLWorkbench.PRINT_TYPE = {}
SQLWorkbench.PRINT_TYPE.NORMAL  = 0
SQLWorkbench.PRINT_TYPE.ERROR   = 1
SQLWorkbench.PRINT_TYPE.WARNING = 2
SQLWorkbench.PRINT_TYPE.NOTICE  = 3
SQLWorkbench.PRINT_TYPE.SUCCESS = 4
function SQLWorkbench:Print(str, print_type)
	if (print_type == nil or print_type == SQLWorkbench.PRINT_TYPE.NORMAL) then
		MsgC(SQLWorkbench.COLOR.LIGHT_BLUE, "[SQLWorkbench] ", Color(255,255,255), tostring(str) .. "\n")
	elseif (print_type == SQLWorkbench.PRINT_TYPE.ERROR) then
		MsgC(SQLWorkbench.COLOR.RED, "[SQLWorkbench] [ERROR] ", Color(255,255,255), tostring(str) .. "\n")
	elseif (print_type == SQLWorkbench.PRINT_TYPE.WARNING) then
		MsgC(SQLWorkbench.COLOR.YELLOW, "[SQLWorkbench] [WARNING] ", Color(255,255,255), tostring(str) .. "\n")
	elseif (print_type == SQLWorkbench.PRINT_TYPE.NOTICE) then
		MsgC(SQLWorkbench.COLOR.LIGHT_BLUE, "[SQLWorkbench] [NOTICE] ", Color(255,255,255), tostring(str) .. "\n")
	elseif (print_type == SQLWorkbench.PRINT_TYPE.SUCCESS) then
		MsgC(SQLWorkbench.COLOR.GREEN, "[SQLWorkbench] [SUCCESS] ", Color(255,255,255), tostring(str) .. "\n")
	end
end

SQLWorkbench:Print("Starting...", SQLWorkbench.PRINT_TYPE.NOTICE)

SQLWorkbench.table_IsEmpty = table.IsEmpty or function(tbl)
	return next(tbl) == nil
end

function SQLWorkbench:Escape(str, connection, no_quotes)
	if (connection ~= nil) then
		if (no_quotes) then
			return GAS.Database.MySQLDatabase:escape(tostring(str))
		else
			return "'" .. GAS.Database.MySQLDatabase:escape(tostring(str)) .. "'"
		end
	else
		return sql.SQLStr(tostring(str), no_quotes)
	end
end

function SQLWorkbench:EscapeTable(table_name)
	return "`" .. (table_name:gsub("\\","\\\\"):gsub("`", "\\`")) .. "`"
end

if (SERVER) then
	resource.AddFile("materials/vgui/sqlworkbench.vtf")

	AddCSLuaFile("sqlworkbench/mysql.lua")
	AddCSLuaFile("sqlworkbench/menu.lua")
	AddCSLuaFile("sqlworkbench/networking.lua")

	for _,f in ipairs((file.Find("sqlworkbench/ace/*", "LUA"))) do
		AddCSLuaFile("sqlworkbench/ace/" .. f)
	end
	for _,f in ipairs((file.Find("sqlworkbench/ace/snippets/*", "LUA"))) do
		AddCSLuaFile("sqlworkbench/ace/snippets/" .. f)
	end

	include("sqlworkbench/database.lua")
end

include("sqlworkbench/mysql.lua")
include("sqlworkbench/networking.lua")
include("sqlworkbench/menu.lua")

SQLWorkbench:Print("Running!", SQLWorkbench.PRINT_TYPE.SUCCESS)
