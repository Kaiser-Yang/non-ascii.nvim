local utils = {}

function utils.get_option(opt, ...)
    if type(opt) == 'function' then
        return opt(...)
    else
        return opt
    end
end

--- @param file_path_list string[]
function utils.read_words_from_file_list(file_path_list)
    local words = {} --- @as non-ascii.Words
    for _, file_path in ipairs(file_path_list) do
        local file = io.open(file_path, 'r')
        if not file then
            vim.notify('Failed to open word file: ' .. file_path, vim.log.levels.ERROR)
            goto continue
        end
        for line in file:lines() do
            words[line] = true
        end
        file:close()
        ::continue::
    end
    return words
end

--- Compare two cursor positions.
--- @param row1 integer The row of the first cursor position.
--- @param col1 integer The column of the first cursor position.
--- @param row2 integer The row of the second cursor position.
--- @param col2 integer The column of the second cursor position.
--- @return integer Returns -1 if the first position is before the second,
--- 1 if after, and 0 if they are same.
function utils.cursor_pos_compare(row1, col1, row2, col2)
    if row1 < row2 then
        return -1
    elseif row1 > row2 then
        return 1
    else
        if col1 < col2 then
            return -1
        elseif col1 > col2 then
            return 1
        else
            return 0
        end
    end
end

function utils.normalize_content_range(row1, col1, row2, col2)
    if utils.cursor_pos_compare(row1, col1, row2, col2) > 0 then
        -- Swap if the first point is greater than the second
        row1, col1, row2, col2 = row2, col2, row1, col1
    end
    return row1, col1, row2, col2
end

--- @param a_row1 integer
--- @param a_col1 integer
--- @param a_row2 integer
--- @param a_col2 integer
--- @param b_row1 integer
--- @param b_col1 integer
--- @param b_row2 integer
--- @param b_col2 integer
--- @return boolean Returns true if content range A is completely within content range B.
function utils.content_range_a_in_b(a_row1, a_col1, a_row2, a_col2, b_row1, b_col1, b_row2, b_col2)
    a_row1, a_col1, a_row2, a_col2 = utils.normalize_content_range(a_row1, a_col1, a_row2, a_col2)
    b_row1, b_col1, b_row2, b_col2 = utils.normalize_content_range(b_row1, b_col1, b_row2, b_col2)
    return (a_row1 > b_row1 or (a_row1 == b_row1 and a_col1 >= b_col1))
        and (a_row2 < b_row2 or (a_row2 == b_row2 and a_col2 <= b_col2))
end

function utils.position_in_range(row, col, range_row1, range_col1, range_row2, range_col2)
    range_row1, range_col1, range_row2, range_col2 =
        utils.normalize_content_range(range_row1, range_col1, range_row2, range_col2)
    return (row > range_row1 or (row == range_row1 and col >= range_col1))
        and (row < range_row2 or (row == range_row2 and col <= range_col2))
end

--- Calculate the new cursor position after moving by a delta.
--- @param row integer The current row of the cursor.
--- @param col integer The current column of the cursor.
--- @param delta integer The delta to move the cursor, which can be a positive or negative integer.
--- @return integer, integer The new row and column of the cursor after applying the delta.
function utils.cursor_pos_after_move(row, col, delta)
    local line_count = vim.api.nvim_buf_line_count(0)
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
    local line_len = vim.fn.strchars(line) + (utils.is_visual() and 1 or 0)
    if line_len == 0 then line_len = 1 end
    while delta ~= 0 do
        if delta > 0 then
            if col < line_len then
                col = col + 1
            elseif row < line_count then
                row = row + 1
                col = 1
                line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
                line_len = vim.fn.strchars(line) + (utils.is_visual() and 1 or 0)
                if line_len == 0 then line_len = 1 end
            else
                break -- No more lines to move to
            end
            delta = delta - 1
        elseif delta < 0 then
            if col > 1 then
                col = col - 1
            elseif row > 1 then
                row = row - 1
                line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
                line_len = vim.fn.strchars(line) + (utils.is_visual() and 1 or 0)
                if line_len == 0 then line_len = 1 end
                col = line_len
            else
                break -- No more lines to move to
            end
            delta = delta + 1
        end
    end
    return row, col
end

--- @param row integer
--- @param is_separator function(string): boolean
--- @param preffered_jump_length integer[]
--- @param words non-ascii.Words
--- @return non-ascii.MatchRange[]
function utils.split_line(row, is_separator, preffered_jump_length, words)
    local ranges = {} --- @as non-ascii.MatchRange[]
    local i = 0
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
    local line_len = vim.fn.strchars(line)
    if line_len == 0 and not is_separator('') then
        table.insert(ranges, {
            row = row,
            col = 1,
            length = 1,
        })
    end
    while i < line_len do
        local current_range --- @as non-ascii.MatchRange
        for _, length in ipairs(preffered_jump_length) do
            if i + length - 1 < line_len then
                local word = vim.fn.strcharpart(line, i, length)
                if words[word] then
                    current_range = {
                        row = row,
                        col = i + 1, -- convert to 1-indexed
                        length = length,
                    }
                    i = i + length
                    break
                end
            end
        end
        if not current_range then
            if is_separator(vim.fn.strcharpart(line, i)) then
                while
                    i < line_len
                    and is_separator(vim.fn.strcharpart(line, i))
                do
                    i = i + 1
                end
            else
                -- A normal word
                local length = 1
                while
                    i + length < line_len
                    and not is_separator(vim.fn.strcharpart(line, i + length))
                    and not words[vim.fn.strcharpart(line, i + length, 1)]
                do
                    length = length + 1
                end
                current_range = {
                    row = row,
                    col = i + 1, -- convert to 1-indexed
                    length = length,
                }
                i = i + length
            end
        end
        if current_range then table.insert(ranges, current_range) end
    end
    return ranges
end

--- @return integer, integer
function utils.get_end_of_file()
    local line_count = vim.api.nvim_buf_line_count(0)
    local last_line = vim.api.nvim_buf_get_lines(0, line_count - 1, line_count, false)[1] or ''
    local last_line_len = vim.fn.strchars(last_line) + (utils.is_visual() and 1 or 0)
    if last_line_len == 0 then last_line_len = 1 end
    return line_count, last_line_len
end

--- @param a non-ascii.MatchRange
--- @param b non-ascii.MatchRange
function utils.has_separator_between(a, b)
    if utils.cursor_pos_compare(a.row, a.col, b.row, b.col) > 0 then
        return utils.has_separator_between(b, a)
    end
    local a_row_end, a_col_end = utils.cursor_pos_after_move(a.row, a.col, a.length)
    return utils.cursor_pos_compare(a_row_end, a_col_end, b.row, b.col) ~= 0
end

function utils.is_visual() return vim.api.nvim_get_mode().mode:match('[vV\22]') ~= nil end

--- @return integer?, integer?
function utils.get_visual_start_pos()
    if not utils.is_visual() then return nil, nil end
    local pos = vim.fn.getcharpos('v')
    return pos[2], pos[3] -- row, col
end

function utils.is_reverse_visual()
    if not utils.is_visual() then return false end
    local _, row, col, _, _ = unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
    local pos = vim.fn.getcharpos('v')
    local visual_start_row, visual_start_col = pos[2], pos[3]
    return utils.cursor_pos_compare(visual_start_row, visual_start_col, row, col) > 0
end

function utils.is_operator() return vim.api.nvim_get_mode().mode:match('o') ~= nil end

return utils
