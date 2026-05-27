///|
fn nonempty(s : String?) -> String? {
  match s {
    Some("") => None
    other => other
  }
}

///|
enum ConfigLocation {
  Explicit(String)
  Default(String)
} derive(Eq, Debug)

///|
fn resolve_config_location(
  explicit : String?,
  env_config : String?,
  xdg : String?,
  home : String?,
) -> ConfigLocation? {
  [
    nonempty(explicit).map(v => Explicit(v)),
    nonempty(env_config).map(v => Explicit(v)),
    nonempty(xdg).map(x => Default(x + "/cbhook")),
    nonempty(home).map(h => Default(h + "/.config/cbhook")),
  ].fold(init=None, fn(acc, c) { if acc is Some(_) { acc } else { c } })
}

///|
async fn discover_config_path(explicit : String?) -> String? {
  match
    resolve_config_location(
      explicit,
      @env.get_env_var("CBHOOK_CONFIG"),
      @env.get_env_var("XDG_CONFIG_HOME"),
      @env.get_env_var("HOME"),
    ) {
    None => None
    Some(Explicit(p)) => Some(p)
    Some(Default(dir)) =>
      Some(default_config_file(dir, @fs.exists("\{dir}/config.pkl")))
  }
}

///|
fn default_config_file(dir : String, pkl_exists : Bool) -> String {
  if pkl_exists {
    "\{dir}/config.pkl"
  } else {
    "\{dir}/config.json"
  }
}

///|
async fn require_config_path(explicit : String?) -> String {
  match discover_config_path(explicit) {
    Some(p) => p
    None =>
      raise @config.ConfigError(
        "no config found (use --config, $CBHOOK_CONFIG, or ~/.config/cbhook/config.{pkl,json})",
      )
  }
}
