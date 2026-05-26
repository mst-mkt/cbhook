///|
async test "run_pipe round-trips multibyte and multiline text through cat" {
  let cmd = ["cat"]
  @test.assert_eq(run_pipe(cmd[:], "あ\nb\n日本語"), "あ\nb\n日本語")
}

///|
async test "run_pipe transforms via the command's stdout" {
  let cmd = ["tr", "[:lower:]", "[:upper:]"]
  @test.assert_eq(run_pipe(cmd[:], "hello"), "HELLO")
}

///|
async test "run_pipe streams a payload larger than the pipe buffer" {
  let cmd = ["cat"]
  let big = String::make(100000, 'x')
  @test.assert_eq(run_pipe(cmd[:], big), big)
}

///|
async test "run_pipe raises on an empty command" {
  let empty : Array[String] = []
  let raised = try {
    run_pipe(empty[:], "x") |> ignore
    false
  } catch {
    ActionError(_) => true
    _ => false
  }
  @test.assert_eq(raised, true)
}

///|
async test "run_pipe raises with the command name on a non-zero exit" {
  let cmd = ["false"]
  let msg = try {
    run_pipe(cmd[:], "x") |> ignore
    "no error"
  } catch {
    ActionError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("false"), true)
}

///|
async test "run_pipe raises when the command does not exist" {
  let cmd = ["cbhook-no-such-command-xyz"]
  let raised = try {
    run_pipe(cmd[:], "x") |> ignore
    false
  } catch {
    _ => true
  }
  @test.assert_eq(raised, true)
}

///|
async test "run_exec runs the command and discards stdout" {
  let cmd = ["echo", "ignored"]
  run_exec(cmd[:], "x")
  @test.assert_eq(true, true)
}
