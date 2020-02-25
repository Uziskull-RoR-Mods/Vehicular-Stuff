-- Made by Uziskull

--------------------
-- Global Sprites --
--------------------

emptySprite = Sprite.load("vehicular_stuff_empty_sprite", "sprites/empty", 1, 0, 0)

----------------------
-- Global Constants --
----------------------

ACTIVITY_WARTHOG_DRIVER = 15001
ACTIVITY_WARTHOG_TURRET = 15002

ACTIVITY_POGO_DRIVER = 15003

-----------
-- Flags --
-----------

local noWarthog = modloader.checkFlag("vehicular_disable_warthog")
local noPogo = modloader.checkFlag("vehicular_disable_pogo")
-- local noChaircopter = modloader.checkFlag("vehicular_disable_chaircopter")

-----------------------

require("vehicleManager")
if not noWarthog then
    require("warthog")
end
if not noPogo then
    require("pogo")
end
-- if not noChaircopter then
    -- require("chaircopter")
-- end


-- debug
debugDone = false
registercallback("onGameEnd", function() debugDone = false end)
registercallback("onStep", function()
    local p = net.online and net.localPlayer or misc.players[1] 
    if not debugDone then
        local tp = Object.find("Teleporter"):find(1)
        tp:set("active", 3)
        p.x, p.y = tp.x, tp.y - 10
        p:set("true_invincible", 1)
        debugDone = true
    end
    local t = warthog:findAll()
    for _, pi in ipairs(pogo:findAll()) do
        table.insert(t, pi)
    end
    for i, ii in ipairs(t) do
        if input.checkKeyboard("numpad"..i) == input.PRESSED then
            p.x, p.y = ii.x, ii.y - 10
            break
        end
    end
end)