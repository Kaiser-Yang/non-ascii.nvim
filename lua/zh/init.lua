local zh = {}
local utils = require('zh.utils')
local default_config = require('zh.config') --- @as zh.Config
local current_config = default_config --- @as zh.Config

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
--- @param opts zh.WordJumpConfig
--- @return zh.MatchRange[]
local function split_line(row, opts)
    local range = {} --- @as zh.MatchRange[]
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
                -- Find the next word boundary
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

--- @param row integer
--- @param col integer
--- @param prev? zh.MatchRange
--- @param cur zh.MatchRange
--- @param next? zh.MatchRange
--- @param reverse boolean
--- @param to_end boolean
local function set_cursor(row, col, prev, cur, next, reverse, to_end)
    local function normal_cmd()
        vim.cmd('normal! ' .. get_cmd(reverse, to_end) .. '<cr>')
    end
    if not cur or not cur.matched then
        normal_cmd()
    else
        local movement_handlers = {
            ge = function()
                if not prev or not prev.matched then
                    normal_cmd()
                else
                    return prev.row, prev.start + prev.length - 1
                end
            end,
            b = function()
                if col ~= cur.start then
                    return cur.row, cur.start
                elseif prev and prev.matched then
                    return prev.row, prev.start
                else
                    normal_cmd()
                end
            end,
            w = function()
                if not next or not next.matched then
                    normal_cmd()
                else
                    return next.row, next.start
                end
            end,
            e = function()
                if col ~= cur.start + cur.length - 1 then
                    return cur.row, cur.start + cur.length - 1
                elseif next and next.matched then
                    return next.row, next.start + next.length - 1
                else
                    normal_cmd()
                end
            end,
        }
        local new_row, new_col = movement_handlers[get_cmd(reverse, to_end)]()
        if not new_row or not new_col then return end
        vim.fn.setcursorcharpos(new_row, new_col)
    end
end

--- @param row integer
--- @param col integer
--- @return zh.MatchRange, zh.MatchRange, zh.MatchRange
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

--- @param opts? zh.WordJumpConfig
--- @param reverse? boolean
local function word_jump(opts, reverse, to_end)
    opts = opts or {}
    reverse = reverse or false
    opts = vim.tbl_deep_extend('force', current_config.word_jump, opts)
    local cnt = vim.v.count1
    while cnt > 0 do
        local _, row, col, _, _ = unpack(vim.fn.getcursorcharpos(vim.api.nvim_get_current_win()))
        local prev, cur, next = get_prev_cur_next_range(row, col, opts)
        set_cursor(row, col, prev, cur, next, reverse, to_end)
        cnt = cnt - 1
    end
end

--- @param opts? zh.Config
function zh.setup(opts)
    opts = opts or {}
    current_config = vim.tbl_deep_extend('force', default_config, opts)
    current_config.word_jump._words = utils.read_words_from_file_list(
        utils.get_option(current_config.word_jump.word_files, current_config.word_jump)
    )
end

--- @param opts? zh.WordJumpConfig
function zh.w(opts) word_jump(opts, false, false) end

--- @param opts? zh.WordJumpConfig
function zh.b(opts) word_jump(opts, true, false) end

--- @param opts? zh.WordJumpConfig
function zh.e(opts) word_jump(opts, false, true) end

--- @param opts? zh.WordJumpConfig
function zh.ge(opts) word_jump(opts, true, true) end

function zh.f() end

function zh.F() end

function zh.t() end

function zh.T() end

return zh
