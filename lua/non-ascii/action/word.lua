local word = {}
local utils = require('non-ascii.utils')

--- @param row integer
--- @param col integer
--- @param is_separator function(string): boolean
--- @param before_limit integer
--- @param after_limit integer
--- @param preferred_jump_length integer[]
--- @param words non-ascii.Words
--- @return non-ascii.MatchRange[]
local function split_lines(
    row,
    col,
    is_separator,
    before_limit,
    after_limit,
    preferred_jump_length,
    words
)
    local res = {} --- @as non-ascii.MatchRange[]
    local prev_idx, cur_idx, next_idx
    local line_ranges = utils.split_line(row, is_separator, preferred_jump_length, words)
    for i, range in ipairs(line_ranges) do
        if range.col <= col and range.col + range.length - 1 >= col then
            cur_idx = i
        elseif range.col + range.length - 1 < col then
            prev_idx = i
        elseif not next_idx and range.col > col then
            next_idx = i
        end
    end
    local line_count, _ = utils.get_end_of_file()
    --- @return non-ascii.MatchRange[]
    local function process_lines(
        start,
        finish,
        step,
        limit,
        extract_from_last,
        insert_at_first,
        idx
    )
        local collected = {} --- @as non-ascii.MatchRange[]
        while #collected < limit and idx and idx >= 1 and idx <= #line_ranges do
            if insert_at_first then
                table.insert(collected, 1, line_ranges[idx])
            else
                table.insert(collected, line_ranges[idx])
            end
            idx = idx + (extract_from_last and -1 or 1)
        end
        for line_num = start, finish, step do
            local segments = utils.split_line(line_num, is_separator, preferred_jump_length, words)
            -- Add end-of-line segment if newline isn't a separator
            if not is_separator('\n') then
                local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1] or ''
                local line_len = vim.fn.strchars(line)
                table.insert(segments, {
                    row = line_num,
                    col = line_len,
                    length = 1,
                })
            end
            -- Process segments until limit is reached
            while #collected < limit and #segments > 0 do
                local segment = table.remove(segments, extract_from_last and #segments or 1)
                if insert_at_first then
                    table.insert(collected, 1, segment)
                else
                    table.insert(collected, segment)
                end
            end

            if #collected >= limit then break end
        end
        while #collected < limit do
            if insert_at_first then
                table.insert(collected, 1, '')
            else
                table.insert(collected, '')
            end
        end
        return collected
    end
    local before_ranges = process_lines(row - 1, 1, -1, before_limit, true, true, prev_idx)
    local after_ranges = process_lines(row + 1, line_count, 1, after_limit, false, false, next_idx)
    for i = 1, before_limit do
        res[i] = before_ranges[i]
    end
    res[before_limit + 1] = cur_idx and line_ranges[cur_idx] or nil
    for i = 1, after_limit do
        res[before_limit + 1 + i] = after_ranges[i]
    end
    for i = 1, #res do
        if res[i] == '' then res[i] = nil end
    end
    return res
end

local function get_start_pos(row, col, action, is_separator, preferred_jump_length, words)
    if utils.is_visual() then
        local visual_start_row, visual_start_col = utils.get_visual_start_pos()
        assert(visual_start_row and visual_start_col)
        if utils.cursor_pos_compare(row, col, visual_start_row, visual_start_col) ~= 0 then
            return visual_start_row, visual_start_col
        end
    end
    local res = split_lines(row, col, is_separator, 1, 1, preferred_jump_length, words)
    local prev, cur, next = res[1], res[2], res[3]
    if not cur then
        if action == 'iw' then
            if prev then
                return utils.cursor_pos_after_move(prev.row, prev.col, prev.length)
            else
                return 1, 1
            end
        else
            return row, col
        end
    else
        if action == 'iw' then
            return cur.row, cur.col
        else
            if next and utils.has_separator_between(cur, next) then
                return cur.row, cur.col
            elseif prev and utils.has_separator_between(prev, cur) then
                return utils.cursor_pos_after_move(prev.row, prev.col, prev.length)
            else
                return cur.row, cur.col
            end
        end
    end
end

--- Get the cursor position after executing a word jump command.
--- @param row integer
--- @param col integer
--- @param action non-ascii.WordAction
--- @param is_separator function(string): boolean
--- @param preferred_jump_length integer[]
--- @param words non-ascii.Words
--- @return integer, integer -- new_row, new_col
local function internal_get_cursor_pos(row, col, action, is_separator, preferred_jump_length, words)
    assert(action ~= 'iw' and action ~= 'aw', 'Use get_cursor_pos for iw/aw actions')
    -- Do not use unpack here, the return value is a list containing nil
    local res = split_lines(row, col, is_separator, 1, 1, preferred_jump_length, words)
    local prev, cur, next = res[1], res[2], res[3]
    --- @param candidate? non-ascii.MatchRange
    --- @param jump_pos_extractor function(non-ascii.WordRange): integer, integer
    --- @param consider_cur boolean
    --- @param default_row integer
    --- @param default_col integer
    --- @return integer, integer -- jump_row, jump_col
    local function handler(candidate, jump_pos_extractor, consider_cur, default_row, default_col)
        local jump_row, jump_col
        if cur then
            jump_row, jump_col = jump_pos_extractor(cur)
        end
        if
            consider_cur
            and cur
            and (
                utils.cursor_pos_compare(jump_row, jump_col, row, col) ~= 0
                or utils.is_operator() and (action == 'e' or action == 'ge')
            )
        then
            return jump_row, jump_col
        elseif not candidate then
            return default_row, default_col
        else
            return jump_pos_extractor(candidate)
        end
    end
    local line_count, last_line_length = utils.get_end_of_file()
    local movement_handlers = {
        ge = function()
            return handler(
                prev,
                function(c) return utils.cursor_pos_after_move(c.row, c.col, c.length - 1) end,
                false,
                1,
                1
            )
        end,
        w = function()
            return handler(
                next,
                function(c) return c.row, c.col end,
                false,
                line_count,
                last_line_length
            )
        end,
        b = function()
            return handler(prev, function(c) return c.row, c.col end, true, 1, 1)
        end,
        e = function()
            return handler(
                next,
                function(c) return utils.cursor_pos_after_move(c.row, c.col, c.length - 1) end,
                true,
                line_count,
                last_line_length
            )
        end,
    }
    return movement_handlers[action]()
end

local function get_cursor_pos(row, col, action, is_separator, preferred_jump_length, words)
    if action == 'iw' then
        if utils.is_reverse_visual() then
        else
        end
    elseif action == 'aw' then
        if utils.is_reverse_visual() then
        else
        end
    else
        return internal_get_cursor_pos(row, col, action, is_separator, preferred_jump_length, words)
    end
end

--- @param action non-ascii.WordAction
--- @param is_separator function(string): boolean
--- @param preferred_jump_length integer[]
--- @param words non-ascii.Words
function word.jump(action, is_separator, preferred_jump_length, words)
    local _, row, col, _, _ = unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    local start_row, start_col
    local visual_start_row, visual_start_col = utils.get_visual_start_pos()
    if action == 'iw' or action == 'aw' then
        start_row, start_col =
            get_start_pos(row, col, action, is_separator, preferred_jump_length, words)
    end
    local cnt = vim.v.count1
    local extra_motion = utils.is_operator() and (action == 'e' or action == 'ge')
    local first_time = true
    while cnt > 0 do
        local new_row, new_col =
            get_cursor_pos(row, col, action, is_separator, preferred_jump_length, words)
        if
            (not utils.is_visual() or not first_time)
                and utils.cursor_pos_compare(new_row, new_col, row, col) == 0
            or utils.is_visual()
                and first_time
                and utils.content_range_a_in_b(
                    start_row,
                    start_col,
                    new_row,
                    new_col,
                    ---@diagnostic disable-next-line: param-type-mismatch
                    visual_start_row,
                    ---@diagnostic disable-next-line: param-type-mismatch
                    visual_start_col,
                    row,
                    col
                )
        then
            new_row, new_col = utils.cursor_pos_after_move(
                row,
                col,
                (action == 'e' or action == 'w') and 1
                    or (action == 'b' or action == 'ge') and -1
                    or utils.is_reverse_visual() and -1
                    or 1
            )
            -- We are at the end of the file
            if utils.cursor_pos_compare(new_row, new_col, row, col) == 0 then
                extra_motion = true
                break
            else
                extra_motion = false
            end
            if not utils.is_operator() or not first_time then
                new_row, new_col = get_cursor_pos(
                    new_row,
                    new_col,
                    action,
                    is_separator,
                    preferred_jump_length,
                    words
                )
                if utils.is_operator() then extra_motion = true end
            end
        end
        first_time = false
        row, col = new_row, new_col
        cnt = cnt - 1
    end
    if start_row and start_col then
        vim.cmd('normal! v')
        vim.fn.setcursorcharpos(start_row, start_col)
        vim.cmd('normal! o')
    end
    vim.fn.setcursorcharpos(row, col)
    if extra_motion then vim.cmd('normal! x') end
end

return word
