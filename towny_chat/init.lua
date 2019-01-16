-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

local modpath = minetest.get_modpath(minetest.get_current_modname())
towny.chat.modpath = modpath

minetest.register_on_chat_message(function (name, message)
	local town = towny.get_player_town(name)
	local result = ("<%s> %s"):format(name, message)
	if town then
		result = ("[%s] <%s> %s"):format(towny.get_full_name(town), towny.get_player_name(name), message)
	end
	minetest.chat_send_all(result)
	return true
end)
