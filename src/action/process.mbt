///|
pub(all) suberror ActionError {
  ActionError(String)
}

///|
async fn capture(
  cmd : String,
  args : ArrayView[String],
  input : String,
) -> (Int, String) {
  @async.with_task_group(group => {
    let (child_stdin, parent_write) = @process.write_to_process()
    // Feed stdin from a detached task: a command that exits without draining
    // stdin (or a payload larger than the pipe buffer) must not block the read.
    group.spawn_bg(no_wait=true, () => {
      defer parent_write.close()
      parent_write.write(@utf8.encode(input)) catch {
        _ => ()
      }
    })
    let (status, stdout) = @process.collect_stdout(cmd, args, stdin=child_stdin)
    (status, stdout.text())
  })
}

///|
async fn run_capture(run : ArrayView[String], input : String) -> String {
  match run {
    [] => raise ActionError("empty command")
    [cmd, .. args] => {
      let (status, out) = capture(cmd, args, input)
      if status != 0 {
        raise ActionError("\{cmd} exited with status \{status}")
      }
      out
    }
  }
}

///|
pub async fn run_pipe(run : ArrayView[String], input : String) -> String {
  run_capture(run, input)
}

///|
pub async fn run_exec(run : ArrayView[String], input : String) -> Unit {
  run_capture(run, input) |> ignore
}
