///|
fn rep(pattern : String, template : String, text : String) -> String raise {
  replace(@regexp.compile(pattern), template, text)
}

///|
fn rep_f(
  pattern : String,
  flags : String,
  template : String,
  text : String,
) -> String raise {
  replace(@regexp.compile(pattern, flags~), template, text)
}

///|
test "replace is global" {
  @test.assert_eq(rep("o", "0", "foo food"), "f00 f00d")
}

///|
test "positional capture refs" {
  @test.assert_eq(rep("(a)(b)", "$2$1", "ab"), "ba")
}

///|
test "named capture ref" {
  @test.assert_eq(rep("(?<x>[0-9]+)", "[${x}]", "n42"), "n[42]")
}

///|
test "braced numeric ref" {
  @test.assert_eq(rep("(a)", "${1}${1}", "a"), "aa")
}

///|
test "$$ is a literal dollar" {
  @test.assert_eq(rep("a", "$$", "a"), "$")
}

///|
test "non-ref dollar is literal" {
  @test.assert_eq(rep("a", "x$", "a"), "x$")
}

///|
test "$ before a non-digit char is literal" {
  @test.assert_eq(rep("a", "$z", "a"), "$z")
  @test.assert_eq(rep("(a)", "$1$z", "a"), "a$z")
}

///|
test "multibyte text is preserved around replacements" {
  @test.assert_eq(rep("o", "0", "fooあ"), "f00あ")
  @test.assert_eq(rep("あ", "い", "xあy"), "xいy")
}

///|
test "surrogate-pair char is preserved around replacements" {
  @test.assert_eq(rep("o", "0", "f😀oo"), "f😀00")
}

///|
test "zero-width match interleaves correctly across surrogate pairs" {
  @test.assert_eq(rep("x*", "-", "a😀b"), "-a-😀-b-")
}

///|
test "surrogate-pair capture is expanded intact" {
  @test.assert_eq(rep("(😀+)", "[$1]", "x😀😀y"), "x[😀😀]y")
}

///|
test "lone trailing dollar is literal" {
  @test.assert_eq(rep("a", "$", "a"), "$")
}

///|
test "$0 is the whole match" {
  @test.assert_eq(rep("a(b)", "<$0>", "ab"), "<ab>")
}

///|
test "bare $12 is group 1 then literal 2" {
  @test.assert_eq(rep("(X)", "$12", "X"), "X2")
}

///|
test "braced numeric ref to a missing group is empty" {
  @test.assert_eq(rep("(X)", "[${12}]", "X"), "[]")
}

///|
test "unclosed brace ref swallows the rest" {
  @test.assert_eq(rep("(X)", "p${ab", "X"), "p")
}

///|
test "missing named ref is empty" {
  @test.assert_eq(rep("(?<x>X)", "[${nope}]", "X"), "[]")
}

///|
test "empty braces ref is empty" {
  @test.assert_eq(rep("(a)", "[${}]", "a"), "[]")
}

///|
test "non-participating group ref is empty" {
  @test.assert_eq(rep("(a)|(b)", "<$1$2>", "b"), "<b>")
}

///|
test "nonexistent group ref is empty" {
  @test.assert_eq(rep("a", "<$1>", "a"), "<>")
}

///|
test "captures update on every global match" {
  @test.assert_eq(rep("(.)", "$1$1", "ab"), "aabb")
}

///|
test "engine flags are honoured (case-insensitive)" {
  @test.assert_eq(rep_f("a", "i", "X", "AaA"), "XXX")
}

///|
test "zero-width match never loops forever" {
  @test.assert_eq(rep("x*", "-", "abc"), "-a-b-c-")
}

///|
test "empty input still gets a zero-width replacement" {
  @test.assert_eq(rep("a*", "-", ""), "-")
}

///|
test "whole-text trim with anchors works (first/last only)" {
  @test.assert_eq(rep("^ +| +$", "", "  hi  "), "hi")
}

///|
test "anchored pattern re-evaluates per suffix (known regexp limitation)" {
  // KNOWN LIMITATION, not desired: correct output is "Zaa" (^ matches only the
  // string start). The regexp lib has no offset matching, so the suffix re-run
  // re-anchors ^ and yields "ZZZ". Pinned to catch regressions.
  @test.assert_eq(rep("^a", "Z", "aaa"), "ZZZ")
}
