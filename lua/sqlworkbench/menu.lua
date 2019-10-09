-- I wish Lua had Regex...
function SQLWorkbench:GetTableNameFromSQL(query, sqlite)
	local columns, tbl_name
	local a,b = query:match("^[sS][eE][lL][eE][cC][tT]%s+(.-)%s+[fF][rR][oO][mM]%s+(.-) ")
	columns, tbl_name = a, b
	if (b == nil) then
		local a,b = query:match("^[sS][eE][lL][eE][cC][tT]%s+(.-)%s+[fF][rR][oO][mM]%s+(.+)$")
		if (b ~= nil) then
			columns, tbl_name = a, b
		end
	end

	if (columns ~= nil and tbl_name ~= nil) then
		if (columns ~= "*") then
			local open_str_char
			local open_func = false
			local open_func_str_char
			local open_func_comma = false
			local open_func_just_opened = false
			for i=1,#columns do
				local char = columns[i]
				--print(char, open_str_char, open_func, open_func_str_char, open_func_comma, open_func_just_opened)
				if (char == " ") then continue end
				if (open_str_char == nil) then
					if (char == "`" or (sqlite and (char == "'" or char == '"'))) then
						open_str_char = char
					elseif (char == ",") then
						return
					else
						open_str_char = false
					end
				elseif (open_func) then
					if (open_func_str_char == nil) then
						if (char == ",") then
							if (open_func_just_opened) then
								return
							else
								open_func_comma = true
							end
						elseif (char == "`" or char == "'" or char == '"') then
							open_func_str_char = char
							open_func_comma = false
						elseif (char == ")") then
							if (open_func_comma) then return end
							open_func = false
						end
					else
						if (char == open_func_str_char) then
							open_func_str_char = nil
						end
					end
					open_func_just_opened = false
				elseif (open_str_char == true or open_str_char == false) then
					if (char == "(") then
						open_func = true
						open_func_just_opened = true
					elseif (char == ",") then
						if (open_str_char == false and (columns[i - 1] == "`" or columns[i - 1] == "'" or columns[i - 1] == '"')) then return end
						open_str_char = nil
					end
				elseif (char == open_str_char) then
					if (columns[i - 1] == "`" or columns[i - 1] == "'" or columns[i - 1] == '"') then return end
					open_str_char = true
				end
				if (i == #columns and (char == "," or (open_str_char == false and (char == "`" or char == "'" or char == '"')))) then return end
			end
		end
		
		local f,l = tbl_name:sub(1,1), tbl_name:sub(-1,-1)
		if (f == "`" or (sqlite and (f == "'" or f == '"'))) then
			if (f ~= l) then
				return
			else
				return tbl_name:sub(2,-2), columns ~= "*"
			end
		elseif (not sqlite and (f == "'" or f == '"')) then
			return
		else
			return tbl_name, columns ~= "*"
		end
	end
end

--[[
function SQLWorkbench:TestGetTableNameFromSQL()
	-- tests the above algorithm
	local tests = {
		SQLWorkbench:GetTableNameFromSQL("SELECT * FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT * FROM `jeff`") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT * FROM 'jeff'") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT * FROM \"jeff\"") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT * FROM 'jeff'", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT * FROM \"jeff\"", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT ,`column` FROM jeff") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column` FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT `column` FROM `jeff`") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column' FROM `jeff`") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column' FROM `jeff`") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column` FROM 'jeff'") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column` FROM \"jeff\"") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column' FROM jeff") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT \"column\" FROM jeff") == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, `column` FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP(`column`) FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(`column`), `column` FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP('column'), `column` FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(\"column\"), `column` FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP('column') FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP(\"column\") FROM jeff") == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP('column'), `column` FROM jeff", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(\"column\"), `column` FROM jeff", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(\"column\",), `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(,\"column\"), `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(,`column`), `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(,'column'), `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(\"column\", `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP(`column`, `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT UNIX_TIMESTAMP('column', `column` FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP(\"column\", FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP(`column`, FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP('column', FROM jeff", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP('column') FROM jeff", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, UNIX_TIMESTAMP(\"column\") FROM jeff", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT `column`, 'column', \"column\" FROM jeff", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column', \"column\", `column` FROM jeff", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column', \"column\", `column` FROM `jeff`", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column', \"column\", `column` FROM 'jeff'", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("SELECT 'column', \"column\", `column` FROM \"jeff\"", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("select 'column', \"column\", `column` from \"jeff\"", true) == "jeff",
		SQLWorkbench:GetTableNameFromSQL("select 'column', \"column\", `column` from \"JEFF\"", true) == "JEFF",
		SQLWorkbench:GetTableNameFromSQL("select 'column', from \"JEFF\"", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("select         'column',         from \"JEFF\"", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("select         'column'         from \"JEFF\"", true) == "JEFF",
		SQLWorkbench:GetTableNameFromSQL("select         'column',    \"column\",    `column`    from       \"JEFF\"       ", true) == "JEFF",
		SQLWorkbench:GetTableNameFromSQL("select         'column',    \"column\",   , `column`    from       \"JEFF\"       ", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("select         'column',    \"column\",    `column`    ,from       \"JEFF\"       ", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("select         'column',    \"column\",    `column`    ,from       \"JEFF\"  ,     ", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("select         'column',    \"column\",    `column`    ,from       JEFF  ,     ", true) == nil,
		SQLWorkbench:GetTableNameFromSQL("select         'column',    \"column\",    `column`    from       JEFF       ", true) == "JEFF",
		SQLWorkbench:GetTableNameFromSQL("SELECT `id`, strftime('%s', `last_updated`) FROM `gas_servers` LIMIT 60") == "gas_servers",
	}
	for i,v in ipairs(tests) do
		if (v) then
			print(i .. ": passed")
		else
			print(i .. ": failed")
		end
	end
end
]]

if (SERVER) then

	SQLWorkbench.PlayersUsingMenu = {}
	net.Receive("SQLWorkbench_MenuClosed", function(_, ply)
		SQLWorkbench.PlayersUsingMenu[ply] = nil
		if (SQLWorkbench.MySQL.Connections[ply] ~= nil) then
			for _,conn in pairs(SQLWorkbench.MySQL.Connections[ply]) do
				local connection = conn[1]
				if (connection ~= nil and connection:status() ~= mysqloo.DATABASE_NOT_CONNECTED) then
					connection:disconnect()
				end
			end
			SQLWorkbench.MySQL.Connections[ply] = nil
		end
	end)
	net.Receive("SQLWorkbench_MenuMinimized", function(_, ply)
		SQLWorkbench.PlayersUsingMenu[ply] = nil
	end)
	function SQLWorkbench:IsPlayerUsingMenu(ply)
		return IsValid(ply) and SQLWorkbench.PlayersUsingMenu[ply] == true
	end

	function SQLWorkbench:OpenMenu(ply)
		if (not ply:IsSuperAdmin()) then return false end

		SQLWorkbench.PlayersUsingMenu[ply] = true

		net.Start("SQLWorkbench_OpenMenu")
		net.Send(ply)

		return true
	end

	net.Receive("SQLWorkbench_OpenMenu", function(_, ply)
		if (not SQLWorkbench:OpenMenu(ply)) then
			net.Start("SQLWorkbench_NoPermission")
			net.Send(ply)
		end
	end)

	hook.Add("PlayerSay", "SQLWorkbench_ChatCommand", function(ply, txt)
		if (string.Trim(txt:lower()) == "!sqlworkbench") then
			if (not SQLWorkbench:OpenMenu(ply)) then
				net.Start("SQLWorkbench_NoPermission")
				net.Send(ply)
			end
			return ""
		end
	end)

else

	concommand.Add("sqlworkbench", function()
		net.Start("SQLWorkbench_OpenMenu")
		net.SendToServer()
	end, nil, "SQLWorkbench - in-game SQLite and MySQL database viewer")

	if (IsValid(SQLWorkbench.Menu)) then
		SQLWorkbench.Menu:Close()
	end

	function SQLWorkbench:QueryTimestamp(QueryTime)
		if (QueryTime >= 60000) then
			return "[" .. QueryTime / 60000 .. " mins]"
		elseif (QueryTime >= 1000) then
			return "[" .. QueryTime / 1000 .. "s]"
		else
			return "[" .. QueryTime .. "ms]"
		end
	end

	SQLWorkbench.ConnectionPanels = {}

	local BodyFont = "Tahoma"
	if (system.IsOSX()) then BodyFont = "Helvetica" end

	surface.CreateFont("SQLWorkbench_Body", {
		font = BodyFont,
		size = 14
	})

	surface.CreateFont("SQLWorkbench_Body_Small", {
		font = BodyFont,
		size = 13
	})

	surface.CreateFont("SQLWorkbench_Body_VerySmall", {
		font = BodyFont,
		size = 12
	})

	local SQLFont = "Consolas"
	if (system.IsOSX()) then BodyFont = "Monaco" end

	surface.CreateFont("SQLWorkbench_SQLFont", {
		font = SQLFont,
		size = 14
	})

	surface.CreateFont("SQLWorkbench_Warning", {
		font = BodyFont,
		weight = 700,
		size = 13
	})

	local LogoMat = Material("vgui/sqlworkbench.vtf")
	
	net.Receive("SQLWorkbench_OpenMenu", function()
		if (IsValid(SQLWorkbench.Menu)) then
			SQLWorkbench.Menu:SetVisible(true)
			return
		end

		local embed = hook.Run("SQLWorkbench.Embed")
		if (IsValid(embed)) then
			SQLWorkbench.Menu = vgui.Create("DFrame", embed)
			SQLWorkbench.Menu:Dock(FILL)
			SQLWorkbench.Menu:SetDraggable(false)
			SQLWorkbench.Menu:ShowCloseButton(false)
		else
			SQLWorkbench.Menu = vgui.Create("DFrame")
			SQLWorkbench.Menu:SetSize(math.min(1000, ScrW()), math.min(700, ScrH()))
			SQLWorkbench.Menu:Center()
			SQLWorkbench.Menu:MakePopup()
		end
		SQLWorkbench.Menu:SetTitle("SQLWorkbench")
		SQLWorkbench.Menu:SetIcon("icon16/database.png")

		SQLWorkbench.Menu.btnMinim:SetDisabled(false)
		function SQLWorkbench.Menu.btnMinim:DoClick()
			net.Start("SQLWorkbench_MenuMinimized")
			net.SendToServer()
			SQLWorkbench.Menu:SetVisible(false)
		end

		function SQLWorkbench.Menu:OnClose()
			net.Start("SQLWorkbench_MenuClosed")
			net.SendToServer()
		end

		SQLWorkbench.Menu.Tabs = vgui.Create("DPropertySheet", SQLWorkbench.Menu)
		SQLWorkbench.Menu.Tabs:Dock(FILL)
		SQLWorkbench.Menu.Tabs:SetupCloseButton(function()
			local tab = SQLWorkbench.Menu.Tabs:GetActiveTab()
			local connection_id = tab.connection_id
			if (connection_id ~= nil and connection_id ~= 0) then
				Derma_Query("Are you sure you want to close this connection?", "SQLWorkbench", "Yes", function()
					SQLWorkbench.Menu.Tabs:SetActiveTab(SQLWorkbench.Menu.Tabs:GetItems()[1].Tab)
					SQLWorkbench.Menu.Tabs:CloseTab(tab, true)
					SQLWorkbench.ConnectionPanels[connection_id] = nil

					net.Start("SQLWorkbench_MySQL_AbortConnection")
						net.WriteUInt(connection_id, 16)
					net.SendToServer()
				end, "Cancel")
			end
		end)
		SQLWorkbench.Menu.Tabs.CloseButton:SetVisible(false)
		function SQLWorkbench.Menu.Tabs:OnActiveTabChanged(old, new)
			if (new.connection_id == nil or new.connection_id == 0) then
				self.CloseButton:SetVisible(false)
			else
				self.CloseButton:SetVisible(true)
			end
		end

		function SQLWorkbench.Menu.Tabs:CreateConnection(host, connection_id)
			local ConnectionPanel = vgui.Create("DPanel", SQLWorkbench.Menu)
			ConnectionPanel.Paint = nil
			SQLWorkbench.ConnectionPanels[connection_id] = ConnectionPanel

			ConnectionPanel.HorizDivider = vgui.Create("DHorizontalDivider", ConnectionPanel)
			ConnectionPanel.HorizDivider:Dock(FILL)
			ConnectionPanel.HorizDivider:SetLeftMin(225)
			ConnectionPanel.HorizDivider:SetDividerWidth(10)

			ConnectionPanel.TablesContainer = vgui.Create("DPanel", ConnectionPanel.HorizDivider)
			ConnectionPanel.HorizDivider:SetLeft(ConnectionPanel.TablesContainer)

			ConnectionPanel.RefreshTables = vgui.Create("DButton", ConnectionPanel.TablesContainer)
			ConnectionPanel.RefreshTables:SetText("Refresh Tables")
			ConnectionPanel.RefreshTables:SetIcon("icon16/arrow_refresh.png")
			ConnectionPanel.RefreshTables:Dock(TOP)
			ConnectionPanel.RefreshTables:SetTall(25)
			ConnectionPanel.RefreshTables:SetDisabled(true)
			function ConnectionPanel.RefreshTables:DoClick()
				self:SetDisabled(true)
				ConnectionPanel.Tables:Clear()
				net.Start("SQLWorkbench_GetTables")
					net.WriteUInt(connection_id, 16)
				net.SendToServer()
			end

			ConnectionPanel.Tables = vgui.Create("DTree", ConnectionPanel.TablesContainer)
			ConnectionPanel.Tables:Dock(FILL)
			ConnectionPanel.Tables:DockMargin(-19, 0, 0, 0)
			ConnectionPanel.Tables.NodeDictionary = {}
			ConnectionPanel.Tables.PrimaryKeys = {}
			ConnectionPanel.Tables.Structures = {}
			function ConnectionPanel.Tables:SetActiveTable(active_tbl, specific_columns)
				self.ActiveTable = active_tbl
				self.ActiveTable_WithSpecificColumns = specific_columns or false
				if (IsValid(ConnectionPanel.Tables:GetSelectedItem())) then
					ConnectionPanel.Tables:GetSelectedItem():SetSelected(false)
				end
				if (active_tbl ~= nil and IsValid(ConnectionPanel.Tables.NodeDictionary[active_tbl])) then
					ConnectionPanel.Tables.NodeDictionary[active_tbl]:SetSelected(true)
				end
			end
			function ConnectionPanel.Tables:OnNodeSelected(node)
				ConnectionPanel.DataContainer:SetSQLQuery("SELECT * FROM `" .. node:GetText() .. "` LIMIT 60")
				ConnectionPanel.DataContainer.ExecuteQuery:DoClick()
			end
			net.Start("SQLWorkbench_GetTables")
				net.WriteUInt(connection_id, 16)
			net.SendToServer()

			ConnectionPanel.DatabaseView = vgui.Create("DVerticalDivider", ConnectionPanel.HorizDivider)
			ConnectionPanel.DatabaseView:SetTopMin(200)
			ConnectionPanel.HorizDivider:SetRight(ConnectionPanel.DatabaseView)

			ConnectionPanel.DataContainer = vgui.Create("DPanel", ConnectionPanel.DatabaseView)
			ConnectionPanel.DataContainer.Paint = nil
			ConnectionPanel.DatabaseView:SetTop(ConnectionPanel.DataContainer)

			ConnectionPanel.DataContainer.InfoLabelContainer = vgui.Create("DPanel", ConnectionPanel.DataContainer)
			ConnectionPanel.DataContainer.InfoLabelContainer:Dock(TOP)
			ConnectionPanel.DataContainer.InfoLabelContainer:SetTall(25)
			function ConnectionPanel.DataContainer.InfoLabelContainer:Paint(w,h)
				surface.SetDrawColor(24,25,21)
				surface.DrawRect(0,0,w,h)
			end

			ConnectionPanel.DataContainer.InfoLabel = vgui.Create("DLabel", ConnectionPanel.DataContainer.InfoLabelContainer)
			ConnectionPanel.DataContainer.InfoLabel:Dock(FILL)
			ConnectionPanel.DataContainer.InfoLabel:SetContentAlignment(5)
			ConnectionPanel.DataContainer.InfoLabel:DockMargin(2,2,2,2)
			ConnectionPanel.DataContainer.InfoLabel:SetText("Waiting for query...")
			ConnectionPanel.DataContainer.InfoLabel:SetFont("SQLWorkbench_SQLFont")
			ConnectionPanel.DataContainer.InfoLabel:SetTextColor(SQLWorkbench.COLOR.GREEN)

			function ConnectionPanel.DataContainer:GetSQLQuery(callback)
				if (ConnectionPanel.DataContainer.QueryBoxHTML:IsVisible()) then
					ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "ReturnSQLQuery", function(SQLQuery)
						callback(SQLQuery)
					end)
					ConnectionPanel.DataContainer.QueryBoxHTML:RunJavascript("gmod.ReturnSQLQuery(query_box.getValue())")
				else
					callback(ConnectionPanel.DataContainer.QueryBox:GetValue())
				end
			end

			function ConnectionPanel.DataContainer:SetSQLQuery(SQLQuery)
				ConnectionPanel.DataContainer.QueryBoxHTML:RunJavascript("gmod.SetSQLQuery(" .. util.TableToJSON({SQLQuery}):sub(2,-2) .. ")")
			end

			local function QueryBoxFocused(self, gained)
				ConnectionPanel.DataContainer.ExecuteQuery:MoveToAfter(self)
				ConnectionPanel.DataContainer.ModeSwitch:MoveToAfter(self)
				ConnectionPanel.DataContainer.Beautify:MoveToAfter(self)
			end

			local function QueryBoxAllowInput(self, char)
				local binding = input.LookupKeyBinding(input.GetKeyCode(char))
				if (binding == "toggleconsole") then
					gui.HideGameUI()
				end
			end

			ConnectionPanel.DataContainer.QueryBoxHTML = vgui.Create("DHTML", ConnectionPanel.DataContainer)
			ConnectionPanel.DataContainer.QueryBoxHTML:Dock(FILL)
			ConnectionPanel.DataContainer.QueryBoxHTML:SetTall(150)
			ConnectionPanel.DataContainer.QueryBoxHTML.OnFocusChanged = QueryBoxFocused
			function ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript(f)
				return include("sqlworkbench/ace/" .. f .. ".lua")
			end
			ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "VerticalScrollbarVisible", function(visible)
				ConnectionPanel.DataContainer.QueryBoxHTML.VerticalScrollbarVisible = visible or nil
				ConnectionPanel.DataContainer:InvalidateLayout(true)
			end)
			ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "SuppressConsole", function(text)
				gui.HideGameUI()
			end)
			ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "DisableExecuteButton", function(disable)
				ConnectionPanel.DataContainer.ExecuteQuery:SetDisabled(disable)
			end)
			ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "SetClipboardText", function(text)
				SetClipboardText(text)
			end)
			ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "SQLBeautified", function(beautified)
				ConnectionPanel.DataContainer.QueryBox:SetValue(beautified)
			end)
			ConnectionPanel.DataContainer.QueryBoxHTML:AddFunction("gmod", "ShowContextMenu", function()
				local menu = DermaMenu()

				menu:AddOption("Cut", function()
					ConnectionPanel.DataContainer.QueryBoxHTML:RunJavascript("gmod.Cut()")
				end):SetIcon("icon16/cut_red.png")

				menu:AddOption("Copy", function()
					ConnectionPanel.DataContainer.QueryBoxHTML:RunJavascript("gmod.Copy()")
				end):SetIcon("icon16/page_copy.png")

				menu:AddOption("Paste", function()
					Derma_Message("Sorry, Lua cannot read your clipboard directly, use CTRL + V instead", "SQLWorkbench", "OK")
				end):SetIcon("icon16/page_white_paste.png")

				if (ConnectionPanel.Tables.ActiveTable ~= nil) then
					local presets, _presets = menu:AddSubMenu("Presets")
					_presets:SetIcon("icon16/wand.png")

					presets:AddOption("SELECT", function()
						local columns = ""
						for _,column in ipairs(ConnectionPanel.Tables.Structures[ConnectionPanel.Tables.ActiveTable]) do
							columns = columns .. SQLWorkbench:EscapeTable(column) .. ", "
						end
						ConnectionPanel.DataContainer:SetSQLQuery("SELECT " .. (columns:gsub(", $","")) .. " FROM " .. SQLWorkbench:EscapeTable(ConnectionPanel.Tables.ActiveTable) .. " LIMIT 60")
					end):SetIcon("icon16/magnifier.png")
					
					presets:AddOption("INSERT", function()
						local columns = ""
						local values = ""
						for _,column in ipairs(ConnectionPanel.Tables.Structures[ConnectionPanel.Tables.ActiveTable]) do
							columns = columns .. SQLWorkbench:EscapeTable(column) .. ", "
							values = values .. "'', "
						end
						ConnectionPanel.DataContainer:SetSQLQuery("INSERT INTO " .. SQLWorkbench:EscapeTable(ConnectionPanel.Tables.ActiveTable) .. " (" .. (columns:gsub(", $","")) .. ") VALUES(" .. (values:gsub(", $","")) .. ")")
					end):SetIcon("icon16/table_row_insert.png")
					
					presets:AddOption("UPDATE", function()
						ConnectionPanel.DataContainer:SetSQLQuery("UPDATE " .. SQLWorkbench:EscapeTable(ConnectionPanel.Tables.ActiveTable) .. " SET `column`='value', `column`='value' WHERE `column`='value'")
					end):SetIcon("icon16/table_refresh.png")
					
					presets:AddOption("DELETE", function()
						local columns = ""
						for _,column in ipairs(ConnectionPanel.Tables.Structures[ConnectionPanel.Tables.ActiveTable]) do
							columns = columns .. SQLWorkbench:EscapeTable(column) .. "='value', "
						end
						ConnectionPanel.DataContainer:SetSQLQuery("DELETE FROM " .. SQLWorkbench:EscapeTable(ConnectionPanel.Tables.ActiveTable) .. " WHERE " .. (columns:gsub(", $","")))
					end):SetIcon("icon16/table_row_delete.png")
				end

				menu:Open()
			end)
			ConnectionPanel.DataContainer.QueryBoxHTML:SetHTML([[
				<!DOCTYPE html>
				<html>
					<head>
						<style>
							body,html {
								width: 100%;
								height: 100%;
							}

							body {
								margin: 0;
								background-color: #fff;
							}

							#query-box {
								position: absolute;
								width: 100%;
								height: 100%;
							}
						</style>
					</head>
					<body>
						<div id="query-box" oncontextmenu="gmod.ShowContextMenu()"></div>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("ace.js.1") .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("ace.js.2") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("ext-language_tools.js") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("theme-monokai.js") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("mode-mysql.js") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("mode-sql.js") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("snippets/mysql.js") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("snippets/sql.js") .. [[</script>
						<script type="text/javascript">]] .. ConnectionPanel.DataContainer.QueryBoxHTML:GetAceScript("sql-formatter.js") .. [[</script>
						<script type="text/javascript">
							var gmod = gmod || {};
						
							var console_key = "]] .. ((input.LookupBinding("toggleconsole") or ""):gsub("\\","\\\\"):gsub("\"","\\\"")) .. [[";

							var query_box = ace.edit("query-box");
							query_box.setOptions({
								enableBasicAutocompletion: true,
								enableLiveAutocompletion: true
							});
							query_box.setTheme("ace/theme/monokai");
							query_box.setShowPrintMargin(false);
							query_box.session.setUseWrapMode(true);
							if (]] .. connection_id .. [[ === 0)
								query_box.session.setMode("ace/mode/sql");
							else
								query_box.session.setMode("ace/mode/mysql");

							var ExecuteButtonDisabled = true;
							query_box.session.on("change", function(e) {
								if (console_key.length > 0 && e.action === "insert" && e.lines.indexOf(console_key) !== -1) {
									gmod.SuppressConsole()
								}
								if (ExecuteButtonDisabled !== (query_box.session.getValue().length === 0)) {
									ExecuteButtonDisabled = !ExecuteButtonDisabled;
									gmod.DisableExecuteButton(ExecuteButtonDisabled);
								}
								window.setTimeout(function() {
									gmod.VerticalScrollbarVisible(document.getElementsByClassName("ace_scrollbar-v")[0].style.display !== "none");
								}, 50);
							});

							gmod.SetSQLQuery = function(SQLQuery) {
								query_box.session.setValue(SQLQuery);
							};

							gmod.Cut = function() {
								var full_selection = "";
								var ranges = query_box.selection.getAllRanges();
								for (var i = 0; i < ranges.length; i++) {
									var range = ranges[i];
									full_selection += query_box.session.getTextRange(range) + "\n";
									query_box.session.doc.remove(range);
								}
								gmod.SetClipboardText(full_selection.substr(0, full_selection.length - 1));
							};

							gmod.Copy = function() {
								var full_selection = "";
								var ranges = query_box.selection.getAllRanges();
								for (var i = 0; i < ranges.length; i++) full_selection += query_box.session.getTextRange(ranges[i]) + "\n";
								gmod.SetClipboardText(full_selection.substr(0, full_selection.length - 1));
							};

							gmod.Beautify = function() {
								query_box.session.setValue(sqlFormatter.format(query_box.session.getValue(), {language: "sql", indent: "    "}));
							};

							gmod.BeautifySQL = function(SQLQuery) {
								gmod.SQLBeautified(sqlFormatter.format(SQLQuery, {language: "sql", indent: "    "}));
							};
						</script>
					</body>
				</html>
			]])

			ConnectionPanel.DataContainer.QueryBox = vgui.Create("DTextEntry", ConnectionPanel.DataContainer)
			ConnectionPanel.DataContainer.QueryBox:Dock(FILL)
			ConnectionPanel.DataContainer.QueryBox:SetTall(150)
			ConnectionPanel.DataContainer.QueryBox:SetContentAlignment(7)
			ConnectionPanel.DataContainer.QueryBox:SetFont("SQLWorkbench_SQLFont")
			ConnectionPanel.DataContainer.QueryBox:SetPlaceholderText("SQL query...")
			ConnectionPanel.DataContainer.QueryBox:SetMultiline(true)
			ConnectionPanel.DataContainer.QueryBox:SetVisible(false)
			ConnectionPanel.DataContainer.QueryBox.OnFocusChanged = QueryBoxFocused
			ConnectionPanel.DataContainer.QueryBox.AllowInput = QueryBoxAllowInput
			function ConnectionPanel.DataContainer.QueryBox:OnChange()
				ConnectionPanel.DataContainer.ExecuteQuery:SetDisabled(self:GetValue() == 0)
			end

			ConnectionPanel.DataContainer.Beautify = vgui.Create("DButton", ConnectionPanel.DataContainer)
			ConnectionPanel.DataContainer.Beautify:SetIcon("icon16/wand.png")
			ConnectionPanel.DataContainer.Beautify:SetText("Beautify")
			ConnectionPanel.DataContainer.Beautify:SetSize(90, 25)
			ConnectionPanel.DataContainer.Beautify:SetContentAlignment(4)
			function ConnectionPanel.DataContainer.Beautify:DoClick()
				if (ConnectionPanel.DataContainer.QueryBox:IsVisible()) then
					ConnectionPanel.DataContainer.QueryBoxHTML:RunJavascript("gmod.BeautifySQL(" .. util.TableToJSON({ConnectionPanel.DataContainer.QueryBox:GetValue()}):sub(2,-2) .. ")")
				else
					ConnectionPanel.DataContainer.QueryBoxHTML:RunJavascript("gmod.Beautify()")
				end
			end

			ConnectionPanel.DataContainer.ModeSwitch = vgui.Create("DButton", ConnectionPanel.DataContainer)
			ConnectionPanel.DataContainer.ModeSwitch:SetIcon("icon16/style.png")
			ConnectionPanel.DataContainer.ModeSwitch:SetText("Basic Mode")
			ConnectionPanel.DataContainer.ModeSwitch:SetSize(90, 25)
			ConnectionPanel.DataContainer.ModeSwitch:SetContentAlignment(4)
			function ConnectionPanel.DataContainer.ModeSwitch:DoClick()
				if (self:GetText() == "Basic Mode") then
					ConnectionPanel.DataContainer.ModeSwitch:SetIcon("icon16/page_code.png")
					self:SetText("IDE Mode")
					ConnectionPanel.DataContainer:GetSQLQuery(function(SQLQuery)
						ConnectionPanel.DataContainer.QueryBox:SetValue(SQLQuery)
					end)
					ConnectionPanel.DataContainer.QueryBox:SetVisible(true)
					ConnectionPanel.DataContainer.QueryBoxHTML:SetVisible(false)
					ConnectionPanel.DataContainer.QueryBox:OnFocusChanged()
				else
					ConnectionPanel.DataContainer.ModeSwitch:SetIcon("icon16/style.png")
					self:SetText("Basic Mode")
					ConnectionPanel.DataContainer:SetSQLQuery(ConnectionPanel.DataContainer.QueryBox:GetValue())
					ConnectionPanel.DataContainer.QueryBox:SetVisible(false)
					ConnectionPanel.DataContainer.QueryBoxHTML:SetVisible(true)
					ConnectionPanel.DataContainer.QueryBoxHTML:OnFocusChanged()
				end
			end

			ConnectionPanel.DataContainer.ExecuteQuery = vgui.Create("DButton", ConnectionPanel.DataContainer)
			ConnectionPanel.DataContainer.ExecuteQuery:SetIcon("icon16/script.png")
			ConnectionPanel.DataContainer.ExecuteQuery:SetText("Execute")
			ConnectionPanel.DataContainer.ExecuteQuery:SetSize(90, 25)
			ConnectionPanel.DataContainer.ExecuteQuery:SetContentAlignment(4)
			ConnectionPanel.DataContainer.ExecuteQuery:SetDisabled(true)
			function ConnectionPanel.DataContainer.ExecuteQuery:DoClick()
				ConnectionPanel.DataContainer:GetSQLQuery(function(SQLQuery)
					local compressed_query = util.Compress(SQLQuery)
					if (#compressed_query + (16 / 4) > 64000) then
						Derma_Message("Even after compressing your SQL query, it's too big to send!\nThe maximum a query can be, after compression, is 64 KB.", "SQLWorkbench", "OK")				
						return
					end

					local active_tbl, specific_columns = SQLWorkbench:GetTableNameFromSQL(SQLQuery)
					ConnectionPanel.Tables:SetActiveTable(active_tbl, specific_columns)
					if (active_tbl ~= nil) then
						net.Start("SQLWorkbench_GetTableStructure")
							net.WriteUInt(connection_id, 16)
							net.WriteString(active_tbl)
						net.SendToServer()
					end

					ConnectionPanel.RefreshTables.RefreshAfterQuery = (SQLQuery:find("CREATE TABLE") ~= nil) or nil

					ConnectionPanel.DataContainer.InfoLabel:SetText("Executing query...")
					self:SetDisabled(true)
					ConnectionPanel.DataContainer.QueryBox:SetDisabled(true)
					ConnectionPanel.DataContainer.DataTable:Clear()

					net.Start("SQLWorkbench_Query")
						net.WriteUInt(connection_id, 16)
						net.WriteData(compressed_query, #compressed_query)
					net.SendToServer()
				end)
			end

			ConnectionPanel.DataContainer.DataTable = vgui.Create("DListView", ConnectionPanel.DatabaseView)
			ConnectionPanel.DatabaseView:SetBottom(ConnectionPanel.DataContainer.DataTable)
			function ConnectionPanel.DataContainer.DataTable:SetSQLColumns(sql_tbl)
				if (ConnectionPanel.Tables.PrimaryKeys[sql_tbl] ~= nil and not SQLWorkbench.table_IsEmpty(ConnectionPanel.Tables.PrimaryKeys[sql_tbl])) then
					local primary_keys = ConnectionPanel.Tables.PrimaryKeys[sql_tbl]
					for _,column in ipairs(ConnectionPanel.Tables.Structures[sql_tbl]) do
						local col = self:AddColumn(column)
						if (primary_keys[column]) then
							col.Header:SetTextColor(SQLWorkbench.COLOR.GOLD)
						end
					end
				else
					for _,column in ipairs(ConnectionPanel.Tables.Structures[sql_tbl]) do
						self:AddColumn(column)
					end
				end
			end
			function ConnectionPanel.DataContainer.DataTable:OnRowRightClick(row_id, row)
				local menu = DermaMenu()

				if (#self:GetSelected() == 1) then
					local view, _view = menu:AddSubMenu("View")
					_view:SetIcon("icon16/magnifier.png")
					for i,column in ipairs(self.Columns) do
						view:AddOption(column.Header:GetText(), function()
							Derma_StringRequest("SQLWorkbench", column.Header:GetText(), row.Columns[i]:GetText(), function(str)
								SetClipboardText(str)
							end, nil, "Copy", "Dismiss")
						end):SetIcon("icon16/table.png")
					end
				end

				if (ConnectionPanel.Tables.ActiveTable ~= nil and ConnectionPanel.Tables.PrimaryKeys[ConnectionPanel.Tables.ActiveTable] ~= nil and not SQLWorkbench.table_IsEmpty(ConnectionPanel.Tables.PrimaryKeys[ConnectionPanel.Tables.ActiveTable])) then
					if (#self:GetSelected() == 1) then
						local update, _update = menu:AddSubMenu("Update")
						_update:SetIcon("icon16/wand.png")
						for i,column in ipairs(self.Columns) do
							update:AddOption(column.Header:GetText(), function()
								Derma_StringRequest("SQLWorkbench", column.Header:GetText(), row.Columns[i]:GetText(), function(str)
									local data = {
										table = ConnectionPanel.Tables.ActiveTable,
										data = {
											[column.Header:GetText()] = str
										},
										constraints = {}
									}
									for i,column in pairs(self.Columns) do
										if (not ConnectionPanel.Tables.PrimaryKeys[ConnectionPanel.Tables.ActiveTable][column.Header:GetText()]) then continue end
										data.constraints[column.Header:GetText()] = row.Columns[i]:GetText()
									end
									data = util.Compress(util.TableToJSON(data))
									net.Start("SQLWorkbench_UpdateRow")
										net.WriteUInt(connection_id, 16)
										net.WriteData(data, #data)
									net.SendToServer()
									row.Columns[i]:SetText(str)
									self:InvalidateLayout()
								end, nil, "Update", "Cancel")
							end):SetIcon("icon16/table.png")
						end
					end

					menu:AddOption("Delete", function()
						for _,row in ipairs(self:GetSelected()) do
							local data = {
								table = ConnectionPanel.Tables.ActiveTable,
								data = {}
							}
							for i,column in pairs(self.Columns) do
								if (not ConnectionPanel.Tables.PrimaryKeys[ConnectionPanel.Tables.ActiveTable][column.Header:GetText()]) then continue end
								data.data[column.Header:GetText()] = row.Columns[i]:GetText()
							end
							data = util.Compress(util.TableToJSON(data))
							net.Start("SQLWorkbench_DeleteRow")
								net.WriteUInt(connection_id, 16)
								net.WriteData(data, #data)
							net.SendToServer()
							self:RemoveLine(row:GetID())
						end
					end):SetIcon("icon16/delete.png")
				else
					local function no_pk_msg()
						Derma_Message("The primary keys of this table could not be found, or SQLWorkbench\nwas unable to determine what table your query is selecting.", "SQLWorkbench", "OK")
					end
					if (#self:GetSelected() == 1) then menu:AddOption("Update", no_pk_msg):SetIcon("icon16/error.png") end
					menu:AddOption("Delete", no_pk_msg):SetIcon("icon16/error.png")
				end

				menu:Open()
			end

			function ConnectionPanel.DataContainer:PerformLayout()
				self.Beautify:AlignBottom(5 + self.ExecuteQuery:GetTall() + 5 + self.ModeSwitch:GetTall() + 5)
				self.ModeSwitch:AlignBottom(5 + self.ExecuteQuery:GetTall() + 5)
				self.ExecuteQuery:AlignBottom(5)

				local v_scrollbar = 0
				if (ConnectionPanel.DataContainer.QueryBoxHTML:IsVisible() and ConnectionPanel.DataContainer.QueryBoxHTML.VerticalScrollbarVisible) then
					v_scrollbar = 17
				end
				self.Beautify:AlignRight(5 + v_scrollbar)
				self.ModeSwitch:AlignRight(5 + v_scrollbar)
				self.ExecuteQuery:AlignRight(5 + v_scrollbar)
			end

			local icon = "icon16/database_connect.png"
			if (connection_id == 0) then icon = "icon16/database.png" end

			local ConnectionPanelTabData = SQLWorkbench.Menu.Tabs:AddSheet(host, ConnectionPanel, icon)
			local ConnectionPanelTab = ConnectionPanelTabData.Tab
			ConnectionPanelTab.connection_id = connection_id
			if (connection_id ~= 0) then SQLWorkbench.Menu.Tabs:SetActiveTab(ConnectionPanelTab) end
		end

			SQLWorkbench.Menu.Tabs.NewConnection = vgui.Create("DPanel", SQLWorkbench.Menu)
			SQLWorkbench.Menu.Tabs:AddSheet("+ New Connection", SQLWorkbench.Menu.Tabs.NewConnection, "icon16/wand.png")

				SQLWorkbench.Menu.Tabs.NewConnection.GitHub = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection)
				SQLWorkbench.Menu.Tabs.NewConnection.GitHub:SetText("GitHub")
				SQLWorkbench.Menu.Tabs.NewConnection.GitHub:SizeToContents()
				SQLWorkbench.Menu.Tabs.NewConnection.GitHub:SetTextColor(Color(0,140,255))
				SQLWorkbench.Menu.Tabs.NewConnection.GitHub:SetMouseInputEnabled(true)
				SQLWorkbench.Menu.Tabs.NewConnection.GitHub:SetCursor("hand")
				function SQLWorkbench.Menu.Tabs.NewConnection.GitHub:DoClick()
					gui.OpenURL("https://github.com/WilliamVenner/SQLWorkbench")
				end

				SQLWorkbench.Menu.Tabs.NewConnection.Copyright = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection)
				SQLWorkbench.Menu.Tabs.NewConnection.Copyright:SetText("© " .. os.date("%Y") .. " William Venner")
				SQLWorkbench.Menu.Tabs.NewConnection.Copyright:SizeToContents()
				SQLWorkbench.Menu.Tabs.NewConnection.Copyright:SetTextColor(SQLWorkbench.COLOR.BLACK)

				SQLWorkbench.Menu.Tabs.NewConnection.GitHubStar = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection)
				SQLWorkbench.Menu.Tabs.NewConnection.GitHubStar:SetText("If this tool helped you, please give it a star on GitHub!")
				SQLWorkbench.Menu.Tabs.NewConnection.GitHubStar:SizeToContents()
				SQLWorkbench.Menu.Tabs.NewConnection.GitHubStar:SetTextColor(SQLWorkbench.COLOR.BLACK)

				SQLWorkbench.Menu.Tabs.NewConnection.Form = vgui.Create("DPanel", SQLWorkbench.Menu.Tabs.NewConnection)
				SQLWorkbench.Menu.Tabs.NewConnection.Form.Paint = nil
				SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems = {}
				SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems = {}
				SQLWorkbench.Menu.Tabs.NewConnection.Form.Items = SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo = vgui.Create("DImage", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo:SetMaterial(LogoMat)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo:SetSize(256,256)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo:DockMargin(0, -44, 0, 0)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Logo)
					
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:SetFont("SQLWorkbench_Body")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:SetText("Host")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:SetTextColor(SQLWorkbench.COLOR.BLACK)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:SetContentAlignment(4)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:SizeToContents()
					SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel:DockMargin(0, -44 + 20, 0, 5)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.HostLabel)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Host = vgui.Create("DTextEntry", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:SetPlaceholderText((game.GetIPAddress():gsub(":%d+$","")))
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:OnChange()
						SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:VerifyForm()
					end
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:OnValueChange(val)
						local port = val:match(":(%d+)$")
						if (port ~= nil) then
							self:SetText((val:gsub(":%d+$","")))
							SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:SetValue(port)
						end
					end
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:OnFocusChanged(gained)
						if (not gained) then
							self:OnValueChange(self:GetValue())
						end
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Host)
					
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:SetFont("SQLWorkbench_Body")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:SetText("Username")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:SetTextColor(SQLWorkbench.COLOR.BLACK)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:SetContentAlignment(4)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:SizeToContents()
					SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel:DockMargin(0, 0, 0, 5)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.UsernameLabel)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Username = vgui.Create("DTextEntry", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:SetPlaceholderText("Billy")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:OnChange()
						SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:VerifyForm()
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Username)
					
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:SetFont("SQLWorkbench_Body")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:SetText("Password")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:SetTextColor(SQLWorkbench.COLOR.BLACK)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:SetContentAlignment(4)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:SizeToContents()
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel:DockMargin(0, 0, 0, 5)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordLabel)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Password = vgui.Create("DTextEntry", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:SetPlaceholderText("qwerty123")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:OnChange()
						SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:VerifyForm()
					end
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:PaintOver(w,h)
						if (not self:IsHovered()) then
							surface.SetDrawColor(SQLWorkbench.COLOR.BLACK)
							surface.DrawRect(2,2,w-4,h-4)
							draw.SimpleText("Hover to show", "SQLWorkbench_Body_VerySmall", w / 2, h / 2, SQLWorkbench.COLOR.WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Password)
					
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:SetFont("SQLWorkbench_Body")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:SetText("Database")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:SetTextColor(SQLWorkbench.COLOR.BLACK)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:SetContentAlignment(4)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:SizeToContents()
					SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel:DockMargin(0, 0, 0, 5)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.DatabaseLabel)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Database = vgui.Create("DTextEntry", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:SetPlaceholderText("darkrp")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:OnChange()
						SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:VerifyForm()
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Database)
					
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:SetFont("SQLWorkbench_Body")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:SetText("Port")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:SetTextColor(SQLWorkbench.COLOR.BLACK)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:SetContentAlignment(4)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:SizeToContents()
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel:DockMargin(0, 0, 0, 5)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.PortLabel)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Port = vgui.Create("DTextEntry", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:SetValue(3306)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:SetPlaceholderText("3306")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:AllowInput(char)
						return tonumber(char) == nil
					end
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:OnChange()
						local val = self:GetValue()
						if (val ~= "" and (not tonumber(val) or tonumber(val) > 65535 or tonumber(val) % 1 ~= 0)) then
							self:SetText(self._val or "3306")
						else
							self._val = val
							SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:VerifyForm()
						end
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.Port)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect = vgui.Create("DButton", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:SetIcon("icon16/connect.png")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:SetText("Connect")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:SetDisabled(true)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:VerifyForm()
						self:SetDisabled(not (
							#SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:GetValue() > 0 and
							#SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:GetValue() > 0 and
							#SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:GetValue() > 0 and
							tonumber(SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:GetValue()) and
							tonumber(SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:GetValue()) < 65535 and
							tonumber(SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:GetValue()) % 1 == 0
						))
					end
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect:DoClick()
						SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar.Started = SysTime()
						
						local host = SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:GetValue()
						SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting.client_connection_id = SQLWorkbench.MySQL:StartConnection(
							SQLWorkbench.Menu.Tabs.NewConnection.Form.Host:GetValue(),
							SQLWorkbench.Menu.Tabs.NewConnection.Form.Username:GetValue(),
							SQLWorkbench.Menu.Tabs.NewConnection.Form.Password:GetValue(),
							SQLWorkbench.Menu.Tabs.NewConnection.Form.Database:GetValue(),
							tonumber(SQLWorkbench.Menu.Tabs.NewConnection.Form.Port:GetValue()),

							function(connection_id, err)
								if (err ~= nil) then
									Derma_Message("Failed to connect to MySQL server! Error:\n\n" .. err, "SQLWorkbench", "OK")
								end

								for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(false) end
								SQLWorkbench.Menu.Tabs.NewConnection.Form.Items = SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems
								for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(true) end
								SQLWorkbench.Menu.Tabs.NewConnection.Form._w, SQLWorkbench.Menu.Tabs.NewConnection.Form._h = nil, nil
								SQLWorkbench.Menu.Tabs.NewConnection.Form:InvalidateLayout(true)

								if (connection_id ~= nil) then
									SQLWorkbench.Menu.Tabs.NewConnection.Form:Reset()
									SQLWorkbench.Menu.Tabs:CreateConnection(host, connection_id)
								end
							end
						)

						for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(false) end
						SQLWorkbench.Menu.Tabs.NewConnection.Form.Items = SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems
						for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(true) end
						SQLWorkbench.Menu.Tabs.NewConnection.Form._w, SQLWorkbench.Menu.Tabs.NewConnection.Form._h = nil, nil
						SQLWorkbench.Menu.Tabs.NewConnection.Form:InvalidateLayout(true)
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items, SQLWorkbench.Menu.Tabs.NewConnection.Form.Connect)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:SetTextColor(SQLWorkbench.COLOR.RED)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:SetWrap(true)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:SetFont("SQLWorkbench_Warning")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:SetText("WARNING: Your password is very weakly encrypted before being sent through the Internet, and can be easily decrypted by an attacker!")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:SetAutoStretchVertical(true)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning:PerformLayout()
						self:GetParent()._w, self:GetParent()._h = nil, nil
						self:InvalidateParent(true)
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items, SQLWorkbench.Menu.Tabs.NewConnection.Form.PasswordWarning)

					--########### LOADING ###########--

					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel = vgui.Create("DLabel", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:SetFont("SQLWorkbench_Body")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:SetText("Connecting...")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:SetTextColor(SQLWorkbench.COLOR.BLACK)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:SetContentAlignment(4)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:SizeToContents()
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel:DockMargin(0, -44 + 20, 0, 5)
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingLabel)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar = vgui.Create("DProgress", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar:DockMargin(0, 0, 0, 10)
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar:Think()
						if (not self:IsVisible() or self.Started == nil) then return end
						self:SetFraction(math.min((SysTime() - self.Started) / 2, 1))
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.ConnectingProgressBar)

					SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting = vgui.Create("DButton", SQLWorkbench.Menu.Tabs.NewConnection.Form)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting:Dock(TOP)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting:SetSize(200, 25)
					SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting:SetText("Abort")
					SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting:SetIcon("icon16/disconnect.png")
					function SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting:DoClick()
						net.Start("SQLWorkbench_MySQL_AbortConnecting")
							net.WriteUInt(self.client_connection_id, 16)
						net.SendToServer()

						for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(false) end
						SQLWorkbench.Menu.Tabs.NewConnection.Form.Items = SQLWorkbench.Menu.Tabs.NewConnection.Form.InputItems
						for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(true) end
						SQLWorkbench.Menu.Tabs.NewConnection.Form._w, SQLWorkbench.Menu.Tabs.NewConnection.Form._h = nil, nil
						SQLWorkbench.Menu.Tabs.NewConnection.Form:InvalidateLayout(true)
					end
					table.insert(SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems, SQLWorkbench.Menu.Tabs.NewConnection.Form.AbortConnecting)

				for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.LoadingItems) do v:SetVisible(false) end
				for _,v in ipairs(SQLWorkbench.Menu.Tabs.NewConnection.Form.Items) do v:SetVisible(true) end

				function SQLWorkbench.Menu.Tabs.NewConnection.Form:PerformLayout(w,h)
					if (self._w == w and self._h == h) then return end

					local prev
					local form_height = 0
					for i,v in ipairs(self.Items) do
						if (not v:IsVisible()) then continue end

						if (prev) then v:MoveToAfter(prev) end
						prev = v

						local l,t,r,b = v:GetDockMargin()
						form_height = form_height + v:GetTall() + t + b
					end
					self:SetSize(256, form_height)
					self._w, self._h = w,form_height

					self:InvalidateParent()
				end
				SQLWorkbench.Menu.Tabs.NewConnection.Form:InvalidateLayout()

				function SQLWorkbench.Menu.Tabs.NewConnection.Form:Reset()
					self.Host:SetText("")
					self.Username:SetText("")
					self.Password:SetText("")
					self.Database:SetText("")
					self.Port:SetText("3306")
					self.Connect:SetDisabled(true)
				end

			function SQLWorkbench.Menu.Tabs.NewConnection:PerformLayout()
				self.Form:Center()
				self.GitHub:AlignRight(10)
				self.GitHub:AlignBottom(10 + self.Copyright:GetTall() + 5 + self.GitHubStar:GetTall() + 5)
				self.Copyright:AlignRight(10)
				self.Copyright:AlignBottom(10 + self.GitHubStar:GetTall() + 5)
				self.GitHubStar:AlignRight(10)
				self.GitHubStar:AlignBottom(10)
			end

		SQLWorkbench.Menu.Tabs:CreateConnection("SQLite", 0)
	end)

	net.Receive("SQLWorkbench_GetTableStructure", function()
		local connection_id = net.ReadUInt(16)
		local table_name = net.ReadString()
		SQLWorkbench.ConnectionPanels[connection_id].Tables.Structures[table_name] = {}
		SQLWorkbench.ConnectionPanels[connection_id].Tables.PrimaryKeys[table_name] = {}
		for i=1,net.ReadUInt(12) do
			local column = net.ReadString()
			local pk = net.ReadBool()
			table.insert(SQLWorkbench.ConnectionPanels[connection_id].Tables.Structures[table_name], column)
			SQLWorkbench.ConnectionPanels[connection_id].Tables.PrimaryKeys[table_name][column] = pk or nil
		end
	end)

	net.Receive("SQLWorkbench_GetTables", function()
		local connection_id = net.ReadUInt(16)

		local ConnectionPanel = SQLWorkbench.ConnectionPanels[connection_id]
		if (not IsValid(ConnectionPanel)) then return end

		ConnectionPanel.Tables:Clear()
		for i=1,net.ReadUInt(12) do
			local tbl_name = net.ReadString()
			local is_empty = net.ReadBool()

			local icon = "icon16/table_add.png"
			if (is_empty) then icon = "icon16/table.png" end

			local node = ConnectionPanel.Tables:AddNode(tbl_name, icon)
			if (tbl_name == ConnectionPanel.Tables.ActiveTable) then
				ConnectionPanel.Tables:SetSelectedItem(node)
			end

			ConnectionPanel.Tables.NodeDictionary[tbl_name] = node

			function node:DoRightClick()
				local menu = DermaMenu()

				menu:AddOption("View SQL", function()
					Derma_Query("This will overwrite your current SQL query, are you sure?", "SQLWorkbench", "Yes", function()
						net.Start("SQLWorkbench_ViewSQL")
							net.WriteUInt(connection_id, 16)
							net.WriteString(tbl_name)
						net.SendToServer()
					end, "Cancel")
				end):SetIcon("icon16/table_lightning.png")
				
				menu:AddOption("Delete", function()
					Derma_Query("Are you sure you want to DELETE table `" .. tbl_name .. "`?", "SQLWorkbench", "Yes", function()
						net.Start("SQLWorkbench_DeleteTable")
							net.WriteUInt(connection_id, 16)
							net.WriteString(tbl_name)
						net.SendToServer()
						node:Remove()
					end, "Cancel")
				end):SetIcon("icon16/delete.png")

				menu:AddOption("Empty", function()
					Derma_Query("Are you sure you want to EMPTY table `" .. tbl_name .. "`?", "SQLWorkbench", "Yes", function()
						net.Start("SQLWorkbench_EmptyTable")
							net.WriteUInt(connection_id, 16)
							net.WriteString(tbl_name)
						net.SendToServer()
						node:SetIcon("icon16/table.png")
					end, "Cancel")
				end):SetIcon("icon16/bin_empty.png")

				menu:Open()
			end
		end
		ConnectionPanel.RefreshTables:SetDisabled(false)
	end)

	net.Receive("SQLWorkbench_QueryError", function()
		local connection_id = net.ReadUInt(16)
		local QueryTime = net.ReadUInt(32)
		if (not IsValid(SQLWorkbench.ConnectionPanels[connection_id])) then return end

		local err = net.ReadString()

		local ConnectionPanel = SQLWorkbench.ConnectionPanels[connection_id]
		ConnectionPanel.DataContainer.QueryBox:SetDisabled(false)
		ConnectionPanel.DataContainer.ExecuteQuery:SetDisabled(false)
		ConnectionPanel.DataContainer.Beautify:SetDisabled(false)
		ConnectionPanel.RefreshTables.RefreshAfterQuery = nil

		Derma_Message("Your SQL query threw an error! Error:\n\n" .. err, "SQLWorkbench", "OK")
		ConnectionPanel.DataContainer.InfoLabel:SetText("Query returned error " .. SQLWorkbench:QueryTimestamp(QueryTime))
	end)

	net.Receive("SQLWorkbench_QueryNoResults", function()
		local connection_id = net.ReadUInt(16)
		local QueryTime = net.ReadUInt(32)
		if (not IsValid(SQLWorkbench.ConnectionPanels[connection_id])) then return end

		local affected_rows = net.ReadUInt(16)
		local last_insert
		if (net.ReadBool()) then
			last_insert = net.ReadUInt(64)
		end

		local ConnectionPanel = SQLWorkbench.ConnectionPanels[connection_id]

		ConnectionPanel.DataContainer.QueryBox:SetDisabled(false)
		ConnectionPanel.DataContainer.ExecuteQuery:SetDisabled(false)
		ConnectionPanel.DataContainer.Beautify:SetDisabled(false)
		if (ConnectionPanel.RefreshTables.RefreshAfterQuery) then
			ConnectionPanel.RefreshTables:DoClick()
			ConnectionPanel.RefreshTables.RefreshAfterQuery = nil
		end

		local DataTable = ConnectionPanel.DataContainer.DataTable
		DataTable:Clear()
		if (ConnectionPanel.Tables.ActiveTable ~= nil) then
			for _,v in pairs(DataTable.Columns) do
				v:Remove()
			end
			DataTable.Columns = {}
			DataTable:InvalidateLayout(true)
			DataTable.pnlCanvas:InvalidateLayout(true)

			DataTable:SetSQLColumns(ConnectionPanel.Tables.ActiveTable)
		end

		if (affected_rows > 0) then
			if (last_insert) then
				ConnectionPanel.DataContainer.InfoLabel:SetText(affected_rows .. " affected row(s), last insert ID: " .. last_insert .. " " .. SQLWorkbench:QueryTimestamp(QueryTime))
			else
				ConnectionPanel.DataContainer.InfoLabel:SetText(affected_rows .. " affected row(s) " .. SQLWorkbench:QueryTimestamp(QueryTime))
			end
		elseif (last_insert) then
			ConnectionPanel.DataContainer.InfoLabel:SetText("Last insert ID: " .. last_insert .. " " .. SQLWorkbench:QueryTimestamp(QueryTime))
		else
			ConnectionPanel.DataContainer.InfoLabel:SetText("Query returned no results " .. SQLWorkbench:QueryTimestamp(QueryTime))
		end
	end)

	net.Receive("SQLWorkbench_QueryResults", function(len)
		local connection_id = net.ReadUInt(16)
		local QueryTime = net.ReadUInt(32)
		if (not IsValid(SQLWorkbench.ConnectionPanels[connection_id])) then return end
		local unserialized = util.JSONToTable(util.Decompress(net.ReadData(len - 16 - 32)))

		local ConnectionPanel = SQLWorkbench.ConnectionPanels[connection_id]

		ConnectionPanel.DataContainer.QueryBox:SetDisabled(false)
		ConnectionPanel.DataContainer.ExecuteQuery:SetDisabled(false)
		ConnectionPanel.DataContainer.Beautify:SetDisabled(false)
		ConnectionPanel.RefreshTables.RefreshAfterQuery = nil

		local DataTable = ConnectionPanel.DataContainer.DataTable
		DataTable:Clear()
		for _,v in pairs(DataTable.Columns) do
			v:Remove()
		end
		DataTable.Columns = {}
		DataTable:InvalidateLayout(true)
		DataTable.pnlCanvas:InvalidateLayout(true)

		ConnectionPanel.DataContainer.InfoLabel:SetText("Query returned " .. #unserialized .. " row(s) " .. SQLWorkbench:QueryTimestamp(QueryTime))

		if (ConnectionPanel.Tables.ActiveTable_WithSpecificColumns ~= true and ConnectionPanel.Tables.ActiveTable ~= nil and ConnectionPanel.Tables.Structures[ConnectionPanel.Tables.ActiveTable] ~= nil) then
			DataTable:SetSQLColumns(ConnectionPanel.Tables.ActiveTable)
			for _,row in ipairs(unserialized) do
				local row_items = {}
				for _,column in ipairs(ConnectionPanel.Tables.Structures[ConnectionPanel.Tables.ActiveTable]) do
					row_items[#row_items + 1] = row[column]
				end
				DataTable:AddLine(unpack(row_items))
			end
		else
			local setup_columns = false
			for _,row in ipairs(unserialized) do
				if (not setup_columns) then
					setup_columns = true
					if (ConnectionPanel.Tables.ActiveTable ~= nil and ConnectionPanel.Tables.PrimaryKeys[ConnectionPanel.Tables.ActiveTable] ~= nil) then
						local primary_keys = ConnectionPanel.Tables.PrimaryKeys[ConnectionPanel.Tables.ActiveTable]
						for column in pairs(row) do
							local col = DataTable:AddColumn(column)
							if (primary_keys[column]) then
								col.Header:SetTextColor(SQLWorkbench.COLOR.GOLD)
							end
						end
					else
						for column in pairs(row) do
							DataTable:AddColumn(column)
						end
					end
				end
				local row_items = {}
				for _,val in pairs(row) do
					row_items[#row_items + 1] = val
				end
				DataTable:AddLine(unpack(row_items))
			end
		end
	end)

	net.Receive("SQLWorkbench_ViewSQL", function(len)
		local connection_id = net.ReadUInt(16)
		local ConnectionPanel = SQLWorkbench.ConnectionPanels[connection_id]
		if (not IsValid(ConnectionPanel)) then return end
		ConnectionPanel.DataContainer:SetSQLQuery(util.Decompress(net.ReadData(len - 16)))
		ConnectionPanel.DataContainer.Beautify:DoClick()
	end)

end