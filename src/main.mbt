///|
extern "c" fn c_exit(code : Int) -> Unit = "exit"

///|
enum Pending {
  Watch(config~ : String?)
  Check(config~ : String?)
  Service(config~ : String?)
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
fn std_options() -> Array[@admiral.OptionDef] {
  [
    @admiral.string("config", short='c', description="Path to the config file (.json)"),
    @admiral.bool("verbose", short='v', description="Verbose (debug) logging"),
    @admiral.bool("quiet", short='q', description="Quiet (warnings only)"),
  ]
}

///|
fn select_command(pending : Ref[Pending?], ctx : @admiral.Context, p : Pending) -> Unit {
  set_flag_level(ctx.get_bool("verbose"), ctx.get_bool("quiet"))
  pending.val = Some(p)
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
        options=std_options(),
        run=Some(fn(ctx) {
          select_command(pending, ctx, Watch(config=ctx.get_string("config")))
        }),
      ),
      @admiral.command(
        name="check",
        description="Validate the config and exit (no watching).",
        options=std_options(),
        run=Some(fn(ctx) {
          select_command(pending, ctx, Check(config=ctx.get_string("config")))
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
              select_command(pending, ctx, Service(config=ctx.get_string("config")))
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
  let pending : Ref[Pending?] = { val: None }
  try build_cli(pending).run() catch {
    e => fail_exit(e)
  }
  match pending.val {
    Some(Watch(config~)) => try watch(config) catch { e => fail_exit(e) }
    Some(Check(config~)) => try check(config) catch { e => fail_exit(e) }
    Some(Service(config~)) =>
      try service_install(config) catch {
        e => fail_exit(e)
      }
    None => ()
  }
}
