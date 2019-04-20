SQLWorkbench.Database = {}

function SQLWorkbench.Database:Query(connection, query, callback)
	if (connection == nil) then
		local res = sql.Query(query)
		if (res == false) then
			if (callback) then callback(nil, nil, nil, sql.LastError()) end
			return
		end
		local affected_rows = 0
		local affected_rows_query = sql.Query("SELECT changes() AS AFFECTED_ROWS LIMIT 1")
		if (affected_rows_query and #affected_rows_query > 0) then affected_rows = tonumber(affected_rows_query[1].AFFECTED_ROWS) or 0 end
		if (callback) then callback(res, affected_rows) end
	else
		local mysqloo_query = connection:query(query)
		if (callback) then
			function mysqloo_query:onSuccess(data)
				local last_insert = self:lastInsert()
				if (last_insert == 0) then last_insert = nil end
				callback(data, self:affectedRows(), last_insert)
			end
			function mysqloo_query:onError(err)
				callback(nil, nil, nil, err)
			end
		end
		mysqloo_query:start()
	end
end

function SQLWorkbench.Database:Prepare(connection, query, data, callback)
	if (connection == nil) then
		local new_query = ""
		local arg_num = 1
		local active_special_char
		for i=1, #query do
			if (not active_special_char) then
				if (query[i] == "`" or query[i] == "'" or query[i] == "\"") then
					active_special_char = query[i]
				elseif (query[i] == "?") then
					if (data[arg_num] == NULL or data[arg_num] == nil) then
						new_query = new_query .. "NULL"
					else
						new_query = new_query .. sql.SQLStr(data[arg_num])
					end
					arg_num = arg_num + 1
					continue
				end
			else
				if (query[i] == active_special_char) then
					active_special_char = nil
				end
			end
			new_query = new_query .. query[i]
		end
		if (active_special_char ~= nil) then
			ErrorNoHalt("[SQLWorkbench] Unfinished " .. active_special_char .. " in SQLite prepared query:\n")
			print(query)
			return
		end

		local res = sql.Query(new_query)
		if (res == false) then
			if (callback) then callback(nil, nil, nil, sql.LastError()) end
			return
		end

		local affected_rows = 0
		local affected_rows_query = sql.Query("SELECT changes() AS AFFECTED_ROWS LIMIT 1")
		if (affected_rows_query and #affected_rows_query > 0) then affected_rows = tonumber(affected_rows_query[1].AFFECTED_ROWS) or 0 end

		local last_insert = nil
		local last_insert_query = sql.Query("SELECT last_insert_rowid() AS LAST_INSERT")
		if (last_insert_query and #last_insert_query > 0) then last_insert = tonumber(last_insert_query[1].LAST_INSERT) end

		if (callback) then callback(res, affected_rows, last_insert) end
	else
		local mysqloo_prepared = connection:prepare(query)
		for i,v in ipairs(data) do
			if (v == NULL) then
				mysqloo_prepared:setNull(i)
			else
				local v_type = type(v)
				if (v_type == "number") then
					mysqloo_prepared:setNumber(i, v)
				elseif (v_type == "string") then
					mysqloo_prepared:setString(i, v)
				elseif (v_type == "boolean") then
					mysqloo_prepared:setBoolean(i, v)
				end
			end
		end
		if (callback) then
			function mysqloo_prepared:onSuccess(data)
				local last_insert = self:lastInsert()
				if (last_insert == 0) then last_insert = nil end
				callback(data, self:affectedRows(), last_insert)
			end
			function mysqloo_prepared:onError(err)
				callback(nil, nil, nil, err)
			end
		end
		mysqloo_prepared:start()
	end
end

net.Receive("SQLWorkbench_GetTables", function(_, ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end

	if (connection_id == 0) then
		SQLWorkbench.Database:Query(nil, "SELECT `tbl_name` FROM sqlite_master WHERE `type`='table' ORDER BY `name`", function(rows)
			net.Start("SQLWorkbench_GetTables")
				net.WriteUInt(connection_id, 16)
				net.WriteUInt(#rows, 12)
				for _,row in ipairs(rows) do
					net.WriteString(row.tbl_name)
					local is_empty_query = sql.Query("SELECT 1 FROM " .. SQLWorkbench:EscapeTable(row.tbl_name) .. " LIMIT 1")
					net.WriteBool(is_empty_query == nil or #is_empty_query == 0)
				end
			net.Send(ply)
		end)
	else
		SQLWorkbench.Database:Prepare(SQLWorkbench.MySQL:GetConnection(ply, connection_id), "SELECT `TABLE_NAME`, `TABLE_ROWS` FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? ORDER BY `TABLE_NAME`", {SQLWorkbench.MySQL:GetDatabaseName(ply, connection_id)}, function(rows)
			net.Start("SQLWorkbench_GetTables")
				net.WriteUInt(connection_id, 16)
				net.WriteUInt(#rows, 12)
				for _,row in ipairs(rows) do
					net.WriteString(row.TABLE_NAME)
					net.WriteBool(not tonumber(row.TABLE_ROWS) or tonumber(row.TABLE_ROWS) == 0)
				end
			net.Send(ply)
		end)
	end
end)

net.Receive("SQLWorkbench_GetTableStructure", function(_, ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end
	local table_name = net.ReadString()

	if (connection_id == 0) then
		SQLWorkbench.Database:Query(nil, "PRAGMA table_info(" .. SQLWorkbench:EscapeTable(table_name) .. ")", function(rows, _, __, err)
			if (err == nil and rows ~= nil and #rows > 0) then
				net.Start("SQLWorkbench_GetTableStructure")
					net.WriteUInt(connection_id, 16)
					net.WriteString(table_name)
					net.WriteUInt(#rows, 12)
					for _,row in pairs(rows) do
						net.WriteString(row.name)
						net.WriteBool(row.pk ~= "0")
					end
				net.Send(ply)
			end
		end)
	else
		SQLWorkbench.Database:Query(SQLWorkbench.MySQL:GetConnection(ply, connection_id), "SHOW COLUMNS FROM " .. SQLWorkbench:EscapeTable(table_name), function(rows, _, __, err)
			if (err == nil and rows ~= nil and #rows > 0) then
				net.Start("SQLWorkbench_GetTableStructure")
					net.WriteUInt(connection_id, 16)
					net.WriteString(table_name)
					net.WriteUInt(#rows, 12)
					for _,row in pairs(rows) do
						net.WriteString(row.Field)
						net.WriteBool(row.Key == "PRI")
					end
				net.Send(ply)
			end
		end)
	end
end)

net.Receive("SQLWorkbench_Query", function(len, ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end
	local query = util.Decompress(net.ReadData(len - 16))

	local connection
	local connection_tag = "SQLite"
	if (connection_id ~= 0) then
		connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		connection_tag = "#" .. connection_id
	end

	SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] ran query:", SQLWorkbench.PRINT_TYPE.NOTICE)
	print(query)
	
	local QueryStart = SysTime()
	SQLWorkbench.Database:Query(connection, query, function(rows, affected_rows, last_insert, err)
		QueryTime = math.Round((SysTime() - QueryStart) * 1000)
		if (err ~= nil) then
			net.Start("SQLWorkbench_QueryError")
				net.WriteUInt(connection_id, 16)
				net.WriteUInt(QueryTime, 32)
				net.WriteString(err)
			net.Send(ply)

			SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] query error: " .. err, SQLWorkbench.PRINT_TYPE.ERROR)
		elseif (rows == nil or #rows == 0) then
			net.Start("SQLWorkbench_QueryNoResults")
				net.WriteUInt(connection_id, 16)
				net.WriteUInt(QueryTime, 32)
				net.WriteUInt(affected_rows, 16)
				if (last_insert ~= nil) then
					net.WriteBool(true)
					net.WriteUInt(last_insert, 64)
				else
					net.WriteBool(false)
				end
			net.Send(ply)

			local last_insert_print = ""
			if (last_insert ~= nil) then last_insert_print = ", last insert ID: " .. tostring(last_insert) end
			SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] query returned no results, " .. affected_rows .. " affected row(s)" .. last_insert_print, SQLWorkbench.PRINT_TYPE.NOTICE)
		else
			local serialized = util.Compress(util.TableToJSON(rows))
			net.Start("SQLWorkbench_QueryResults")
				net.WriteUInt(connection_id, 16)
				net.WriteUInt(QueryTime, 32)
				net.WriteData(serialized, #serialized)
			net.Send(ply)

			SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] query returned " .. #rows .. " row(s)", SQLWorkbench.PRINT_TYPE.NOTICE)
		end
	end)
end)

net.Receive("SQLWorkbench_DeleteRow", function(len, ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end
	local deletion_data = util.JSONToTable(util.Decompress(net.ReadData(len - 16)))
	
	local connection
	local connection_tag = "SQLite"
	if (connection_id ~= 0) then
		connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		connection_tag = "#" .. connection_id
	end

	local prepared_data = {}
	local where = ""
	for column, data in pairs(deletion_data.data) do
		where = where .. SQLWorkbench:EscapeTable(column) .. "=? AND "
		prepared_data[#prepared_data + 1] = data
	end
	SQLWorkbench.Database:Prepare(connection, "DELETE FROM " .. SQLWorkbench:EscapeTable(deletion_data.table) .. " WHERE " .. (where:gsub("AND $","")), prepared_data, function(_, affected_rows, __, err)
		if (err ~= nil) then
			net.Start("SQLWorkbench_DeleteRow_Failed")
			net.Send(ply)
		else
			SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] deleted " .. affected_rows .. " row(s) in " .. SQLWorkbench:EscapeTable(deletion_data.table), SQLWorkbench.PRINT_TYPE.NOTICE)
		end
	end)
end)

net.Receive("SQLWorkbench_UpdateRow", function(len, ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end
	local update_data = util.JSONToTable(util.Decompress(net.ReadData(len - 16)))
	
	local connection
	local connection_tag = "SQLite"
	if (connection_id ~= 0) then
		connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		connection_tag = "#" .. connection_id
	end

	local prepared_data = {}
	local set = ""
	for column, data in pairs(update_data.data) do
		set = set .. SQLWorkbench:EscapeTable(column) .. "=?, "
		prepared_data[#prepared_data + 1] = data
	end
	local where = ""
	for column, data in pairs(update_data.constraints) do
		where = where .. SQLWorkbench:EscapeTable(column) .. "=? AND "
		prepared_data[#prepared_data + 1] = data
	end
	SQLWorkbench.Database:Prepare(connection, "UPDATE " .. SQLWorkbench:EscapeTable(update_data.table) .. " SET " .. (set:gsub(", $","")) .. " WHERE " .. (where:gsub(" AND $","")), prepared_data, function(_, affected_rows, __, err)
		if (err ~= nil) then
			net.Start("SQLWorkbench_UpdateRow_Failed")
			net.Send(ply)
		else
			SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] updated " .. affected_rows .. " row(s) in " .. SQLWorkbench:EscapeTable(update_data.table), SQLWorkbench.PRINT_TYPE.NOTICE)
		end
	end)
end)

net.Receive("SQLWorkbench_DeleteTable", function(_,ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end

	local table_name = net.ReadString()

	local connection
	local connection_tag = "SQLite"
	if (connection_id ~= 0) then
		connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		connection_tag = "#" .. connection_id
	end
	SQLWorkbench.Database:Query(connection, "DROP TABLE " .. SQLWorkbench:EscapeTable(table_name))
	SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] deleted table " .. SQLWorkbench:EscapeTable(table_name), SQLWorkbench.PRINT_TYPE.NOTICE)
end)

net.Receive("SQLWorkbench_EmptyTable", function(_,ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end

	local connection
	local connection_tag = "SQLite"
	if (connection_id ~= 0) then
		connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		connection_tag = "#" .. connection_id
	end

	local table_name = net.ReadString()
	if (connection_id == 0) then
		sql.Query("DELETE FROM " .. SQLWorkbench:EscapeTable(table_name))
		sql.Query("VACUUM")
	else
		SQLWorkbench.Database:Query(connection, "TRUNCATE " .. SQLWorkbench:EscapeTable(table_name))
	end

	SQLWorkbench:Print("[" .. connection_tag .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] emptied table " .. SQLWorkbench:EscapeTable(table_name), SQLWorkbench.PRINT_TYPE.NOTICE)
end)

net.Receive("SQLWorkbench_ViewSQL", function(_,ply)
	local connection_id = net.ReadUInt(16)
	if (not ply:IsSuperAdmin() or not SQLWorkbench:IsPlayerUsingMenu(ply) or (connection_id ~= 0 and not SQLWorkbench.MySQL:IsConnected(ply, connection_id))) then return end

	local table_name = net.ReadString()
	if (connection_id == 0) then
		SQLWorkbench.Database:Prepare(nil, "SELECT `sql` FROM sqlite_master WHERE `type`='table' AND `tbl_name`=? ORDER BY `name`", {table_name}, function(rows)
			local compressed_sql = util.Compress(rows[1].sql)
			net.Start("SQLWorkbench_ViewSQL")
				net.WriteUInt(connection_id, 16)
				net.WriteData(compressed_sql, #compressed_sql)
			net.Send(ply)
		end)
	else
		SQLWorkbench.Database:Query(SQLWorkbench.MySQL:GetConnection(ply, connection_id), "SHOW CREATE TABLE " .. SQLWorkbench:EscapeTable(table_name), function(rows)
			local compressed_sql = util.Compress(rows[1]["Create Table"])
			net.Start("SQLWorkbench_ViewSQL")
				net.WriteUInt(connection_id, 16)
				net.WriteData(compressed_sql, #compressed_sql)
			net.Send(ply)
		end)
	end
end)
