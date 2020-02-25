local spawnList = {}
local spawnListSize = 0
local maxWidth = 0
local maxHeight = 0

function addVehicle(spawnFunction, max_width, max_height, count)
    spawnListSize = spawnListSize + 1
    spawnList[spawnListSize] = {spawnFunction, count}
    maxWidth = math.max(maxWidth, max_width)
    maxHeight = math.max(maxHeight, max_height)
end

function shuffle(tbl)
  size = #tbl
  for i = size, 1, -1 do
    local rand = math.random(i)
    tbl[i], tbl[rand] = tbl[rand], tbl[i]
  end
  return tbl
end

local VEH_ID = 0
function nextVehicleID()
    VEH_ID = VEH_ID + 1
    return VEH_ID
end

registercallback("onStageEntry", function()
    if net.host then
        local canSpawn = {}
        local count = 0
        local stageWidth, _ = Stage.getDimensions()
        for _, flooor in pairs(Object.find("B"):findAll()) do
            if flooor.x > 2 * maxWidth and flooor.x < stageWidth - 2 * maxWidth then
                count = count + 1
                canSpawn[count] = {flooor.x, flooor.y - maxHeight}
            end
        end
        local canSpawnLength = count
        spawnList = shuffle(spawnList)
        if spawnListSize > 0 then
            for i = 1, spawnListSize do
                if count > 0 then
                    if math.random(1, 2) == 1 then
                        for j = 1, spawnList[i][2] do
                            local prob = 1
                            if j > 1 then prob = math.random(1, 2) end
                            if prob == 1 then
                                chosenOne = math.random(1, canSpawnLength)
                                while canSpawn[chosenOne][1] == -1 do
                                    chosenOne = math.random(1, canSpawnLength)
                                end
                                local inst = spawnList[i][1](canSpawn[chosenOne][1], canSpawn[chosenOne][2])
                                inst:getData().id = nextVehicleID()
                                canSpawn[chosenOne][1] = -1
                                count = count - 1
                            end
                        end
                    end
                end
            end
        end
    end
end, 1000)

registercallback("onStageEntry", function()
    for _, p in ipairs(misc.players) do
        p:set("canrope", 1)
        p:getData().driving = nil
    end
end, 900)