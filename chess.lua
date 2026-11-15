-- Find connected monitor
local mon = peripheral.find("monitor")
if not mon then
    error("Advanced Monitor not found! Please connect a monitor to the computer.")
end

if not mon.isColor() then
    error("An Advanced (gold) Monitor with color support is required!")
end

-- Adjust text scale to fit the monitor size
mon.setTextScale(1)
local mw, mh = mon.getSize()
if mw < 28 or mh < 18 then
    mon.setTextScale(0.5)
    mw, mh = mon.getSize()
end

-- Board initialization (Uppercase = White, lowercase = Black)
local board = {}
local turn = "white"
local selected = nil
local validMoves = {}
local statusText = "Turn: WHITE"
local gameOver = false

local function initBoard()
    board = {
        {"r", "n", "b", "q", "k", "b", "n", "r"},
        {"p", "p", "p", "p", "p", "p", "p", "p"},
        {" ", " ", " ", " ", " ", " ", " ", " "},
        {" ", " ", " ", " ", " ", " ", " ", " "},
        {" ", " ", " ", " ", " ", " ", " ", " "},
        {" ", " ", " ", " ", " ", " ", " ", " "},
        {"P", "P", "P", "P", "P", "P", "P", "P"},
        {"R", "N", "B", "Q", "K", "B", "N", "R"}
    }
    turn = "white"
    selected = nil
    validMoves = {}
    statusText = "Turn: WHITE"
    gameOver = false
end

-- Helper functions for piece checks
local function getPieceColor(p)
    if p == " " then return nil end
    if p:match("%u") then return "white" end
    return "black"
end

local function inBounds(r, c)
    return r >= 1 and r <= 8 and c >= 1 and c <= 8
end

-- Generate valid moves for the selected square
local function getMoves(r, c)
    local moves = {}
    local p = board[r][c]
    local color = getPieceColor(p)
    if not color then return moves end

    local type = p:upper()

    local function addIfValid(nr, nc)
        if not inBounds(nr, nc) then return false end
        local targetColor = getPieceColor(board[nr][nc])
        if targetColor == nil then
            table.insert(moves, {r = nr, c = nc})
            return true -- empty square, can continue sliding
        elseif targetColor ~= color then
            table.insert(moves, {r = nr, c = nc})
            return false -- enemy piece, cannot move further
        end
        return false -- friendly piece
    end

    local function slide(dirs)
        for _, d in ipairs(dirs) do
            local nr, nc = r + d[1], c + d[2]
            while addIfValid(nr, nc) do
                nr = nr + d[1]
                nc = nc + d[2]
            end
        end
    end

    if type == "P" then
        local dir = (color == "white") and -1 or 1
        local startRow = (color == "white") and 7 or 2
        -- Forward move
        if inBounds(r + dir, c) and board[r + dir][c] == " " then
            table.insert(moves, {r = r + dir, c = c})
            if r == startRow and board[r + 2 * dir][c] == " " then
                table.insert(moves, {r = r + 2 * dir, c = c})
            end
        end
        -- Diagonal capture
        for _, dc in ipairs({-1, 1}) do
            local nr, nc = r + dir, c + dc
            if inBounds(nr, nc) then
                local tc = getPieceColor(board[nr][nc])
                if tc and tc ~= color then
                    table.insert(moves, {r = nr, c = nc})
                end
            end
        end
    elseif type == "R" then
        slide({{1,0}, {-1,0}, {0,1}, {0,-1}})
    elseif type == "B" then
        slide({{1,1}, {1,-1}, {-1,1}, {-1,-1}})
    elseif type == "Q" then
        slide({{1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1}})
    elseif type == "N" then
        local jumps = {{-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}}
        for _, j in ipairs(jumps) do
            addIfValid(r + j[1], c + j[2])
        end
    elseif type == "K" then
        for dr = -1, 1 do
            for dc = -1, 1 do
                if dr ~= 0 or dc ~= 0 then
                    addIfValid(r + dr, c + dc)
                end
            end
        end
    end

    return moves
end

local function isHighlighted(r, c)
    for _, m in ipairs(validMoves) do
        if m.r == r and m.c == c then return true end
    end
    return false
end

-- Render interface on the monitor
local cellW = 3
local cellH = 2
local startX = 3
local startY = 2

local function draw()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- Column labels
    local cols = {"A", "B", "C", "D", "E", "F", "G", "H"}
    mon.setTextColor(colors.lightGray)
    for c = 1, 8 do
        mon.setCursorPos(startX + (c - 1) * cellW + 1, startY - 1)
        mon.write(cols[c])
    end

    -- Draw squares and pieces
    for r = 1, 8 do
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.lightGray)
        mon.setCursorPos(startX - 2, startY + (r - 1) * cellH)
        mon.write(tostring(9 - r))

        for c = 1, 8 do
            local bg = ((r + c) % 2 == 0) and colors.lightGray or colors.gray
            if selected and selected.r == r and selected.c == c then
                bg = colors.yellow
            elseif isHighlighted(r, c) then
                bg = (board[r][c] ~= " ") and colors.red or colors.lime
            end

            mon.setBackgroundColor(bg)
            for dy = 0, cellH - 1 do
                mon.setCursorPos(startX + (c - 1) * cellW, startY + (r - 1) * cellH + dy)
                mon.write(string.rep(" ", cellW))
            end

            local piece = board[r][c]
            if piece ~= " " then
                local pColor = getPieceColor(piece)
                mon.setTextColor(pColor == "white" and colors.white or colors.black)
                mon.setCursorPos(startX + (c - 1) * cellW + 1, startY + (r - 1) * cellH)
                mon.write(piece:upper())
            end
        end
    end

    -- Status text and reset button
    local infoY = startY + 8 * cellH + 1
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setCursorPos(startX, infoY)
    mon.write(statusText)

    mon.setBackgroundColor(colors.red)
    mon.setTextColor(colors.white)
    mon.setCursorPos(startX, infoY + 2)
    mon.write(" [ NEW GAME ] ")
end

-- Handle monitor touch events
local function handleClick(x, y)
    local infoY = startY + 8 * cellH + 1
    -- Check reset button click
    if y == infoY + 2 and x >= startX and x <= startX + 13 then
        initBoard()
        draw()
        return
    end

    if gameOver then return end

    local c = math.floor((x - startX) / cellW) + 1
    local r = math.floor((y - startY) / cellH) + 1

    if not inBounds(r, c) then return end

    -- Execute move if clicked square is highlighted
    if selected and isHighlighted(r, c) then
        local targetPiece = board[r][c]
        board[r][c] = board[selected.r][selected.c]
        board[selected.r][selected.c] = " "

        -- Pawn promotion to Queen
        if board[r][c] == "P" and r == 1 then board[r][c] = "Q" end
        if board[r][c] == "p" and r == 8 then board[r][c] = "q" end

        -- Check win condition on King capture
        if targetPiece:upper() == "K" then
            gameOver = true
            statusText = (turn == "white") and "WHITE WINS!" or "BLACK WINS!"
        else
            turn = (turn == "white") and "black" or "white"
            statusText = (turn == "white") and "Turn: WHITE" or "Turn: BLACK"
        end

        selected = nil
        validMoves = {}
        draw()
        return
    end

    -- Select friendly piece
    local clickedPiece = board[r][c]
    if getPieceColor(clickedPiece) == turn then
        selected = {r = r, c = c}
        validMoves = getMoves(r, c)
    else
        selected = nil
        validMoves = {}
    end
    draw()
end

-- Start the game
initBoard()
draw()
print("Chess started on the monitor! Hold Ctrl+T to exit.")

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    handleClick(x, y)
end
