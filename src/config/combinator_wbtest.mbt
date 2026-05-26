///|
fn[T] dec(s : Schema[T], json : Json) -> Result[T, Array[String]] {
  (s.decode)(json, "$")
}

///|
fn[T] sch(s : Schema[T]) -> Json {
  (s.to_schema)()
}

///|
test "string_schema" {
  @test.assert_eq(dec(string_schema(), "hi".to_json()), Ok("hi"))
  @test.assert_eq(
    dec(string_schema(), (1).to_json()),
    Err(["$: expected a string"]),
  )
  assert_json(sch(string_schema()), @json.parse("{ \"type\": \"string\" }"))
}

///|
test "int_schema without minimum" {
  @test.assert_eq(dec(int_schema(), (3).to_json()), Ok(3))
  @test.assert_eq(
    dec(int_schema(), (1.5).to_json()),
    Err(["$: expected an integer"]),
  )
  @test.assert_eq(dec(int_schema(), "x".to_json()), Err(["$: expected a number"]))
  @test.assert_eq(
    dec(int_schema(), (1.0e12).to_json()),
    Err(["$: expected an integer"]),
  )
  assert_json(sch(int_schema()), @json.parse("{ \"type\": \"integer\" }"))
}

///|
test "int_schema with minimum" {
  @test.assert_eq(dec(int_schema(minimum=5), (5).to_json()), Ok(5))
  @test.assert_eq(
    dec(int_schema(minimum=5), (4).to_json()),
    Err(["$: expected >= 5"]),
  )
  assert_json(
    sch(int_schema(minimum=5)),
    @json.parse("{ \"type\": \"integer\", \"minimum\": 5 }"),
  )
}

///|
test "int_schema accumulates non-integer and minimum errors together" {
  @test.assert_eq(
    dec(int_schema(minimum=5), (2.5).to_json()),
    Err(["$: expected an integer", "$: expected >= 5"]),
  )
}

///|
test "enum_schema" {
  let s = enum_schema(["a", "b"], v => match v {
    "a" => Some(1)
    "b" => Some(2)
    _ => None
  })
  @test.assert_eq(dec(s, "b".to_json()), Ok(2))
  @test.assert_eq(
    dec(s, "c".to_json()),
    Err(["$: expected one of a, b, got \"c\""]),
  )
  @test.assert_eq(dec(s, (0).to_json()), Err(["$: expected a string"]))
  assert_json(sch(s), @json.parse("{ \"enum\": [\"a\", \"b\"] }"))
}

///|
test "array_schema (no minimum) decodes and accumulates element errors" {
  let s = array_schema(string_schema())
  @test.assert_eq(dec(s, ["x", "y"].to_json()), Ok(["x", "y"]))
  @test.assert_eq(dec(s, @json.parse("[]")), Ok([]))
  @test.assert_eq(
    dec(s, [1, 2].to_json()),
    Err(["$[0]: expected a string", "$[1]: expected a string"]),
  )
  @test.assert_eq(dec(s, "x".to_json()), Err(["$: expected an array"]))
  assert_json(
    sch(s),
    @json.parse("{ \"type\": \"array\", \"items\": { \"type\": \"string\" } }"),
  )
}

///|
test "array_schema with min_items" {
  let s = array_schema(string_schema(), min_items=2)
  @test.assert_eq(
    dec(s, ["only"].to_json()),
    Err(["$: expected at least 2 item(s)"]),
  )
  @test.assert_eq(dec(s, ["a", "b"].to_json()), Ok(["a", "b"]))
  assert_json(get_key(sch(s), "minItems"), (2).to_json())
}

///|
test "array_schema accumulates min_items and element errors together" {
  let s = array_schema(string_schema(), min_items=2)
  @test.assert_eq(
    dec(s, [1].to_json()),
    Err(["$: expected at least 2 item(s)", "$[0]: expected a string"]),
  )
}

///|
test "const_field matches, mismatches, wrong type, and missing" {
  let s = pure(fn(_u) { "ok" }).apply(const_field("kind", "x")).build()
  @test.assert_eq(dec(s, @json.parse("{ \"kind\": \"x\" }")), Ok("ok"))
  @test.assert_eq(
    dec(s, @json.parse("{ \"kind\": \"y\" }")),
    Err(["$.kind: expected \"x\", got \"y\""]),
  )
  @test.assert_eq(
    dec(s, @json.parse("{ \"kind\": 1 }")),
    Err(["$.kind: expected \"x\""]),
  )
  @test.assert_eq(
    dec(s, @json.parse("{}")),
    Err(["$: missing required field \"kind\""]),
  )
  assert_json(
    get_key(get_key(sch(s), "properties"), "kind"),
    @json.parse("{ \"const\": \"x\" }"),
  )
}

///|
test "build decodes an object and accumulates field errors" {
  let s = pure(fn(a) { fn(b) { (a, b) } })
    .apply(required_field("a", string_schema()))
    .apply(required_field("b", int_schema()))
    .build()
  @test.assert_eq(dec(s, @json.parse("{ \"a\": \"x\", \"b\": 3 }")), Ok(("x", 3)))
  @test.assert_eq(
    dec(s, @json.parse("{ \"a\": 1, \"b\": \"y\" }")),
    Err(["$.a: expected a string", "$.b: expected a number"]),
  )
  @test.assert_eq(
    dec(s, @json.parse("{}")),
    Err([
      "$: missing required field \"a\"",
      "$: missing required field \"b\"",
    ]),
  )
  @test.assert_eq(
    dec(s, @json.parse("{ \"a\": \"x\", \"b\": 3, \"c\": 9 }")),
    Err(["$: unknown field \"c\""]),
  )
  @test.assert_eq(dec(s, (1).to_json()), Err(["$: expected an object"]))
}

///|
test "build emits an object schema with required and additionalProperties" {
  let s = pure(fn(a) { fn(b) { (a, b) } })
    .apply(required_field("a", string_schema()))
    .apply(optional_field("b", int_schema()))
    .build()
  let j = sch(s)
  assert_json(get_key(j, "type"), "object".to_json())
  assert_json(get_key(j, "additionalProperties"), false.to_json())
  assert_json(get_key(j, "required"), ["a"].to_json())
  assert_json(
    get_key(get_key(j, "properties"), "a"),
    @json.parse("{ \"type\": \"string\" }"),
  )
}

///|
test "optional_field yields None when absent, Some when present" {
  let s = pure(fn(a) { a }).apply(optional_field("a", string_schema())).build()
  @test.assert_eq(dec(s, @json.parse("{}")), Ok(None))
  @test.assert_eq(dec(s, @json.parse("{ \"a\": \"v\" }")), Ok(Some("v")))
}

///|
test "tagged dispatches and reports tag problems" {
  let s = tagged("k", [
    ("a", pure(fn(_u) { "A" }).apply(const_field("k", "a")).build()),
    ("b", pure(fn(_u) { "B" }).apply(const_field("k", "b")).build()),
  ])
  @test.assert_eq(dec(s, @json.parse("{ \"k\": \"a\" }")), Ok("A"))
  @test.assert_eq(dec(s, @json.parse("{ \"k\": \"b\" }")), Ok("B"))
  @test.assert_eq(
    dec(s, @json.parse("{ \"k\": \"c\" }")),
    Err(["$.k: unknown value \"c\" (expected one of a, b)"]),
  )
  @test.assert_eq(
    dec(s, @json.parse("{ \"k\": 1 }")),
    Err(["$.k: expected a string"]),
  )
  @test.assert_eq(
    dec(s, @json.parse("{}")),
    Err(["$: missing required field \"k\""]),
  )
  @test.assert_eq(dec(s, (1).to_json()), Err(["$: expected an object"]))
  guard get_key(sch(s), "oneOf") is Array(vs) else { abort("oneOf") }
  @test.assert_eq(vs.length(), 2)
}
