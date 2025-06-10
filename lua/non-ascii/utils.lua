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
    local line_len = vim.fn.strchars(line)
    while delta ~= 0 do
        if delta > 0 then
            if col < line_len then
                col = col + 1
            elseif row < line_count then
                row = row + 1
                col = 1
                line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
                line_len = vim.fn.strchars(line)
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
                line_len = vim.fn.strchars(line)
                col = line_len
            else
                break -- No more lines to move to
            end
            delta = delta + 1
        end
    end
    return row, col
end

return utils
