-- scuba mod for minetest
-- tested with minetest 4.14
-- for copyright, see README.md

local air   = {}
local timer = 0

local function scuba()
   local players = minetest.get_connected_players()
   for i, player in ipairs(players) do

      local pl_name   = player:get_player_name()
      local playerinv = minetest.get_inventory({type="player", name=pl_name})

      -- lookup for full tank
      local inventory = playerinv:get_list("main")
      local meta      = nil
      local tank      = nil
      local tankidx   = 0
      local pl_air    = air[pl_name]

      for i = 1, 8 do
	 if inventory[i]:get_name() == "scuba:tankfull" then
	    -- print ("Scuba --> Found tank on ", pl_name, "slot", i)
	    meta = minetest.deserialize(inventory[i]:get_metadata())
	    if meta ~= nil and meta.air ~= nil and meta.air > 0 then
	       tank    = inventory[i]
	       tankidx = i
	       -- print ("Scuba --> metadata.air", meta.air)
	       break
	    end
	 end
      end

      if tank == nil or player:get_breath() > 10 then	  
	 -- print ("Scuba --> breath", player:get_breath())
	 if pl_air ~= nil and pl_air.zid ~= -1 then
	    player:hud_remove(pl_air.zid)
	    player:hud_remove(pl_air.zid2)
	    pl_air.zid = -1
	 end
      end
      
      if tank ~= nil then
	 
	 if pl_air == nil then break end
	 
	 if player:get_breath() <= 10 then
	    if pl_air.zid == -1 then
	       pl_air.zid2 = player:hud_add( {
		     hud_elem_type = "image",
		     position = {x=0.50,y=1},
		     offset = {x=25, y=-95},
		     name = "scuba air gauge bg",
		     text = "psibar.png",
		     alignment = {x=1,y=-1},
		     scale = {x=1, y=1},
	       } )
	       
	       pl_air.zid = player:hud_add( {
		     hud_elem_type = "statbar",
		     position = {x=0.50,y=1},
		     offset = {x=25, y=-110},
		     name = "scuba air gauge",
		     text = "psi.png",
		     number = meta.air,
		     alignment = {x=1,y=-1},
		     scale = {x=1, y=1},
	       } )
	    else -- if zid
	       player:hud_change(pl_air.zid, "number", meta.air)
	    end -- if zid
	    
	    if meta.air > 0 then player:set_breath(10) end
	    meta.air = meta.air - 1 
	    tank:set_metadata(minetest.serialize(meta))
	    playerinv:set_stack("main", tankidx, tank)	       
	    if meta.air <= 0 then
	       -- print ("Scuba --> TANK is now empty", meta.air)
	       playerinv:set_stack("main", tankidx, ItemStack("scuba:tankempty"))
	    end
	    
	 end -- player:get_breath()

      end -- if tank ~= nil

   end --for players

end

minetest.after(3, function()
		  minetest.register_globalstep(function(dtime)
			timer = timer + dtime
			-- print("Scuba timer (timer, dtime)", timer, dtime)
			if timer < 3 then return end
			timer = 0
			-- print("Scuba timer reset")
			scuba()
		  end) --function
end) --function

minetest.register_on_joinplayer(function(player)
      local p = player:get_player_name()
      local pl_air = air[p]
      if pl_air == nil then
	 air[p] = {zid = -1}
	 print("Scuba --> " .. p .. " joins")
      end --if
end) --function

minetest.register_craftitem("scuba:tankempty", {
			       description = "Empty Scuba Tank",
			       drawtype = "plantlike",
			       tiles = { "tankempty.png" },
			       inventory_image = "tankempty.png",
			       wield_image = "tankempty.png",
			       sunlight_propagates = false,
			       paramtype = "light",
			       walkable = true,
			       buildable_to = false,
			       drop = "",
			       stack_max = 1,
			       groups = {airtank=1, emptytank=1},
})

minetest.register_craftitem("scuba:tankfull", {
			       description = "Full Scuba Tank",
			       drawtype = "plantlike",
			       tiles = { "tankfull.png" },
			       inventory_image = "tankfull.png",
			       wield_image = "tankfull.png",
			       sunlight_propagates = false,
			       paramtype = "light",
			       walkable = true,
			       buildable_to = false,
			       drop = "",
			       stack_max = 1,
			       groups = {airtank=1,fulltank=1},
			       on_use = function(itemstack, user, pointed_thing)
				  local p = user:get_player_name()
				  print("Scuba --> " .. p .. " empties tank")
				  --tank is now used -- hacky inv swap to tankempty
				  local fakestack = ItemStack("scuba:tankempty")
				  return fakestack
			       end,
})

minetest.register_craft({
      output = 'scuba:tankempty',
      recipe = {
	 {'', 'default:steel_ingot', ''},
	 {'default:steel_ingot', '', 'default:steel_ingot'},
	 {'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
      }
})


minetest.register_craft({
      output = 'scuba:airfill',
      recipe = {
	 {'', 'default:steel_ingot', 'default:steel_ingot'},
	 {'default:steel_ingot', '', 'default:steel_ingot'},
	 {'default:steel_ingot', 'default:steel_ingot', ''},
      }
})


minetest.register_craft({
      type = "cooking",
      output = "scuba:tankfull",
      recipe = "scuba:tankempty",
      cooktime = 30,
})

scuba_airfill_formspec =
   "size[8,7]"..
   "list[current_name;src;2,1;1,1;]"..
   "image[3,1;1,1;filling.png]"..
   "list[current_name;dst;4,1;1,1;]"..
   "list[current_player;main;0,3;8,4;]"

minetest.register_node("scuba:airfill", {
			  description = "Scuba Airfill Station",
			  tiles = {"scuba.png"},
			  groups = {oddly_breakable_by_hand=1, dig_immediate=1},
			  stack_max = 1,
			  on_construct = function(pos)
			     local meta = minetest.get_meta(pos)
			     meta:set_string("formspec", scuba_airfill_formspec)
			     meta:set_string("infotext", "Scuba Airfill Station")
			     local inv = meta:get_inventory()
			     inv:set_size("src", 1)
			     inv:set_size("dst", 1)
			  end,
			  can_dig = function(pos,player)
			     local meta = minetest.get_meta(pos);
			     local inv = meta:get_inventory()
			     if not inv:is_empty("dst") then
				return false
			     elseif not inv:is_empty("src") then
				return false
			     else
				return true
			     end
			  end,
			  allow_metadata_inventory_put = function(pos, listname, index,
								  stack, player)
			     if stack:get_name() ~= "scuba:tankempty" then
				return 0
			     elseif listname == "src" then
				return stack:get_count()
			     else
				return 0
			     end
			  end,
			  allow_metadata_inventory_move = function(pos,
								   from_list, from_index,
								   to_list, to_index,
								   count, player)
			     return 0
			  end,
})

minetest.register_abm({

      nodenames = {"scuba:airfill"},
      interval = 1.0,
      chance = 1,
      action = function(pos, node, active_object_count, active_object_count_wider)

	 local meta = minetest.get_meta(pos)
	 local inv = meta:get_inventory()
	 local srclist = inv:get_list("src")
	 local cooked = nil
	 local aftercooked

	 if srclist then
	    cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1,
							     items = srclist})
	 end
	 
	 if cooked and cooked.item and not cooked.item:is_empty() then
	    meta:set_string("infotext","Scuba Airfill Station in function")
	    meta:set_float("src_time", meta:get_float("src_time") + 1)
	    print ("Scuba --> cooked.time, src_time", cooked.time,
		   meta:get_float("src_time"))
	    if meta:get_float("src_time") >= cooked.time then
	       -- check if there's room for output in "dst" list
	       if inv:room_for_item("dst",cooked.item) then
		  -- Set meta information (tank capacity)
		  local meta2 = {air = 100}
		  cooked.item:set_metadata(minetest.serialize(meta2))
		  print ("Scuba --> tank filled",
			 cooked.item:get_name(),
			 tostring(minetest.serialize(meta2)))
		  -- Put result in "dst" list
		  inv:add_item("dst", cooked.item)
                  -- take stuff from "src" list
		  inv:set_stack("src", 1, aftercooked.items[1])
	       else
		  print("Could not insert '"..cooked.item:to_string().."'")
	       end
	       meta:set_float("src_time", 0)
	    end
	 end

	 if cooked and cooked.item and cooked.item:is_empty() then
	    meta:set_string("infotext","Scuba Airfill Station is empty")
	    meta:set_float("src_time", 0)
	 end
      end,
})

