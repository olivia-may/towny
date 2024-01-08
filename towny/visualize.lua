-- Visualize an area
-- TODO: Use particles

local c_obj_props = {
	hp 			= 1,
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
	timer0 = 0,
	on_step = function (self,dt)
		self.timer0 = self.timer0 + 1
		if self.timer0 > 600 then
			self.object:remove()
		end
	end
})

function towny.regions.visualize_area(p1,p2,pos)
	-- 8 is half mapblock size
	local center = {x=p1.x - 8,y=p1.y - 8,z=p1.z - 8}

	local e = minetest.add_entity(center, "towny:region_visual")
end
