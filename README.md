# zh.nvim

## 功能

WIP：

* 中文搜索
* 单词的跳转
* 字符的跳转
* 集成 [flash.nvim](https://github.com/folke/flash.nvim)
* 支持所以自定义的输入方案，默认提供86五笔，全拼，小鹤双拼。

## 字典转换

以[wubi.dict.yaml](https://gitee.com/hi-coder/rime-wubi/raw/master/wubi.dict.yaml)为例，
演示如何通过命令行的方式将该字典转换成 `lua` 中的 `table`。

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
./converter.py # converter.py 会输出 char.lua 和 word.lua 两个文件
```
