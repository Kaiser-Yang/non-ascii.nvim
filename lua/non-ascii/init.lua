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
--- @return non-ascii.MatchRange[]
local function split_line(row)
    local range = {} --- @as non-ascii.MatchRange[]
    local i = 0
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
    local line_len = vim.fn.strchars(line)
    while i < line_len do
        local matched = false
        for _, length in ipairs(current_config.word_jump.preffered_jump_length) do
            if i + length <= line_len then
                local word = vim.fn.strcharpart(line, i, length)
                if current_config.word_jump._words[word] then
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
--- @param row integer
--- @param col integer
--- @param cmd string
--- @return integer, integer -- row, col
local function get_normal_cursor_pos(row, col, cmd)
    local _, original_row, original_col, _, _ =
        unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    vim.fn.setcursorcharpos(row, col)
    vim.cmd('normal! ' .. cmd)
    local _, normal_row, normal_col, _, _ =
        unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    vim.fn.setcursorcharpos(original_row, original_col)
    return normal_row, normal_col
end

--- Get the cursor position after executing a word jump command.
--- @param row integer
--- @param col integer
--- @param prev? non-ascii.MatchRange
--- @param cur? non-ascii.MatchRange
--- @param next? non-ascii.MatchRange
--- @param reverse boolean
--- @param to_end boolean
--- @return integer, integer -- new_row, new_col
local function get_cursor_pos(row, col, prev, cur, next, reverse, to_end)
    local normal_row, normal_col = get_normal_cursor_pos(row, col, get_cmd(reverse, to_end))
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
local function get_prev_cur_next_range(row, col)
    local current_line_range = split_line(row)
    local prev, cur, next
    for i, range in ipairs(current_line_range) do
        if range.start <= col and col < range.start + range.length then
            cur = range
            if i - 1 >= 1 then prev = current_line_range[i - 1] end
            if i + 1 <= #current_line_range then next = current_line_range[i + 1] end
        end
    end
    if prev == nil and row - 1 >= 1 then
        local last_line_range = split_line(row - 1)
        prev = last_line_range[#last_line_range]
    end
    if next == nil and row + 1 <= vim.api.nvim_buf_line_count(0) then
        next = split_line(row + 1)[1]
    end
    return prev, cur, next
end

--- Get the final cursor position after executing word jump command <cnt> times.
--- @param row integer -- Starting row
--- @param col integer -- Starting column
--- @param reverse boolean
--- @param to_end boolean
--- @param cnt integer
--- @return integer, integer
local function get_final_cursor_pos(row, col, reverse, to_end, cnt)
    local is_visual = vim.api.nvim_get_mode().mode:match('[vV\22]') ~= nil
    -- If in visual mode, exit visual mode first
    if is_visual then vim.cmd('normal! ') end

    while cnt > 0 do
        local prev, cur, next = get_prev_cur_next_range(row, col)
        row, col = get_cursor_pos(row, col, prev, cur, next, reverse, to_end)
        cnt = cnt - 1
    end

    -- Restore the visual mode if it was
    if is_visual then vim.cmd('normal! gv') end
    return row, col
end

--- @param reverse boolean
--- @param to_end boolean
local function word_jump(reverse, to_end)
    local _, row, col, _, _ = unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    row, col = get_final_cursor_pos(row, col, reverse, to_end, vim.v.count1)
    vim.fn.setcursorcharpos(row, col)
end

local function get_next_iw_pos(row, col, reverse)
    local tmp_row_1, tmp_col_1 = get_normal_cursor_pos(row, col, 'e')
    local tmp_row_2, tmp_col_2 = get_normal_cursor_pos(row, col, 'w')
    tmp_row_2, tmp_col_2 = utils.cursor_pos_after_move(tmp_row_2, tmp_col_2, -1)
    local tmp_row_3, tmp_col_3 = get_normal_cursor_pos(row, col, 'e')
    tmp_row_3, tmp_col_3 = get_normal_cursor_pos(tmp_row_3, tmp_col_3, 'ge')
    if reverse then
        tmp_row_1, tmp_col_1 = get_normal_cursor_pos(row, col, 'b')
        tmp_row_2, tmp_col_2 = get_normal_cursor_pos(row, col, 'ge')
        tmp_row_2, tmp_col_2 = utils.cursor_pos_after_move(tmp_row_2, tmp_col_2, 1)
        tmp_row_3, tmp_col_3 = get_normal_cursor_pos(row, col, 'b')
        tmp_row_3, tmp_col_3 = get_normal_cursor_pos(tmp_row_3, tmp_col_3, 'w')
    end
    if
        utils.cursor_pos_compare(tmp_row_3, tmp_col_3, row, col) == 0
        or utils.cursor_pos_compare(tmp_row_1, tmp_col_1, row, col) == 0
    then
        return row, col
    elseif
        (
            not reverse
                and utils.cursor_pos_compare(tmp_row_1, tmp_col_1, tmp_row_2, tmp_col_2) <= 0
            or reverse
                and utils.cursor_pos_compare(tmp_row_1, tmp_col_1, tmp_row_2, tmp_col_2) >= 0

        ) and utils.cursor_pos_compare(tmp_row_1, tmp_col_1, row, col) ~= 0
    then
        return tmp_row_1, tmp_col_1
    else
        return tmp_row_2, tmp_col_2
    end
end

--- @param opts? non-ascii.Config
function non_ascii.setup(opts)
    opts = opts or {}
    current_config = vim.tbl_deep_extend('force', default_config, opts)
    current_config.word_jump._words =
        utils.read_words_from_file_list(utils.get_option(current_config.word_jump.word_files))
end

function non_ascii.w() word_jump(false, false) end

function non_ascii.b() word_jump(true, false) end

function non_ascii.e() word_jump(false, true) end

function non_ascii.ge() word_jump(true, true) end

function non_ascii.iw()
    local _, cur_row, cur_col, _, _ =
        unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    local _, cur, _ = get_prev_cur_next_range(cur_row, cur_col)
    local is_visual = vim.api.nvim_get_mode().mode:match('[vV\22]') ~= nil
    local visual_start_row, visual_start_col
    local not_selected
    local reverse = false
    if is_visual then
        local pos = vim.fn.getcharpos('v')
        visual_start_row, visual_start_col = pos[2], pos[3]
        if cur_row == visual_start_row and cur_col == visual_start_col then not_selected = true end
        reverse = utils.cursor_pos_compare(visual_start_row, visual_start_col, cur_row, cur_col) > 0
    end
    local start_row, start_col, end_row, end_col
    local cnt = vim.v.count1 - 1
    if not is_visual or not_selected then
        if not cur then
            -- This is an empty line
            start_row, start_col = cur_row, cur_col
            end_row, end_col = cur_row, cur_col
            if is_visual then cnt = cnt + 1 end
        elseif cur.matched then
            start_row, start_col = cur.row, cur.start
            end_row, end_col = cur.row, cur.start + cur.length - 1
            if is_visual and cur.length == 1 then cnt = cnt + 1 end
        else
            start_row, start_col = get_next_iw_pos(cur_row, cur_col, true)
            end_row, end_col = get_next_iw_pos(cur_row, cur_col, false)
            if
                is_visual
                and utils.cursor_pos_compare(start_row, start_col, end_row, end_col) == 0
            then
                cnt = cnt + 1
            end
        end
    else
        start_row, start_col = visual_start_row, visual_start_col
        if not cur then
            -- This is an empty line
            end_row, end_col = cur_row, cur_col
        elseif cur.matched then
            end_row, end_col = cur.row, (reverse and cur.start or cur.start + cur.length - 1)
        else
            end_row, end_col = get_next_iw_pos(cur_row, cur_col, reverse)
        end
        if utils.cursor_pos_compare(end_row, end_col, cur_row, cur_col) == 0 then cnt = cnt + 1 end
    end
    while cnt > 0 do
        end_row, end_col = utils.cursor_pos_after_move(end_row, end_col, reverse and -1 or 1)
        _, cur, _ = get_prev_cur_next_range(end_row, end_col)
        if not cur then
            -- This is an empty line,
            -- so we do nothing
        elseif cur.matched then
            end_row, end_col = cur.row, (reverse and cur.start or cur.start + cur.length - 1)
        else
            end_row, end_col = get_next_iw_pos(end_row, end_col, reverse)
        end
        cnt = cnt - 1
    end
    if is_visual then vim.cmd('normal! ') end
    vim.cmd('normal! v')
    vim.fn.setcursorcharpos(start_row, start_col)
    vim.cmd('normal! o')
    vim.fn.setcursorcharpos(end_row, end_col)
end

function non_ascii.aw() end

function non_ascii.f() end

function non_ascii.F() end

function non_ascii.t() end

function non_ascii.T() end

return non_ascii
