--- @alias non-ascii.WordAction 'w' | 'b' | 'e' | 'ge' | 'iw' | 'aw'

--- @class non-ascii.WordActionConfig
--- @field is_separator function(string): boolean

--- @class non-ascii.WordJumpConfig
--- @field preffered_jump_length integer[]
--- @field word_files string[] | function(): string[]
--- @field word_action_config table<non-ascii.WordAction, non-ascii.WordActionConfig>
--- @field words non-ascii.Words

--- @class non-ascii.Config
--- @field word non-ascii.WordJumpConfig
