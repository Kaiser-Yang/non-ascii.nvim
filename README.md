# non-ascii.nvim

## 功能

* 单词的跳转：
    * `non-ascii.w`：跳转到下一个单词开头。
    * `non-ascii.b`：跳转到上一个单词开头。
    * `non-ascii.e`：跳转到下一个单词结尾。
    * `non-ascii.ge`：跳转到上一个单词结尾。
* `motion`：
    * `non-ascii.iw`：在单词中。
    * `non-ascii.aw`：在单词周围，会选中分隔符。

WIP：

* 句子跳转:
    * `non-ascii.next_sentence`：跳转到上一个句子开头
    * `non-ascii.prev_sentence`：跳转到下一个句子开头
* 中文搜索
* 字符的跳转
* 集成 [flash.nvim](https://github.com/folke/flash.nvim)
* 支持所以自定义的输入方案，默认提供86五笔，全拼，小鹤双拼。
    * `non-ascii.is`：在句子中。
    * `non-ascii.as`：在句子周围，会选中分隔符。

## 快速开始

使用 [lazy.nvim](https://github.com/folke/lazy.nvim) 安装并配置：

```lua
return {
    'Kaiser-Yang/non-ascii.nvim',
    dependencies = {
        -- 推荐
        -- 可以使用 ; 和 , 来重复上一个操作
        -- 你可以查看 nvim-treesitter-textobjects 的文档学习如何配置
        'nvim-treesitter/nvim-treesitter',
        'nvim-treesitter/nvim-treesitter-textobjects',
    },
    opts = {
        word = {
            -- word 文件每行为一个中文词语
            -- 查看 字典转换 部分了解如何生成 word 文件
            word_files = { vim.fn.expand('path/to/your/word/file') },
        }
    },
    config = function(_, opts)
        local non_ascii= require('non-ascii')
        non_ascii.setup(opts)
        local ts_repeat_move = require('nvim-treesitter.textobjects.repeatable_move')
        local next_word, prev_word = ts_repeat_move.make_repeatable_move_pair(
            non_ascii.w,
            non_ascii.b
        )
        local next_end_word, prev_end_word = ts_repeat_move.make_repeatable_move_pair(
            non_ascii.e,
            non_ascii.ge
        )
        vim.keymap.set({ 'n', 'x' }, 'w', next_word, { desc = 'Next word' })
        vim.keymap.set({ 'n', 'x' }, 'b', prev_word, { desc = 'Previous word' })
        vim.keymap.set({ 'n', 'x' }, 'e', next_end_word, { desc = 'Next end word' })
        vim.keymap.set({ 'n', 'x' }, 'ge', prev_end_word, { desc = 'Previous end word' })
        -- 如果你不使用 nvim-treesitter-textobjects，可以直接使用
        -- vim.keymap.set({ 'n', 'x' }, 'w', non_ascii.w, { desc = 'Next word' })
        -- vim.keymap.set({ 'n', 'x' }, 'b', non_ascii.b, { desc = 'Previous word' })
        -- vim.keymap.set({ 'n', 'x' }, 'e', non_ascii.e, { desc = 'Next end word' })
        -- vim.keymap.set({ 'n', 'x' }, 'ge', non_ascii.ge, { desc = 'Previous end word' })

        vim.keymap.set('o', 'w', non_ascii.w, { desc = 'Next word' })
        vim.keymap.set('o', 'b', non_ascii.b, { desc = 'Previous word' })
        vim.keymap.set('o', 'e', non_ascii.e, { desc = 'Next end word' })
        vim.keymap.set('o', 'ge', non_ascii.ge, { desc = 'Previous end word' })
        vim.keymap.set({ 'x', 'o' }, 'iw', non_ascii.iw, { desc = 'Inside a word' })
        vim.keymap.set({ 'x', 'o' }, 'aw', non_ascii.aw, { desc = 'Around a word' })
    end,
}
```

如果你不想自己生成 `word` 文件，可以直接使用
[zh_dict.txt](https://github.com/Kaiser-Yang/dotfiles/blob/main/.config/nvim/dict/zh_dict.txt)。
该文件是我个人使用的 `word` 文件，包含了常用的中文词语。

## 字典转换

以
[wubi.dict.yaml](https://gitee.com/hi-coder/rime-wubi/raw/master/wubi.dict.yaml)
为例，
演示如何通过命令行的方式将该字典转换成 `lua` 中的 `table`，并生成 `word` 文件。

首先通过 `sed` 命令删除文件中的注释、空行以及头部信息：

```bash
sed -e '/^[#-.]/d' -e '/^[[:blank:]]/d' -e '/^.*:/d' wubi.dict.yaml
```

接下来我们提取编码：

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
