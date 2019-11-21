-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

-- TODO: Economy

local modpath = minetest.get_modpath(minetest.get_current_modname())
towny = {
	modpath = modpath,
	regions = {
		size     = tonumber(minetest.settings:get('towny_claim_size')) or 16,
		height   = tonumber(minetest.settings:get('towny_claim_height')) or 64,
		distance = tonumber(minetest.settings:get('towny_distance')) or 80,
		vertical = {
			static = minetest.settings:get_bool('towny_static_height', false),
			miny   = tonumber(minetest.settings:get('towny_static_miny')) or -32000,
			maxy   = tonumber(minetest.settings:get('towny_static_maxy')) or 32000,
		},

		-- Regions loaded into memory cache, see "Town regions data structure"
		memloaded = {},
	},
	-- See "Town data structure"
	storage = {},
	towns   = {},
	chat    = {
		chatmod = minetest.settings:get_bool('towny_chat', true),
		invite  = minetest.settings:get_bool('towny_invite', true),
		invites = {},
	},
	levels = {
		{
			members = 0,
			name_tag = 'Ruins',
			mayor_tag = 'Spirit',
			claimblocks = 1,
		}, {
			members = 1,
			name_tag = 'Settlement',
			mayor_tag = 'Hermit',
			claimblocks = 16,
		}, {
			members = 2,
			name_tag = 'Hamlet',
			mayor_tag = 'Chief',
			claimblocks = 32,
		}, {
			members = 6,
			name_tag = 'Village',
			mayor_tag = 'Baron Von',
			claimblocks = 96,
		}, {
			members = 10,
			name_tag = 'Town',
			mayor_tag = 'Viscount',
			claimblocks = 160,
		}, {
			members = 14,
			name_tag = 'Large Town',
			mayor_tag = 'Count Von',
			claimblocks = 224,
		}, {
			members = 20,
			name_tag = 'City',
			mayor_tag = 'Earl',
			claimblocks = 320,
		}, {
			members = 24,
			name_tag = 'Large City',
			mayor_tag = 'Duke',
			claimblocks = 384,
		}, {
			members = 28,
			name_tag = 'Metropolis',
			mayor_tag = 'Lord',
			claimblocks = 448,
		}
	},
	flags = {
		town = {
			['town_build'] =        {"boolean", "lets everyone build in unplotted town claims"},
			['plot_build'] =        {"boolean", "lets everyone build in unowned town plots"},
			['plot_member_build'] = {"boolean", "if false, plot members don't have build rights to plots by default"},
			['teleport'] =          {"vector",  "town teleport point"},
			['pvp'] =               {"boolean", "players can fight in the town if true, ignores server pvp settings"},
			['plot_pvp'] =          {"boolean", "default plot pvp setting. defaults to false"},
			['joinable'] =          {"boolean", "if true, anyone can join this town. defaults to false"},
			['greeting'] =          {"string",  "town's greeting message"},
			['tax'] =               {"number",  "how much each member has to pay each day to stay in town"},
			['mayor'] =             {"member",  "town's mayor"},
			['bank'] =              {"number",  "town's treasury", false},
			['claim_blocks'] =      {"number",  "town's bonus claim blocks", false},
			['origin'] =            {"vector",  "town's center position, set at town creation", false},
		},
		town_member = {
			['town_build'] =   {"boolean", "member can build in unplotted town claims"},
			['claim_create'] = {"boolean", "member can claim land for the town"},
			['claim_delete'] = {"boolean", "member can abandon claim blocks"},
			['plot_create'] =  {"boolean", "member can create plots"},
			['plot_delete'] =  {"boolean", "member can delete plots"},
		},
		plot = {
			['teleport'] =  {"vector",   "plot's teleport point"},
			['pvp'] =       {"boolean",  "players can fight here if true, ignores server pvp settings"},
			['cost'] =      {"number",   "plot cost (only with economy)"},
			['claimable'] = {"boolean",  "is this plot available for claiming. if cost is more than 0, require payment"},
			['greeting'] =  {"string",   "plot's greeting message (defaults to \"{owner}'s Plot\"/\"Unclaimed Plot\")"},
		},
		plot_member = {
			['plot_build'] = {"boolean", "member can build on plot. defaults to 'plot_member_build' town flag"},
			['build']      = "plot_build",
		},
	},

	-- Set to true if files need to be updated
	dirty = false,
}

--[[
	-- Town data structure
	town_id = {
		name = "Town Name",
		members = {<members with flags>},
		flags = {<town specific flags>},
		plots = {
			plot_id = {
				owner = "Owner name",
				members = {<members with flags>},
				flags = {<plot specific flags>}
			}
		}
	}

	-- Town regions data structure
	town_id = {
		origin = <town origin>,
		blocks = {
			{
				x, y, x,   -- Origin point for claim block
				plot = nil -- Plot ID if this claim block is plotted
				origin = true -- Center of town, if present
			}
		},
	}
]]

dofile(modpath.."/storage/init.lua")
dofile(modpath.."/visualize.lua")
dofile(modpath.."/regions.lua")
dofile(modpath.."/town.lua")
dofile(modpath.."/commands.lua")
