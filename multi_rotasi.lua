-- =================================================================
-- Rotasi Growlauncher
-- Script by VaaaStore
-- =================================================================

math.randomseed(os.time())

local config = {
    -- ID Pickaxe atau Alat Kerja Utama agar TIDAK Ikut Ter-Drop
    pickaxe_id = 28, 

    -- NAMA AKUN UTAMA KAMU (WHITE-LIST)
    owner_names = {
        "NAMA_AKUN_UTAMAMU_1",
        "NAMA_AKUN_UTAMAMU_2"
    },

    -- DAFTAR 7 WORLD FARM ANDA
    farm_worlds = {
        "WORLD_FARM_1", "WORLD_FARM_2", "WORLD_FARM_3", 
        "WORLD_FARM_4", "WORLD_FARM_5", "WORLD_FARM_6", "WORLD_FARM_7"
    },
    
    break_world = "WORLD_BREAK_KAMU",
    break_door  = "DOORBREAK",
    storage_world = "WORLD_STORAGE_KAMU",
    storage_door  = "DOORSTORAGE",
    
    -- Konfigurasi Koordinat & Scan Gudang
    base_drop_x = 30,
    base_drop_y = 30,
    max_scan_range = 15,
    max_object_per_tile = 4000, -- Clean Magic Number

    -- ID Item Data
    block_id = 1058, 
    pack_id  = 4310, 
    wl_id    = 242,  
    punch_action_id = 18, -- Clean Magic Number (Action ID untuk Punch)

    -- Posisi PNB
    pnb_x = 3, 
    pnb_y = 1,

    -- Parameter Keamanan & Target
    hit_count = 4,
    trigger_pnb_blocks = 150,     
    target_planted_per_world = 2645, 

    -- DELAY CONFIGURATION (Dinamis & Acak)
    delay_place_min = 200, delay_place_max = 250,
    delay_punch_min = 210, delay_punch_max = 265,
    delay_plant_min = 195, delay_plant_max = 245,
    path_delay_min  = 320, path_delay_max  = 380,

    loop_delay = 600,
    warp_delay = 6500, 
    flee_sleep_duration_sec = 120, -- Clean Magic Number untuk durasi rehat (2 menit)

    trash_items = {5028, 5038}, 
    trash_count = 150
}

-- Global State Tracking
local current_farm_index = 1
local global_planted_counter = 0
local seed_id = config.block_id + 1
local watermark = "Raditya Refactored Bot V3.1"
local blacklisted_tiles = {} -- Sekarang menggunakan Hash Map O(1)

-- =================================================================
-- 1. CORE API & OPTIMIZED CACHING WRAPPER
-- =================================================================
local function call_api(name, ...)
    local upper_name = name:sub(1,1):upper() .. name:sub(2)
    local lower_name = name:sub(1,1):lower() .. name:sub(2)
    if _G[lower_name] and type(_G[lower_name]) == "function" then return true, _G[lower_name](...)
    elseif _G[upper_name] and type(_G[upper_name]) == "function" then return true, _G[upper_name](...)
    end
    return false, nil
end

local function sleep_hp(ms)
    if type(sleep) == "function" then sleep(ms)
    elseif type(Delay) == "function" then Delay(ms)
    else
        local start = os.clock()
        while os.clock() - start < (ms / 1000) do end
    end
end

local function log_hp(text)
    call_api("log", "[" .. watermark .. "] " .. tostring(text))
end

local function send_packet_hp(packet_type, packet_string)
    pcall(function()
        if type(sendPacket) == "function" then sendPacket(packet_type, packet_string)
        elseif type(SendPacket) == "function" then SendPacket(packet_type, packet_string)
        end
    end)
    sleep_hp(250)
end

local function send_action_packet(type_id, tx, ty, val)
    pcall(function()
        -- Disesuaikan dengan Struct TankPacket di API Docs:
        -- TankPacket: netid, secnetid, type, state, value, x, y, xspeed, yspeed, px, py, time, ...
        local pkt = { 
            type = type_id, 
            value = val, 
            px = tx, 
            py = ty,
            x = tx * 32,
            y = ty * 32
        }
        if type(sendPacketRaw) == "function" then sendPacketRaw(false, pkt)
        elseif type(SendPacketRaw) == "function" then SendPacketRaw(false, pkt)
        elseif type(sendRaw) == "function" then sendRaw(false, pkt)
        end
    end)
end

local function get_player_tile()
    local ok, player = call_api("getLocal")
    if ok and player and player.posX then return math.floor(player.posX / 32), math.floor(player.posY / 32) end
    return nil, nil
end

local function get_bot_name()
    local ok, player = call_api("getLocal")
    if ok and player and player.name then return player.name:upper() end
    return ""
end

local function inv(item_id)
    local ok, inventory = call_api("getInventory")
    if not ok or type(inventory) ~= "table" then return 0 end
    for _, item in pairs(inventory) do
        if item.id == item_id then return item.amount end
    end
    return 0
end

local function get_gems_count()
    -- Disesuaikan dengan API Docs: getGems() mengembalikan number langsung
    if type(getGems) == "function" then return getGems() end
    if type(GetGems) == "function" then return GetGems() end
    return 0
end

local function walk_to(tile_x, tile_y)
    local px, py = get_player_tile()
    if px == tile_x and py == tile_y then return true end
    
    -- Disesuaikan dengan API Docs: FindPath(x, y, check_only?)
    local ok, _ = call_api("findPath", tile_x, tile_y)
    if not ok and type(FindPath) == "function" then
        FindPath(tile_x, tile_y)
    end
    sleep_hp(math.random(config.path_delay_min, config.path_delay_max))
    
    -- Verifikasi Posisi Akhir
    local ax, ay = get_player_tile()
    return (ax == tile_x and ay == tile_y)
end

-- =================================================================
-- 2. DYNAMIC STORAGE SCANNER & TOTAL FAST DROP LOGIC
-- =================================================================
local function find_valid_drop_tile()
    local ok_t, tiles = call_api("getTiles")
    -- Disesuaikan dengan API Docs: getObjectList()
    local ok_o, objects = call_api("getObjectList")
    if not ok_o or type(objects) ~= "table" then
        ok_o, objects = call_api("getObjects")
    end

    if not ok_t or type(tiles) ~= "table" then return config.base_drop_x, config.base_drop_y end

    for i = 0, config.max_scan_range do
        local target_x = config.base_drop_x + i
        local target_y = config.base_drop_y
        local is_blocked = false
        local item_count = 0

        for _, tile in pairs(tiles) do
            if tile.x == target_x and tile.y == target_y then
                if tile.fg ~= 0 then is_blocked = true end
                break
            end
        end

        if ok_o and type(objects) == "table" then
            for _, obj in pairs(objects) do
                -- Disesuaikan dengan Struct WorldObject API Docs: pos (Vector2), amount, itemid
                local obj_x = obj.pos and math.floor(obj.pos.x / 32) or 0
                local obj_y = obj.pos and math.floor(obj.pos.y / 32) or 0
                if obj_x == target_x and obj_y == target_y then item_count = item_count + (obj.amount or 0) end
            end
        end

        if not is_blocked and item_count < config.max_object_per_tile then return target_x, target_y end
    end
    return config.base_drop_x, config.base_drop_y
end

local function warp_to_world(world_name, door_id)
    log_hp("Warping ke: " .. world_name)
    if door_id and door_id ~= "" then send_packet_hp(3, "action|join_request\nname|" .. world_name .. "|" .. door_id)
    else send_packet_hp(3, "action|join_request\nname|" .. world_name)
    end
    sleep_hp(config.warp_delay)
end

local function execute_fast_drop_all()
    local valid_x, valid_y = find_valid_drop_tile()
    if walk_to(valid_x, valid_y) then
        local ok, inventory = call_api("getInventory")
        if not ok or type(inventory) ~= "table" then return end
        
        log_hp("Melakukan INSTANT TOTAL DROP...")
        for _, item in pairs(inventory) do
            if item.id ~= config.pickaxe_id and item.amount > 0 then
                send_action_packet(2, valid_x, valid_y, item.amount)
                send_packet_hp(2, "action|drop\nitemID|" .. item.id)
                sleep_hp(60) 
            end
        end
    end
end

local function handle_storage_drop()
    warp_to_world(config.storage_world, config.storage_door)
    execute_fast_drop_all()
end

-- =================================================================
-- 3. WHITE-LIST FLEE SYSTEM (KABUR, FAST DROP, REHAT 2 MENIT)
-- =================================================================
local function is_player_owner(name_to_check)
    if not name_to_check then return false end
    local cleaned_name = name_to_check:upper():gsub("_", ""):gsub("`", "")
    
    for _, owner_name in ipairs(config.owner_names) do
        local cleaned_owner = owner_name:upper():gsub("_", ""):gsub("`", "")
        if cleaned_name:find(cleaned_owner) then return true end
    end
    return false
end

local function scan_and_flee_check()
    -- Disesuaikan dengan API Docs: getPlayerList() mengembalikan NetAvatar[]
    local ok, players = call_api("getPlayerList")
    if not ok or type(players) ~= "table" then
        ok, players = call_api("getPlayers")
    end

    if not ok or type(players) ~= "table" then return end
    
    local bot_name = get_bot_name()
    local stranger_detected = false
    
    for _, player in pairs(players) do
        if player.name then
            local p_name = player.name:upper()
            if p_name ~= bot_name and not is_player_owner(p_name) then
                stranger_detected = true
                log_hp("⚠️ TERDETEKSI ANCAMAN ORANG ASING: " .. player.name)
                break
            end
        end
    end
    
    if stranger_detected then
        log_hp("🚨 Protokol Flee Aktif! Kabur ke Gudang...")
        warp_to_world(config.storage_world, config.storage_door)
        execute_fast_drop_all()
        
        log_hp("⛔ Memulai mode tidur darurat...")
        local seconds_left = config.flee_sleep_duration_sec
        while seconds_left > 0 do
            log_hp("Sisa waktu rehat: " .. seconds_left .. " detik...")
            sleep_hp(30000)
            seconds_left = seconds_left - 30
        end
        
        log_hp("Waktu tidur selesai. Kembali ke medan kerja.")
        warp_to_world(config.farm_worlds[current_farm_index], "")
    end
end

-- =================================================================
-- 4. AUTO BUY PACKS & SHOP MANAGEMENT (ALOKASI GEMS)
-- =================================================================
local function check_and_spend_gems()
    local current_gems = get_gems_count()
    if current_gems >= 50000 then
        log_hp("💎 Gems mencapai " .. current_gems .. ". Memulai belanja aset...")
        send_packet_hp(2, "action|buy\nitem|buy_surgeon") 
        sleep_hp(math.random(1200, 1600))
        
        local remaining_gems = get_gems_count()
        local wl_to_buy = math.floor(remaining_gems / 2000)
        
        if wl_to_buy > 0 then
            for i = 1, wl_to_buy do
                send_packet_hp(2, "action|buy\nitem|world_lock")
                sleep_hp(math.random(1000, 1300))
            end
        end
    end
end

-- =================================================================
-- 5. ISOLATED BREAK WORLD LOGIC (PNB VERTICAL 3 BLOK KE ATAS)
-- =================================================================
local function execute_isolated_pnb()
    log_hp("Menuju WORLD BREAK khusus untuk PNB aman...")
    warp_to_world(config.break_world, config.break_door)

    if walk_to(config.pnb_x, config.pnb_y) then
        log_hp("Memulai proses PNB 3 Blok ke Atas...")
        
        while inv(config.block_id) > 0 do
            scan_and_flee_check() 
            local px, py = get_player_tile()
            if not px then break end
            
            local target_tiles = {
                {x = px, y = py - 1}, {x = px, y = py - 2}, {x = px, y = py - 3} 
            }

            for i = 1, 3 do
                if inv(config.block_id) > 0 then
                    send_action_packet(3, target_tiles[i].x, target_tiles[i].y, config.block_id)
                    sleep_hp(math.random(config.delay_place_min, config.delay_place_max))
                end
            end

            for i = 3, 1, -1 do 
                for hit = 1, config.hit_count do
                    send_action_packet(3, target_tiles[i].x, target_tiles[i].y, config.punch_action_id)
                    sleep_hp(math.random(config.delay_punch_min, config.delay_punch_max))
                end
            end
            sleep_hp(math.random(90, 140))
        end
    end
end

-- =================================================================
-- 6. REINFORCED FARMING & PLANTING LOGIC WITH DATA PASSING
-- =================================================================
local function trash_management()
    for _, item_id in ipairs(config.trash_items) do
        if inv(item_id) >= config.trash_count then
            send_packet_hp(2, "action|trash\nitemID|" .. item_id)
            send_packet_hp(2, "action|dialog_return\ndialog_name|trash_item\nitemID|" .. item_id .. "|\ncount|" .. config.trash_count)
            sleep_hp(math.random(350, 480))
        end
    end
end

-- Optimasi O(1) Matrix String Lookup
local function is_tile_blacklisted(x, y)
    local key = x .. ":" .. y
    return blacklisted_tiles[key] == true
end

local function set_tile_blacklist(x, y)
    local key = x .. ":" .. y
    blacklisted_tiles[key] = true
end

local function check_world_cleared(tiles)
    if type(tiles) ~= "table" then return true end
    for _, tile in pairs(tiles) do
        if tile.fg == seed_id and tile.readyharvest == true then return false end
    end
    return true
end

-- Menerima data tiles dari loop utama (Mencegah pemanggilan getTiles berulang kali)
local function do_harvest_phase(tiles)
    if type(tiles) ~= "table" then return end

    for _, tile in pairs(tiles) do
        scan_and_flee_check() 
        
        if tile.fg == seed_id and tile.readyharvest == true then
            if inv(config.block_id) >= config.trigger_pnb_blocks then
                execute_isolated_pnb()
                warp_to_world(config.farm_worlds[current_farm_index], "")
                return -- Keluar fase untuk me-refresh data tile yang baru
            end

            if walk_to(tile.x, tile.y) then
                send_action_packet(3, tile.x, tile.y, config.punch_action_id)
                sleep_hp(math.random(config.delay_punch_min, config.delay_punch_max))
            end
        end
    end
end

-- Menerima data tiles dari loop utama
local function do_planting_phase(tiles)
    if type(tiles) ~= "table" then return end

    for _, tile in pairs(tiles) do
        scan_and_flee_check() 
        
        if tile.fg == 0 and inv(seed_id) > 0 and not is_tile_blacklisted(tile.x, tile.y) then
            if global_planted_counter >= config.target_planted_per_world then break end

            local ok_b, below = call_api("getTile", tile.x, tile.y + 1)
            if ok_b and below and below.fg ~= 0 and below.fg % 2 == 0 then
                
                if walk_to(tile.x, tile.y) then
                    send_action_packet(3, tile.x, tile.y, seed_id)
                    sleep_hp(math.random(config.delay_plant_min, config.delay_plant_max))
                    
                    local ok_v, check_tile = call_api("getTile", tile.x, tile.y)
                    if ok_v and check_tile and check_tile.fg == seed_id then
                        global_planted_counter = global_planted_counter + 1
                    else
                        set_tile_blacklist(tile.x, tile.y) -- Simpan dalam format O(1)
                    end
                end
            end
        end
    end
end

-- Helper khusus mengecek nama world saat ini (Disesuaikan dengan API Docs: GetWorldName / getCurrentWorldName)
local function get_current_world_name_hp()
    if type(GetWorldName) == "function" then return GetWorldName() end
    if type(getCurrentWorldName) == "function" then return getCurrentWorldName() end
    return ""
end

-- =================================================================
-- 7. MAIN LOOP EXECUTION WITH GLOBAL FAULT TOLERANCE (PCALL WRAPPED)
-- =================================================================
log_hp("Script Enterprise V3.1 Resmi Berjalan Dengan Optimasi O(1) & Data Passing!")

while true do
    -- Menggunakan pcall aman di loop utama agar script tidak mati jika terjadi error tak terduga
    local status, err = pcall(function()
        trash_management()
        check_and_spend_gems() 

        local current_world_name = config.farm_worlds[current_farm_index]
        local active_world_name = get_current_world_name_hp()
        
        if active_world_name ~= "" and active_world_name ~= current_world_name then
            warp_to_world(current_world_name, "")
            blacklisted_tiles = {} -- Reset Hash Map saat ganti world
            global_planted_counter = 0
        else
            -- Mengambil data TILES SEKALI saja untuk satu putaran siklus kerja (Optimasi Utama)
            local ok_t, shared_tiles = call_api("getTiles")
            
            if ok_t and type(shared_tiles) == "table" then
                do_harvest_phase(shared_tiles)

                if inv(config.block_id) >= 10 then
                    execute_isolated_pnb()
                    warp_to_world(current_world_name, "")
                end

                do_planting_phase(shared_tiles)

                local is_cleared = check_world_cleared(shared_tiles)
                local is_target_reached = (global_planted_counter >= config.target_planted_per_world)
                local is_seed_empty = (inv(seed_id) == 0)

                if is_cleared and (is_target_reached or is_seed_empty) then
                    log_hp("World Selesai. Menuju gudang...")
                    handle_storage_drop()

                    current_farm_index = current_farm_index + 1
                    if current_farm_index > #config.farm_worlds then
                        current_farm_index = 1
                    end
                end
            end
        end
    end)

    if not status then
        log_hp("⚠️ Pcall mendeteksi internal error: " .. tostring(err) .. ". Melanjutkan loop demi stabilitas...")
        sleep_hp(2000) -- Beri jeda 2 detik sebelum mencoba ulang siklus agar tidak spamming error
    end

    sleep_hp(config.loop_delay + math.random(-30, 45))
end
