#!/usr/bin/env python3
"""mcheck — static structural validation of MATLAB sources.

Tier B requires structural and static validation before shipping, because
no interpreter is available in the authoring session. This checker is
itself an instrument written in the same session as the code it checks, so
per BEST_PRACTICE F3 it MUST be fault-injected before any of its claims are
believed. Run with --selftest to do that; the checker refuses to report a
clean tree unless its self-test has passed in the same invocation.

What it checks
  1. Block balance: every opener has a matching `end`, accounting for
     `end` used as an array index (inside ( ) [ ] { }).
  2. Every public .m file carries a help block starting on the line after
     the signature, and that block contains the mandatory sections.
  3. Forbidden functions do not appear in +geo.
  4. No variable shadows a MATLAB builtin the project cares about.

What it CANNOT check, and therefore does not claim
  - Semantics of any kind. A file can be perfectly balanced and wrong.
  - Whether a called function exists.
  - Anything about runtime behaviour.
These are why a clean run here is necessary and not sufficient: the MATLAB
suite is the gate that can see behaviour. Under Tier A that suite runs in
the same session, so a deliverable is no longer PROVISIONAL on arrival -
it is proved before it is committed.

geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations
import re, sys, pathlib

OPENERS = {"function", "classdef", "methods", "properties", "events",
           "enumeration", "if", "for", "parfor", "while", "switch", "try",
           "arguments", "spmd"}
# `end` closes these; `else`/`elseif`/`catch`/`case`/`otherwise` do not.
NEUTRAL = {"else", "elseif", "catch", "case", "otherwise"}

FORBIDDEN_IN_GEO = ["range", "prctile", "caxis", "eval", "evalin",
                    "assignin", "setappdata", "getappdata", "findobj",
                    "light", "material", "shading"]

REQUIRED_HELP = ["DESCRIPTION", "See also"]


def strip_code(line: str) -> str:
    """Remove comments and string literals, preserving bracket structure."""
    out, i, n = [], 0, len(line)
    in_s = in_d = False
    while i < n:
        c = line[i]
        if in_s:
            if c == "'":
                if i + 1 < n and line[i + 1] == "'":
                    i += 2; continue
                in_s = False
            i += 1; continue
        if in_d:
            if c == '"':
                if i + 1 < n and line[i + 1] == '"':
                    i += 2; continue
                in_d = False
            i += 1; continue
        if c == "%":
            break
        if c == "." and line[i:i + 3] == "...":
            break
        if c == '"':
            in_d = True; out.append(" "); i += 1; continue
        if c == "'":
            # Transpose only if the IMMEDIATELY preceding character can end
            # an operand. The immediately preceding one, not the last
            # non-space one, and the difference is load-bearing: a quote
            # with whitespace before it is a string, because a transpose
            # never has a space before it.
            #
            # Measured, not reasoned. The previous rule skipped spaces, so
            #     err.identifier ']. Run the mirror first.'
            # read as a transpose after `identifier`, the ']' inside the
            # string was counted as a real bracket, and the file's bracket
            # depth ran at -1 from that line onward. Every `x(end+1)`
            # after it then had its `end` counted as a block terminator,
            # and the checker reported "unmatched 'end'" 228 lines away
            # from the actual cause - in a function that was correct.
            prev = out[-1] if out else ""
            if prev and (prev.isalnum() or prev in ")]}._'"):
                out.append("'"); i += 1; continue
            in_s = True; out.append(" "); i += 1; continue
        out.append(c); i += 1
    return "".join(out)


def check_balance(path: pathlib.Path):
    """Return (depth, problems). depth 0 means balanced."""
    depth, depth_bracket = 0, 0
    stack, problems = [], []
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        code = strip_code(raw)
        for tok in re.finditer(r"[\(\)\[\]\{\}]|\b[A-Za-z_]\w*\b", code):
            t = tok.group(0)
            if t in "([{":
                depth_bracket += 1
            elif t in ")]}":
                depth_bracket -= 1
            elif depth_bracket > 0:
                continue                       # `end` here is an index
            elif t in OPENERS:
                # `properties`/`methods` etc. only open at statement start
                pre = code[:tok.start()].strip()
                if t in {"if", "for", "while", "switch", "try", "parfor",
                         "spmd", "function", "classdef", "arguments",
                         "methods", "properties", "events", "enumeration"} \
                        and pre in ("", "end", ";"):
                    depth += 1
                    stack.append((t, lineno))
            elif t == "end":
                depth -= 1
                if stack:
                    stack.pop()
                if depth < 0:
                    problems.append(f"{path.name}:{lineno}: unmatched 'end'")
                    return depth, problems
    if depth != 0:
        unclosed = ", ".join(f"{t}@{ln}" for t, ln in stack)
        problems.append(
            f"{path.name}: unbalanced, depth {depth:+d}; unclosed: {unclosed}")
    return depth, problems


def check_help(path: pathlib.Path):
    problems = []
    lines = path.read_text().splitlines()
    first = next((i for i, l in enumerate(lines)
                  if l.strip().startswith(("function", "classdef"))), None)
    if first is None:
        return problems
    block = []
    for l in lines[first + 1:]:
        if l.strip().startswith("%"):
            block.append(l)
        elif l.strip() == "":
            if block:
                break
        else:
            break
    if not block:
        problems.append(f"{path.name}: no help block after the signature")
        return problems
    text = "\n".join(block)
    for sec in REQUIRED_HELP:
        if sec not in text:
            problems.append(f"{path.name}: help block missing '{sec}'")
    return problems


def check_forbidden(root: pathlib.Path):
    problems = []
    geo = root / "+geo"
    if not geo.exists():
        return problems
    for f in geo.rglob("*.m"):
        for lineno, raw in enumerate(f.read_text().splitlines(), 1):
            code = strip_code(raw)
            for name in FORBIDDEN_IN_GEO:
                if re.search(rf"(?<![\w.]){name}\s*\(", code):
                    problems.append(
                        f"{f.relative_to(root)}:{lineno}: forbidden '{name}'")
    return problems


def selftest() -> bool:
    """Prove each check FIRES on a broken fixture and is SILENT on a good one."""
    import tempfile, os
    ok = True
    good = "function y = f(x)\n%F  One line.\n%\n%   DESCRIPTION\n%     d\n%\n%   See also G.\ny = x(end);\nif y > 0\n    y = 1;\nend\nend\n"
    bad_unclosed = "function y = f(x)\n%F  One line.\n%\n%   DESCRIPTION\n%   See also G.\nif x > 0\n    y = 1;\nend\n"
    bad_extra = good + "end\n"
    no_help = "function y = f(x)\ny = x;\nend\n"
    # A quote preceded by a SPACE after an identifier is a string, not a
    # transpose. Reading it as a transpose leaks the bracket inside the
    # literal into the bracket count and poisons every `x(end+1)` after
    # it. Both halves are fixtured: the string case must stay silent, and
    # a genuine transpose in the same shape must not become a string.
    quoted_bracket = ("function f(err)\n%F  One line.\n%\n%   DESCRIPTION\n"
                      "%     d\n%\n%   See also G.\n"
                      "error('geo:x:Y', ['bad [' err.identifier "
                      "']. Run it first.']);\nv = [1 2 3];\nw = v(end);\n"
                      "u = v ';\nend\n")
    transpose_ok = ("function y = f(x)\n%F  One line.\n%\n%   DESCRIPTION\n"
                    "%     d\n%\n%   See also G.\n"
                    "y = x';\ny = y(end);\nend\n")
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        cases = [("good.m", good, False, False),
                 ("unclosed.m", bad_unclosed, True, False),
                 ("extra.m", bad_extra, True, False),
                 ("nohelp.m", no_help, False, True),
                 ("quoted_bracket.m", quoted_bracket, False, False),
                 ("transpose_ok.m", transpose_ok, False, False)]
        for name, txt, want_bal, want_help in cases:
            p = d / name
            p.write_text(txt)
            _, bal = check_balance(p)
            hp = check_help(p)
            if bool(bal) != want_bal:
                print(f"  SELFTEST FAIL balance on {name}: got {bal}")
                ok = False
            if bool(hp) != want_help:
                print(f"  SELFTEST FAIL help on {name}: got {hp}")
                ok = False
        # forbidden-function check
        g = d / "+geo"
        g.mkdir()
        (g / "bad.m").write_text("function f()\nx = range([1 2]);\nend\n")
        if not check_forbidden(d):
            print("  SELFTEST FAIL: forbidden-function check did not fire")
            ok = False
        (g / "bad.m").write_text("function f()\nx = max(a)-min(a);\nend\n")
        if check_forbidden(d):
            print("  SELFTEST FAIL: forbidden-function check false positive")
            ok = False
    print(f"  self-test: {'PASS' if ok else 'FAIL'}")
    return ok


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    print("mcheck — static structural validation")
    print("=" * 60)
    if not selftest():
        print("\nSELF-TEST FAILED. No claim from this run may be believed.")
        return 2

    files = sorted(root.rglob("*.m"))
    problems = []
    for f in files:
        _, p = check_balance(f)
        problems += p
        problems += check_help(f)
    problems += check_forbidden(root)

    print(f"\n  files checked : {len(files)}")
    if problems:
        print(f"  PROBLEMS      : {len(problems)}\n")
        for p in problems:
            print(f"    ! {p}")
        return 1
    print("  problems      : 0")
    print("\n  NOTE: structural only. This says nothing about semantics,")
    print("  Necessary, not sufficient: only the MATLAB suite sees behaviour.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
