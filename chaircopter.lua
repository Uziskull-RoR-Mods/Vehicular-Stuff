-- Made by Uziskull

-----------
-- Flags
-----------

local noSound = modloader.checkFlag("vehicular_no_sound")
local noSoundChair = modloader.checkFlag("vehicular_chaircopter_no_sound")

----------------------
-- Objects and sprites and sounds and stuff
----------------------

local jumpPad = Object.find("Geyser")
local jumpPadSound = Sound.find("Geyser")

-- local sTakeoff = Sound.load("sound_chaircopter_takeoff", "sound/chaircopter/takeoff")
-- local sFlying = Sound.load("sound_chaircopter_flying", "sound/chaircopter/flying")
-- local sLanding = Sound.load("sound_chaircopter_landing", "sound/chaircopter/landing")

local chair = Object.new("Chaircopter")

local sprites = {
    { -- red
        stop = Sprite.load("chaircopter_red_stop", "sprites/chaircopter/red/stop", 1, 16, 24),
        -- start = Sprite.load("chaircopter_red_start", "sprites/chaircopter/red/start", 4, 3, 11),
        -- keep = Sprite.load("chaircopter_red_keep", "sprites/chaircopter/red/keep", 4, 3, 11)
    },
    -- { -- blue
        -- stop = Sprite.load("chaircopter_blue_stop", "sprites/chaircopter/blue/stop", 1, 16, 24),
        -- start = Sprite.load("chaircopter_blue_start", "sprites/chaircopter/blue/start", 4, 3, 11),
        -- keep = Sprite.load("chaircopter_blue_keep", "sprites/chaircopter/blue/keep", 4, 3, 11)
    -- },
    -- { -- green
        -- stop = Sprite.load("chaircopter_green_stop", "sprites/chaircopter/green/stop", 1, 16, 24),
        -- start = Sprite.load("chaircopter_green_start", "sprites/chaircopter/green/start", 4, 3, 11),
        -- keep = Sprite.load("chaircopter_green_keep", "sprites/chaircopter/green/keep", 4, 3, 11)
    -- },
    -- { -- pink
        -- stop = Sprite.load("chaircopter_pink_stop", "sprites/chaircopter/pink/stop", 1, 16, 24),
        -- start = Sprite.load("chaircopter_pink_start", "sprites/chaircopter/pink/start", 4, 3, 11),
        -- keep = Sprite.load("chaircopter_pink_keep", "sprites/chaircopter/pink/keep", 4, 3, 11)
    -- }
}

local chairInstance = {}
local chairHandler = nil
local chairs = 0

-- local function drawChairs(handler, frame)
    -- -- TODO: might be needed to save and increment animation frames
    -- for i = 1, chairs do
        -- if chairInstance[i] ~= nil then
            -- if chairInstance[i]:isValid() then
                -- local facing = 1
                -- if chairInstance[i]:get("facingLeft") == 1 then
                    -- facing = -1
                -- end
                -- if chairInstance[i]:get("riding") == 0 then
                    -- if chairInstance[i]:get("spriteNum") ~= 1 then
                        -- chairInstance[i]:set("spriteNum", 1)
                    -- end
                    -- graphics.drawImage{
                        -- image = chairInstance[i].sprite,
                        -- x = chairInstance[i].x,
                        -- y = chairInstance[i].y - 6,
                        -- xscale = facing
                    -- }
                -- else
                    -- graphics.drawImage{
                        -- image = chairInstance[i].sprite,
                        -- x = chairInstance[i].x,
                        -- y = chairInstance[i].y,
                        -- subimage = chairInstance[i]:get("spriteNum"),
                        -- xscale = facing,
                        -- angle = chairInstance[i].angle
                    -- }
                -- end
                -- graphics.print("facing: " .. facing, chairInstance[i].x, chairInstance[i].y - 8)
                -- log("yeet")
            -- end
        -- end
    -- end
-- end

chair:addCallback("create", function(self)
    chairs = chairs + 1
    self:set("chairID", chairs)
    chairInstance[chairs] = self

    -------------
    --- DEBUG ---
    -------------
    if chairs == 1 then
        misc.players[1].x = self.x
        misc.players[1].y = self.y
    end
    -------------
    -------------
    
    -- self.visible = false
    local rand = 1 -- math.random(4)
    self.sprite = sprites[rand].stop
    self:set("skin", rand)
    
    self.xscale = math.random(0, 1)
    if self.xscale == 0 then
        self.xscale = -1
    end
    
    self:set("drawPopup", 0)
    self:set("riding", 0)
    self:set("enterCooldown", 0)
    self:set("jumpPadCooldown", 0)
    self:set("spriteNum", 1)
    
    self:set("accelGrav", 0.26)
    self:set("speedY", 0)
    self:set("speedX", 0)
    self:set("accelY", 0)
    self:set("accelAccelY", 0.1)--0.004335) -- after 60 frames, speed becomes equal to gravity (0.26)
    self:set("accelX", 0.1778)   -- after 90 frames, speed becomes equal to one tile (16px) per tick
    self:set("maxYSpeed", 4)--8)
    self:set("maxXSpeed", 8)--16)    -- top speed is hit at 90 frames
    
    self:set("heldJump", 0)
    self:set("heldDirection", 0)
end)

chair:addCallback("step", function(self)
    self.sprite = sprites[1].stop
    -- local spriteTable = sprites[self:get("skin")]
    -- if self:get("speedY") >= 0 and self.sprite ~= spriteTable.stop then
        -- self.sprite = spriteTable.stop
    -- elseif self:get("speedY") >= self:get("accelGrav") * -1 and self.sprite ~= spriteTable.start then
        -- self.sprite = spriteTable.start
    -- else
        -- self.sprite = spriteTable.keep
    -- end
    
    local grav = self:get("accelGrav")
    if self:get("riding") == 1 then
        grav = self:get("accelGrav") / 2
    end
    
    if self:get("enterCooldown") > 0 then self:set("enterCooldown", self:get("enterCooldown") - 1) end
    if self:get("jumpPadCooldown") > 0 then self:set("jumpPadCooldown", self:get("jumpPadCooldown") - 1) end

    local oldY = self.y
    local oldX = self.x
    
    if self:get("riding") == 1 then
        if self:get("heldDirection") ~= 0 then
            if self:get("heldDirection") > 0 then
                self:set("speedX", math.min(self:get("speedX") + self:get("accelX"), self:get("maxXSpeed")))
            else
                self:set("speedX", math.max(self:get("speedX") - self:get("accelX"), self:get("maxXSpeed") * -1))
            end
            self:set("heldDirection", 0)
        elseif self:get("speedX") ~= 0 then
            local drag = self:get("accelX") / 3
            if self:get("speedX") > 0 then
                drag = drag * -1
                self:set("speedX", math.max(self:get("speedX") + drag, 0))
            else
                self:set("speedX", math.min(self:get("speedX") + drag, 0))
            end
        end
        
        self.x = self.x + self:get("speedX")
        self.angle = 45 / self:get("maxXSpeed") * self:get("speedX")
        
        local d = 1
        if self:get("speedX") > 0 then d = -1 end
        while self:collidesMap(self.x, self.y) do
            self.x = self.x + d
            self.angle = 0
            self:set("speedX", 0)
        end
        
        if self:get("heldJump") == 1 then
            self:set("heldJump", 0)
            self:set("accelY", math.min(self:get("accelY") + self:get("accelAccelY"), grav * 2))
        else
            self:set("accelY", math.max(self:get("accelY") - self:get("accelAccelY"), 0))
        end
    end
    
    self:set("speedY", math.clamp(self:get("speedY") + grav - self:get("accelY"), self:get("maxYSpeed") * -1, self:get("maxYSpeed")))
    local newY = self.y + self:get("speedY")
    
    if oldY > newY then --hitting ceiling
        while self:collidesMap(self.x, newY - self.sprite.yorigin) do
            newY = newY + 1
            self:set("speedY", 0)
        end
    elseif oldY < newY then --hitting floor
        while self:collidesMap(self.x, newY) do
            newY = newY - 1
            self:set("speedY", 0)
        end
    end
    
    self.y = newY
    
    if self:get("jumpPadCooldown") == 0 then
        local closestJumpPad = jumpPad:findNearest(self.x, self.y)
        if closestJumpPad ~= nil then
            if closestJumpPad:isValid() then
                if self:collidesWith(closestJumpPad, self.x, self.y) then
                    self:set("speedY", -12)
                    jumpPadSound:play()
                    self:set("jumpPadCooldown", 10)
                end
            end
        end
    end
end)

chair:addCallback("destroy", function(self)
    chairInstance[self:get("chairID")] = nil
end)
----------------------
-- Buffs
----------------------

local chairBuff = Buff.new("Mounting Chaircopter")
chairBuff.sprite = emptySprite
local playerBaseStatChair = {}

chairBuff:addCallback("start", function(player)
    playerBaseStatChair[player.playerIndex] = {
        player:get("pHmax"),
        player:get("pVmax"),
        player:get("pVspeed"),
        player:get("pGravity1"),
        player:get("pGravity2")
    }
    player:set("pHmax", 0)
    player:set("pVmax", 0)
    player:set("pVspeed", 0)
    player:set("pGravity1", 0)
    player:set("pGravity2", 0)
    player:set("canrope", 0)
end)

chairBuff:addCallback("step", function(player, remainingTime)
    local i = player:get("chairID")
    if i ~= nil then
        if chairInstance[i] ~= nil then
            if chairInstance[i]:isValid() then
                local dX = chairInstance[i].xscale * -1
                
                player.x = chairInstance[i].x + dX
                player.y = chairInstance[i].y - (player.sprite.height - player.sprite.yorigin) - 2
                
                if player:get("outside_screen") == 89 then
                    chairInstance[i]:destroy()
                    player:removeBuff(chairBuff)
                end
            end
        end
    end
    
    -- lets the player only use use items
    for i=2,5 do
        player:setAlarm(i, 1)
    end
    
    if remainingTime == 1 then
        player:applyBuff(chairBuff, 59)
    end
end)

chairBuff:addCallback("end", function(player)
    player:set("pHmax", playerBaseStatChair[player.playerIndex][1])
    player:set("pVmax", playerBaseStatChair[player.playerIndex][2])
    player:set("pVspeed", playerBaseStatChair[player.playerIndex][3])
    player:set("pGravity1", playerBaseStatChair[player.playerIndex][4])
    player:set("pGravity2", playerBaseStatChair[player.playerIndex][5])
    player:set("canrope", 1)
end)

----------------------
-- Actual things
----------------------

addVehicle(function(x,y)
    chair:create(x,y)
end, sprites[1].stop.width, sprites[1].stop.height, 2)

registercallback("onGameEnd", function()
    chairInstance = {}
    chairHandler = nil
    chairs = 0
end)

registercallback("onStageEntry", function()
    -- chairHandler = graphics.bindDepth(-7, drawChairs)
    for _, goodGuy in ipairs(misc.players) do
        if goodGuy:hasBuff(chairBuff) then
            goodGuy:removeBuff(chairBuff)
        end
        goodGuy:set("chairID", nil)
    end
end)

registercallback("onPlayerDeath", function(player)
    if player:hasBuff(chairBuff) then
        player:removeBuff(chairBuff)
        local i = player:get("chairID")
        if i ~= nil then
            chairInstance[i]:set("enterCooldown", 60)
            chairInstance[i]:set("riding", 0)
        end
    end
end)

registercallback("onPlayerStep", function(player)
    local gamepad = input.getPlayerGamepad(player)
    local holdingLeft = false
    local holdingRight = false
    if gamepad == nil then
        if player:control("left") == input.HELD then
            holdingLeft = true
        end
        if player:control("right") == input.HELD then
            holdingRight = true
        end
    else
        if input.getGamepadAxis("lh", gamepad) < -0.3 or 
            input.checkGamepad("padl", gamepad) == input.HELD then
            holdingLeft = true
        end
        if input.getGamepadAxis("lh", gamepad) > 0.3 or 
            input.checkGamepad("padr", gamepad) == input.HELD then
            holdingRight = true
        end
    end
    
    if player:hasBuff(chairBuff) then
        local i = player:get("chairID")
        if i ~= nil then
            if player:control("enter") == input.PRESSED and chairInstance[i]:get("enterCooldown") == 0 then
                chairInstance[i]:set("riding", 0)
                player:removeBuff(chairBuff)
                player:set("chairID", nil)
            end
            if player:getFacingDirection() == 0 and chairInstance[i].xscale == -1 then
                chairInstance[i].xscale = 1
            elseif player:getFacingDirection() == 180 and chairInstance[i].xscale == 1 then
                chairInstance[i].xscale = -1
            end
            if player:control("jump") == input.HELD then
                chairInstance[i]:set("heldJump", 1)
            else
                chairInstance[i]:set("heldJump", 0)
            end
            if holdingRight then
                chairInstance[i]:set("heldDirection", 1)
            elseif holdingLeft then
                chairInstance[i]:set("heldDirection", -1)
            else
                chairInstance[i]:set("heldDirection", 0)
            end
        end
    else
        for i = 1, chairs do
            if chairInstance[i] ~= nil then
                if chairInstance[i]:isValid() then
                    if player:collidesWith(chairInstance[i], player.x, player.y) then
                        if chairInstance[i]:get("riding") == 1 then
                            if chairInstance[i]:get("drawPopup") == 1 then
                                chairInstance[i]:set("drawPopup", 0)
                            end
                        else
                            if chairInstance[i]:get("drawPopup") == 0 then
                                chairInstance[i]:set("drawPopup", 1)
                            end
                            if player:control("enter") == input.PRESSED and chairInstance[i]:get("enterCooldown") == 0 and player:get("activity") == 0 then
                                chairInstance[i]:set("riding", 1)
                                player:applyBuff(chairBuff, 60)
                                player:set("chairID", i)
                                chairInstance[i]:set("drawPopup", 0)
                                chairInstance[i]:set("enterCooldown", 60)
                            end
                        end
                    else
                        if chairInstance[i]:get("drawPopup") == 1 then
                            chairInstance[i]:set("drawPopup", 0)
                        end
                    end
                end
            end
        end
    end
end)

registercallback("onDraw", function()
    local enterKeyText = input.getControlString("enter")
    local textPart1 = "Press "
    local textPart2 = " to ride the chaircopter"
    local fullText = textPart1 .. enterKeyText .. textPart2
    for i = 1, chairs do
        if chairInstance[i] ~= nil then
            if chairInstance[i]:isValid() then
                if chairInstance[i]:get("drawPopup") == 1 then
                    graphics.color(Color.WHITE)
                    graphics.print(textPart1, chairInstance[i].x - graphics.textWidth(fullText, graphics.FONT_DEFAULT) / 2, chairInstance[i].y - chairInstance[i].sprite.height)
                    graphics.color(Color.YELLOW)
                    graphics.print(enterKeyText, chairInstance[i].x - graphics.textWidth(fullText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1, graphics.FONT_DEFAULT), chairInstance[i].y - chairInstance[i].sprite.height)
                    graphics.color(Color.WHITE)
                    graphics.print(textPart2, chairInstance[i].x - graphics.textWidth(fullText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1 .. enterKeyText, graphics.FONT_DEFAULT), chairInstance[i].y - chairInstance[i].sprite.height)
                end
            end
        end
    end
end)