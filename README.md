# zh.nvim

## 功能

* 单词的跳转：
    * `zh.w`：跳转到下一个单词开头
    * `zh.b`：跳转到上一个单词开头
    * `zh.e`：跳转到下一个单词结尾
    * `zh.ge`：跳转到上一个单词结尾

WIP：

* 中文搜索
* 字符的跳转
* 集成 [flash.nvim](https://github.com/folke/flash.nvim)
* 支持所以自定义的输入方案，默认提供86五笔，全拼，小鹤双拼。

## 快速开始

使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 安装并配置：

```lua
return {
    'Kaiser-Yang/zh.nvim',
    dependencies = {
        -- 推荐
        -- 可以使用 ; 和 , 来重复上一个操作
        -- 你可以查看 nvim-treesitter-textobjects 的文档学习如何配置
        'nvim-treesitter/nvim-treesitter',
        'nvim-treesitter/nvim-treesitter-textobjects',
    },
    opts = {
        word_jump = {
            -- word 文件每行为一个中文词语
            -- 查看 字典转换 部分了解如何生成 word 文件
            word_files = { vim.fn.expand('path/to/your/word/file') },
        }
    },
    config = function(_, opts)
        local zh = require('zh')
        zh.setup(opts)
        local map_set = require('utils').map_set
        local ts_repeat_move = require('nvim-treesitter.textobjects.repeatable_move')
        local next_word, prev_word = ts_repeat_move.make_repeatable_move_pair(
            zh.w,
            zh.b
        )
        local next_end_word, prev_end_word = ts_repeat_move.make_repeatable_move_pair(
            zh.e,
            zh.ge
        )
        map_set('n', 'w', next_word, { desc = 'Next word' })
        map_set('n', 'b', prev_word, { desc = 'Previous word' })
        map_set('n', 'e', next_end_word, { desc = 'Next end word' })
        map_set('n', 'ge', prev_end_word, { desc = 'Previous end word' })
    end,
}
```

## 字典转换

以[wubi.dict.yaml](https://gitee.com/hi-coder/rime-wubi/raw/master/wubi.dict.yaml)为例，
演示如何通过命令行的方式将该字典转换成 `lua` 中的 `table`，并生成 `word` 文件。

首先通过 `sed` 命令删除文件中的注释、空行以及头部信息：

```bash
sed -e '/^[#-.]/d' -e '/^[[:blank:]]/d' -e '/^.*:/d' wubi.dict.yaml
```

接下来我们提取单字的编码：

```bash
sed -e '/^[#-.]/d' -e '/^[[:blank:]]/d' -e '/^.*:/d' wubi.dict.yaml | \
awk '{print $1, $2, $3}' | sort -k2,2 -k3nr,3 | awk '{print $1, $2}'
```

对于存在简码的输入方案，为了能更好的避免冲突，我们希望删除简码的其他候选项
（例如 `a` 在86五笔中是 `工` 字的简码，
而有的方案在输入 `a` 时会添加 `戈` 字到候选中，
我们希望删除这样的候选项）：

```bash
sed -e '/^[#-.]/d' -e '/^[[:blank:]]/d' -e '/^.*:/d' wubi.dict.yaml | \
awk '{print $1, $2, $3}' | sort -k2,2 -k3nr,3 | awk '{print $1, $2}' | \
./remover.py 4 # 最大码长为4，这样会让1，2，3按照简码处理
```

最后将结果转换成 `lua` 中的 `table`：

```bash
sed -e '/^[#-.]/d' -e '/^[[:blank:]]/d' -e '/^.*:/d' wubi.dict.yaml | \
awk '{print $1, $2, $3}' | sort -k2,2 -k3nr,3 | awk '{print $1, $2}' | \
./remover.py 4 | \
./converter.py # converter.py 会输出 word_list.txt char.lua 和 word.lua 三个文件
```
