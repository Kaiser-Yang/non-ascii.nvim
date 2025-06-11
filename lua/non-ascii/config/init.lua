local function is_separator(str, consider_empty_line, consider_newline)
    if consider_empty_line and str == '' then return true end
    if consider_newline and str == '\n' then return true end
    return #str > 0 and not str:match('^[%w\n]$')
end

--- @type non-ascii.Config
return {
    word = {
        preffered_jump_length = { 9, 8, 7, 6, 5, 4, 3, 2, 1 },
        word_files = {},
        word_action_config = {
            w = { is_separator = function(str) return is_separator(str, true, true) end },
            b = { is_separator = function(str) return is_separator(str, true, true) end },
            e = { is_separator = function(str) return is_separator(str, true, true) end },
            ge = { is_separator = function(str) return is_separator(str, true, true) end },
            iw = { is_separator = function(str) return is_separator(str, false, false) end },
            aw = { is_separator = function(str) return is_separator(str, false, false) end },
        },
        -- Some special words that are not in the word files
        words = {},
    },
}
