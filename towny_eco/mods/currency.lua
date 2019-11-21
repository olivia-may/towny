-- Simple "currency" mod API

local denoms = {
	["currency:minegeld_cent_5"] = 0.05,
	["currency:minegeld_cent_10"] = 0.10,
	["currency:minegeld_cent_25"] = 0.25,
	["currency:minegeld"] = 1,
	["currency:minegeld_5"] = 5,
	["currency:minegeld_10"] = 10,
	["currency:minegeld_50"] = 50,
	["currency:minegeld_100"] = 100,
}

function towny.eco.get_currency()
	return "Minegeld"
end

function towny.eco.format_number(number)
	return ("%.2f MG$"):format(number)
end

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- Item-based functions

local function to_stacks(items)
	local counted = {}
	for _,i in pairs(items) do
		if counted[i] then
			counted[i] = counted[i] + 1
		else
			counted[i] = 1
		end
	end

	local stacks = {}
	for itm,cnt in pairs(counted) do
		table.insert(stacks, ItemStack(itm .. " " .. cnt))
	end

	return stacks
end

local function get_closest_note(amount, notes)
	local t = nil
	local a = 0
	for itm,val in pairs(denoms) do
		local b = (notes == nil)
		if notes and notes[itm] ~= nil and notes[itm] > 0 then
			b = true
		end
		if val <= amount and a <= val and b then
			t = itm
			a = val
		end
	end
	return a, t
end

local function denominate(amount)
	local items = {}
	local tc = amount

	while tc > 0 do
		local amount,item = get_closest_note(tc)
		if amount == 0 then break end
		tc = tc - amount
		table.insert(items, item)
	end

	return to_stacks(items)
end

local function notes_inv(inventory)
	local total = 0
	for _,stack in pairs(inventory:get_list("main")) do
		local value = denoms[stack:get_name()]
		if value then
			total = total + (value * stack:get_count())
		end
	end
	return total
end

local function highest_note(notes, amount)
	local result = nil
	local tmount = 0
	for note,cnt in pairs(notes) do
		local nt = denoms[note]
		if nt > amount and cnt > 0 then
			result = note
			tmount = nt
		end
	end
	return tmount, result
end

local function take_notes(inventory, total)
	-- Take an audit of all the notes in the inventory
	local notes = {}
	for _,stack in pairs(inventory:get_list("main")) do
		local name = stack:get_name()
		if denoms[name] then
			if notes[name] then
				notes[name] = notes[name] + stack:get_count()
			else
				notes[name] = stack:get_count()
			end
		end
	end

	local original = table.copy(notes)

	-- Loop through, getting the highest notes first
	while total > 0 do
		local amount,item = get_closest_note(total,notes)
		if amount == 0 then break end
		if notes[item] then
			notes[item] = notes[item] - 1
		end
		total = total - amount
	end

	-- If the total was not reached, try to get the next highest note
	local give = 0
	if total > 0 then
		local nxam,note = highest_note(notes, total)
		if nxam > total then
			notes[note] = notes[note] - 1
			give = nxam - total
			total = 0
		end
	end

	-- Couldn't take total balance
	if total > 0 then
		return nil
	end

	-- Take from inventory
	for note,count in pairs(notes) do
		if original[note] then
			local taken = original[note] - count
			if taken > 0 then
				inventory:remove_item("main", ItemStack(note .. " " .. taken))
			end
		end
	end

	if give > 0 then
		local stacks = denominate(give)
		for _,stack in pairs(stacks) do
			inventory:add_item("main", stack)
		end
	end

	return total
end

-- Public functions

function towny.eco.get_player_balance(player)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end
	if not player then return 0 end
	if towny.eco.type == "item" then
		return notes_inv(player:get_inventory())
	else
		local meta = player:get_meta()
		return meta:get_float("money")
	end
end

function towny.eco.charge_player(player, amount)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end
	if not player then return false end
	if towny.eco.type == "item" then
		return take_notes(player:get_inventory(), amount)
	else
		local meta = player:get_meta()
		local money = meta:get_float("money")
		if money < amount then
			return false
		end
		meta:set_float(money - amount)
		return amount
	end
end

function towny.eco.pay_player(player, amount)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end
	if not player then return false end
	if towny.eco.type == "item" then
		local inventory = player:get_inventory()
		local stacks = denominate(amount)
		for _,stack in pairs(stacks) do
			inventory:add_item("main", stack)
		end
	else
		local meta = player:get_meta()
		local money = meta:get_float("money")
		meta:set_float(money + amount)
		return true
	end
end

local requests = {}

local function c(msg)
	return minetest.colorize("#09b700",msg)
end

local function b(msg)
	return minetest.colorize("#078c00",msg)
end

local function msg(name,msg)
	minetest.chat_send_player(name,msg)
	return true
end

local function fm(amount)
	return towny.eco.format_number(amount)
end

local function help()
	return minetest.colorize("#e5b002", "Command usage:") .. "\n" ..
		b("/money") .. c(" - Check your balance") .. "\n" ..
		b("/money transfer") .. c(" <player> <amount> - Give money to a player") .. "\n" ..
		b("/money request") .. c(" <player> <amount> - Request money from a player") .. "\n"
end

local function money_command(name, param)
	local player = minetest.get_player_by_name(name)
	if not player then
		return false, "Only an online player can run this command."
	end

	if param == "" then
		return true, b("Balance: ") .. c(fm(towny.eco.get_player_balance(player)))
	end

	local command,target,amount = param:match("^(%a+) ([%a%d_-]+) ([%d.]+)$")
	local target_player = minetest.get_player_by_name(target or "")
	if command and not target then
		return false, "The target player doesn't exist."
	end

	amount = tonumber(amount)

	if command == "transfer" or command == "pay" or command == "give" then
		local taken = towny.eco.charge_player(player, amount)
		if not taken then
			return false, "You do not have enough money."
		end

		towny.eco.pay_player(target_player, amount)
		minetest.chat_send_player(target, c("Player %s has paid you %s!"):format(name, fm(amount)))
		return true, c("Successfully given %s to %s."):format(fm(amount), target)
	elseif command == "request" then
		if requests[name.."-"..target] then
			return false, "You have already requested money from that player."
		end
		requests[name.."-"..target] = true

		minetest.chat_send_player(target, c("Player %s requested a total of %s from you. Run '/money pay %s %d' to pay them.")
			:format(name, fm(amount), name, amount))
		return true, c("Request sent.")
	end

	return false, help()
end

minetest.register_chatcommand("money", {
	description = "View and transfer your money",
	privs = {interact = true},
	func = money_command
})

towny.eco.type = "item"
towny.eco.enabled = true
