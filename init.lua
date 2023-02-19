nick_prefix = {}
local s = core.get_mod_storage()

function nick_prefix.get(name)
	if not name then return end
	local prefix,color = s:get_string(name):match("(%S+)%s(%S+)")
	return prefix,color
end
function nick_prefix.set(name,prefix,color)
	if not (name and prefix and color) then return end
	s:set_string(name,"["..prefix.."] "..color)
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
		if vanished then
			player:set_nametag_attributes({color={a=0},text = " "})
			return
		end
		local prefix,color = nick_prefix.get(name)
		if (prefix and color) then
			player:set_nametag_attributes({color = {a=255}, text = core.colorize(color,prefix)..name})
		else
			player:set_nametag_attributes({color = {a=255}, text = name})
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

core.register_on_chat_message(function(name,message)
	local prefix,color = nick_prefix.get(name)
	if prefix and color and core.check_player_privs(name, {shout = true}) then
		core.log("action","CHAT: "..core.format_chat_message(name,core.strip_colors(message)))
		core.chat_send_all(core.format_chat_message(core.colorize(color,prefix).." "..name,message))
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
	local prefix,color = nick_prefix.get(param)
	if prefix and color then
		return true, param.."'s prefix is "..core.colorize(color,prefix).." (colorstring: "..color..")"
	else
		return false, "Specified player doesn't have any prefix"
	end
end})

core.register_chatcommand("setprefix", {
 privs = {nick_prefix=true},
 description = "Set prefix of player",
 params = "<playername> <prefix> <color>",
 func = function(name,param)
	local pname, prefix, color = param:match("(%S+)%s+(%S+)%s+(%S+)")
	if not (pname and prefix and color) then return false, "Invalid parameters" end
	nick_prefix.set(pname,prefix,color)
	return true,"Prefix of "..pname.." now set to "..core.colorize(color,"["..prefix.."]")
end})

core.register_chatcommand("delprefix", {
 privs = {nick_prefix=true},
 description = "Delete any player's prefix or your own",
 params = "[playername]",
 func = function(name,param)
	if not param or param == "" then
		param = name
	end
	nick_prefix.del(param)
	return true,"Prefix of "..param.." deleted"
end})

core.register_chatcommand("prefixes", {
 privs={nick_prefix=true},
 description="List all players with nick prefixes",
 func = function(name,param)
	core.chat_send_player(name, "-!- List of players with nick prefixes:")
	local num = 1
	for player,_ in pairs(s:to_table().fields) do
		local prefix, color = nick_prefix.get(player)
		if prefix and color then
			core.chat_send_player(name, num..") "..player..": "..core.colorize(color,prefix).." ("..color..")")
			num = num + 1
		end
	end
	return true, "-!- Players with nick prefixes listed."
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
			local prefix,color = nick_prefix.get(name)
			if prefix and color then
				table.insert(out,core.colorize(color,prefix).." "..name)
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
