#!/usr/bin/env -S gawk -f
# 统计词频，忽略大小写和标点。
# 用法: gawk -f examples/scripts/wordfreq.awk examples/data/poem.txt | sort -k2,2nr -k1,1

{
    for (i = 1; i <= NF; i++) {
        word = tolower($i)
        gsub(/[^a-z0-9']/, "", word)
        if (word != "") freq[word]++
    }
}

END {
    for (word in freq) printf "%s\t%d\n", word, freq[word]
}
