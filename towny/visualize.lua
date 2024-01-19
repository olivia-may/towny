-- Visualize an area
-- TODO: Use particles

local c_obj_props = {
	hp 		= 1,
	glow 		= 1,
	physical 	= false,
	pointable 	= true,
	visual 		= "cube",
	-- 16 is mapblock size
	visual_size = {x = 16, y = 16},
	textures 	= {"towny_visualize.png","towny_visualize.png","towny_visualize.png",
				   "towny_visualize.png","towny_visualize.png","towny_visualize.png"},
	static_save = false,
	use_texture_alpha = true,
}

minetest.register_entity("towny:region_visual", {
	initial_properties = c_obj_props,
	on_punch = function(self)
		self.object:remove()
	end,
	timer = 0,
	on_step = function (self,dtime)
		self.timer = self.timer + dtime
		-- 60 seconds
		if self.timer > 10 then
			self.object:remove()
		end
	end
})

function towny.visualize_block(block)
	-- 8 is half mapblock size
	minetest.add_entity(vector.add(block.pos_min, 8), "towny:region_visual")
end
