
-- Privileges

minetest.register_privilege("towny", {
	description = "Can create and join towns",
})

minetest.register_privilege("towny_admin", {
	description = "Can administrate other people's towns",
	give_to_singleplayer = false
})

-- Commands

local function town_command (name, param)
	if not minetest.get_player_by_name(name) then return false, "Can't run command on behalf of offline player." end
	local pr1, pr2 = string.match(param, "^([%a%d_-]+) (.+)$")
	local town = towny:get_player_town(name)

	-- Pre town requirement

	if (pr1 == "create" or pr1 == "new") and pr2 then
		return towny:create_town(nil, name, pr2)
	end

	if not town then
		return false, "You are not currently in a town."
	end

	-- Town management commands
	local tdata = towny.towns[town]

	if param == "extend" or param == "claim" then
		return towny:extend_town(nil, name)
	elseif param == "leave" then
		return towny:leave_town(name)
	elseif param == "unclaim" then
		return towny:abridge_town(nil, name)
	elseif param == "visualize" then
		towny.regions:visualize_town(town)
		return true
	elseif (param == "delete" or param == "abandon") or (pr1 == "delete" or pr1 == "abandon") then
		if towny.chat['delete_verify_' .. name] and pr2 == "I WANT TO DELETE MY TOWN" then
			towny.chat['delete_verify_' .. name] = nil
			return towny:delete_town(nil, name)
		else
			towny.chat['delete_verify_' .. name] = true
			minetest.chat_send_player(name, minetest.colorize("#f79204",
				"WARNING! Deleting your town will render ALL of the buildings in it without protection!"))
			return false, "Please run the command again with 'I WANT TO DELETE MY TOWN' in all caps written after it."
		end
	end

	-- Plot management commands
	if pr1 == "plot" then
		local pl1, pl2 = string.match(pr2, "^([%a%d_-]+) (.+)$")
		
	end

	return false, "Invalid command usage."
end

minetest.register_chatcommand("town", {
	description = "Manage your town",
	privs = {towny = true},
	func = town_command
})
