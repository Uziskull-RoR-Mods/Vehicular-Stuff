-- Made by Uziskull

-----------
-- Flags
-----------

local noSound = modloader.checkFlag("vehicular_no_sound")
local noSoundPogo = modloader.checkFlag("vehicular_pogo_no_sound")

----------------------
-- Objects and sprites and sounds and stuff
----------------------

local jumpPad = Object.find("Geyser")
local jumpPadSound = Sound.find("Geyser")

local jumpie = Sound.load("sound_pogo_jumpie", "sound/pogo/jumpie")
local jumpo = Sound.load("sound_pogo_jumpo", "sound/pogo/jumpo")

pogo = Object.new("Pogo Stick")

local sprites = {
    red = Sprite.load("pogo_red", "sprites/pogo/pogo_red", 4, 3, 11),
    blue = Sprite.load("pogo_blue", "sprites/pogo/pogo_blue", 4, 3, 11),
    green = Sprite.load("pogo_green", "sprites/pogo/pogo_green", 4, 3, 11),
    pink = Sprite.load("pogo_pink", "sprites/pogo/pogo_pink", 4, 3, 11),
    
    mask1 = Sprite.load("pogo_mask_1", "sprites/pogo/mask1", 1, 3, 11),
    mask2 = Sprite.load("pogo_mask_2", "sprites/pogo/mask2", 1, 3, 11),
    mask3 = Sprite.load("pogo_mask_3", "sprites/pogo/mask3", 1, 3, 11),
    mask4 = Sprite.load("pogo_mask_4", "sprites/pogo/mask4", 1, 3, 11)
}

function getPos(player, pogo)
    local dX = -pogo.xscale
    return pogo.x + dX, pogo.y - (player.sprite.height - player.sprite.yorigin) - 1
end

local function drawPogos(handler, frame)
    local enterKeyText = input.getControlString("enter")
    local textPart1 = "Press "
    local textPart2 = " to ride the pogo stick"
    local fullText = textPart1 .. enterKeyText .. textPart2
    for _, pogoInst in ipairs(pogo:findAll()) do
        if pogoInst:isValid() then
            local pogoData = pogoInst:getData()
            if pogoData.riding == 0 then
                if pogoData.spriteNum ~= 1 then
                    pogoData.spriteNum = 1
                end
                graphics.drawImage{
                    image = pogoInst.sprite,
                    subimage = 1,
                    x = pogoInst.x,
                    y = pogoInst.y - 6,
                    angle = 90,
                    xscale = pogoInst.xscale
                }
                if pogoData.drawPopup == 1 then
                    graphics.color(Color.WHITE)
                    graphics.print(textPart1, pogoInst.x - graphics.textWidth(fullText, graphics.FONT_DEFAULT) / 2, pogoInst.y - pogoInst.sprite.height)
                    graphics.color(Color.ROR_YELLOW)
                    graphics.print(enterKeyText, pogoInst.x - graphics.textWidth(fullText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1, graphics.FONT_DEFAULT), pogoInst.y - pogoInst.sprite.height)
                    graphics.color(Color.WHITE)
                    graphics.print(textPart2, pogoInst.x - graphics.textWidth(fullText, graphics.FONT_DEFAULT) / 2 + graphics.textWidth(textPart1 .. enterKeyText, graphics.FONT_DEFAULT), pogoInst.y - pogoInst.sprite.height)
                end
            else
                graphics.drawImage{
                    image = pogoInst.sprite,
                    x = pogoInst.x,
                    y = pogoInst.y,
                    subimage = pogoData.spriteNum
                }
            end
        end
    end
end

pogo:addCallback("create", function(self)
    local pogoData = self:getData()

    self.visible = false
    local rand = math.random(4)
    if rand == 1 then
        self.sprite = sprites.red
    elseif rand == 2 then
        self.sprite = sprites.blue
    elseif rand == 3 then
        self.sprite = sprites.green
    else
        self.sprite = sprites.pink
    end
    self.mask = sprites.mask1
    
    self.xscale = math.random() * 10 <= 5 and -1 or 1
    
    pogoData.drawPopup = 0
    pogoData.riding = 0
    pogoData.enterCooldown = 0
    pogoData.jumpPadCooldown = 0
    pogoData.spriteNum = 1
    pogoData.waitJumpFrames = 10
    
    pogoData.accelY = 0.26
    pogoData.speedY = 0
    
    pogoData.heldDirection = 0
    pogoData.heldJump = 0
    
end)

----------------------
-- Packets (Pre-Step) 
----------------------
pogoJumpkillPacket = net.Packet("Jumpkill Pogo", function(sender, baddie)
    local actualBaddie = baddie:resolve()
    if actualBaddie ~= nil then
        actualBaddie:kill()
    end
end)

pogo:addCallback("step", function(self)
    local pogoData = self:getData()
    pogoData.enterCooldown = math.max(pogoData.enterCooldown - 1, 0)
    pogoData.jumpPadCooldown = math.max(pogoData.jumpPadCooldown - 1, 0)

    if pogoData.riding == 1 then
        local distanceToFloor = 7
        if pogoData.spriteNum == 2 then
            distanceToFloor = 6
            self.mask = sprites.mask2
        elseif pogoData.spriteNum == 3 then
            distanceToFloor = 5
            self.mask = sprites.mask3
        elseif pogoData.spriteNum == 4 then
            distanceToFloor = 9
            self.mask = sprites.mask4
        end
        
        local oldSpeed = pogoData.speedY
        if not self:collidesMap(self.x, self.y + distanceToFloor + 1) then
            pogoData.speedY = pogoData.speedY + pogoData.accelY
        end
        
        if oldSpeed <= 0 and pogoData.speedY >= 0 and pogoData.spriteNum == 4 then
            pogoData.spriteNum = 1
            distanceToFloor = 7
        end
        
        if self:collidesMap(self.x, self.y + distanceToFloor + 1) then
            if pogoData.spriteNum < 3 then
                if pogoData.spriteNum == 1 then
                    pogoData.spriteNum = 2
                    self.mask = sprites.mask2
                elseif pogoData.spriteNum == 2 then
                    pogoData.spriteNum = 3
                    self.mask = sprites.mask3
                end
                self.y = self.y + 1
            elseif pogoData.spriteNum == 3 then
                if pogoData.waitJumpFrames > 0 then
                    pogoData.waitJumpFrames = pogoData.waitJumpFrames - 1
                else
                    pogoData.waitJumpFrames = 10
                    if pogoData.heldJump == 1 then
                        pogoData.spriteNum = 4
                        self.mask = sprites.mask4
                        pogoData.speedY = -10
                        if not (noSound or noSoundPogo) then
                            jumpo:play(0.75 + math.random() / 4, 0.4)
                        end
                        pogoData.heldJump = 0
                    else
                        pogoData.spriteNum = 1
                        self.mask = sprites.mask1
                        pogoData.speedY = -5
                        if not (noSound or noSoundPogo) then
                            jumpie:play(0.75 + math.random() / 4, 0.3)
                        end
                    end
                end
            end
        end
        if pogoData.spriteNum ~= 3 and pogoData.heldDirection ~= 0 then
            if not self:collidesMap(self.x + pogoData.heldDirection, self.y) then
                self.x = self.x + pogoData.heldDirection
            end
            pogoData.heldDirection = 0
        end
        
        if pogoData.jumpPadCooldown == 0 then
            local closestJumpPad = jumpPad:findNearest(self.x, self.y)
            if closestJumpPad ~= nil then
                if closestJumpPad:isValid() then
                    if self:collidesWith(closestJumpPad, self.x, self.y) then
                        pogoData.speedY = -12
                        jumpPadSound:play()
                        pogoData.jumpPadCooldown = 10
                    end
                end
            end
        end
        
        local oldY = self.y
        self.y = self.y + pogoData.speedY
        
        -- host only
        if net.host then
            if pogoData.speedY >= 7.5 then
                local enemyList = ParentObject.find("enemies")
                for _, baddie in ipairs(enemyList:findAll()) do
                    if not baddie:isBoss() and self:collidesWith(baddie, self.x, self.y) then
                        baddie:kill()
                        pogoJumpkillPacket:sendAsHost(net.ALL, nil, baddie:getNetIdentity())
                    end
                end
            end
        end
        
        if oldY > self.y then --hitting ceiling
            while self:collidesMap(self.x, self.y - self.sprite.yorigin) do
                self.y = self.y + 1
                pogoData.speedY = 0
            end
        elseif oldY < self.y then --hitting floor
            while self:collidesMap(self.x, self.y + distanceToFloor) do
                self.y = self.y - 1
                pogoData.speedY = 0
            end
        end
    else
        if not self:collidesMap(self.x, self.y - self.sprite.yorigin + 1) then
            pogoData.speedY = pogoData.speedY + pogoData.accelY
        end
        self.y = self.y + pogoData.speedY
        while self:collidesMap(self.x, self.y - self.sprite.yorigin) do
            self.y = self.y - 1
            pogoData.speedY = 0
        end
    end
end)

----------------------
-- Packets (Pre-Buff)
----------------------
pogoCreatePacket = net.Packet("Pogo Create", function(sender, numPogos, ...) -- x1, y1, color1, x2, y2, color2, x3, y3, color3, x4, y4, color4)
    local pogos = {...}
    for i = 1, numPogos do
        j = 1 + (i - 1) * 3
        local pinst = pogo:create(pogos[j], pogos[j+1])
        pinst:getData().id = pogos[j+2]
        pinst.sprite = pogos[j+3]
    end
end)
requestPogoPacket = net.Packet("Request Pogo", function(sender)
    local pogos = {}
    for _, pogoInst in ipairs(pogo:findAll()) do
        table.insert(pogos, pogoInst.x)
        table.insert(pogos, pogoInst.y)
        table.insert(pogos, pogoInst:getData().id)
        table.insert(pogos, pogoInst.sprite)
    end
    if #pogos > 0 then
        pogoCreatePacket:sendAsHost(net.DIRECT, sender, #pogos, table.unpack(pogos))
    end
end)

outsideScreenPogoPacket = net.Packet("Outside Screen Pogo", function(sender, actualPlayer, pogoID)
    local p = actualPlayer:resolve()
    if p ~= nil then
        local pogoInst = nil
        for _, inst in ipairs(pogo:findAll()) do
            if inst:getData().id == pogoID then
                pogoInst = inst
                break
            end
        end
        if pogoInst ~= nil and pogoInst:isValid() then
            pogoInst:destroy()
            p:getData().driving = nil
            p:set("activity", 0):set("canrope", 1)
        end
    end
end)
pogoEnterPacket = net.Packet("Enter Pogo", function(sender, actualPlayer, pogoID)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if net.host then
            pogoEnterPacket:sendAsHost(net.EXCLUDE, sender, p:getNetIdentity(), pogoID)
        end
        local pogoInst = nil
        for _, inst in ipairs(pogo:findAll()) do
            if inst:getData().id == pogoID then
                pogoInst = inst
                break
            end
        end
        if pogoInst ~= nil and pogoInst:isValid() then
            local pogoData = pogoInst:getData()
            pogoData.riding = 1
            p:set("activity", ACTIVITY_POGO_DRIVER):set("canrope", 0)
            p:getData().driving = pogoInst
            pogoData.drawPopup = 0
            pogoData.enterCooldown = 60
        end
    end
end)
pogoLeavePacket = net.Packet("Leave Pogo", function(sender, actualPlayer, pogoID)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if net.host then
            pogoLeavePacket:sendAsHost(net.EXCLUDE, sender, p:getNetIdentity(), pogoID)
        end
        local pogoInst = nil
        for _, inst in ipairs(pogo:findAll()) do
            if inst:getData().id == pogoID then
                pogoInst = inst
                break
            end
        end
        if pogoInst ~= nil and pogoInst:isValid() then
            local pogoData = pogoInst:getData()
            pogoData.riding = 0
            p:set("activity", 0):set("canrope", 1)
            p:getData().driving = nil
        end
    end
end)
pogoStepPacket = net.Packet("Step Pogo", function(sender, actualPlayer, x, y, eC, r, fL, dP, hJ, hD)
    local p = actualPlayer:resolve()
    if p ~= nil then
        if p ~= net.localPlayer then
            if net.host then
                pogoStepPacket:sendAsHost(net.EXCLUDE, sender, p:getNetIdentity(), x, y, eC, r, fL, dP, hJ, hD)
            end
            local pogoInst = p:getData().driving
            if pogoInst ~= nil and pogoInst:isValid() then
                pogoInst.x, pogoInst.y = x, y
            
                local xx, yy = getPos(p, pogoInst)
                p:set("ghost_x", xx):set("ghost_y", yy)
                
                pogoData.enterCooldown = eC
                pogoData.riding = r
                pogoData.facingLeft = fL
                pogoData.drawPopup = dP
                pogoData.heldJump = hJ
                pogoData.heldDirection = hD
            end
        end
    end
end)

----------------------
-- Actual things
----------------------

addVehicle(function(x,y)
    return pogo:create(x,y)
end, sprites.red.width, sprites.red.height, 4)

registercallback("onStageEntry", function()
    if not net.host then
        requestPogoPacket:sendAsClient()
    end
end)

registercallback("onStageEntry", function()
    graphics.bindDepth(-9, drawPogos)
end)

registercallback("onPlayerDeath", function(player)
    local pogoInst = p:getData().driving
    if pogoInst ~= nil and pogoInst:isValid() then
        local pogoData = pogoInst:getData()
        pogoData.enterCooldown = 60
        pogoData.riding = 0
    end
end)

registercallback("onPlayerStep", function(player)
    if not net.online or player == net.localPlayer then
        local playerData = player:getData()
        
        if playerData.driving ~= nil then
            local drivingObj = playerData.driving:getObject()
            if drivingObj == pogo then
                player:set("pVspeed", 0)
                for _, i in ipairs({0, 2, 3, 4, 5}) do
                    player:setAlarm(i, math.max(player:getAlarm(i), 1))
                end
                player:set("canrope", 0)
                
                if playerData.driving:isValid() then
                    player.x, player.y = getPos(player, playerData.driving)
                    
                    if net.host then
                        if player:get("outside_screen") == 89 then
                            local pogoID = playerData.driving:getData().id
                            playerData.driving:destroy()
                            player:set("activity", 0):set("canrope", 1)
                            playerData.driving = nil
                            outsideScreenPogoPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), pogoID)
                        end
                    end
                end
            end
        else
            if player:get("activity") == ACTIVITY_POGO_DRIVER then
                player:set("activity", 0):set("canrope", 1)
            end
        end
        
        local holding = {}
        for _, dir in ipairs({"left", "right"}) do
            holding[dir] = player:control(dir) == input.HELD
        end
        
        local pogoInst = playerData.driving
        local pogoData = nil
        if pogoInst ~= nil and pogoInst:isValid() then
            pogoData = pogoInst:getData()
            if player:control("enter") == input.PRESSED and pogoData.enterCooldown == 0 then
                if not net.host then
                    pogoLeavePacket:sendAsClient(player:getNetIdentity(), pogoInst:getData().id)
                else
                    pogoData.riding = 0
                    player:set("activity", 0):set("canrope", 1)
                    playerData.driving = nil
                    
                    pogoLeavePacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), pogoInst:getData().id)
                end
            end
            local playerFacing = player:getFacingDirection() == 0 and 1 or -1
            if playerFacing ~= pogoInst.xscale then
                pogoInst.xscale = playerFacing
            end
            pogoData.heldJump = player:control("jump") == input.HELD and 1 or 0
            if holding.right then
                pogoData.heldDirection = 1
            elseif holding.left then
                pogoData.heldDirection = -1
            else
                pogoData.heldDirection = 0
            end
        else
            pogoInst = pogo:findNearest(player.x, player.y)
            if pogoInst ~= nil and pogoInst:isValid() then
                pogoData = pogoInst:getData()
                if player:collidesWith(pogoInst, player.x, player.y) then
                    if pogoData.riding == 1 then
                        if pogoData.drawPopup == 1 then
                            pogoData.drawPopup = 0
                        end
                    else
                        if pogoData.drawPopup == 0 then
                            pogoData.drawPopup = 1
                        end
                        if player:control("enter") == input.PRESSED and pogoData.enterCooldown == 0 and player:get("activity") == 0 then
                            if not net.host then
                                pogoEnterPacket:sendAsClient(player:getNetIdentity(), pogoData.id)
                            else
                                pogoData.riding = 1
                                player:set("activity", ACTIVITY_POGO_DRIVER):set("canrope", 0)
                                playerData.driving = pogoInst
                                pogoData.drawPopup = 0
                                pogoData.enterCooldown = 60
                                
                                pogoEnterPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(), pogoInst:getData().id)
                            end
                        end
                    end
                else
                    if pogoData.drawPopup == 1 then
                        pogoData.drawPopup = 0
                    end
                end
            end
        end
        
        if playerData.driving ~= nil and playerData.driving == pogoInst and pogoData ~= nil then
            pogoStepPacket:sendAsClient(player:getNetIdentity(),
                pogoInst.x, pogoInst.y,
                pogoData.enterCooldown,
                pogoData.riding,
                pogoData.facingLeft,
                pogoData.drawPopup,
                pogoData.heldJump,
                pogoData.heldDirection
            )
            pogoStepPacket:sendAsHost(net.ALL, nil, player:getNetIdentity(),
                pogoInst.x, pogoInst.y,
                pogoData.enterCooldown,
                pogoData.riding,
                pogoData.facingLeft,
                pogoData.drawPopup,
                pogoData.heldJump,
                pogoData.heldDirection
            )
        end
    end
end)

