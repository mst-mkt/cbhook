///|
const SERVICE_LABEL : String = "dev.keito.cbhook"

///|
const UNIT_FILENAME : String = "cbhook.service"

///|
enum ServiceOs {
  Linux
  Macos
} derive(Eq, Debug)

///|
fn os_of_uname(name : String) -> ServiceOs raise {
  match name {
    "Darwin" => Macos
    "Linux" => Linux
    "" => fail("could not detect the operating system (uname failed)")
    other => fail("service install supports Linux and macOS only (uname: \{other})")
  }
}

///|
async fn detect_os() -> ServiceOs raise {
  let (status, out, _err) = @process.collect_output("uname", ["-s"])
  os_of_uname(if status == 0 { out.text().trim().to_owned() } else { "" })
}

///|
fn absolutize(path : String, cwd : String?) -> String {
  match path[:] {
    ['/', ..] => path
    _ =>
      match cwd {
        Some(c) => "\{c}/\{path}"
        None => path
      }
  }
}

///|
enum ExeClass {
  Ready(String)
  Bare(String)
} derive(Eq, Debug)

///|
fn classify_exe(argv : ArrayView[String], cwd : String?) -> ExeClass? {
  match argv {
    [] => None
    [exe, ..] =>
      match exe[:] {
        ['/', ..] => Some(Ready(exe))
        _ =>
          if exe.contains("/") {
            Some(Ready(absolutize(exe, cwd)))
          } else {
            Some(Bare(exe))
          }
      }
  }
}

///|
// A PATH entry only counts if it is a regular file (or a symlink to one),
// not a same-named directory.
async fn search_path(dirs : ArrayView[StringView], name : String) -> String? {
  match dirs {
    [] => None
    [dir, .. rest] => {
      let candidate = "\{dir}/\{name}"
      if is_regular_file(candidate) {
        Some(candidate)
      } else {
        search_path(rest, name)
      }
    }
  }
}

///|
async fn is_regular_file(path : String) -> Bool {
  try @fs.kind(path) is @fs.Regular catch {
    _ => false
  }
}

///|
async fn find_on_path(name : String) -> String? {
  match nonempty(@env.get_env_var("PATH")) {
    Some(path) => search_path(path.split(":").to_array()[:], name)
    None => None
  }
}

///|
async fn executable_path() -> String raise {
  match classify_exe(@env.args()[:], @env.current_dir()) {
    Some(Ready(p)) => p
    Some(Bare(name)) =>
      match find_on_path(name) {
        Some(p) => p
        None =>
          fail(
            "could not locate the cbhook executable '\{name}' on PATH; run service install with an absolute path",
          )
      }
    None => fail("could not determine the cbhook executable path")
  }
}

///|
fn config_home_of(xdg : String?, home : String?) -> String? {
  match nonempty(xdg) {
    Some(x) => Some(x)
    None =>
      match nonempty(home) {
        Some(h) => Some("\{h}/.config")
        None => None
      }
  }
}

///|
fn display_env_of(lookup : (String) -> String?) -> Array[(String, String)] {
  // A user service has no graphical-session context, so the clipboard backend
  // (xclip/wl-copy) needs these forwarded explicitly.
  ["WAYLAND_DISPLAY", "DISPLAY", "XDG_RUNTIME_DIR"].fold(init=[], fn(acc, k) {
    match nonempty(lookup(k)) {
      Some(v) => [..acc, (k, v)]
      None => acc
    }
  })
}

///|
fn systemd_unit(exec_start : String, env : Array[(String, String)]) -> String {
  let env_lines = env.map(fn(kv) { "Environment=\{kv.0}=\{kv.1}" })
  [
    "[Unit]",
    "Description=cbhook clipboard watcher",
    "After=graphical-session.target",
    "",
    "[Service]",
    "ExecStart=\{exec_start}",
    "Restart=on-failure",
    ..env_lines,
    "",
    "[Install]",
    "WantedBy=default.target",
    "",
  ].join("\n")
}

///|
fn launchd_plist(label : String, exe : String, config : String) -> String {
  [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
    "<plist version=\"1.0\">",
    "<dict>",
    "  <key>Label</key>",
    "  <string>\{label}</string>",
    "  <key>ProgramArguments</key>",
    "  <array>",
    "    <string>\{exe}</string>",
    "    <string>watch</string>",
    "    <string>--config</string>",
    "    <string>\{config}</string>",
    "  </array>",
    "  <key>RunAtLoad</key>",
    "  <true/>",
    "  <key>KeepAlive</key>",
    "  <dict>",
    "    <key>SuccessfulExit</key>",
    "    <false/>",
    "  </dict>",
    "</dict>",
    "</plist>",
    "",
  ].join("\n")
}

///|
async fn write_unit(dir : String, file : String, content : String) -> Unit raise {
  // Re-installing overwrites any existing unit rather than appending or failing.
  @fs.mkdir(dir, recursive=true)
  @fs.write_file(file, @utf8.encode(content), create_mode=CreateOrTruncate)
}

///|
async fn service_install(config : String?) -> Unit raise {
  let exe = executable_path()
  let config_path = absolutize(require_config_path(config), @env.current_dir())
  match detect_os() {
    Linux => {
      let dir = match config_home_of(
          @env.get_env_var("XDG_CONFIG_HOME"),
          @env.get_env_var("HOME"),
        ) {
        Some(c) => "\{c}/systemd/user"
        None => fail("neither XDG_CONFIG_HOME nor HOME is set")
      }
      let file = "\{dir}/\{UNIT_FILENAME}"
      let exec_start = "\"\{exe}\" watch --config \"\{config_path}\""
      write_unit(dir, file, systemd_unit(exec_start, display_env_of(@env.get_env_var)))
      log_info("installed \{file}")
      log_info("enable with: systemctl --user enable --now \{UNIT_FILENAME}")
    }
    Macos => {
      let home = match nonempty(@env.get_env_var("HOME")) {
        Some(h) => h
        None => fail("HOME is not set")
      }
      let dir = "\{home}/Library/LaunchAgents"
      let file = "\{dir}/\{SERVICE_LABEL}.plist"
      write_unit(dir, file, launchd_plist(SERVICE_LABEL, exe, config_path))
      log_info("installed \{file}")
      log_info("load with: launchctl load \{file}")
    }
  }
}
