///|
test "decide suppresses the self-write echo" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(Some("foo"), "foo", c), None)
}

///|
test "decide transforms a fresh value" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(None, "foo", c), Some("f00"))
}

///|
test "decide returns None when the transform is a no-op" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(None, "xyz", c), None)
}

///|
test "decide guards oscillation in one step" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a", "with": "b" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(None, "a", c), Some("b"))
  @test.assert_eq(decide(Some("b"), "b", c), None)
}

///|
test "error_message extracts the ConfigError payload" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a(", "with": "" } } ] }
  let msg = try {
    @engine.compile(@config.parse(json)) |> ignore
    "no error"
  } catch {
    e => error_message(e)
  }
  @test.assert_eq(msg.contains("config.hooks[0].action.pattern"), true)
}

///|
test "error_message unwraps a Failure without the type prefix" {
  let msg = try {
    fail("boom")
  } catch {
    e => error_message(e)
  }
  @test.assert_eq(msg, "boom")
}
