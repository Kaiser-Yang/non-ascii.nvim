local non_ascii = {}
local utils = require('non-ascii.utils')
local default_config = require('non-ascii.config') --- @as non-ascii.Config
local current_config = default_config --- @as non-ascii.Config

--- @param reverse boolean
--- @param to_end boolean
--- @return string
local get_cmd = function(reverse, to_end)
    if reverse then
        return to_end and 'ge' or 'b'
    else
        return to_end and 'e' or 'w'
    end
end

--- @param row integer
--- @param opts non-ascii.WordJumpConfig
--- @return non-ascii.MatchRange[]
local function split_line(row, opts)
    local range = {} --- @as non-ascii.MatchRange[]
    local i = 0
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
    local line_len = vim.fn.strchars(line)
    while i < line_len do
        local matched = false
        for _, length in ipairs(opts.preffered_jump_length) do
            if i + length <= line_len then
                local word = vim.fn.strcharpart(line, i, length)
                if opts._words[word] then
                    table.insert(range, {
                        row = row,
                        -- convert to 1-indexed
                        start = i + 1,
                        length = length,
                        matched = true,
                    })
                    i = i + length
                    matched = true
                    break
                end
            end
        end
        if not matched then
            local current_char = vim.fn.strcharpart(line, i, 1)
            -- Single Chinese character or punctuation
            if #current_char ~= 1 then
                table.insert(range, {
                    row = row,
                    start = i + 1,
                    -- convert to 1-indexed
                    length = 1,
                    matched = true,
                })
                i = i + 1
            else
                -- Find the next non-ASCII boundary
                local length = 1
                while i + length < line_len and #vim.fn.strcharpart(line, i + length, 1) == 1 do
                    length = length + 1
                end
                table.insert(range, {
                    row = row,
                    -- convert to 1-indexed
                    start = i + 1,
                    length = length,
                    matched = false,
                })
                i = i + length
            end
        end
    end
    return range
end

--- Return the position of the cursor after executing a normal command.
--- @param cmd 'w' | 'b' | 'e' | 'ge'
--- @return integer, integer -- row, col
local function get_normal_cursor_pos(cmd)
    vim.cmd('normal! ' .. cmd .. '<cr>')
    local _, normal_row, normal_col, _, _ =
        unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    return normal_row, normal_col
end

--- Get the cursor position after executing a word jump command.
--- @param row integer
--- @param col integer
--- @param prev? non-ascii.MatchRange
--- @param cur non-ascii.MatchRange
--- @param next? non-ascii.MatchRange
--- @param reverse boolean
--- @param to_end boolean
--- @return integer, integer -- new_row, new_col
local function get_cursor_pos(row, col, prev, cur, next, reverse, to_end)
    local normal_row, normal_col = get_normal_cursor_pos(get_cmd(reverse, to_end))
    --- @param r integer
    --- @param c integer
    --- @return integer, integer -- row_dis, col_dis
    local function get_distance(r, c) return math.abs(r - row), math.abs(c - col) end
    --- @param r integer
    --- @param c integer
    --- @param candidata_col_dis_calculator function(integer, integer): integer
    --- @return integer, integer -- jump_row, jump_col
    local function selector(r, c, candidata_col_dis_calculator)
        local candidate_row_dis, candidate_col_dis = get_distance(r, c)
        local normal_row_dis, normal_col_dis = get_distance(normal_row, normal_col)
        if candidate_row_dis < normal_row_dis then
            return r, c
        elseif candidate_row_dis > normal_row_dis then
            return normal_row, normal_col
        else
            if normal_row ~= row then
                candidate_col_dis = candidata_col_dis_calculator(c)
                normal_col_dis = candidata_col_dis_calculator(normal_col)
            end
            if candidate_col_dis < normal_col_dis then
                return r, c
            else
                return normal_row, normal_col
            end
        end
    end
    --- @param candidate? non-ascii.MatchRange
    --- @param jump_col_extractor function(non-ascii.MatchRange): integer
    --- @param consider_cur boolean
    --- @param candidate_col_dis_calculator function(integer): integer
    --- @return integer, integer -- jump_row, jump_col
    local function handler(
        candidate,
        jump_col_extractor,
        consider_cur,
        candidate_col_dis_calculator
    )
        if consider_cur and cur and cur.matched and jump_col_extractor(cur) ~= col then
            return cur.row, jump_col_extractor(cur)
        else
            if not candidate or not candidate.matched then
                return normal_row, normal_col
            else
                return selector(
                    candidate.row,
                    jump_col_extractor(candidate),
                    candidate_col_dis_calculator
                )
            end
        end
    end
    local movement_handlers = {
        ge = function()
            return handler(
                prev,
                function(c) return c.start + c.length - 1 end,
                false,
                function(c) return -c end
            )
        end,
        w = function()
            return handler(next, function(c) return c.start end, false, function(c) return c end)
        end,
        b = function()
            return handler(prev, function(c) return c.start end, true, function(c) return -c end)
        end,
        e = function()
            return handler(
                next,
                function(c) return c.start + c.length - 1 end,
                true,
                function(c) return c end
            )
        end,
    }
    return movement_handlers[get_cmd(reverse, to_end)]()
end

--- Get the previous, current, and next match ranges based on the cursor position.
--- @param row integer
--- @param col integer
--- @return non-ascii.MatchRange, non-ascii.MatchRange, non-ascii.MatchRange
local function get_prev_cur_next_range(row, col, opts)
    local current_line_range = split_line(row, opts)
    local prev, cur, next
    for i, range in ipairs(current_line_range) do
        if range.start <= col and col < range.start + range.length then
            cur = range
            if i - 1 >= 1 then prev = current_line_range[i - 1] end
            if i + 1 <= #current_line_range then next = current_line_range[i + 1] end
        end
    end
    if prev == nil and row - 1 >= 1 then
        local last_line_range = split_line(row - 1, opts)
        prev = last_line_range[#last_line_range]
    end
    if next == nil and row + 1 <= vim.api.nvim_buf_line_count(0) then
        next = split_line(row + 1, opts)[1]
    end
    return prev, cur, next
end

--- @param opts? non-ascii.WordJumpConfig
--- @param reverse? boolean
local function word_jump(opts, reverse, to_end)
    opts = opts or {}
    reverse = reverse or false
    opts = vim.tbl_deep_extend('force', current_config.word_jump, opts)
    local cnt = vim.v.count1
    local _, row, col, _, _ = unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    while cnt > 0 do
        local prev, cur, next = get_prev_cur_next_range(row, col, opts)
        row, col = get_cursor_pos(row, col, prev, cur, next, reverse, to_end)
        cnt = cnt - 1
    end
    vim.fn.setcursorcharpos(row, col)
end

--- @param opts? non-ascii.Config
function non_ascii.setup(opts)
    opts = opts or {}
    current_config = vim.tbl_deep_extend('force', default_config, opts)
    current_config.word_jump._words = utils.read_words_from_file_list(
        utils.get_option(current_config.word_jump.word_files)
    )
end

--- @param opts? non-ascii.WordJumpConfig
function non_ascii.w(opts) word_jump(opts, false, false) end

--- @param opts? non-ascii.WordJumpConfig
function non_ascii.b(opts) word_jump(opts, true, false) end

--- @param opts? non-ascii.WordJumpConfig
function non_ascii.e(opts) word_jump(opts, false, true) end

--- @param opts? non-ascii.WordJumpConfig
function non_ascii.ge(opts) word_jump(opts, true, true) end

function non_ascii.iw() end

function non_ascii.aw() end

function non_ascii.f() end

function non_ascii.F() end

function non_ascii.t() end

function non_ascii.T() end

return non_ascii
