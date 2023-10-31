local function lerp(a, b, t)
    return a + (b - a) * t
end

local function fpsLerp(a, b, t, dt)
    return a + (b - a) * (1 - math.exp(-t * dt))
end

local function clamp(a, min, max)
    return math.max(min, math.min(max, a))
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    -- top left of screen (8/10 height, 6/10 width)
    mapCanvas = love.graphics.newCanvas(1280/10*6, 720)
    -- right side of screen (2/10 height, 4/10 width)
    tilesetCanvas = love.graphics.newCanvas(1280/10*4, 720)
    tilesetCanvasWidth = 1280/10*4
    tilesetCanvasHeight = 720

    curLayer = 1
    
    -- load tileset
    tiles = {}
    tilesetImg = love.graphics.newImage("tileset.png")
    tilesetRawWidth = tilesetImg:getWidth()
    tilesetRawHeight = tilesetImg:getHeight()
    -- tiles are done in UV coordinates
    -- 12 tiles in width
    -- 11 tiles in height
    tileWidth = tilesetRawWidth / 12
    tileHeight = tilesetRawHeight / 11
    -- quads
    for y = 0, 10 do
        for x = 0, 11 do
            table.insert(tiles, love.graphics.newQuad(x * tileWidth, y * tileHeight, tileWidth, tileHeight, tilesetRawWidth, tilesetRawHeight))
        end
    end

    tilesetScale = 1
    lerpedTilesetScale = 1
    tilesetOffsetX = 0
    tilesetOffsetY = 0

    -- 10 layers
    mapTiles = {}
    for i = 1, 10 do
        mapTiles[i] = {}
    end
    -- holds a table like this: {x = 0, y = 0, tile = 1}

    mapScale = 1
    lerpedMapScale = 1
    mapOffsetX = 0
    mapOffsetY = 0

    -- how many tiles in the map
    mapTileWidth = 64
    mapTileHeight = 64
    mapTileSize = 16

    mapWidth = mapTileWidth * mapTileSize
    mapHeight = mapTileHeight * mapTileSize

    curTile = 1
    multiTileSelect = false
    multiTileSelects = {} -- holds the tile indexes

    curMapEditor = "tile"
end

function love.update(dt)
    mapScale = clamp(mapScale, 0.1, 10)
    tilesetScale = clamp(tilesetScale, 0.1, 10)
    lerpedMapScale = fpsLerp(lerpedMapScale, mapScale, 10, dt)
    lerpedTilesetScale = fpsLerp(lerpedTilesetScale, tilesetScale, 10, dt)
    local mx, my = love.mouse.getPosition()

    if mx < 1280/10*6 then
        if love.mouse.isDown(1) then
            -- place tile
            if not multiTileSelect and curMapEditor == "tile" then
                mx, my = mx / mapScale, my / mapScale
                mx, my = mx - mapOffsetX, my - mapOffsetY
                mx, my = math.floor(mx / mapTileSize), math.floor(my / mapTileSize)
                -- check if we're in the map
                if mx >= 0 and mx < mapTileWidth and my >= 0 and my < mapTileHeight then
                    -- check if we're already placing a tile
                    local found = false
                    for i = 1, #mapTiles[curLayer] do
                        if mapTiles[curLayer][i].x == mx and mapTiles[curLayer][i].y == my then
                            found = true
                            mapTiles[curLayer][i].tile = curTile
                        end
                    end
                    if not found then
                        table.insert(mapTiles[curLayer], {x = mx, y = my, tile = curTile})
                    end
                end
            elseif multiTileSelect and curMapEditor == "tile" then
                mx, my = mx / mapScale, my / mapScale
                mx, my = mx - mapOffsetX, my - mapOffsetY
                mx, my = math.floor(mx / mapTileSize), math.floor(my / mapTileSize)
                if #mapTiles[curLayer] >= 1 then
                    mx, my = mx - ((multiTileSelects[1] - 1) % 12), my - math.floor((multiTileSelects[1] - 1) / 12)

                    if mx >= 0 and mx < mapTileWidth and my >= 0 and my < mapTileHeight then
                        -- check if we're already placing a tile
                        local found = false
                        for i = 1, #mapTiles[curLayer] do
                            if mapTiles[curLayer][i] then
                                if mapTiles[curLayer][i].x == mx and mapTiles[curLayer][i].y == my then
                                    table.remove(mapTiles[curLayer], i)
                                end
                            end
                        end
                        if not found then
                            for i = 1, #multiTileSelects do
                                table.insert(mapTiles[curLayer], {x = mx + ((multiTileSelects[i] - 1) % 12), y = my + math.floor((multiTileSelects[i] - 1) / 12), tile = multiTileSelects[i]})
                            end
                        end
                    end
                end
            end
        elseif love.mouse.isDown(2) then
            -- remove tile
            mx, my = mx / mapScale, my / mapScale
            mx, my = mx - mapOffsetX, my - mapOffsetY
            mx, my = math.floor(mx / mapTileSize), math.floor(my / mapTileSize)
            -- check if we're in the map
            if mx >= 0 and mx < mapTileWidth and my >= 0 and my < mapTileHeight then
                -- check if we're already placing a tile
                for i = 1, #mapTiles[curLayer] do
                    if mapTiles[curLayer][i].x == mx and mapTiles[curLayer][i].y == my then
                        table.remove(mapTiles[curLayer], i)
                    end
                end
            end
        end
    end
end

function love.keypressed(k, scancode, isrepeat)
    if k == "escape" then
        love.event.quit()
    elseif k == "t" then
        curMapEditor = "tile"
    elseif k == "m" then
        curMapEditor = "map"
    elseif k == "tab" then
        multiTileSelect = not multiTileSelect
        if multiTileSelect then
            multiTileSelects = {}
        end
    elseif k == "s" then
        -- map format is like this:
        --[[
            [tile,x,y]|[tile,x,y]|etc
        ]]
        local mapString = ""
        for i = 1, #mapTiles do
            for j = 1, #mapTiles[i] do
                mapString = mapString .. "[" .. mapTiles[i][j].tile .. "," .. mapTiles[i][j].x .. "," .. mapTiles[i][j].y .. "]|"
            end
            --mapString = mapString .. "[" .. mapTiles[curLayer][i].tile .. "," .. mapTiles[curLayer][i].x .. "," .. mapTiles[curLayer][i].y .. "]|"
        end
        mapString = mapString:sub(1, -2)
        love.filesystem.write("map.txt", mapString)
        love.system.openURL("file://" .. love.filesystem.getSaveDirectory() .. "/map.txt")
    elseif k == "l" then
        local mapString = love.filesystem.read("map.txt")
        mapTiles = {}
        for tile, x, y in mapString:gmatch("%[(%d+),(%d+),(%d+)%]") do
            table.insert(mapTiles[curLayer], {x = tonumber(x), y = tonumber(y), tile = tonumber(tile)})
        end
    elseif tonumber(k) then
        local layer = tonumber(k)
        if layer == 0 then layer = 10 end
        curLayer = layer
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if love.mouse.isDown(1) then
        -- is it moving?
        if dx ~= 0 or dy ~= 0 then
            if x < 1280/10*6 and curMapEditor == "map" then
                mapOffsetX = mapOffsetX + dx / mapScale
                mapOffsetY = mapOffsetY + dy / mapScale
            elseif x > 1280/10*6 then
                -- move tileset
                tilesetOffsetX = tilesetOffsetX + dx / tilesetScale
                tilesetOffsetY = tilesetOffsetY + dy / tilesetScale
            end
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        if x < 1280/10*6 then
            -- place tile if we're in the map and curMapEditor is "tile"
            if curMapEditor == "tile" and not multiTileSelect then -- no multi tile select
                x, y = x / mapScale, y / mapScale
                x, y = x - mapOffsetX, y - mapOffsetY
                x, y = math.floor(x / mapTileSize), math.floor(y / mapTileSize)
                -- check if we're in the map
                if x >= 0 and x < mapTileWidth and y >= 0 and y < mapTileHeight then
                    -- check if we're already placing a tile
                    local found = false
                    for i = 1, #mapTiles[curLayer] do
                        if mapTiles[curLayer][i].x == x and mapTiles[curLayer][i].y == y then
                            found = true
                            mapTiles[curLayer][i].tile = curTile
                        end
                    end
                    if not found then
                        table.insert(mapTiles[curLayer], {x = x, y = y, tile = curTile})
                    end
                end
            elseif curMapEditor == "tile" and multiTileSelect then -- multi tile select
                x, y = x / mapScale, y / mapScale
                x, y = x - mapOffsetX, y - mapOffsetY
                x, y = math.floor(x / mapTileSize), math.floor(y / mapTileSize)
                if #multiTileSelects > 1 then
                    x, y = x - ((multiTileSelects[1] - 1) % 12), y - math.floor((multiTileSelects[1] - 1) / 12)
                    if x >= 0 and x < mapTileWidth and y >= 0 and y < mapTileHeight then
                        -- check if we're already placing a tile
                        local found = false
                        for i = 1, #mapTiles[curLayer] do
                            if mapTiles[curLayer][i] then
                                if mapTiles[curLayer][i].x == x and mapTiles[curLayer][i].y == y then
                                    table.remove(mapTiles[curLayer], i)
                                end
                            end
                        end
                        if not found then
                            for i = 1, #multiTileSelects do
                                table.insert(mapTiles[curLayer], {x = x + ((multiTileSelects[i] - 1) % 12), y = y + math.floor((multiTileSelects[i] - 1) / 12), tile = multiTileSelects[i]})
                            end
                        end
                    end
                end
            end
        elseif curMapEditor == "tile" then
            if not multiTileSelect then
                x, y = x - 1280/10*6 - (tilesetOffsetX * tilesetScale), y - (tilesetOffsetY * tilesetScale)
                x, y = math.floor(x / tilesetScale), math.floor(y / tilesetScale)
            
                if x >= 0 and x < tilesetCanvasWidth and y >= 0 and y < tilesetCanvasHeight then
                    curTile = math.floor(x / tileWidth) + math.floor(y / tileHeight) * 12 + 1
                end
            else
                -- multi tile select
                x, y = x - 1280/10*6 - (tilesetOffsetX * tilesetScale), y - (tilesetOffsetY * tilesetScale)
                x, y = math.floor(x / tilesetScale), math.floor(y / tilesetScale)
            
                if x >= 0 and x < tilesetCanvasWidth and y >= 0 and y < tilesetCanvasHeight then
                    local alreadySelected = false
                    for i = 1, #multiTileSelects do
                        if multiTileSelects[i] == math.floor(x / tileWidth) + math.floor(y / tileHeight) * 12 + 1 then
                            alreadySelected = true
                            table.remove(multiTileSelects, i)
                        end
                    end
                    if not alreadySelected then
                        table.insert(multiTileSelects, math.floor(x / tileWidth) + math.floor(y / tileHeight) * 12 + 1)
                    end
                end
            end
        end
    end
end

function love.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    if mx > 1280/10*6 then
        if y > 0 then
            tilesetScale = tilesetScale + 0.1
        elseif y < 0 then
            tilesetScale = tilesetScale - 0.1
        end
    else
        if y > 0 then
            mapScale = mapScale + 0.1
        elseif y < 0 then
            mapScale = mapScale - 0.1
        end
    end
end

function love.draw()
    love.graphics.setCanvas(mapCanvas)
        love.graphics.clear()
        love.graphics.setColor(0.25, 0.25, 0.25)
        love.graphics.rectangle("fill", 0, 0, 1280/10*6, 720)

        love.graphics.setColor(1, 1, 1)
        love.graphics.push()
            love.graphics.scale(lerpedMapScale, lerpedMapScale)
            love.graphics.translate(mapOffsetX, mapOffsetY)
            -- draw a grid
            love.graphics.setColor(0.5, 0.5, 0.5)
            for x = 0, mapWidth, mapTileSize do
                love.graphics.line(x, 0, x, mapHeight)
            end
            for y = 0, mapHeight, mapTileSize do
                love.graphics.line(0, y, mapWidth, y)
            end
            love.graphics.setColor(1, 1, 1)
            -- draw map
            for i = 1, #mapTiles do
                --love.graphics.draw(tilesetImg, tiles[mapTiles[i].tile], mapTiles[i].x * mapTileSize, mapTiles[i].y * mapTileSize)
                for j = 1, #mapTiles[i] do
                    if mapTiles[i][j].tile then
                        love.graphics.draw(tilesetImg, tiles[mapTiles[i][j].tile], mapTiles[i][j].x * mapTileSize, mapTiles[i][j].y * mapTileSize)
                    end
                end
            end
            love.graphics.setColor(1, 1, 1)
        love.graphics.pop()
    love.graphics.setCanvas()

    love.graphics.setCanvas(tilesetCanvas)
        love.graphics.clear()
        love.graphics.push()
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("fill", 0, 0, 1280/10*4, 720)
            love.graphics.setColor(1, 1, 1)
            love.graphics.scale(lerpedTilesetScale, lerpedTilesetScale)
            love.graphics.translate(tilesetOffsetX, tilesetOffsetY)
            -- draw  tileset
            for i = 1, #tiles do
                love.graphics.draw(tilesetImg, tiles[i], (i - 1) % 12 * tileWidth, math.floor((i - 1) / 12) * tileHeight)
            end
            -- highlight current tile
            love.graphics.setColor(1, 0, 0)
            if not multiTileSelect then
                love.graphics.rectangle("line", (curTile - 1) % 12 * tileWidth, math.floor((curTile - 1) / 12) * tileHeight, tileWidth, tileHeight)
            else
                -- highlight all selected tiles
                for i = 1, #multiTileSelects do
                    love.graphics.rectangle("line", (multiTileSelects[i] - 1) % 12 * tileWidth, math.floor((multiTileSelects[i] - 1) / 12) * tileHeight, tileWidth, tileHeight)
                end
            end
            love.graphics.setColor(1, 1, 1)
        love.graphics.pop()
    love.graphics.setCanvas()

    love.graphics.clear()
    love.graphics.draw(mapCanvas, 0, 0)
    -- draw line between map and tileset
    love.graphics.setColor(0, 0, 0)
    love.graphics.line(1280/10*6, 0, 1280/10*6, 720)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(tilesetCanvas, 1280/10*6, 0)

    love.graphics.setColor(0,0,0,1) -- right aligned debug text and info
    love.graphics.printf("Map Editor " ..
                        "\n\n" ..
                        "Current Map Editor: " .. curMapEditor ..
                        "\n" ..
                        "Current Tile: " .. curTile ..
                        "\n" ..
                        "Multi Tile Select: " .. tostring(multiTileSelect) ..
                        "\n" ..
                        "Multi Tile Selects: " .. table.concat(multiTileSelects, ", ") ..
                        
                        "\n\n" ..
                        "Key Bindings:" ..
                        "\n" ..
                        "Escape: Quit" ..
                        "\n" ..
                        "T: Switch to Tile Editor" ..
                        "\n" ..
                        "M: Switch to Map viewer" ..
                        "\n" ..
                        "Tab: Toggle Multi Tile Select" ..
                        "\n" ..
                        "Mouse Wheel: Zoom" ..
                        "\n" ..
                        "Left Click: Place Tile/Select Tile" ..
                        "\n" ..
                        "Right Click: Remove Tile" ..
                        "\n" ..
                        "Left click and drag: Move Map/Tileset" ..
                        "\n" .. 
                        "Number Keys: Switch Layers" ..,
                        0, 0, 1280, "right")
end

function love.quit()

end