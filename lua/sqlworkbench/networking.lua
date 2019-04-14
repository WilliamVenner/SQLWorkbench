if (SERVER) then

	for _,v in ipairs({
		"SQLWorkbench_OpenMenu",
		"SQLWorkbench_MenuClosed",
		"SQLWorkbench_MenuMinimized",
		"SQLWorkbench_NoPermission",
		
		"SQLWorkbench_GetTables",
		"SQLWorkbench_GetTableStructure",
		"SQLWorkbench_Query",
		"SQLWorkbench_QueryError",
		"SQLWorkbench_QueryNoResults",
		"SQLWorkbench_QueryResults",
		"SQLWorkbench_DeleteRow",
		"SQLWorkbench_DeleteRow_Failed",
		"SQLWorkbench_UpdateRow",
		"SQLWorkbench_UpdateRow_Failed",
		"SQLWorkbench_DeleteTable",
		"SQLWorkbench_EmptyTable",
		"SQLWorkbench_ViewSQL",

		"SQLWorkbench_No_MySQLOO",
		"SQLWorkbench_MySQL_StartConnection",
		"SQLWorkbench_MySQL_ConnectionError",
		"SQLWorkbench_MySQL_AbortConnection",
	}) do util.AddNetworkString(v) end

else
	
	net.Receive("SQLWorkbench_NoPermission", function()
		chat.AddText(Color(255,0,0), "[SQLWorkbench] ", Color(255,255,255), "You must be a super admin to access SQLWorkbench")
	end)

	net.Receive("SQLWorkbench_No_MySQLOO", function()
		Derma_Query("You do not have MySQLOO installed on your server!\nThis module must be installed before you can connect to MySQL servers", "SQLWorkbench", "Install", function()
			gui.OpenURL("https://github.com/FredyH/MySQLOO")
		end, "Dismiss")
	end)
	
	net.Receive("SQLWorkbench_DeleteRow_Failed", function()
		Derma_Message("Failed to delete row for some reason!", "SQLWorkbench", "OK")
	end)
	
	net.Receive("SQLWorkbench_UpdateRow_Failed", function()
		Derma_Message("Failed to update row for some reason!", "SQLWorkbench", "OK")
	end)
	
end