local non_ascii = {}
local utils = require('non-ascii.utils')
local default_config = require('non-ascii.config') --- @as non-ascii.Config
local current_config = default_config --- @as non-ascii.Config
local word_action = require('non-ascii.action.word')

--- @param opts? non-ascii.Config
function non_ascii.setup(opts)
    opts = opts or {}
    current_config = vim.tbl_deep_extend('force', default_config, opts)
    current_config.word.words = vim.tbl_deep_extend(
        'force',
        current_config.word.words,
        utils.read_words_from_file_list(utils.get_option(current_config.word.word_files))
    )
end

function non_ascii.w()
    word_action.jump(
        'w',
        current_config.word.word_action_config.w.is_separator,
        current_config.word.preffered_jump_length,
        current_config.word.words
    )
end

function non_ascii.b()
    word_action.jump(
        'b',
        current_config.word.word_action_config.b.is_separator,
        current_config.word.preffered_jump_length,
        current_config.word.words
    )
end

function non_ascii.e()
    word_action.jump(
        'e',
        current_config.word.word_action_config.e.is_separator,
        current_config.word.preffered_jump_length,
        current_config.word.words
    )
end

function non_ascii.ge()
    word_action.jump(
        'ge',
        current_config.word.word_action_config.ge.is_separator,
        current_config.word.preffered_jump_length,
        current_config.word.words
    )
end

function non_ascii.iw()
    word_action.jump(
        'iw',
        current_config.word.word_action_config.iw.is_separator,
        current_config.word.preffered_jump_length,
        current_config.word.words
    )
end

function non_ascii.aw()
    word_action.jump(
        'aw',
        current_config.word.word_action_config.aw.is_separator,
        current_config.word.preffered_jump_length,
        current_config.word.words
    )
end

function non_ascii.f() end

function non_ascii.F() end

function non_ascii.t() end

function non_ascii.T() end

return non_ascii
