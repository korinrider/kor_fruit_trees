-- TODO
-- + Make cherry edible
-- + Make cherry sapling grow into a tree
-- + make leaf decay instantly
-- + make it so that the updates dont go out of sync because of light levels <- deleted light dependency
-- + make it possible to register other trees in the same fashion without having to copy the code
-- + add variability to the tree shape by selecting random shematics
-- + add a tool for harvesting fruit in an area
-- + add pear, orange, lemon
-- + make leaves update synchronoslly with a sertain dispersion
-- + make the fruit decay after a while
-- + make wooden stuff be fuel
-- + make only fraction of leaves generate fruit (around 0,8% probability)
-- + make a variable for fruiting chance
-- + make trees grow only on soil
-- + sapling does check for empty space around it 
-- make trees look better by making the bottom/top of the fruiting block have no fruits
-- Optional: make leaves look dencer?
-- Optional: make pear bloom not so intence (think about orang/lemon too)
-- make bonemeal work
-- make additional variants for lemon/orange 
-- find good values for the time intervals and make them default instead of debug
-- FIX - shematics for oranges and lemons are not working
-- PUBLISH THE MOD
-- Optionally: make oranges and lemons bloom and fruit all year round
-- make so that the synchroneous updates are not broaken by the edge of updated chunks
-- make so that the fruit pole can be used to harvest fruit from a longer distance
-- POTENTIAL BUG - if a cherry grew in a dark area (artificil light) nad then was put in the dark, it would not decay

-- POTENTIAL BUG - sapling checks only some portion of air around it and can grow through with some leaves through walls
-- POTENTIAL BUG - trigger leaf cycle doesnt check for leaves of other trees

-- Notes to self
-- /grant singleplayer all
-- //mtschemcreate

local DEBUG = true

local path = minetest.get_modpath(minetest.get_current_modname()) .. "/"

local S = default.get_translator
local fruit_decay=true
local ld_radius = 3

--------------------------------
-- some general stuff
--------------------------------

local function print_keys(t)
	for key,_ in pairs(t) do
		minetest.chat_send_all(key)
	end
end

local function after_place_leaves(...)
	return default.after_place_leaves(...)
end

local movement_gravity = tonumber(
	minetest.settings:get("movement_gravity")) or 9.81

local function decay_a_leaf(pos, leaves)
	local node = minetest.get_node(pos)
	local drops = minetest.get_node_drops(node.name)
	for _, item in ipairs(drops) do
		local is_leaf
		for _, v in pairs(leaves) do
			if v == item then
				is_leaf = true
			end
		end
		if minetest.get_item_group(item, "leafdecay_drop") ~= 0 or
				not is_leaf then
			minetest.add_item({
				x = pos.x - 0.5 + math.random(),
				y = pos.y - 0.5 + math.random(),
				z = pos.z - 0.5 + math.random(),
			}, item)
		end
	end

	minetest.remove_node(pos)
	minetest.check_for_falling(pos)

	-- spawn a few particles for the removed node
	minetest.add_particlespawner({
		amount = 32,
		time = 0.001,
		minpos = vector.subtract(pos, {x=0.5, y=0.5, z=0.5}),
		maxpos = vector.add(pos, {x=0.5, y=0.5, z=0.5}),
		minvel = vector.new(-0.8, -1, -0.8),
		maxvel = vector.new(0.8, 0, 0.8),
		minacc = vector.new(0, -movement_gravity/4, 0),
		maxacc = vector.new(0, -movement_gravity/4, 0),
		minsize = 1,
		maxsize = 3,
		minexptime = 1,
        maxexptime = 3,
		node = node,
	})
end

local function leaf_decay(pos, leaves, trunk)
	for _, v in pairs(minetest.find_nodes_in_area(vector.subtract(pos, ld_radius),
			vector.add(pos, ld_radius), leaves)) do
			find_trunk = minetest.find_nodes_in_area(vector.subtract(v, ld_radius), vector.add(v, ld_radius), trunk)
			if next(find_trunk) == nil then
				decay_a_leaf(v, leaves)
			end
	end
end

local trigger_leaf_cycle = function(pos, radius, height, fruit_name, disp, t_interval)
	pos_list = minetest.find_nodes_in_area({x=pos.x-radius, y=pos.y, z=pos.z-radius}, {x=pos.x+radius, y=pos.y+height, z=pos.z+radius}, {"kor_fruit_trees:" .. fruit_name .. "_leaves"})
	for i, p in ipairs(pos_list) do
		minetest.get_node_timer(p):start(t_interval+ math.random(1, disp))
	end
end

--------------------------------
-- some general stuff
--------------------------------
-- function that harvests a corresponding fruit from any kor_fruit_trees:fruit_leaves_fruit node

function s_split(inputstr, sep)
	if sep == nil then
			sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
			table.insert(t, str)
	end
	return t
end

local harvest_fruit_leaves = function(pos, node, player)
	node = minetest.get_node(pos)
	local fruit_name = node.name:sub(17, -14)
	--minetest.chat_send_all("harvesting " .. fruit_name)
	minetest.swap_node(pos, {name = "kor_fruit_trees:" .. fruit_name .. "_leaves", param2=node.param2})
	minetest.sound_play(default.node_sound_leaves_defaults(), { pos = pos }, true)
	if fruit_decay == false then
		minetest.get_node_timer(pos):start(minetest.get_item_group(node.name, "t_interval"))
	else
		local timer = minetest.get_node_timer(pos)
		t = timer:get_elapsed()
		timer:stop()
		timer:start(2*minetest.get_item_group(node.name, "t_interval")-t)
	end
	--minetest.chat_send_all("kor_fruit_trees:".. fruit_name .. "_fruit 1")
	player:get_inventory():add_item("main", "kor_fruit_trees:".. fruit_name .. "_fruit 1") 
end

local can_grow_fruit_tree = function(pos, min_radius, height)
	local node_under = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
	if not node_under then
		return false
	end
	if minetest.get_item_group(node_under.name, "soil") == 0 then
		return false
	end
	local light_level = minetest.get_node_light(pos)
	if not light_level or light_level < 11 then
		return false
	end
	node = minetest.get_node_or_nil({x = pos.x, y = pos.y+1, z = pos.z})
	if node then
		if node.name ~= "air" then
			return false
		end
	end
	for i = -min_radius,min_radius,1 
	do 
		for j = -min_radius,min_radius,1 
		do 
			for k = 2,height,1 
			do 
				node = minetest.get_node_or_nil({x = pos.x+i, y = pos.y+k, z = pos.z+j})
				if node then
					if node.name ~= "air" then
						return false
					end
				end
			end
		end
	end
	return true
end

local grow_new_tree = function(pos, t_disp, radius, height, schematics, fruit_name, n_variants, t_interval)
	if not can_grow_fruit_tree(pos, 1, height) then
		-- try a bit later again
		minetest.get_node_timer(pos):start(math.random(150, 300))
		return
	end
	minetest.set_node(pos, {name = "air"})
	local path = minetest.get_modpath("kor_fruit_trees") .. schematics .. math.random(1, n_variants) .. ".mts"
	minetest.place_schematic({x = pos.x - radius, y = pos.y, z = pos.z - radius}, path, "random", nil, false)
	trigger_leaf_cycle(pos, radius, height, fruit_name, t_disp, t_interval)
end

local far_harvest = function(pointed_thing, player)
	if pointed_thing.type ~= "node" then
		return
	else
		pos = pointed_thing.under
		node = minetest.get_node(pos)
	end
	if minetest.get_item_group(node.name, "fruit_tree_leves")==1 then
		local fruit_name = s_split(node.name:sub(17, -1), "_")[1]
		pos_list = minetest.find_nodes_in_area({x=pos.x-1, y=pos.y-1, z=pos.z-1}, {x=pos.x+1, y=pos.y+3, z=pos.z+1}, {"kor_fruit_trees:" .. fruit_name .. "_leaves_fruit"})
		if #pos_list > 0 then
			for i, p in ipairs(pos_list) do
				node = minetest.get_node(p)
				harvest_fruit_leaves(p, node, player)
			end
		end
	end
end

--------------------------------
-- a large function that defines a tree
--------------------------------

local function register_kor_fruit_tree(fruit_name, n_variants, radius, height, t_grow_sap_u, t_grow_sap_l, t_interval, t_dispersion, fruiting_chance, fruit_leaves_type)

	minetest.register_node("kor_fruit_trees:" .. fruit_name .. "_leaves", {
		description = S( fruit_name .. " tree leaves"),
		drawtype = "allfaces",
		waving = 1,
		tiles = { fruit_name .. "_leaves.png"},
		paramtype = "light",
		is_ground_content = false,
		groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1, t_interval = t_interval, fruit_tree_leves=1},
		drop = {
			max_items = 1,
			items = {
				{
					-- player will get sapling with 1/20 chance
					items = {"kor_fruit_trees:" .. fruit_name .. "_sapling"},
					rarity = 20,
				},
				{
					-- player will get leaves only if he get no saplings,
					-- this is because max_items is 1
					items = {"kor_fruit_trees:" .. fruit_name .. "_leaves"},
				}
			}
		},
		sounds = default.node_sound_leaves_defaults(),
		on_timer = function(pos, elapsed)
			minetest.set_node(pos, {name = "kor_fruit_trees:" .. fruit_name .. "_leaves_bloom"})
			minetest.get_node_timer(pos):start(t_interval)
		end,
	})

	minetest.register_node("kor_fruit_trees:" .. fruit_name .. "_leaves_bloom", {
		description = S( fruit_name .. " tree leaves"),
		drawtype = "allfaces",
		waving = 1,
		tiles = { fruit_name .. "_leaves_bloom.png"},
		paramtype = "light",
		is_ground_content = false,
		groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1, t_interval = t_interval, fruit_tree_leves=1},
		drop = {
			max_items = 1,
			items = {
				{
					-- player will get sapling with 1/20 chance
					items = {"kor_fruit_trees:" .. fruit_name .. "_sapling"},
					rarity = 20,
				},
				{
					-- player will get leaves only if he get no saplings,
					-- this is because max_items is 1
					items = {"kor_fruit_trees:" .. fruit_name .. "_leaves_bloom"},
				}
			}
		},
		sounds = default.node_sound_leaves_defaults(),
		on_timer = function(pos, elapsed)
			if math.random(1, 10) <= fruiting_chance then
				minetest.set_node(pos, {name = "kor_fruit_trees:" .. fruit_name .. "_leaves_fruit"})
				minetest.get_node_timer(pos):start(t_interval)
			else
				minetest.set_node(pos, {name = "kor_fruit_trees:" .. fruit_name .. "_leaves"})
				minetest.get_node_timer(pos):start(2*t_interval)
			end
		end,
	})
	
	if fruit_leaves_type=="nodebox" then
		fruit_leves_tiles = {fruit_name .. "_leaves.png", fruit_name .. "_leaves.png", fruit_name .. "_leaves_fruit.png", fruit_name .. "_leaves_fruit.png", fruit_name .. "_leaves_fruit.png", fruit_name .. "_leaves_fruit.png"}
	else
		fruit_leves_tiles = {fruit_name .. "_leaves_fruit.png"}
	end

	minetest.register_node("kor_fruit_trees:" .. fruit_name .. "_leaves_fruit", {
		description = S( fruit_name .. " Tree Leaves"),
		drawtype = fruit_leaves_type,
		node_box = {
			type = "fixed",
			fixed = {
				{ -1/2, -1/2,-1/2,  1/2,  1/2, 1/2},
			},
		},
		waving = 1,
		tiles = fruit_leves_tiles,
		--tiles = {fruit_name .. "_leaves_fruit.png"},
		paramtype = "light",
		is_ground_content = false,
		groups = {snappy = 3, leafdecay = 3, flammable = 2, leaves = 1, t_interval = t_interval, fruit_tree_leves=1},
		drop = {
			max_items = 2,
			items = {
				{
					-- player will get sapling with 1/20 chance
					items = {"kor_fruit_trees:" .. fruit_name .. "_sapling"},
					rarity = 20,
				},
				{
					-- player will get leaves only if he get no saplings,
					-- this is because max_items is 1
					items = {"kor_fruit_trees:" .. fruit_name .. "_leaves"},
					rarity = 1,
				},
				{
					-- player will get leaves only if he get no saplings,
					-- this is because max_items is 1
					items = {"kor_fruit_trees:" .. fruit_name .. "_fruit"},
					rarity = 1,
				}
			}
		},
		sounds = default.node_sound_leaves_defaults(),
		on_rightclick = harvest_fruit_leaves,
		after_place_node = after_place_leaves,
		t_interval = t_interval,
		on_timer = function(pos, elapsed)
			if fruit_decay then
				minetest.set_node(pos, {name = "kor_fruit_trees:" .. fruit_name .. "_leaves"})
				minetest.get_node_timer(pos):start(t_interval)
			end
		end,
	})

	minetest.register_node("kor_fruit_trees:" .. fruit_name .. "_trunk", {
		description = S( fruit_name .. " tree trunk"),
		tiles = { fruit_name .. "_trunk_section.png",  fruit_name .. "_trunk_section.png",  fruit_name .. "_trunk.png"},
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {tree = 1, choppy = 2, oddly_breakable_by_hand = 1, flammable = 2},
		sounds = default.node_sound_wood_defaults(),
		on_place = minetest.rotate_node,
		after_destruct = function(pos, oldnode)
			leaf_decay(pos, {"kor_fruit_trees:" .. fruit_name .. "_leaves", "kor_fruit_trees:" .. fruit_name .. "_leaves_bloom", "kor_fruit_trees:" .. fruit_name .. "_leaves_fruit"}, "kor_fruit_trees:" .. fruit_name .. "_trunk")
		end
	})

	minetest.register_craftitem("kor_fruit_trees:" .. fruit_name .. "_fruit", {
		description = S(fruit_name),
		inventory_image = fruit_name .. "_fruit.png",
		groups = {
			flammable = 2,
		},
		on_use = minetest.item_eat(2)
	})

	minetest.register_node("kor_fruit_trees:" .. fruit_name .. "_sapling", {
		description = S( fruit_name .. " Tree Sapling"),
		drawtype = "plantlike",
		tiles = { fruit_name .. "_sapling.png"},
		inventory_image =  fruit_name .. "_sapling.png",
		wield_image =  fruit_name .. "_sapling.png",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		on_timer = grow_sapling,
		selection_box = {
			type = "fixed",
			fixed = {-4 / 16, -0.5, -4 / 16, 4 / 16, 7 / 16, 4 / 16}
		},
		groups = {snappy = 2, dig_immediate = 3, flammable = 2,
			attached_node = 1, sapling = 1},
		sounds = default.node_sound_leaves_defaults(),

		on_construct = function(pos)
			minetest.get_node_timer(pos):start(math.random(t_grow_sap_l, t_grow_sap_u))
		end,

		on_place = function(itemstack, placer, pointed_thing)
			itemstack = default.sapling_on_place(itemstack, placer, pointed_thing,
				"kor_fruit_trees:" .. fruit_name .. "_sapling",
				-- minp, maxp to be checked, relative to sapling pos
				-- minp_relative.y = 1 because sapling pos has been checked
				{x = -3, y = 1, z = -3},
				{x = 3, y = 6, z = 3},
				-- maximum interval of interior volume check
				4)

			return itemstack
		end,

		on_timer = function(pos)
			grow_new_tree(pos, t_dispersion, radius, height, "/schematics/" .. fruit_name .. "_tree", fruit_name, n_variants, t_interval)
		end,
	})

	-- wooden stuff

	minetest.register_node("kor_fruit_trees:" .. fruit_name .. "_planks", {
		description = S( fruit_name .. " Wood Planks"),
		paramtype2 = "facedir",
		place_param2 = 0,
		tiles = {fruit_name .. "_planks.png"},
		is_ground_content = false,
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
		sounds = default.node_sound_wood_defaults(),
	})

	stairs.register_stair_and_slab( fruit_name .. "_wood", "kor_fruit_trees:" .. fruit_name .. "_planks",
		{choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
		{fruit_name .. "_planks.png"},
		S(fruit_name .. " Wood Stair"),
		S(fruit_name .. " Wood Slab"),
		default.node_sound_wood_defaults()
	)

	default.register_fence("kor_fruit_trees:fence_" .. fruit_name .. "_wood", {
		description = S(fruit_name .. " Wood Fence"),
		texture = fruit_name .. "_planks.png",
		inventory_image = "default_fence_overlay.png^" .. fruit_name .. "_planks.png^" ..
					"default_fence_overlay.png^[makealpha:255,126,126",
		wield_image = "default_fence_overlay.png^" .. fruit_name .. "_planks.png^" ..
					"default_fence_overlay.png^[makealpha:255,126,126",
		material = "kor_fruit_trees:" .. fruit_name .. "_planks",
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
		sounds = default.node_sound_wood_defaults()
	})

	default.register_fence_rail("kor_fruit_trees:fence_rail_" .. fruit_name .. "_wood", {
		description = S(fruit_name .. " Wood Fence Rail"),
		texture = fruit_name .. "_planks.png",
		inventory_image = "default_fence_rail_overlay.png^" .. fruit_name .. "_planks.png^" ..
					"default_fence_rail_overlay.png^[makealpha:255,126,126",
		wield_image = "default_fence_rail_overlay.png^" .. fruit_name .. "_planks.png^" ..
					"default_fence_rail_overlay.png^[makealpha:255,126,126",
		material = "kor_fruit_trees:" .. fruit_name .. "_planks",
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, wood = 1},
		sounds = default.node_sound_wood_defaults()
	})

	default.register_mesepost("kor_fruit_trees:" .. fruit_name .. "_post_light_willow_wood", {
		description = S(fruit_name .. " Wood Mese Post Light"),
		texture = fruit_name .. "_planks.png",
		material = "kor_fruit_trees:" .. fruit_name .. "_planks",
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1}
	})

	doors.register_fencegate("kor_fruit_trees:gate_" .. fruit_name .. "_wood", {
		description = S(fruit_name .. " Wood Fence Gate"),
		texture = fruit_name .. "_planks.png",
		material = "kor_fruit_trees:" .. fruit_name .. "_planks",
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1}
	})

end

-- reminder for vars (fruit_name, n_variants, radius, height, t_grow_sap_u, t_grow_sap_l, t_interval, t_dispersion, fruiting_chance)
if DEBUG then
	register_kor_fruit_tree("cherry", 9, 3, 7, 1, 2, 30, 5, 8, "allfaces")
	register_kor_fruit_tree("orange", 1, 3, 7, 1, 2, 30, 5, 8, "nodebox")
	register_kor_fruit_tree("lemon", 1, 3, 7, 1, 2, 30, 5, 8, "nodebox")
	register_kor_fruit_tree("pear", 6, 3, 7, 1, 2, 30, 5, 8, "nodebox")
else
	register_kor_fruit_tree("cherry", 9, 3, 7, 200, 400, 300-15, 30, 8, "allfaces")
	register_kor_fruit_tree("orange", 1, 3, 7, 200, 400, 300-15, 30, 8, "nodebox")
	register_kor_fruit_tree("lemon", 1, 3, 7, 200, 400, 300-30, 60, 8, "nodebox")
	register_kor_fruit_tree("pear", 6, 3, 7, 200, 400, 300-30, 60, 8, "nodebox")
end

-- frut pole as a tool for harvesting fruit

minetest.register_tool("kor_fruit_trees:fruit_pole", {
	description = S("Pole fore collecting fruit"),
	inventory_image = "fruit_pole.png",
	groups = {tool = 1},
	on_use = function(itemstack, user, pointed_thing)
		far_harvest(pointed_thing, user)
	end,
	on_place = function(itemstack, user, pointed_thing)
		far_harvest(pointed_thing, user)	
	end,
})

minetest.register_craft({
	output = "kor_fruit_trees:fruit_pole",
	recipe = {
		{"default:stick", "default:stick", "default:stick"},
		{"", "default:stick", ""},
		{"", "default:stick", ""},
	}
})
