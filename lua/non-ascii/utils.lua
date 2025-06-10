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

return utils
