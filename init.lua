nick_prefix = {}
local hidden_nicks = {}
local s = core.get_mod_storage()

local function migrate()
	for name,str in pairs(s:to_table().fields) do
		local prefix, color = str:match("(%S+)%s(%S+)")
		if prefix and color then
			local data = {
				prefix = prefix:gsub("[%[%]]",""),
				color = color
			}
			s:set_string(name, core.serialize(data))
		end
	end
	s:set_string("[migrated]", "[yes]")
end

function nick_prefix.get(name)
	local sdata = name and s:get(name)
	if not sdata then return {} end
	local data = core.deserialize(sdata)
	if not data then
		if not s:get("[migrated]") then
			migrate()
			return nick_prefix.get(name)
		end
		return {}
	end
	return data
end
function nick_prefix.set(name,data)
	if not (name and data) then return end
	s:set_string(name, core.serialize(data))
	nick_prefix.update_ntag(name)
end
function nick_prefix.del(name)
	if not name then return end
	s:set_string(name,"")
	nick_prefix.update_ntag(name)
end
function nick_prefix.update_ntag(name)
	local player = core.get_player_by_name(name)
	if player then
		local vanished = vanish and vanish.vanished[name]
		if vanished or hidden_nicks[name] then
			player:set_nametag_attributes({color={a=0},text = " "})
			return
		end
		local data = nick_prefix.get(name)
		if data then
			local prefix = ""
			if data.pronouns then
				prefix = prefix .. "["..data.pronouns.."] "
			end
			if data.prefix and data.color then
				prefix = prefix .. core.colorize(data.color, "["..data.prefix.."] ")
			end
			player:set_nametag_attributes({color = {a=255,r=255,g=255,b=255}, text = prefix..name})
		else
			player:set_nametag_attributes({color = {a=255,r=255,g=255,b=255}, text = name})
		end
	end
end
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.3 then return end -- 0.3 sec delay for lower CPU usage
	timer = 0
	for _,player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local ctrl = player:get_player_control()
		local ntag = player:get_nametag_attributes()
		if not ctrl.sneak then
			nick_prefix.update_ntag(name)
		end
		if ctrl.sneak then
			player:set_nametag_attributes({color={a=0},text = " "})
		end
	end
end)

core.register_privilege("nick_prefix",{description = "Allows to manage nick prefixes", give_to_singleplayer = false})
core.register_privilege("np_pronouns",{description = "Allows to manage pronouns", give_to_singleplayer = false})

core.register_on_chat_message(function(name,message)
	local data = nick_prefix.get(name)
	if data and core.check_player_privs(name, "shout") then
		local prefix = ""
		if data.pronouns then
			prefix = prefix .. "["..data.pronouns.."] "
		end
		if data.prefix and data.color then
			prefix = prefix .. core.colorize(data.color, "["..data.prefix.."] ")
		end
		core.log("action","CHAT: "..core.format_chat_message(name,core.strip_colors(message)))
		core.chat_send_all(core.format_chat_message(prefix..name,message))
		return true
	end
end)

core.register_chatcommand("getprefix", {
 description = "Get any player's prefix or your own",
 params = "[playername]",
 func = function(name,param)
	if not param or param == "" then
		param = name
	end
	local data = nick_prefix.get(param)
	if data and data.prefix and data.color then
		return true, param.."'s prefix is "..core.colorize(data.color,data.prefix).." (colorstring: "..data.color..")"
	else
		return false, "Specified player doesn't have any prefix"
	end
end})

core.register_chatcommand("getpronouns", {
 description = "Get any player's pronouns or your own",
 params = "[playername]",
 func = function(name,param)
	if not param or param == "" then
		param = name
	end
	local data = nick_prefix.get(param)
	if data and data.pronouns then
		return true, param.."'s pronouns is "..data.pronouns
	else
		return false, "Specified player doesn't have any pronouns"
	end
end})

core.register_chatcommand("setprefix", {
 privs = {nick_prefix=true},
 description = "Set prefix of player",
 params = "<playername> <prefix> <color>",
 func = function(name,param)
	local pname, prefix, color = param:match("(%S+)%s+(%S+)%s+(%S+)")
	if not (pname and prefix and color) then return false, "Invalid parameters" end
	local data = nick_prefix.get(pname)
	data.prefix = prefix
	data.color = color
	nick_prefix.set(pname,data)
	return true,"Prefix of "..pname.." has been set to "..core.colorize(color,"["..prefix.."]")
end})

core.register_chatcommand("setpronouns", {
 privs = {np_pronouns=true},
 description = "Set pronouns of player",
 params = "<playername> <pronouns>",
 func = function(name,param)
	local pname, pronouns = param:match("(%S+)%s+(%S+)")
	if not (pname and pronouns) then return false, "Invalid parameters" end
	local data = nick_prefix.get(pname)
	data.pronouns = pronouns
	nick_prefix.set(pname,data)
	return true,"pronouns of "..pname.." has been set to "..pronouns..""
end})

core.register_chatcommand("delprefix", {
 privs = {nick_prefix=true},
 description = "Delete any player's prefix or your own",
 params = "[playername]",
 func = function(name,param)
	if not param or param == "" then
		param = name
	end
	local data = nick_prefix.get(param)
	data.prefix = nil
	data.color = nil
	if not next(data) then
		nick_prefix.del(param)
	else
		nick_prefix.set(param,data)
	end
	return true,"Prefix of "..param.." deleted"
end})

core.register_chatcommand("delpronouns", {
 privs = {np_pronouns=true},
 description = "Delete any player's pronouns or your own",
 params = "[playername]",
 func = function(name,param)
	if not param or param == "" then
		param = name
	end
	local data = nick_prefix.get(param)
	data.pronouns = nil
	if not next(data) then
		nick_prefix.del(param)
	else
		nick_prefix.set(param,data)
	end
	return true,"pronouns of "..param.." deleted"
end})

core.register_chatcommand("hidenick",{
  description = "Hide your or other player's nametag",
  privs = {nick_prefix=true},
  params = "[playername]",
  func = function(name, param)
	local pname = not param or param == "" and name or param
	local player = core.get_player_by_name(pname)
	if not player then
		return false, "Invalid player '"..pname.."'"
	end
	hidden_nicks[pname] = true
	nick_prefix.update_ntag(pname)
	return true, "Nickname of "..pname.." hidden"
end})

core.register_chatcommand("shownick",{
  description = "Show hidden nametag",
  privs = {nick_prefix=true},
  params = "[playername]",
  func = function(name, param)
	local pname = not param or param == "" and name or param
	local player = core.get_player_by_name(pname)
	if not player then
		return false, "Invalid player '"..pname.."'"
	end
	hidden_nicks[pname] = nil
	nick_prefix.update_ntag(pname)
	return true, "Nickname of "..pname.." shown"
end})

core.register_chatcommand("prefixes", {
 privs={nick_prefix=true},
 description="List all players with nick prefixes",
 func = function(name,param)
	core.chat_send_player(name, "-!- List of players with nick prefixes:")
	local num = 1
	for pname,_ in pairs(s:to_table().fields) do
		local data = nick_prefix.get(pname)
		if data.prefix and data.color then
			core.chat_send_player(name, num..") "..pname..": "..core.colorize(data.color,data.prefix).." ("..data.color..")")
			num = num + 1
		end
	end
	return true, "-!- Players with nick prefixes listed."
end})

core.register_chatcommand("pronouns_list", {
 privs={np_pronouns=true},
 description="List all players with pronouns",
 func = function(name,param)
	core.chat_send_player(name, "-!- List of players with pronouns:")
	local num = 1
	for pname,_ in pairs(s:to_table().fields) do
		local data = nick_prefix.get(pname)
		if data.pronouns then
			core.chat_send_player(name, num..") "..pname..": "..data.pronouns)
			num = num + 1
		end
	end
	return true, "-!- Players with pronouns listed."
end})

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not name then return end
	nick_prefix.update_ntag(name)
end)

core.register_chatcommand("players", {
 description = "List all players currently online with their nick prefixes",
 func = function(name, param)
	local list = core.get_connected_players()
	local out = {}
	for _,player in ipairs(list) do
		local name = player:get_player_name()
		if name then
			local data = nick_prefix.get(name)
			if data then
				local prefix = ""
				if data.pronouns then
					prefix = prefix .. "["..data.pronouns.."] "
				end
				if data.prefix and data.color then
					prefix = prefix .. core.colorize(data.color, "["..data.prefix.."] ")
				end
				table.insert(out,prefix..name)
			else
				table.insert(out,name)
			end
		end
	end
	table.sort(out)
	return true, #list.." Online: "..table.concat(out,", ")
end})


local say_def = {
	description = "Say message to global chat",
	params = "<message>",
	privs = {shout=true},
	func = function(name,param)
		if name and param and param ~= "" then
			core.run_callbacks(core.registered_on_chat_messages, 5, name, param)
		end
	end
}


core.register_on_mods_loaded(function()
	if core.chatcommands["say"] then
		core.override_chatcommand("say",say_def)
	else
		core.register_chatcommand("say",say_def)
	end
end)
