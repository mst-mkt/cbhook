///|
extern "c" fn c_exit(code : Int) -> Unit = "exit"

///|
enum Pending {
  Watch(config~ : String?)
  Check(config~ : String?)
}

///|
fn after_fail_marker(m : String) -> String {
  match m.split(" FAILED: ").to_array() {
    [_loc, first, .. rest] =>
      rest.fold(init=first.to_owned(), fn(acc, p) { acc + " FAILED: " + p.to_owned() })
    _ => m
  }
}

///|
fn error_message(e : Error) -> String {
  match e {
    @config.ConfigError(m) => m
    @action.ActionError(m) => m
    Failure::Failure(m) => after_fail_marker(m)
    _ => e.to_string()
  }
}

///|
fn build_cli(pending : Ref[Pending?]) -> @admiral.CliApp {
  @admiral.cli(
    name="cbhook",
    version="0.1.0",
    description="Watch the clipboard and transform it with hooks.",
    commands=[
      @admiral.command(
        name="watch",
        description="Watch the clipboard and apply hooks on each change.",
        options=[
          @admiral.string(
            "config",
            short='c',
            description="Path to the config file (.json)",
          ),
        ],
        run=Some(fn(ctx) {
          pending.val = Some(Watch(config=ctx.get_string("config")))
        }),
      ),
      @admiral.command(
        name="check",
        description="Validate the config and exit (no watching).",
        options=[
          @admiral.string(
            "config",
            short='c',
            description="Path to the config file (.json)",
          ),
        ],
        run=Some(fn(ctx) {
          pending.val = Some(Check(config=ctx.get_string("config")))
        }),
      ),
      @admiral.command(
        name="schema",
        description="Print the config JSON Schema (draft-07).",
        run=Some(fn(_ctx) { println(@config.schema_json()) }),
      ),
    ],
  )
}

///|
async fn main {
  let pending : Ref[Pending?] = { val: None }
  try build_cli(pending).run() catch {
    e => {
      println("cbhook: \{error_message(e)}")
      c_exit(1)
    }
  }
  match pending.val {
    Some(Watch(config~)) =>
      try watch(config) catch {
        e => {
          println("cbhook: \{error_message(e)}")
          c_exit(1)
        }
      }
    Some(Check(config~)) =>
      try check(config) catch {
        e => {
          println("cbhook: \{error_message(e)}")
          c_exit(1)
        }
      }
    None => ()
  }
}
