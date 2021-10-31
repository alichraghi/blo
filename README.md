# Blo
![test.png](/assets/example.png)

example:
```
info: Usage: blo [OPTION]... [FILE]...
With no FILE, read standard input.

Options:
-n, --number          prints number of lines
-i, --info            prints the file info (size, mime, modification, etc)
-e, --show-end        prints <end> after file
-a, --ascii           uses ascii chars to print info and lines delimiter
-c, --no-color        disable printing colored output
-h, --help            display this help and exit

Examples:
blo test.txt          prints the test.txt content
blo                   copy standard input to output
```