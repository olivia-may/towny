-- Visualize an area
-- TODO: Use particles

minetest.register_entity("towny:block_visual", {

	initial_properties = {
		hp 		= 1,
		glow 		= 1,
		physical 	= false,
		pointable 	= true,
		visual 		= "cube",
		-- 16 is mapblock size
		visual_size = {x = 16, y = 16},
		textures = {
			"towny_block_visual.png", "towny_block_visual.png",
			"towny_block_visual.png", "towny_block_visual.png",
			"towny_block_visual.png", "towny_block_visual.png"
		},
		static_save = false,
		use_texture_alpha = true,
	},

	on_punch = function(self)
		return true
	end,
	timer = 0,
	on_step = function (self,dtime)
		self.timer = self.timer + dtime
		-- 10 seconds
		if self.timer > 10 then
			self.object:remove()
		end
	end
})

function towny.visualize_block(block)
	-- 8 is half mapblock size
	minetest.add_entity(vector.add(block.pos_min, 8), "towny:block_visual")
end
