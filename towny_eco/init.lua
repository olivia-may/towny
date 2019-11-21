-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

local modpath = minetest.get_modpath(minetest.get_current_modname())

towny.eco = {
	enabled     = false,
	create_cost = tonumber(minetest.settings:get("towny_create_cost")) or 10000,
	claim_cost  = tonumber(minetest.settings:get("towny_claim_cost")) or 1000,
	upkeep_cost = tonumber(minetest.settings:get("towny_upkeep_cost")) or 0,
	taxable     = minetest.settings:get_bool("towny_tax", true)
}

dofile(modpath.."/api.lua")

if minetest.get_modpath("currency") ~= nil then
	dofile(modpath.."/mods/currency.lua")
end
