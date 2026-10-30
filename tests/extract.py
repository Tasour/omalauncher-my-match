#!/usr/bin/env python3
'''Extract a triple-quoted shell script from an .owl file.

The OWL string is a concatenation of chunks and sh(...) values:
    let gamesScript=""" ... WANT="""+sh(favStr)+""" ... """
This prints the shell script with those values replaced by ${TEST_FAV...}
variables, so tests can run the real script without the launcher.
'''
import sys

path, var = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()
needles = (f'let {var}="""', f'source {var}=cmd("""')
for needle in needles:
    if needle in s:
        start = s.index(needle) + len(needle)
        break
else:
    sys.exit(f"no triple-quoted script for {var}")
i = start
chunks: list[str] = []
exprs: list[str] = []
while True:
    j = s.index('"""', i)
    chunks.append(s[i:j])
    i = j + 3
    k = i
    while k < len(s) and s[k] in " \t\r\n":
        k += 1
    if k < len(s) and s[k] == "+":
        k += 1
        e = s.index('"""', k)
        exprs.append(s[k:e].strip().rstrip("+").strip())
        i = e + 3
    else:
        break

values = {
    "sh(favStr)": "${TEST_FAVSTR}",
    "sh(favTid)": "${TEST_FAVTID}",
    "sh(favNoTid)": "${TEST_FAVNOTID}",
    "sh(favLg)": "${TEST_FAVLG}",
}
out = chunks[0]
for expr, chunk in zip(exprs, chunks[1:]):
    # The OWL lexer drops the newline/indent at the start of each chunk after a
    # sh(...) value; mimic that so a missing ';' fails bash -n here too.
    out += values.get(expr, "${" + expr + "}") + chunk.lstrip()
sys.stdout.write(out)
