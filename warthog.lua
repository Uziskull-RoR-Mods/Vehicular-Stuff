-- Made by Uziskull

----------------------
-- Flags
----------------------

local noSound = modloader.checkFlag("vehicular_no_sound")
local noSoundWarthog = modloader.checkFlag("vehicular_warthog_no_sound")

----------------------
-- Sound
----------------------

local soundSkrrt = Sound.load("sound_warthog_skrrt", "sound/warthog/skrrt")
local soundIdle = Sound.load("sound_warthog_idle", "sound/warthog/idle")
local soundAccel = Sound.load("sound_warthog_accel", "sound/warthog/accel")
local soundMax = Sound.load("sound_warthog_max", "sound/warthog/max")
local soundPew = Sound.load("sound_warthog_pew", "sound/warthog/pew")

----------------------
-- Objects and sprites
----------------------
local smallObject = Object.find("EfGold")
local jumpPad = Object.find("Geyser")
local jumpPadSound = Sound.find("Geyser")

local important = {
    warthogCenterX = 40,-- 30, SMALL
    warthogCenterY = 42,-- 31, SMALL
    turretOffsetX = -23,-- -16, SMALL
    turretOffsetY = -23,-- -16, SMALL
    wheelRadius = 16,
    driverDoorHeight = 18, -- 13, SMALL
    jumpOffset = 9
}

local sprites = {
    idle = Sprite.load("warthog_idle", "sprites/warthog/idle", 1, important.warthogCenterX, important.warthogCenterY),
    move = Sprite.load("warthog_move", "sprites/warthog/move", 8, important.warthogCenterX, important.warthogCenterY),
    idleTurret = Sprite.load("warthog_idle_turret", "sprites/warthog/idle_turret", 1, important.warthogCenterX, important.warthogCenterY),
    moveTurret = Sprite.load("warthog_move_turret", "sprites/warthog/move_turret", 8, important.warthogCenterX, important.warthogCenterY),
    jump = Sprite.load("warthog_jump", "sprites/warthog/jump", 1, important.warthogCenterX, important.warthogCenterY + 9),
    jumpTurret = Sprite.load("warthog_jump_turret", "sprites/warthog/jump_turret", 1, important.warthogCenterX, important.warthogCenterY + 9),
    
    turretSprite = Sprite.load("warthog_turret", "sprites/warthog/turret", 1, 0, 16),--11), SMALL
    --turretBullet = Sprite.load("warthog_turret_bullet", "warthog/bullet", 1, 9, 0)
    mask = Sprite.load("warthog_mask", "sprites/warthog/mask", 1, important.warthogCenterX, important.warthogCenterY)
}

warthog = Object.new("Warthog")
warthog.depth = 5
warthog.sprite = sprites.idle
turret = Object.new("Warthog Turret")
turret.depth = 5
turret.sprite = sprites.turretSprite

local function getPos(player, thing)
    local thingObj = thing:getObject()
    local turnMultiplier = thing.xscale
    if thingObj == warthog then
        local jumpOffset = (thing.sprite == sprites.jump or thing.sprite == sprites.jumpTurret) and important.jumpOffset or 0
        return thing.x + turnMultiplier, thing.y - (player.sprite.height - player.sprite.yorigin) - important.driverDoorHeight - jumpOffset
    elseif thingObj == turret then
        local distanceToHandle = (player.sprite.width - player.sprite.xorigin) / 2
        return thing.x + turnMultiplier * distanceToHandle, thing.y - (player.sprite.height - player.sprite.yorigin)
    end
end

local function findVehicleById(vehObj, id)
    local inst = nil
    for _, i in ipairs(vehObj:findAll()) do
        if i:getData().id == id then
            inst = i
            break
        end
    end
    return inst
end

warthog:addCallback("create", function(self)
    local instData = self:getData()
    self.mask = sprites.mask

    -----------
    -- Flags --
    -----------

    if net.host then
        self.xscale = math.random() * 10 <= 5 and 1 or -1
    end
    instData.turretInst = nil
    instData.drawTurretSeatPopup = 0
    instData.turretEnterCooldown = 0
    
    instData.driverSeatTaken = 0
    instData.drawDriverSeatPopup = 0
    instData.driverEnterCooldown = 0
    
    instData.jumpPadCooldown = 0
    instData.collidingWall = 0
    
    -------------
    -- Physics --
    -------------
    
    instData.accelX = 0
    instData.accelY = 0.26
    instData.speedX = 0
    instData.speedY = 0
    
    ------------------
    -- Unstuck code --          -- seeing this one year later is messing with my mind, the fuck's goin on here
    ------------------
    -- host only
    if net.host then
        local smallObjectInstance = smallObject:create(0, 0)
        while smallObjectInstance:collidesMap(self.x, self.y) do
            self.y = self.y - 1
        end
        if self:collidesMap(self.x, self.y) then
            local unstuck = 0
            for i = 0,self.sprite.width + 1 do
                if unstuck == 0 then
                    if not self:collidesMap(self.x - i, self.y) 
                       and self:collidesMap(self.x - i, self.y + 1) then
                        unstuck = i * -1
                    elseif not self:collidesMap(self.x + i, self.y)
                       and self:collidesMap(self.x + i, self.y + 1) then
                        unstuck = i
                    end
                end
            end
            self.x = self.x + unstuck
        end
        smallObjectInstance:delete()
    end
end)

warthog:addCallback("draw", function(self)
    local instData = self:getData()
    if instData.turretInst ~= nil and instData.turretInst:isValid() then
        if instData.speedY < 0 then
            self.sprite = sprites.jumpTurret
        elseif instData.speedX ~= 0 then
            self.sprite = sprites.moveTurret
        else
            self.sprite = sprites.idleTurret
        end
    else
        if instData.speedY < 0 then
            self.sprite = sprites.jump
        elseif instData.speedX ~= 0 then
            self.sprite = sprites.move
        else
            self.sprite = sprites.idle
        end
    end
end)

warthogRoadkillPacket = net.Packet("Roadkill Warthog", function(sender, baddie)
    local actualBaddie = baddie:resolve()
    if actualBaddie ~= nil then
        actualBaddie:kill()
    end
end)

warthog:addCallback("step", function(self)
    local instData = self:getData()
    -------------------
    ---- cooldowns ----
    -------------------
    
    instData.turretEnterCooldown = math.max(instData.turretEnterCooldown - 1, 0)
    instData.driverEnterCooldown = math.max(instData.driverEnterCooldown - 1, 0)
    instData.jumpPadCooldown = math.max(instData.jumpPadCooldown - 1, 0)

    -----------------
    ---- physics ----
    -----------------
    
    if instData.collidingWall ~= 0 then
        if not self:collidesMap(self.x, self.y) and not self:collidesMap(self.x + instData.collidingWall, self.y) then
            instData.collidingWall = 0
        end
    end
    
    -- slow down (and even more if you're facing the other way)
    if instData.accelX == 0 and self:collidesMap(self.x, self.y + 1) then
        if soundMax:isPlaying() then
            soundMax:stop()
        end
        local fasts = instData.speedX
        if fasts > 0 then
            instData.speedX = fasts - 0.50
            if fasts - 0.50 < 0 then
                instData.speedX = 0
            else
                instData.speedX = fasts - 0.50
            end
            if self.xscale == -1 then
                if fasts - 0.50 < 0 then
                    instData.speedX = 0
                else
                    instData.speedX = fasts - 0.50
                end
            end
        elseif fasts < 0 then
            instData.speedX = fasts + 0.50
            if fasts + 0.50 > 0 then
                instData.speedX = 0
            else
                instData.speedX = fasts + 0.50
            end
            if self.xscale == 1 then
                if fasts + 0.50 > 0 then
                    instData.speedX = 0
                else
                    instData.speedX = fasts + 0.50
                end
            end
        end
    end
    
    -- apply acceleration
    local oldSpeed = instData.speedX
    local speed = instData.speedX + instData.accelX
    if math.abs(speed) > 7.5 then
        if speed > 7.5 then
            speed = 7.5
        else --if speed < -7.5 then
            speed = -7.5
        end
        if not (noSound or noSoundWarthog) then
            if soundAccel:isPlaying() then
                soundAccel:stop()
            end
            if not soundMax:isPlaying() then
                --soundMax:loop()
                soundMax:play(1.25, 0.5)
            end
        end
    end
    instData.speedX = speed
    
    -- apply speed
    local oldX = self.x
    self.x = self.x + speed
    
    -- if speed is at max, R O A D K I L L
    -- host only
    if net.host then
        if math.abs(speed) >= 5 or instData.speedY >= 7.5 then
            local enemyList = ParentObject.find("enemies")
            for _, baddie in ipairs(enemyList:findAll()) do
                -- kek check: can't roadkill stuff larger than you
                if baddie.sprite.height <= self.sprite.height and baddie.sprite.width <= self.sprite.width then
                    if self:collidesWith(baddie, self.x, self.y) then
                        baddie:kill()
                        warthogRoadkillPacket:sendAsHost(net.ALL, nil, baddie:getNetIdentity())
                    end
                end
            end
        end
    end
    
    local collisionStep = oldX > self.x and -1 or 1
    
    -- check collision
    if self:collidesMap(self.x, self.y) and not self:collidesMap(oldX, self.y) then
        local collisionX = oldX
        while not self:collidesMap(collisionX, self.y) do
            collisionX = collisionX + collisionStep
        end
        
        -- only climb obstacle if wheelHeight is enough and if not in air
        if not self:collidesMap(collisionX, self.y - important.wheelRadius) and instData.speedY == 0 then
            self.y = self.y - important.wheelRadius
            while not self:collidesMap(collisionX, self.y + 1) do
                self.y = self.y + 1
            end
        else
            -- a wild wall appeared
            self.x = collisionX - collisionStep
            instData.accelX = 0
            instData.speedX = 0
            instData.collidingWall = collisionStep
        end
        -- smallObjectInstance:delete()
    end
    
    -- jump pads!
    if instData.jumpPadCooldown == 0 then
        local closestJumpPad = jumpPad:findNearest(self.x, self.y)
        if closestJumpPad ~= nil then
            if closestJumpPad:isValid() then
                if self:collidesWith(closestJumpPad, self.x, self.y) then
                    instData.speedY = -12
                    jumpPadSound:play()
                    instData.jumpPadCooldown = 10
                end
            end
        end
    end
    
    -- fall down if in air
    local mightBeStuck = false
    --local smallObjectInstance = smallObject:create(0, 0)
    if not self:collidesMap(self.x, self.y + 1) then
        instData.speedY = instData.speedY + instData.accelY
        if instData.speedY > 10 then
            instData.speedY = 10
        end
        mightBeStuck = true
    else
        if instData.speedY > 0 then
            instData.speedY = 0
        end
    end
    --smallObjectInstance:delete()
    
    local oldY = self.y
    self.y = self.y + instData.speedY
    
    if mightBeStuck then
        -- if you hit a ceiling, don't phase through it
        -- also, if you hit the floor too hard, don't phase through it
        local multiplier = -1
        if oldY > self.y then
            multiplier = 1
        end
        while self:collidesMap(self.x, self.y) do
            self.y = self.y + multiplier
            if instData.speedY < 0 then
                instData.speedY = 0
            end
        end
    end
    --smallObjectInstance:delete()
end)

turret:addCallback("create", function(self)
    local instData = self:getData()
    instData.turretShotCooldown = 6
    instData.warthog = nil
end)

turret:addCallback("draw", function(self)
    local instData = self:getData()
    local facingMultiplier = instData.warthog.xscale
    self.x = instData.warthog.x + important.turretOffsetX * facingMultiplier
    self.y = instData.warthog.y + important.turretOffsetY
end)

turret:addCallback("step", function(self)
    local instData = self:getData()
    instData.turretShotCooldown = math.max(instData.turretShotCooldown - 1, 0)
end)

turret:addCallback("destroy", function(self)
    local instData = self:getData()
    local warthogData = instData.warthog:getData()
    warthogData.turretEnterCooldown = 60
    warthogData.driverEnterCooldown = 60
    warthogData.drawTurretSeatPopup = 1
    warthogData.turretInst = nil
end)

----------------------
-- Non-buff Packets --
----------------------
warthogCreatePacket = net.Packet("Create Warthog", function(sender, numWarthogs, ...) -- x1, y1, color1, x2, y2, color2, x3, y3, color3, x4, y4, color4)
    local warthogs = {...}
    for i = 1, numWarthogs do
        j = 1 + (i - 1) * 4
        local winst = warthog:create(warthogs[j], warthogs[j+1])
        winst:getData().id = warthogs[j+2]
        winst.xscale = warthogs[j+3]
    end
end)
requestWarthogPacket = net.Packet("Request Warthog", function(sender)
    local warthogs = {}
    for _, warthogInst in ipairs(warthog:findAll()) do
        table.insert(warthogs, warthogInst.x)
        table.insert(warthogs, warthogInst.y)
        table.insert(warthogs, warthogInst:getData().id)
        table.insert(warthogs, warthogInst.xscale)
    end
    if #warthogs > 0 then
        warthogCreatePacket:sendAsHost(net.DIRECT, sender, #warthogs / 4, table.unpack(warthogs))
    end
end)
warthogJumpPacket = net.Packet("Jump Warthog", function(sender, actualPlayer, warthogID)
    if net.host then
        local p = actualPlayer:resolve()
        if p ~= nil then
            warthogJumpPacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), warthogID)
        end
    end
    local inst = findVehicleById(warthog, warthogID)
    if inst ~= nil then
        if inst:isValid() then
            if inst:collidesMap(inst.x, inst.y + 1) then
                inst:getData().speedY = -8
                if not (noSound or noSoundWarthog) then
                    jumpPadSound:play()
                end
            end
        end
    end
end)
turretFirePacket = net.Packet("Fire Warthog Turret", function(sender, actualPlayer, turretID, x, y, angle)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if net.host then
            turretFirePacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), turretID, x, y, angle)
        end
        ParticleType.find("Spark"):burst("above", x, y, 1)
        local bullet = p:fireBullet(x, y, angle, 1000, 1, Sprite.find("sparks1"), DAMAGER_NO_PROC + DAMAGER_NO_RECALC)
        bullet:set("knockback", 0)
        if soundPew:isPlaying() then
            soundPew:stop()
        end
        if not (noSound or noSoundWarthog) then
            soundPew:play(1 + math.random() / 2, 0.2)
        end
        local inst = findVehicleById(turret, turretID)
        if inst ~= nil and inst:isValid() then
            inst:getData().turretShotCooldown = 6
        end
    end
end)

warthogStepPacket = net.Packet("Step Warthog", function(sender, actualPlayer, x, y, warthogID, tEC, dST, dEC, jPC, cW, aX, aY, sX, sY, xS, tST)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if p ~= net.localPlayer then
            if net.host then
                warthogStepPacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), x, y, warthogID, tEC, dST, dEC, jPC, cW, aX, aY, sX, sY, xS, tST)
            end
            local inst = findVehicleById(warthog, warthogID)
            if inst == nil then
                inst = warthog:create(x, y)
            end
            if inst:isValid() then
                local instData = inst:getData()
                
                inst.x, inst.y = x, y
                
                local xx, yy = getPos(p, inst)
                p:set("ghost_x", xx):set("ghost_y", yy)
                
                instData.turretEnterCooldown = tEC
                instData.driverSeatTaken = dST
                instData.driverEnterCooldown = dEC
                instData.jumpPadCooldown = jPC
                instData.collidingWall = cW
                instData.accelX = aX
                instData.accelY = aY
                instData.speedX = sX
                instData.speedY = sY
                inst.xscale = xS
                local turretInst = nil
                if tST > -1 then
                    turretInst = findVehicleById(turret, tST)
                end
                instData.turretInst = turretInst
            end
        end
    end
end)
turretStepPacket = net.Packet("Step Warthog Turret", function(sender, actualPlayer, turretID, turretAngle, turretXScale, turretShotCooldown)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if p ~= net.localPlayer then
            if net.host then
                turretStepPacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), turretID, turretAngle, turretXScale, turretShotCooldown)
            end
            local inst = findVehicleById(turret, turretID)
            if inst ~= nil then
                if inst:isValid() then
                    local instData = inst:getData()
                    local xx, yy = getPos(p, inst)
                    p:set("ghost_x", xx):set("ghost_y", yy)
                
                    inst.angle = turretAngle
                    inst.xscale = turretXScale
                    instData.turretShotCooldown = turretShotCooldown
                end
            end
        end
    end
end)
warthogEnterPacket = net.Packet("Enter Warthog", function(sender, actualPlayer, warthogID)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if net.host then
            warthogEnterPacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), warthogID)
        end
        p:set("activity", ACTIVITY_WARTHOG_DRIVER)
    end
    local inst = findVehicleById(warthog, warthogID)
    if inst ~= nil then
        if inst:isValid() then
            local instData = inst:getData()
            instData.driverEnterCooldown = 60
            instData.drawDriverSeatPopup = 0
            instData.driverSeatTaken = 1
        end
    end
    if p ~= nil then
        p:getData().driving = inst
    end
end)
warthogLeavePacket = net.Packet("Leave Warthog", function(sender, actualPlayer, warthogID)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if net.host then
            warthogLeavePacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), warthogID)
        end
        p:set("activity", 0):set("canrope", 1)
        p:getData().driving = nil
    end
    local inst = findVehicleById(warthog, warthogID)
    if inst ~= nil then
        if inst:isValid() then
            local instData = inst:getData()
            instData.accelX = 0
            instData.drawDriverSeatPopup = 1
            instData.driverSeatTaken = 0
            instData.driverEnterCooldown = 60
            instData.turretEnterCooldown = 60
        end
    end
end)
outsideScreenWarthogPacket = net.Packet("Outside Screen Warthog", function(sender, actualPlayer, warthogID)
    local p = actualPlayer:resolve()
    local inst = findVehicleById(warthog, warthogID)
    if inst ~= nil and inst:isValid() then
        for _, turretInst in ipairs(turret:findAll()) do
            if turret:getData().warthog:getData().id == warthogID then
                turretInst:destroy()
                break
            end
        end
        inst:destroy()
    end
end)
turretEnterPacket = net.Packet("Enter Warthog Turret", function(sender, actualPlayer, warthogID, turretID, x, y)
    local p = actualPlayer:resolve()
    local turretInst = turret:create(x, y)
    if net.host then
        turretInst:getData().id = nextVehicleID()
    else
        turretInst:getData().id = turretID
    end
    local inst = findVehicleById(warthog, warthogID)
    turretInst:getData().warthog = inst
    if p ~= nil then
        if net.host then
            turretEnterPacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), warthogID, turretInst:getData().id, x, y)
        end
        p:set("activity", ACTIVITY_WARTHOG_TURRET)
        p:getData().driving = turretInst
    end
    if inst ~= nil and inst:isValid() then
        local warthogData = inst:getData()
        warthogData.turretEnterCooldown = 60
        warthogData.turretInst = turretInst
    end
    if p ~= nil then
        if p:getFacingDirection() == 0 then
            turretInst.xscale = 1
        else
            turretInst.xscale = -1
        end
    end
end)
turretLeavePacket = net.Packet("Leave Warthog Turret", function(sender, actualPlayer, turretID)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if net.host then
            turretLeavePacket:sendAsHost(net.ALL, nil, p:getNetIdentity(), turretID)
        end
        p:set("activity", 0):set("canrope", 1)
        p:getData().driving = nil
    end
    local inst = findVehicleById(turret, turretID)
    if inst ~= nil then
        if inst:isValid() then
            inst:destroy()
        end
    end
end)
outsideScreenTurretPacket = net.Packet("Outside Screen Warthog Turret", function(sender, actualPlayer, turretID)
    local p = actualPlayer:resolve()
    local inst = findVehicleById(turret, turretID)
    if inst ~= nil and inst:isValid() then
        inst:destroy()
    end
    if p ~= nil then
        p:set("activity", 0):set("canrope", 1)
        p:getData().driving = nil
    end
end)

----------------------
-- Actual things
----------------------
addVehicle(function(x,y)
    return warthog:create(x,y)
end, sprites.idle.width, sprites.idle.height, 1)

registercallback("onStageEntry", function()
    if not net.host then
        requestWarthogPacket:sendAsClient()
    end
end)

registercallback("onPlayerDeath", function(player)
    local drivingThing = player:getData().driving
    if drivingThing ~= nil then
        local drivingObj = drivingThing:getObject()
        if drivingObj == turret then
            drivingThing:destroy()
        elseif drivingObj == warthog then
            drivingThing:getData().accelX = 0
            local instData = drivingThing:getData()
            instData.drawDriverSeatPopup = 1
            instData.driverSeatTaken = 0
            instData.driverEnterCooldown = 60
        end
    end
end)

registercallback("onPlayerStep", function(player)
    local playerData = player:getData()

    if playerData.driving ~= nil then
        local drivingObj = playerData.driving:getObject()
        if drivingObj == turret or drivingObj == warthog then
            player:set("pVspeed", 0)
            for _, i in ipairs({0, 2, 3, 4, 5}) do
                player:setAlarm(i, math.max(player:getAlarm(i), 1))
            end
            player:set("canrope", 0)
        end
        if drivingObj == turret then
            local turretInstance = playerData.driving
            if turretInstance:isValid() then
                player.x, player.y = getPos(player, turretInstance)
                
                if net.host then
                    if player:get("outside_screen") == 89 then
                        local tID = turretInstance:getData().id
                        turretInstance:destroy()
                        player:set("activity", 0):set("canrope", 1)
                        playerData.driving = nil
                        outsideScreenTurretPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), tID)
                    end
                end
            end
            
        elseif drivingObj == warthog then
            local warthogInstance = playerData.driving
            if warthogInstance:isValid() then
                player.x, player.y = getPos(player, warthogInstance)
                
                if net.host then
                    if player:get("outside_screen") == 89 then
                        local turretInstance = warthogInstance:getData().turretInst
                        if turretInstance ~= nil and turretInstance:isValid() then
                            turretInstance:destroy()
                            warthogInstance:getData().turretInst = nil
                        end
                        local wID = warthogInstance:getData().id
                        warthogInstance:destroy()
                        player:set("activity", 0):set("canrope", 1)
                        playerData.driving = nil
                        
                        outsideScreenWarthogPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), wID)
                    end
                end
            else
                playerData.driving = nil
            end
            
            if not (noSound or noSoundWarthog) then
                if not soundIdle:isPlaying() then
                    soundIdle:play(1, 0.3)
                end
            end
        end
    end
    if playerData.driving == nil then
        local pActivity = player:get("activity")
        if pActivity == ACTIVITY_WARTHOG_DRIVER or pActivity == ACTIVITY_WARTHOG_TURRET then
            player:set("activity", 0):set("canrope", 1)
        end
    end
    
    if not net.online or player == net.localPlayer then
        local holding = {}
        for _, dir in ipairs({"up", "down", "left", "right"}) do
            holding[dir] = player:control(dir) == input.HELD
        end
        
        local warthogInstance = warthog:findNearest(player.x, player.y)
        local turretInstance = nil
        if playerData.driving ~= nil and playerData.driving:getObject() == turret then
            turretInstance = playerData.driving
        end
        if turretInstance ~= nil and turretInstance:isValid() then
            local turretData = turretInstance:getData()
            -- turning and turret controls
            local playerFacing = player:getFacingDirection() == 0 and 1 or -1
            if playerFacing ~= turretInstance.xscale then
                turretInstance.xscale = playerFacing
                turretInstance.angle = turretInstance.angle * -1
            end
            if player:control("enter") == input.PRESSED and warthogInstance:getData().turretEnterCooldown == 0 then
                if not net.host then
                    turretLeavePacket:sendAsClient(player:getNetIdentity(), turretInstance:getData().id)
                else
                    -- exit
                    local tID = turretInstance:getData().id
                    turretInstance:destroy()
                    player:set("activity", 0):set("canrope", 1)
                    playerData.driving = nil
                    
                    turretLeavePacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), tID)
                end
            elseif player:control("ability1") == input.HELD and turretData.turretShotCooldown == 0 then
                local angle = turretInstance.angle
                local facingMultiplier = turretInstance.xscale
                local hypo = math.sqrt((turretInstance.sprite.height - 1)^2 + turretInstance.sprite.width^2)
                local baseAngle = math.atan((turretInstance.sprite.height - 1) / turretInstance.sprite.width) * 180 / math.pi
                local finalX = turretInstance.x + hypo * math.cos((baseAngle + angle * facingMultiplier) * math.pi / 180) * facingMultiplier
                local finalY = turretInstance.y - hypo * math.sin((baseAngle + angle * facingMultiplier) * math.pi / 180)
                if facingMultiplier == -1 then
                    angle = angle + 180
                end
                if not net.host then
                    turretFirePacket:sendAsClient(player:getNetIdentity(), turretInstance:getData().id, finalX, finalY, angle)
                else
                    ParticleType.find("Spark"):burst("above", finalX, finalY, 1)
                    local bullet = player:fireBullet(finalX, finalY, angle, 1000, 1, Sprite.find("sparks1"), DAMAGER_NO_PROC + DAMAGER_NO_RECALC)
                    bullet:set("knockback", 0)
                    if soundPew:isPlaying() then
                        soundPew:stop()
                    end
                    if not (noSound or noSoundWarthog) then
                        soundPew:play(1 + math.random() / 2, 0.2)
                    end
                    turretData.turretShotCooldown = 6
                    
                    turretFirePacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), turretInstance:getData().id, finalX, finalY, angle)
                end
            end
            if holding.up then
                if turretInstance.xscale == 1 and turretInstance.angle < 35 then
                    turretInstance.angle = turretInstance.angle + 1
                elseif turretInstance.xscale == -1 and turretInstance.angle > -35 then
                    turretInstance.angle = turretInstance.angle - 1
                end
            elseif holding.down then
                if turretInstance.xscale == 1 and turretInstance.angle > -35 then --0 then
                    turretInstance.angle = turretInstance.angle - 1
                elseif turretInstance.xscale == -1 and turretInstance.angle < 35 then --0 then
                    turretInstance.angle = turretInstance.angle + 1
                end
            end
        end
        
        if warthogInstance ~= nil then
            if warthogInstance:isValid() then
                local warthogData = warthogInstance:getData()
                
                if warthogData.turretInst ~= nil and not warthogData.turretInst:isValid() then
                    warthogData.turretInst = nil
                end
                
                if playerData.driving ~= nil and playerData.driving == warthogInstance then
                    -- turning and driver controls
                    local playerFacing = player:getFacingDirection() == 0 and 1 or -1
                    if playerFacing ~= warthogInstance.xscale then
                        warthogInstance.xscale = playerFacing
                        warthogInstance.x = warthogInstance.x - 1 * playerFacing -- quick fix to fix bad graphics
                    end
                    if player:control("jump") == input.PRESSED then
                        if not net.host then
                            warthogJumpPacket:sendAsClient(player:getNetIdentity(), warthogInstance:getData().id)
                        else
                            if warthogInstance:collidesMap(warthogInstance.x, warthogInstance.y + 1) then
                                warthogData.speedY = -8
                                if not (noSound or noSoundWarthog) then
                                    jumpPadSound:play()
                                end
                            end
                            
                            warthogJumpPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), warthogInstance:getData().id)
                        end
                    end
                    if holding.right and not holding.left then
                        if warthogData.collidingWall ~= 1 then
                            warthogData.collidingWall = 0
                            if warthogData.accelX < 0.5 then
                                if warthogData.accelX < 0 then
                                    warthogData.accelX = 0
                                    if warthogData.speedX < -3.5 then
                                        if not (noSound or noSoundWarthog) then
                                            if not soundSkrrt:isPlaying() then
                                                soundSkrrt:play(0.9 + math.random() / 5, 0.5)
                                            end
                                        end
                                    end
                                end
                                
                                -- accelerate: if going from nothing, revv it up
                                if warthogData.accelX == 0 then
                                    if not (noSound or noSoundWarthog) then
                                        if soundMax:isPlaying() then
                                            soundMax:stop()
                                        end
                                        if not soundAccel:isPlaying() then
                                            soundAccel:play(0.5 + math.abs(warthogData.speedX) / 7.5, 0.3)
                                        end
                                    end
                                    if warthogData.speedX == 0 then
                                        warthogData.accelX = warthogData.accelX + 0.005
                                    else
                                        warthogData.accelX = warthogData.accelX + 0.5
                                    end
                                else
                                    warthogData.accelX = warthogData.accelX + 0.005
                                end
                            end
                        end
                    elseif holding.left and not holding.right then
                        if warthogData.collidingWall ~= -1 then
                            warthogData.collidingWall = 0
                            if warthogData.accelX > -0.5 then
                                if warthogData.accelX > 0 then
                                    warthogData.accelX = 0
                                    if warthogData.speedX > 3.5 then
                                        if not (noSound or noSoundWarthog) then
                                            if not soundSkrrt:isPlaying() then
                                                soundSkrrt:play(0.9 + math.random() / 5, 0.5)
                                            end
                                        end
                                    end
                                end
                                
                                -- accelerate: if going from nothing, revv it up
                                if warthogData.accelX == 0 then
                                    if not (noSound or noSoundWarthog) then
                                        if soundMax:isPlaying() then
                                            soundMax:stop()
                                        end
                                        if not soundAccel:isPlaying() then
                                            soundAccel:play(0.5 + math.abs(warthogData.speedX) / 7.5, 0.3)
                                        end
                                    end
                                    if warthogData.speedX == 0 then
                                        warthogData.accelX = warthogData.accelX - 0.005
                                    else
                                        warthogData.accelX = warthogData.accelX - 0.5
                                    end
                                else
                                    warthogData.accelX = warthogData.accelX - 0.005
                                end
                            end
                        end
                    else
                        -- nullify acceleration
                        warthogData.accelX = 0
                        if soundMax:isPlaying() then
                            soundMax:stop()
                        end
                        if soundAccel:isPlaying() then
                            soundAccel:stop()
                        end
                    end
                    if player:control("enter") == input.PRESSED and warthogData.driverEnterCooldown == 0 then
                        if not net.host then
                            warthogLeavePacket:sendAsClient(player:getNetIdentity(), warthogInstance:getData().id)
                        else
                            -- exit
                            player:set("activity", 0):set("canrope", 1)
                            playerData.driving = nil
                            warthogData.accelX = 0
                            warthogData.drawDriverSeatPopup = 1
                            warthogData.driverSeatTaken = 0
                            warthogData.driverEnterCooldown = 60
                            warthogData.turretEnterCooldown = 60
                            
                            warthogLeavePacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), warthogInstance:getData().id)
                        end
                    end
                end
                
                local carFacing = warthogInstance.xscale
                local carCoords1 = warthogInstance.x - warthogInstance.sprite.xorigin * carFacing
                local carCoords2 = carCoords1 + (warthogInstance.sprite.width / 3) * carFacing
                local carCoords3 = carCoords2 + (warthogInstance.sprite.width / 3) * carFacing
                if player.y <= warthogInstance.y and player.y >= warthogInstance.y - warthogInstance.sprite.height then
                    if (carFacing == 1 and player.x >= carCoords1 and player.x <= carCoords3)
                    or (carFacing == -1 and player.x >= carCoords3 and player.x <= carCoords1) then --if player:collidesWith(warthogInstance, player.x, player.y) then
                        if warthogData.turretInst == nil and
                        ((carFacing == 1 and player.x < carCoords2) or (carFacing == -1 and player.x > carCoords2)) then --player.x < warthogInstance.x - important.warthogCenterX + warthogInstance.sprite.width / 3 then
                            -- turret seat
                            if player:control("enter") == input.PRESSED and warthogData.turretEnterCooldown == 0 and player:get("activity") == 0 then
                                local turretX = warthogInstance.x + important.turretOffsetX
                                local turretY = warthogInstance.y + important.turretOffsetY
                                if not net.host then
                                    turretEnterPacket:sendAsClient(player:getNetIdentity(), warthogInstance:getData().id, -1, turretX, turretY)
                                else
                                    turretInstance = turret:create(turretX, turretY)
                                    local turretData = turretInstance:getData()
                                    turretData.id = nextVehicleID()
                                    turretData.warthog = warthogInstance
                                    player:set("activity", ACTIVITY_WARTHOG_TURRET)
                                    playerData.driving = turretInstance
                                    warthogData.turretInst = turretInstance
                                    warthogData.turretEnterCooldown = 60
                                    local playerFacing = player:getFacingDirection() == 0 and 1 or -1
                                    turretInstance.xscale = playerFacing
                                    
                                    turretEnterPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), warthogInstance:getData().id, turretData.id, turretX, turretY)
                                end
                            else
                                warthogData.drawDriverSeatPopup = 0
                                warthogData.drawTurretSeatPopup = 1
                            end
                        elseif warthogData.driverSeatTaken == 0 and 
                          ((carFacing == 1 and player.x >= carCoords2) or (carFacing == -1 and player.x <= carCoords2)) then --player.x < warthogInstance.x - important.warthogCenterX + (warthogInstance.sprite.width / 3) * 2 then
                            -- driver seat
                            if player:control("enter") == input.PRESSED and warthogData.driverEnterCooldown == 0 and player:get("activity") == 0 then
                                if not net.host then
                                    warthogEnterPacket:sendAsClient(player:getNetIdentity(), warthogInstance:getData().id)
                                else
                                    player:set("activity", ACTIVITY_WARTHOG_DRIVER)
                                    playerData.driving = warthogInstance
                                    warthogData.driverEnterCooldown = 60
                                    warthogData.drawDriverSeatPopup = 0
                                    warthogData.driverSeatTaken = 1
                                    
                                    warthogEnterPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), warthogInstance:getData().id)
                                end
                            else
                                warthogData.drawDriverSeatPopup = 1
                                warthogData.drawTurretSeatPopup = 0
                            end
                        else
                            if warthogData.drawDriverSeatPopup == 1 then warthogData.drawDriverSeatPopup = 0 end
                            if warthogData.drawTurretSeatPopup == 1 then warthogData.drawTurretSeatPopup = 0 end
                        end
                    else
                        if warthogData.drawDriverSeatPopup == 1 then warthogData.drawDriverSeatPopup = 0 end
                        if warthogData.drawTurretSeatPopup == 1 then warthogData.drawTurretSeatPopup = 0 end
                    end
                else
                    if warthogData.drawDriverSeatPopup == 1 then warthogData.drawDriverSeatPopup = 0 end
                    if warthogData.drawTurretSeatPopup == 1 then warthogData.drawTurretSeatPopup = 0 end
                end
            end
        end
        
        if warthogInstance ~= nil then
            if warthogInstance:isValid() and playerData.driving ~= nil and playerData.driving == warthogInstance then
                local warthogData = warthogInstance:getData()
                local turretInst = warthogData.turretInst
                warthogStepPacket:sendAsClient(player:getNetIdentity(),
                    warthogInstance.x, warthogInstance.y,
                    warthogData.id,
                    warthogData.turretEnterCooldown,
                    warthogData.driverSeatTaken,
                    warthogData.driverEnterCooldown,
                    warthogData.jumpPadCooldown,
                    warthogData.collidingWall,
                    warthogData.accelX,
                    warthogData.accelY,
                    warthogData.speedX,
                    warthogData.speedY,
                    warthogInstance.xscale,
                    turretInst == nil and -1 or turretInst:getData().id
                )
                warthogStepPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(),
                    warthogInstance.x, warthogInstance.y,
                    warthogData.id,
                    warthogData.turretEnterCooldown,
                    warthogData.driverSeatTaken,
                    warthogData.driverEnterCooldown,
                    warthogData.jumpPadCooldown,
                    warthogData.collidingWall,
                    warthogData.accelX,
                    warthogData.accelY,
                    warthogData.speedX,
                    warthogData.speedY,
                    warthogInstance.xscale,
                    turretInst == nil and -1 or turretInst:getData().id
                )
            end
        end
        if turretInstance ~= nil then
            if turretInstance:isValid() and playerData.driving ~= nil and playerData.driving == turretInstance then
                local turretData = turretInstance:getData()
                turretStepPacket:sendAsClient(player:getNetIdentity(),
                    turretData.id,
                    turretInstance.angle,
                    turretInstance.xscale,
                    turretData.turretShotCooldown
                )
                turretStepPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(),
                    turretData.id,
                    turretInstance.angle,
                    turretInstance.xscale,
                    turretData.turretShotCooldown
                )
            end
        end
    end
end)

warthog:addCallback("draw", function(inst)
    local instData = inst:getData()
    local enterKeyText = input.getControlString("enter")
    local textPart1 = "Press "
    local textPart2Turret = " to enter the turret seat"
    local textPart2Driver = " to enter the driver seat"
    local fullTurretText = textPart1 .. enterKeyText .. textPart2Turret
    local fullDriverText = textPart1 .. enterKeyText .. textPart2Driver
    if instData.drawTurretSeatPopup == 1 then
        graphics.color(Color.WHITE)
        graphics.print(textPart1, inst.x - graphics.textWidth(fullTurretText, graphics.FONT_DEFAULT) / 2, inst.y - inst.sprite.height)
        graphics.color(Color.ROR_YELLOW)
        graphics.print(enterKeyText, inst.x - graphics.textWidth(fullTurretText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1, graphics.FONT_DEFAULT), inst.y - inst.sprite.height)
        graphics.color(Color.WHITE)
        graphics.print(textPart2Turret, inst.x - graphics.textWidth(fullTurretText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1 .. enterKeyText, graphics.FONT_DEFAULT), inst.y - inst.sprite.height)
    elseif instData.drawDriverSeatPopup == 1 then
        graphics.color(Color.WHITE)
        graphics.print(textPart1, inst.x - graphics.textWidth(fullDriverText, graphics.FONT_DEFAULT) / 2, inst.y - inst.sprite.height)
        graphics.color(Color.ROR_YELLOW)
        graphics.print(enterKeyText, inst.x - graphics.textWidth(fullDriverText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1, graphics.FONT_DEFAULT), inst.y - inst.sprite.height)
        graphics.color(Color.WHITE)
        graphics.print(textPart2Driver, inst.x - graphics.textWidth(fullDriverText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1 .. enterKeyText, graphics.FONT_DEFAULT), inst.y - inst.sprite.height)
    end
end)