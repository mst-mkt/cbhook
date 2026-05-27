///|
test "error_message extracts the ConfigError payload" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "a(", "replacement": "" } } ] }
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
  let msg = fail("boom") catch { e => error_message(e) }
  @test.assert_eq(msg, "boom")
}

///|
test "error_message unwraps an ActionError" {
  let msg = try {
    raise @action.ActionError("boom")
  } catch {
    e => error_message(e)
  }
  @test.assert_eq(msg, "boom")
}

///|
test "after_fail_marker strips the location prefix" {
  @test.assert_eq(after_fail_marker("src/x.mbt:1:1 FAILED: boom"), "boom")
}

///|
test "after_fail_marker keeps a message without the marker" {
  @test.assert_eq(after_fail_marker("plain message"), "plain message")
}

///|
test "after_fail_marker keeps everything after the first marker" {
  @test.assert_eq(after_fail_marker("loc FAILED: a FAILED: b"), "a FAILED: b")
}
