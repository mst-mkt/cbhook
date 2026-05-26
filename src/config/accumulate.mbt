///|
pub fn join_with(items : Array[String], sep : String) -> String {
  match items {
    [] => ""
    [head, .. tail] => tail.fold(init=head, fn(acc, x) { acc + sep + x })
  }
}

///|
pub fn[T] errs(r : Result[T, Array[String]]) -> Array[String] {
  match r {
    Ok(_) => []
    Err(e) => e
  }
}

///|
pub fn combine(parts : Array[Array[String]]) -> Array[String] {
  parts.fold(init=[], fn(acc, p) { [..acc, ..p] })
}

///|
pub fn[T] sequence(
  rs : Array[Result[T, Array[String]]],
) -> Result[Array[T], Array[String]] {
  rs.fold(init=Ok([]), fn(acc, r) {
    match (acc, r) {
      (Ok(xs), Ok(x)) => Ok([..xs, x])
      _ => Err(combine([errs(acc), errs(r)]))
    }
  })
}
