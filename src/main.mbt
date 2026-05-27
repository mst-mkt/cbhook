///|
extern "c" fn c_exit(code : Int) -> Unit = "exit"

// MoonBit's `fail()` (used by admiral for usage errors) prefixes the message
// with "<loc> FAILED: "; strip it so those errors print cleanly.

///|
fn after_fail_marker(m : String) -> String {
  match m.split(" FAILED: ").to_array() {
    [_loc, first, .. rest] =>
      rest.fold(init=first.to_owned(), fn(acc, p) {
        acc + " FAILED: " + p.to_owned()
      })
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
fn std_options() -> Array[@admiral.OptionDef] {
  [
    @admiral.string(
      "config",
      short='c',
      description="Path to the config file (.json|.pkl)",
    ),
    @admiral.bool("verbose", short='v', description="Verbose (debug) logging"),
    @admiral.bool("quiet", short='q', description="Quiet (warnings only)"),
  ]
}

///|
// admiral's `run` callbacks are synchronous, so a command records its async
// body in this slot; `main` runs it once the event loop is available.
fn set_command(
  slot : Ref[(async () -> Unit)?],
  ctx : @admiral.Context,
  body : async () -> Unit,
) -> Unit {
  set_flag_level(ctx.get_bool("verbose"), ctx.get_bool("quiet"))
  slot.val = Some(body)
}

///|
fn build_cli(slot : Ref[(async () -> Unit)?]) -> @admiral.CliApp {
  @admiral.cli(
    name="cbhook",
    version="0.1.1",
    description="Watch the clipboard and transform it with hooks.",
    commands=[
      @admiral.command(
        name="watch",
        description="Watch the clipboard and apply hooks on each change.",
        options=std_options(),
        run=Some(fn(ctx) {
          set_command(slot, ctx, () => watch(ctx.get_string("config")))
        }),
      ),
      @admiral.command(
        name="check",
        description="Validate the config and exit (no watching).",
        options=std_options(),
        run=Some(fn(ctx) {
          set_command(slot, ctx, () => check(ctx.get_string("config")))
        }),
      ),
      @admiral.command(
        name="eval",
        description="Apply hooks to the given text (or stdin) and print the result.",
        options=std_options(),
        positionals=[
          @admiral.positional(
            "text",
            description="Text to transform (reads stdin if omitted)",
          ),
        ],
        run=Some(fn(ctx) {
          set_command(slot, ctx, () => {
            evaluate(ctx.get_strings("text"), ctx.get_string("config"))
          })
        }),
      ),
      @admiral.command(
        name="schema",
        description="Print the config JSON Schema (draft-07).",
        run=Some(fn(_ctx) { println(@config.schema_json()) }),
      ),
      @admiral.command(
        name="service",
        description="Manage the cbhook background service.",
        subcommands=[
          @admiral.command(
            name="install",
            description="Install a systemd user unit (Linux) or launchd agent (macOS).",
            options=std_options(),
            run=Some(fn(ctx) {
              set_command(slot, ctx, () => {
                service_install(ctx.get_string("config"))
              })
            }),
          ),
        ],
      ),
    ],
  )
}

///|
async fn fail_exit(e : Error) -> Unit {
  log_warn(error_message(e))
  c_exit(1)
}

///|
async fn main {
  let slot : Ref[(async () -> Unit)?] = { val: None }
  build_cli(slot).run() catch {
    e => fail_exit(e)
  }
  match slot.val {
    Some(run_command) => run_command() catch { e => fail_exit(e) }
    None => ()
  }
}
