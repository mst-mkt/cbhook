///|
fn nonempty(s : String?) -> String? {
  match s {
    Some("") => None
    other => other
  }
}

///|
fn resolve_config_path(
  explicit : String?,
  env_config : String?,
  xdg : String?,
  home : String?,
) -> String? {
  match nonempty(explicit) {
    Some(v) => Some(v)
    None =>
      match nonempty(env_config) {
        Some(v) => Some(v)
        None =>
          match nonempty(xdg) {
            Some(x) => Some(x + "/cbhook/config.json")
            None =>
              match nonempty(home) {
                Some(h) => Some(h + "/.config/cbhook/config.json")
                None => None
              }
          }
      }
  }
}

///|
fn discover_config_path(explicit : String?) -> String? {
  resolve_config_path(
    explicit,
    @env.get_env_var("CBHOOK_CONFIG"),
    @env.get_env_var("XDG_CONFIG_HOME"),
    @env.get_env_var("HOME"),
  )
}
