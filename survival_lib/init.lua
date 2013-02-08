
survival = { };

survival.meters = { };

-- Boilerplate to support localized strings if intllib mod is installed.
local S;
if (minetest.get_modpath("intllib")) then
    dofile(minetest.get_modpath("intllib").."/intllib.lua");
    S = intllib.Getter(minetest.get_current_modname());
else
    S = function ( s ) return s; end
end

survival.distance3d = function ( p1, p2 )
    local lenx = math.abs(p2.x - p1.x);
    local leny = math.abs(p2.y - p1.y);
    local lenz = math.abs(p2.z - p1.z);
    local hypotxz = math.sqrt((lenx * lenx) + (lenz * lenz));
    return math.sqrt((hypotxz * hypotxz) + (leny * leny));
end

dofile(minetest.get_modpath("survival_lib").."/config.lua");

survival.create_meter = function ( name, def )
    minetest.register_tool(name, {
        description = def.description;
        inventory_image = def.image;
        on_use = def.on_use;
    });
    if (def.command and def.command.name) then
        local lbl = (def.command.label or def.command.name);
        def.command.func = function ( name, param )
            local ply = minetest.env:get_player_by_name(name);
            local val = math.floor(def.get_value(ply));
            local val2 = math.max(0, math.min(val / 10, 10));
            minetest.chat_send_player(name, lbl..": ["..val.."%] "..string.rep("|", val2));
        end;
        minetest.register_chatcommand(def.command.name, {
            params = "";
            description = S("Display %s"):format(lbl);
            func = def.command.func;
        });
    end
    if (def.recipe) then
        minetest.register_craft({
            output = name;
            recipe = def.recipe;
        });
    end
    def.name = name;
    survival.meters[name] = def;
    survival.meters[#survival.meters + 1] = def;
end

local chat_cmd_def = {
    params = "";
    description = S("Display all player stats");
    func = function ( name, param )
        for i, def in ipairs(survival.meters) do
            if (def.command and def.command.func and (not def.command.not_in_plstats)) then
                def.command.func(name, "");
            end
        end
    end;
};

minetest.register_chatcommand("plstats", chat_cmd_def);
minetest.register_chatcommand("s", chat_cmd_def);

local timer = 0;
local MAX_TIMER = 1;

minetest.register_globalstep(function ( dtime )

    timer = timer + dtime;
    if (timer < MAX_TIMER) then return; end

    timer = timer - MAX_TIMER;

    for _,player in pairs(minetest.get_connected_players()) do
        local inv = player:get_inventory();
        for name, def in pairs(survival.meters) do
            if (def.on_step) then
                def.on_step(player);
            end
            if (survival.conf_getbool("meters_enabled", true)
             and inv:contains_item("main", ItemStack(name))) then
                for i = 1, inv:get_size("main") do
                    local stack = inv:get_stack("main", i);
                    if (stack:get_name() == name) then
                        local value = (65533 * def.get_value(player) / 100);
                        --local wear = stack:get_wear();
                        inv:remove_item("main", stack);
                        stack:add_wear(-65535);
                        stack:add_wear(65534);
                        stack:add_wear(-value);
                        inv:set_stack("main", i, stack);
                        break;
                    end
                end
            end
        end
    end

end);
