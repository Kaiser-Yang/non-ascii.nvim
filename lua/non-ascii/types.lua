--- @alias non-ascii.Encoding table<string, string[]>
--- @alias non-ascii.Decoding table<string, string[]>
--- @alias non-ascii.Schema non_ascii.Decoding
--- @alias non-ascii.Words table<string, boolean>

--- @class non-ascii.WordJumpConfig
--- @field preffered_jump_length integer[]
--- @field word_files string[] | function(): string[]
--- @field _words non-ascii.Words

--- @class non-ascii.Config
--- @field word_jump non-ascii.WordJumpConfig
---
--- @class non-ascii.MatchRange
--- @field row integer
--- @field start integer
--- @field length integer
--- @field matched boolean
