// Minimal cbhook scaffold: watch the system clipboard and echo every change
// to stdout. The rule engine, config loading and actions come later — this just
// proves the toolchain and the clipboard watch loop work end to end.

///|
async fn main {
  try watch_and_echo() catch {
    err => println("cbhook: error: \{err}")
  }
}

///|
async fn watch_and_echo() -> Unit raise {
  @async.with_task_group(group => {
    let clipboard = @clipboard.Clipboard::new()
    println("cbhook: watching clipboard (Ctrl-C to stop)")
    // `watch` spawns a background poll task into `group`; the task group keeps
    // running until that task stops, so this blocks like a daemon.
    let _handle = clipboard.watch(group, text => println("changed: \{text}"))

  })
}
