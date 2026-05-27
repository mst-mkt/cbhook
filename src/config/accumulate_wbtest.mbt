///|
test "join_with" {
  @test.assert_eq(join_with([], ", "), "")
  @test.assert_eq(join_with(["a"], ", "), "a")
  @test.assert_eq(join_with(["a", "b", "c"], ", "), "a, b, c")
}

///|
test "combine" {
  @test.assert_eq(combine([["a"], ["b", "c"], []]), ["a", "b", "c"])
  @test.assert_eq(combine([]), [])
}

///|
test "errs extracts the error list, empty for Ok" {
  let ok : Result[Int, Array[String]] = Ok(1)
  let err : Result[Int, Array[String]] = Err(["a", "b"])
  @test.assert_eq(errs(ok), [])
  @test.assert_eq(errs(err), ["a", "b"])
}

///|
test "sequence collects values or accumulates every error" {
  let all_ok : Array[Result[Int, Array[String]]] = [Ok(1), Ok(2), Ok(3)]
  @test.assert_eq(sequence(all_ok), Ok([1, 2, 3]))
  let mixed : Array[Result[Int, Array[String]]] = [
    Ok(1),
    Err(["a"]),
    Err(["b"]),
  ]
  @test.assert_eq(sequence(mixed), Err(["a", "b"]))
}
