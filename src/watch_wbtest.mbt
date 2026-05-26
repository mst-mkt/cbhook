///|
async test "decide suppresses the self-write echo" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(Some("foo"), "foo", c), None)
}

///|
async test "decide transforms a fresh value" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(None, "foo", c), Some("f00"))
}

///|
async test "decide returns None when the transform is a no-op" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let c = @engine.compile(@config.parse(json))
  @test.assert_eq(decide(None, "xyz", c), None)
}

///|
async test "decide guards oscillation in one step" {
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

///|
test "take_pending returns the value and clears it" {
  let r : Ref[String?] = { val: Some("x") }
  @test.assert_eq(take_pending(r), Some("x"))
  @test.assert_eq(r.val, None)
  @test.assert_eq(take_pending(r), None)
}

///|
async test "drain processes the pending value and resets running" {
  let json =
    #|{ "hooks": [ { "action": { "type": "replace", "pattern": "o", "with": "0" } } ] }
  let compiled = @engine.compile(@config.parse(json))
  @async.with_task_group(_group => {
    let clipboard = @clipboard.Clipboard::new_in_memory()
    let last_written : Ref[String?] = { val: None }
    let pending : Ref[String?] = { val: Some("foo") }
    let running : Ref[Bool] = { val: true }
    drain(clipboard, compiled, last_written, pending, running)
    @test.assert_eq(running.val, false)
    @test.assert_eq(pending.val, None)
    @test.assert_eq(last_written.val, Some("f00"))
    @test.assert_eq(clipboard.get_text(), "f00")
  })
}

///|
async test "load_compiled raises ConfigError for an unreadable path" {
  let msg = try {
    load_compiled(Some("/no/such/cbhook/file.json")) |> ignore
    "no error"
  } catch {
    @config.ConfigError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("cannot read config file"), true)
}
