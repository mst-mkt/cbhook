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
test "take_pending returns the value and clears it" {
  let r : Ref[String?] = { val: Some("x") }
  @test.assert_eq(take_pending(r), Some("x"))
  @test.assert_eq(r.val, None)
  @test.assert_eq(take_pending(r), None)
}

///|
async test "run_pipeline leaves the clipboard unchanged when a hook fails" {
  let json =
    #|{ "hooks": [ { "action": { "type": "exec", "run": ["false"], "on_error": "abort" } } ] }
  let compiled = @engine.compile(@config.parse(json))
  @async.with_task_group(_group => {
    let clipboard = @clipboard.Clipboard::new_in_memory()
    clipboard.set_text("seed")
    let last_written : Ref[String?] = { val: None }
    run_pipeline(clipboard, compiled, last_written, "trigger")
    @test.assert_eq(last_written.val, None)
    @test.assert_eq(clipboard.get_text(), "seed")
  })
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
