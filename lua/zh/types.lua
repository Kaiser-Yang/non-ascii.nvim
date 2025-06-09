--- @alias zh.Encoding table<string, string[]>
--- @alias zh.Decoding table<string, string[]>
--- @alias zh.Schema zh.Decoding
--- @alias zh.Words table<string, boolean>

--- @class zh.WordJumpConfig
--- @field preffered_jump_length integer[]
--- @field word_files string[] | function(): string[]
--- @field _words zh.Words

--- @class zh.Config
--- @field word_jump zh.WordJumpConfig
---
--- @class zh.MatchRange
--- @field row integer
--- @field start integer
--- @field length integer
--- @field matched boolean
