local utils = require('non-ascii.utils')
local special_words = {
    -- English punctuation marks, this is usefull when you use 'cw' on a punctuation mark
    ['-'] = true,
    ['_'] = true,
    ['@'] = true,
    ['#'] = true,
    ['$'] = true,
    ['%'] = true,
    ['&'] = true,
    ['*'] = true,
    ['+'] = true,
    ['/'] = true,
    ['\\'] = true,
    ['='] = true,
    [','] = true,
    ['.'] = true,
    ['...'] = true,
    ['!'] = true,
    ['?'] = true,
    [';'] = true,
    [':'] = true,
    ['"'] = true,
    ["'"] = true,
    ['('] = true,
    [')'] = true,
    ['['] = true,
    [']'] = true,
    ['{'] = true,
    ['}'] = true,
    ['<'] = true,
    ['>'] = true,
    -- Chinese punctuation marks
    ['，'] = true,
    ['。'] = true,
    ['！'] = true,
    ['？'] = true,
    ['；'] = true,
    ['：'] = true,
    ['“'] = true,
    ['”'] = true,
    ['‘'] = true,
    ['’'] = true,
    ['（'] = true,
    ['）'] = true,
    ['【'] = true,
    ['】'] = true,
    ['《'] = true,
    ['》'] = true,
    ['「'] = true,
    ['」'] = true,
    ['〔'] = true,
    ['〕'] = true,
    ['…'] = true,
    ['—'] = true,
    ['·'] = true,
    ['￥'] = true,
    ['％'] = true,
    ['＃'] = true,
    ['＆'] = true,
    ['＊'] = true,
    ['＠'] = true,
    ['／'] = true,
    ['＼'] = true,
    ['＿'] = true,
    ['－'] = true,
    ['＋'] = true,
    ['＝'] = true,
    ['｜'] = true,
    ['｀'] = true,
    ['～'] = true,
}
local function is_word_separator(str, consider_empty_line, consider_newline)
    if str == '' then
        return consider_empty_line and not utils.is_operator()
    elseif str == '\n' then
        return consider_newline and not utils.is_operator()
    end
    return #str > 0 and not str:match('^[%w]') and not special_words[vim.fn.strcharpart(str, 0, 1)]
end

--- @type non-ascii.Config
return {
    word = {
        preffered_jump_length = { 9, 8, 7, 6, 5, 4, 3, 2, 1 },
        word_files = {},
        word_action_config = {
            w = { is_separator = function(str) return is_word_separator(str, true, true) end },
            b = { is_separator = function(str) return is_word_separator(str, true, true) end },
            e = { is_separator = function(str) return is_word_separator(str, true, true) end },
            ge = { is_separator = function(str) return is_word_separator(str, true, true) end },
            iw = { is_separator = function(str) return is_word_separator(str, false, false) end },
            aw = { is_separator = function(str) return is_word_separator(str, false, false) end },
        },
        -- Some special words that are not in the word files
        words = special_words,
    },
}
