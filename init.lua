-- A township system for Minetest servers.
-- The MIT License - 2019  Evert "Diamond" Prants <evert@lunasqu.ee>

local modpath = minetest.get_modpath(minetest.get_current_modname())
towny = {
	regions    = {
		size      = tonumber(minetest.settings:get('towny_claim_size')) or 16,
		height    = tonumber(minetest.settings:get('towny_claim_height')) or 64,
		maxclaims = tonumber(minetest.settings:get('towny_claim_max')) or 128,
		distance  = tonumber(minetest.settings:get('towny_distance')) or 80,

		-- Regions loaded into memory cache, see "Town regions data structure"
		memloaded = {},
	},
	-- See "Town data structure"
	flatfile = {},
	towns    = {},
	chat     = {
		chatmod      = (minetest.settings:get('towny_chat') == "true") or true,
		questionaire = (minetest.settings:get('towny_questionaire') == "true") or true,
		invites      = {},
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

	-- Set to true if files need to be updated
	dirty = false,
}

-- Town data structure
--[[
	town_id = {
		name = "Town Name",
		mayor = "Mayor name",
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
]]

-- Town regions data structure
--[[
	town_id = {
		origin = <town origin>,
		blocks = {
			{
				x, y, x,   -- Origin point for claim block
				plot = nil -- Plot ID if this claim block is plotted
			}
		},
	}
]]

-- Town-specific flags
--[[
	'town_build' 		boolean 	lets everyone build in unplotted town claims
	'plot_build' 		boolean 	lets everyone build in unowned town plots
	'plot_member_build' boolean 	if false, plot members don't have build rights to plots by default
	'teleport' 			position 	town teleport point
	'pvp' 				boolean 	players can fight in the town if true, ignores server pvp settings
	'plot_pvp' 			boolean		default plot pvp setting. defaults to false
	'joinable' 			boolean 	if true, anyone can join this town. defaults to false
	'greeting' 			string 		town's greeting message
	'tax' 				float 		how much each member has to pay each day to stay in town (only with economy)
	'bank' 				float 		town's wealth (only with economy) (unchangeable by owner)
	'claim_blocks'		int 		town's bonus claim blocks (unchangeable by owner)
	'origin'			position	town's center position, set at town creation (unchangeable by owner)
]]

-- Members with flags
--[[
	'plot_build' 	boolean 	if 'plot_member_build' town flag is false,
		this one must be true for a plot member to be able to build on a plot.
		If set to true in town flags, this member can build in all plots.
	'town_build' 	boolean 	if true, this member can build in town claims.
	'claim_create' 	boolean 	if true, this member can claim land for the town
	'claim_delete' 	boolean 	if true, this member can abandon claim blocks
	'plot_create' 	boolean 	if true, this member can create plots
	'plot_delete' 	boolean 	if true, this member can delete plots
]]

-- Plot-specific flags
--[[
	'teleport' 	position 	plot's teleport point
	'pvp' 		boolean 	players can fight here if true, ignores server pvp settings
	'cost' 		float 		plot cost (only with economy)
	'claimable' boolean 	is this plot available for claiming. if cost is more than 0, require payment
	'greeting' 	string 		plot's greeting message (defaults to "{owner}'s Plot"/"Unclaimed Plot")
]]

dofile(modpath.."/flatfile.lua")
dofile(modpath.."/visualize.lua")
dofile(modpath.."/regions.lua")
dofile(modpath.."/town.lua")
dofile(modpath.."/chat.lua")
