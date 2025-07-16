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
    local function handle_new_line(collect, row_num)
        if not is_separator('\n') and row_num < vim.api.nvim_buf_line_count(0) then
            table.insert(collect, {
                row = row_num + 1,
                col = 1,
                length = 1,
            })
        end
    end
    handle_new_line(line_ranges, row)
    for i, range in ipairs(line_ranges) do
        if range.row == row and range.col <= col and range.col + range.length - 1 >= col then
            cur_idx = i
        elseif range.row == row and range.col + range.length - 1 < col then
            prev_idx = i
        elseif not next_idx and (range.row == row and range.col > col or range.row > row) then
            next_idx = i
        end
    end
    local line_count, last_line_length = utils.get_end_of_file()
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
            handle_new_line(segments, line_num)
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
        if before_ranges[i] == '' then
            before_ranges[i] = {
                row = 1,
                col = 1,
                length = 1,
            }
        end
        res[i] = before_ranges[i]
    end
    res[before_limit + 1] = cur_idx and line_ranges[cur_idx] or nil
    for i = 1, after_limit do
        if after_ranges[i] == '' then
            after_ranges[i] = {
                row = line_count,
                col = last_line_length,
                length = 1,
            }
        end
        res[before_limit + 1 + i] = after_ranges[i]
    end
    return res
end

--- @return integer, integer, integer, integer
local function get_start_end_pos(row, col, action, is_separator, preferred_jump_length, words)
    local start_row, start_col, end_row, end_col
    local res = split_lines(row, col, is_separator, 1, 1, preferred_jump_length, words)
    local prev, cur, next = res[1], res[2], res[3]
    local selected
    local visual_start_row, visual_start_col = utils.get_visual_start_pos()
    if utils.is_visual() then
        assert(visual_start_row and visual_start_col)
        if utils.cursor_pos_compare(row, col, visual_start_row, visual_start_col) ~= 0 then
            selected = true
        end
    end
    if selected then
        start_row, start_col = visual_start_row, visual_start_col
    elseif not cur then
        if action == 'iw' then
            if prev then
                start_row, start_col = utils.cursor_pos_after_move(prev.row, prev.col, prev.length)
            else
                start_row, start_col = 1, 1
            end
        else
            -- INFO:
            -- This is the default behavior of neovim, should I update this?
            start_row, start_col = row, col
        end
    else
        if action == 'iw' then
            start_row, start_col = cur.row, cur.col
        else
            if next and utils.has_separator_between(cur, next) then
                start_row, start_col = cur.row, cur.col
            elseif prev and utils.has_separator_between(prev, cur) then
                start_row, start_col = utils.cursor_pos_after_move(prev.row, prev.col, prev.length)
            else
                start_row, start_col = cur.row, cur.col
            end
        end
    end
    -- HACK:
    -- Not elegant at all, a piece of shit code
    -- Try to refactor this code
    if not cur then
        if utils.is_reverse_visual() then
            if action == 'iw' then
                if prev then
                    end_row, end_col = utils.cursor_pos_after_move(prev.row, prev.col, prev.length)
                else
                    end_row, end_col = 1, 1
                end
            else
                if prev then
                    if
                        utils.has_separator_between(prev, {
                            row = row,
                            col = col,
                            length = 1,
                        })
                    then
                        end_row, end_col = prev.row, prev.col
                    else
                        res = split_lines(
                            prev.row,
                            prev.col,
                            is_separator,
                            1,
                            0,
                            preferred_jump_length,
                            words
                        )
                        local prev_prev = res[1]
                        if not prev_prev then
                            end_row, end_col = 1, 1
                        else
                            end_row, end_col = utils.cursor_pos_after_move(
                                prev_prev.row,
                                prev_prev.col,
                                prev_prev.length
                            )
                        end
                    end
                else
                    end_row, end_col = 1, 1
                end
            end
        else
            if action == 'iw' then
                if next then
                    end_row, end_col = utils.cursor_pos_after_move(next.row, next.col, -1)
                else
                    end_row, end_col = utils.get_end_of_file()
                end
            else
                if next then
                    if
                        utils.has_separator_between({
                            row = row,
                            col = col,
                            length = 1,
                        }, next)
                    then
                        end_row, end_col =
                            utils.cursor_pos_after_move(next.row, next.col, next.length - 1)
                    else
                        res = split_lines(
                            next.row,
                            next.col,
                            is_separator,
                            0,
                            1,
                            preferred_jump_length,
                            words
                        )
                        local next_next = res[2]
                        if not next_next then
                            end_row, end_col = utils.get_end_of_file()
                        else
                            end_row, end_col =
                                utils.cursor_pos_after_move(next_next.row, next_next.col, -1)
                        end
                    end
                else
                    end_row, end_col = utils.get_end_of_file()
                end
            end
        end
    else
        if utils.is_reverse_visual() then
            if action == 'iw' then
                end_row, end_col = cur.row, cur.col
            else
                if utils.cursor_pos_compare(row, col, cur.row, cur.col) == 0 then
                    if prev then
                        if utils.has_separator_between(prev, cur) then
                            end_row, end_col = prev.row, prev.col
                        else
                            res = split_lines(
                                prev.row,
                                prev.col,
                                is_separator,
                                1,
                                0,
                                preferred_jump_length,
                                words
                            )
                            local prev_prev = res[1]
                            if not prev_prev then
                                end_row, end_col = 1, 1
                            else
                                end_row, end_col = utils.cursor_pos_after_move(
                                    prev_prev.row,
                                    prev_prev.col,
                                    prev_prev.length
                                )
                            end
                        end
                    else
                        end_row, end_col = 1, 1
                    end
                else
                    if prev then
                        end_row, end_col =
                            utils.cursor_pos_after_move(prev.row, prev.col, prev.length)
                    else
                        end_row, end_col = 1, 1
                    end
                end
            end
        else
            if action == 'iw' then
                end_row, end_col = utils.cursor_pos_after_move(cur.row, cur.col, cur.length - 1)
            else
                local cur_row_end, cur_col_end =
                    utils.cursor_pos_after_move(cur.row, cur.col, cur.length - 1)
                if utils.cursor_pos_compare(row, col, cur_row_end, cur_col_end) == 0 then
                    if next then
                        if utils.has_separator_between(cur, next) then
                            end_row, end_col =
                                utils.cursor_pos_after_move(next.row, next.col, next.length - 1)
                        else
                            res = split_lines(
                                next.row,
                                next.col,
                                is_separator,
                                0,
                                1,
                                preferred_jump_length,
                                words
                            )
                            local next_next = res[2]
                            if not next_next then
                                end_row, end_col = utils.get_end_of_file()
                            else
                                end_row, end_col =
                                    utils.cursor_pos_after_move(next_next.row, next_next.col, -1)
                            end
                        end
                    else
                        end_row, end_col = utils.get_end_of_file()
                    end
                else
                    if next then
                        end_row, end_col = utils.cursor_pos_after_move(next.row, next.col, -1)
                    else
                        end_row, end_col = utils.get_end_of_file()
                    end
                end
            end
        end
    end
    return start_row, start_col, end_row, end_col
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
    --- @param movement non-ascii.WordAction
    local function get_pos(movement, pos)
        pos = pos or { row, col }
        return {
            internal_get_cursor_pos(
                pos[1],
                pos[2],
                movement,
                is_separator,
                preferred_jump_length,
                words
            ),
        }
    end
    local candidates = {}
    -- Check if all candidates match current position
    local function all_candidates_match()
        for _, cand in ipairs(candidates) do
            if utils.cursor_pos_compare(cand[1], cand[2], row, col) ~= 0 then return false end
        end
        return true
    end
    local function add_candidate(pos, adjustment)
        adjustment = adjustment or 0
        local adjusted = { utils.cursor_pos_after_move(pos[1], pos[2], adjustment) }
        table.insert(candidates, adjusted)
    end
    local function select_best_candidate()
        local function comparator(a, b)
            -- Handle current position special case
            if utils.cursor_pos_compare(a[1], a[2], row, col) == 0 then return 1 end
            if utils.cursor_pos_compare(b[1], b[2], row, col) == 0 then return -1 end

            -- Determine comparison direction based on action and mode
            local base_compare = utils.cursor_pos_compare(a[1], a[2], b[1], b[2])
            if action == 'iw' then
                return utils.is_reverse_visual() and -base_compare or base_compare
            else
                return utils.is_reverse_visual() and base_compare or -base_compare
            end
        end

        -- Find best candidate using comparator
        local best = candidates[1]
        for i = 2, #candidates do
            if comparator(candidates[i], best) < 0 then best = candidates[i] end
        end
        return best[1], best[2]
    end
    if action == 'iw' or action == 'aw' then
        add_candidate(get_pos(utils.is_reverse_visual() and 'b' or 'e'))
        local ge_or_w_pos = get_pos(utils.is_reverse_visual() and 'ge' or 'w')
        add_candidate(ge_or_w_pos, utils.is_reverse_visual() and 1 or -1)
        if action == 'aw' and all_candidates_match() then
            ge_or_w_pos = get_pos(utils.is_reverse_visual() and 'ge' or 'w', ge_or_w_pos)
            add_candidate(ge_or_w_pos, utils.is_reverse_visual() and 1 or -1)
        end
        return select_best_candidate()
    else
        local pos = get_pos(action)
        return pos[1], pos[2]
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
    local cnt = vim.v.count1
    local first_time = true
    if action == 'iw' or action == 'aw' then
        local end_row, end_col
        start_row, start_col, end_row, end_col =
            get_start_end_pos(row, col, action, is_separator, preferred_jump_length, words)
        if
            visual_start_row
            and visual_start_col
            and not utils.content_range_a_in_b(
                start_row,
                start_col,
                end_row,
                end_col,
                visual_start_row,
                visual_start_col,
                row,
                col
            )
        then
            row, col = end_row, end_col
            cnt = cnt - 1
            first_time = false
        end
    end
    while cnt > 0 do
        local new_row, new_col =
            get_cursor_pos(row, col, action, is_separator, preferred_jump_length, words)
        if
            (not utils.is_visual() or not first_time)
                and utils.cursor_pos_compare(new_row, new_col, row, col) == 0
                and not (utils.is_operator() and first_time)
            or visual_start_row
                and visual_start_col
                and start_row
                and start_col
                and first_time
                and utils.content_range_a_in_b(
                    start_row,
                    start_col,
                    new_row,
                    new_col,
                    visual_start_row,
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
            new_row, new_col =
                get_cursor_pos(new_row, new_col, action, is_separator, preferred_jump_length, words)
        end
        first_time = false
        row, col = new_row, new_col
        cnt = cnt - 1
    end
    if start_row and start_col then
        if utils.is_visual() then vim.cmd('normal! ') end
        vim.cmd('normal! v')
        vim.fn.setcursorcharpos(start_row, start_col)
        vim.cmd('normal! o')
    end
    local eof_row, eof_col = utils.get_end_of_file()
    if
        utils.is_operator()
        and (
            (action == 'e' or action == 'ge')
            or utils.cursor_pos_compare(row, col, eof_row, eof_col) == 0
        )
    then
        local new_row, new_col = utils.cursor_pos_after_move(row, col, 1)
        if utils.cursor_pos_compare(new_row, new_col, row, col) == 0 then
            vim.schedule(function()
                local line = vim.api.nvim_get_current_line()
                -- Use undojoin here to make sure one undo step can back to the original line
                vim.cmd('undojoin')
                vim.api.nvim_set_current_line(
                    vim.fn.strcharpart(line, 0, vim.fn.strchars(line) - 1)
                )
            end)
        else
            row, col = new_row, new_col
        end
    end
    vim.fn.setcursorcharpos(row, col)
end

return word
