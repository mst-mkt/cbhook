///|
test "positional_text joins words and treats empty as stdin" {
  @test.assert_eq(positional_text([]), None)
  @test.assert_eq(positional_text(["foo"]), Some("foo"))
  @test.assert_eq(positional_text(["foo", "boo"]), Some("foo boo"))
}
