SQLWorkbench.MySQL = {}
SQLWorkbench.MySQL.Connecting = {}
SQLWorkbench.MySQL.Connections = {}

if (SERVER) then
	function SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		if (connection_id == 0 or SQLWorkbench.MySQL.Connections[ply] == nil or SQLWorkbench.MySQL.Connections[ply][connection_id] == nil) then
			return nil
		else
			return SQLWorkbench.MySQL.Connections[ply][connection_id].CONNECTION
		end
	end

	function SQLWorkbench.MySQL:GetDatabaseName(ply, connection_id)
		if (connection_id == 0 or SQLWorkbench.MySQL.Connections[ply] == nil or SQLWorkbench.MySQL.Connections[ply][connection_id] == nil) then
			return nil
		else
			return SQLWorkbench.MySQL.Connections[ply][connection_id].DATABASE
		end
	end

	function SQLWorkbench.MySQL:GetUsername(ply, connection_id)
		if (connection_id == 0 or SQLWorkbench.MySQL.Connections[ply] == nil or SQLWorkbench.MySQL.Connections[ply][connection_id] == nil) then
			return nil
		else
			return SQLWorkbench.MySQL.Connections[ply][connection_id].USERNAME
		end
	end

	function SQLWorkbench.MySQL:GetHost(ply, connection_id)
		if (connection_id == 0 or SQLWorkbench.MySQL.Connections[ply] == nil or SQLWorkbench.MySQL.Connections[ply][connection_id] == nil) then
			return nil
		else
			return SQLWorkbench.MySQL.Connections[ply][connection_id].HOST
		end
	end

	function SQLWorkbench.MySQL:IsConnected(ply, connection_id)
		local connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		return connection ~= nil and connection:status() == mysqloo.DATABASE_CONNECTED
	end

	net.Receive("SQLWorkbench_MySQL_AbortConnecting", function(_, ply)
		local client_connection_id = net.ReadUInt(16)
		if (SQLWorkbench.MySQL.Connecting[ply] ~= nil and SQLWorkbench.MySQL.Connecting[ply][client_connection_id] ~= nil) then
			SQLWorkbench:Print("[#...] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] aborted connecting", SQLWorkbench.PRINT_TYPE.NOTICE)
			SQLWorkbench.MySQL.Connecting[ply][client_connection_id]:disconnect()
			SQLWorkbench.MySQL.Connecting[ply][client_connection_id] = nil
			if (SQLWorkbench.table_IsEmpty(SQLWorkbench.MySQL.Connecting[ply])) then
				SQLWorkbench.MySQL.Connecting[ply] = nil
			end
		end
	end)

	net.Receive("SQLWorkbench_MySQL_AbortConnection", function(_, ply)
		local connection_id = net.ReadUInt(16)
		local connection = SQLWorkbench.MySQL:GetConnection(ply, connection_id)
		if (connection ~= nil and connection:status() ~= mysqloo.DATABASE_NOT_CONNECTED) then
			connection:disconnect()

			SQLWorkbench:Print("[#" .. connection_id .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] disconnected from \"" .. SQLWorkbench.MySQL:GetDatabaseName(ply, connection_id) .. "\" on \"" .. SQLWorkbench.MySQL:GetHost(ply, connection_id) .. "\" as \"" .. SQLWorkbench.MySQL:GetUsername(ply, connection_id) .. "\"", SQLWorkbench.PRINT_TYPE.NOTICE)

			SQLWorkbench.MySQL.Connections[ply][connection_id] = nil
			if (SQLWorkbench.table_IsEmpty(SQLWorkbench.MySQL.Connections[ply])) then
				SQLWorkbench.MySQL.Connections[ply] = nil
			end
		end
	end)

	net.Receive("SQLWorkbench_MySQL_StartConnection", function(_, ply)
		if (not ply:IsSuperAdmin()) then return end

		local client_connection_id = net.ReadUInt(16)

		local host = net.ReadString()
		local username = net.ReadString()

		local cipher = net.ReadUInt(16)
		local password = ""
		for i=1,net.ReadUInt(16) do
			password = password .. string.char(bit.bxor(net.ReadUInt(32), cipher))
		end

		local database = net.ReadString()
		local port = net.ReadUInt(16)

		if (not mysqloo) then
			if ((system.IsLinux() and file.Exists("lua/bin/gmsv_mysqloo_linux.dll", "GAME")) or (system.IsWindows() and file.Exists("lua/bin/gmsv_mysqloo_win32.dll", "GAME"))) then
				require("mysqloo")
			else
				net.Start("SQLWorkbench_No_MySQLOO")
				net.Send(ply)
				return
			end
		end
		
		local connection = mysqloo.connect(host, username, password, database, port)

		SQLWorkbench.MySQL.Connecting[ply] = SQLWorkbench.MySQL.Connecting[ply] or {}
		SQLWorkbench.MySQL.Connecting[ply][client_connection_id] = connection
		
		SQLWorkbench:Print("[#...] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] is connecting to '" .. username .. "'@'" .. host .. "'." .. database, SQLWorkbench.PRINT_TYPE.NOTICE)

		function connection:onConnected()
			SQLWorkbench.MySQL.Connecting[ply][client_connection_id] = nil
			if (SQLWorkbench.table_IsEmpty(SQLWorkbench.MySQL.Connecting[ply])) then
				SQLWorkbench.MySQL.Connecting[ply] = nil
			end

			SQLWorkbench.MySQL.Connections[ply] = SQLWorkbench.MySQL.Connections[ply] or {}
			local connection_id = #SQLWorkbench.MySQL.Connections[ply] + 1
			SQLWorkbench.MySQL.Connections[ply][connection_id] = {
				CONNECTION = connection,
				DATABASE = database,
				HOST = host,
				USERNAME = username
			}

			net.Start("SQLWorkbench_MySQL_StartConnection")
				net.WriteUInt(client_connection_id, 16)
				net.WriteUInt(connection_id, 16)
			net.Send(ply)

			SQLWorkbench:Print("[#" .. connection_id .. "] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] connected successfully!", SQLWorkbench.PRINT_TYPE.SUCCESS)

			connection:setCharacterSet("utf8mb4")
		end

		function connection:onConnectionFailed(err)
			SQLWorkbench.MySQL.Connecting[ply][client_connection_id] = nil
			if (SQLWorkbench.table_IsEmpty(SQLWorkbench.MySQL.Connecting[ply])) then
				SQLWorkbench.MySQL.Connecting[ply] = nil
			end

			net.Start("SQLWorkbench_MySQL_ConnectionError")
				net.WriteUInt(client_connection_id, 16)
				net.WriteString(err or "UNKNOWN")
			net.Send(ply)

			SQLWorkbench:Print("[#!!!] " .. ply:Nick() .. " [" .. ply:SteamID() .. "] failed to connect!", SQLWorkbench.PRINT_TYPE.ERROR)
			SQLWorkbench:Print("Error: ".. err, SQLWorkbench.PRINT_TYPE.ERROR)
		end

		connection:connect()
	end)
else
	local client_connection_id = 0
	local client_connection_callbacks = {}
	function SQLWorkbench.MySQL:StartConnection(host, username, password, database, port, callback)
		client_connection_callbacks[client_connection_id] = callback

		local cipher = math.random(2,65535)
		net.Start("SQLWorkbench_MySQL_StartConnection")
			net.WriteUInt(client_connection_id, 16)
			net.WriteString(host)
			net.WriteString(username)
			net.WriteUInt(cipher, 16)
			net.WriteUInt(#password, 16)
			for i=1,#password do
				local char = password[i]
				net.WriteUInt(bit.bxor(string.byte(char), cipher), 32)
			end
			net.WriteString(database)
			net.WriteUInt(port, 16)
		net.SendToServer()

		client_connection_id = client_connection_id + 1
		return client_connection_id - 1
	end
	net.Receive("SQLWorkbench_MySQL_StartConnection", function()
		local client_connection_id = net.ReadUInt(16)
		local connection_id = net.ReadUInt(16)
		SQLWorkbench.MySQL.Connections[connection_id] = true
		if (client_connection_callbacks[client_connection_id] ~= nil) then
			client_connection_callbacks[client_connection_id](connection_id)
		end
	end)
	net.Receive("SQLWorkbench_MySQL_ConnectionError", function()
		local client_connection_id = net.ReadUInt(16)
		local err = net.ReadString()
		if (client_connection_callbacks[client_connection_id] ~= nil) then
			client_connection_callbacks[client_connection_id](nil, err)
		end
	end)

	function SQLWorkbench.MySQL:AbortConnection(connection_id)
		SQLWorkbench.MySQL.Connections[connection_id] = nil
		SQLWorkbench.ConnectionPanels[connection_id] = nil

		net.Start("SQLWorkbench_MySQL_AbortConnection")
			net.WriteUInt(connection_id, 16)
		net.SendToServer()
	end
end