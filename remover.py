#!/usr/bin/env python3
import sys


def main(max_encoding_length: int):
    lines = sys.stdin.readlines()
    word_set = set()
    new_lines = list()
    encoding_to_word = dict()
    for line in lines:
        if len(line.split()) < 2:
            new_lines.append(line)
            continue
        word, encoding = line.split()
        if (len(encoding) < max_encoding_length and encoding not in encoding_to_word
                or len(encoding) == max_encoding_length and word not in word_set):
            new_lines.append(line)
            word_set.add(word)
            encoding_to_word[encoding] = word
    print(''.join(new_lines))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python remover.py <max_encoding_length>")
        sys.exit(1)
    main(int(sys.argv[1]))
