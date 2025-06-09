#!/usr/bin/env python3
import sys
from collections import defaultdict


def convert_to_lua_table(encoding_to_word: dict[str, set], char_mode: bool):
    lines = []
    lines.append("--- @type zh.Schema")
    lines.append("return {")
    for encoding, words in encoding_to_word.items():
        filtered_words = {word for word in words if (char_mode and len(word)) == 1 or
                          not char_mode and len(word) > 1}
        if len(filtered_words) == 0:
            continue
        lines.append(f'    ["{encoding}"] = {{"' + '", "'.join(filtered_words) + '"},')
    lines.append("}")
    return '\n'.join(lines)


def main():
    lines = sys.stdin.readlines()
    encoding_to_word = defaultdict(set)
    for line in lines:
        if len(line.split()) < 2:
            continue
        word, encoding = line.split()
        encoding_to_word[encoding].add(word)
    with open('char.lua', 'w') as f:
        f.write(convert_to_lua_table(encoding_to_word, char_mode=True))
    with open('word.lua', 'w') as f:
        f.write(convert_to_lua_table(encoding_to_word, char_mode=False))


if __name__ == "__main__":
    main()
