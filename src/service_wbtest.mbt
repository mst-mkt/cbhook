///|
test "os_of_uname maps known kernels" {
  @test.assert_eq(os_of_uname("Darwin"), Macos)
  @test.assert_eq(os_of_uname("Linux"), Linux)
}

///|
test "os_of_uname rejects empty and unknown kernels" {
  let empty = try {
    os_of_uname("") |> ignore
    false
  } catch {
    _ => true
  }
  let unknown = try {
    os_of_uname("Plan9") |> ignore
    false
  } catch {
    _ => true
  }
  @test.assert_eq(empty, true)
  @test.assert_eq(unknown, true)
}

///|
test "absolutize keeps absolute paths and joins relative ones" {
  @test.assert_eq(absolutize("/a/b", Some("/cwd")), "/a/b")
  @test.assert_eq(absolutize("rel", Some("/cwd")), "/cwd/rel")
  @test.assert_eq(absolutize("./rel", Some("/cwd")), "/cwd/./rel")
  @test.assert_eq(absolutize("rel", None), "rel")
}

///|
test "config_home_of prefers XDG and falls back to HOME/.config" {
  @test.assert_eq(config_home_of(Some("/x"), Some("/h")), Some("/x"))
  @test.assert_eq(config_home_of(None, Some("/h")), Some("/h/.config"))
  @test.assert_eq(config_home_of(Some(""), Some("/h")), Some("/h/.config"))
  @test.assert_eq(config_home_of(None, Some("")), None)
  @test.assert_eq(config_home_of(None, None), None)
}

///|
test "display_env_of keeps set, nonempty vars in order" {
  let all = display_env_of(fn(k) {
    match k {
      "WAYLAND_DISPLAY" => Some("wayland-1")
      "DISPLAY" => Some(":0")
      "XDG_RUNTIME_DIR" => Some("/run/user/1000")
      _ => None
    }
  })
  @test.assert_eq(all, [
    ("WAYLAND_DISPLAY", "wayland-1"),
    ("DISPLAY", ":0"),
    ("XDG_RUNTIME_DIR", "/run/user/1000"),
  ])
  let some = display_env_of(fn(k) {
    match k {
      "DISPLAY" => Some(":0")
      "WAYLAND_DISPLAY" => Some("")
      _ => None
    }
  })
  @test.assert_eq(some, [("DISPLAY", ":0")])
}

///|
test "classify_exe distinguishes absolute, relative, and bare names" {
  @test.assert_eq(
    classify_exe(["/opt/cbhook"], None),
    Some(Ready("/opt/cbhook")),
  )
  @test.assert_eq(
    classify_exe(["./cbhook"], Some("/cwd")),
    Some(Ready("/cwd/./cbhook")),
  )
  @test.assert_eq(
    classify_exe(["bin/cbhook"], Some("/cwd")),
    Some(Ready("/cwd/bin/cbhook")),
  )
  @test.assert_eq(classify_exe(["cbhook"], Some("/cwd")), Some(Bare("cbhook")))
  @test.assert_eq(classify_exe([], None), None)
}

///|
test "systemd_unit lays out sections, ordered env, and a trailing newline" {
  let unit = systemd_unit("\"/usr/bin/cbhook\" watch --config \"/c.json\"", [
    ("WAYLAND_DISPLAY", "wayland-1"),
    ("DISPLAY", ":0"),
  ])
  @test.assert_eq(
    unit.contains("ExecStart=\"/usr/bin/cbhook\" watch --config \"/c.json\""),
    true,
  )
  @test.assert_eq(unit.contains("[Unit]"), true)
  // Environment lines must sit inside [Service] (after Restart, before [Install]).
  @test.assert_eq(
    unit.contains(
      "Restart=on-failure\nEnvironment=WAYLAND_DISPLAY=wayland-1\nEnvironment=DISPLAY=:0\n\n[Install]\nWantedBy=default.target",
    ),
    true,
  )
  @test.assert_eq(unit.has_suffix("\n"), true)
}

///|
test "systemd_unit omits Environment lines when no env is given" {
  let unit = systemd_unit("/x watch", [])
  @test.assert_eq(unit.contains("Environment="), false)
}

///|
test "launchd_plist is well-formed and restarts only on failure" {
  let plist = launchd_plist(
    "dev.keito.cbhook", "/usr/local/bin/cbhook", "/c.json",
  )
  @test.assert_eq(plist.contains("<?xml version=\"1.0\""), true)
  @test.assert_eq(plist.contains("<!DOCTYPE plist"), true)
  @test.assert_eq(plist.contains("<string>dev.keito.cbhook</string>"), true)
  @test.assert_eq(plist.contains("<key>RunAtLoad</key>"), true)
  // ProgramArguments must be an ordered array: exe, watch, --config, config.
  @test.assert_eq(
    plist.contains(
      "  <array>\n    <string>/usr/local/bin/cbhook</string>\n    <string>watch</string>\n    <string>--config</string>\n    <string>/c.json</string>\n  </array>",
    ),
    true,
  )
  // KeepAlive must restart only on failure (SuccessfulExit=false), not on success.
  @test.assert_eq(
    plist.contains(
      "<key>KeepAlive</key>\n  <dict>\n    <key>SuccessfulExit</key>\n    <false/>\n  </dict>",
    ),
    true,
  )
  @test.assert_eq(plist.has_suffix("\n"), true)
}

///|
test "launchd_plist escapes XML metacharacters in paths" {
  let plist = launchd_plist(
    "dev.keito.cbhook", "/usr/local/bin/cbhook", "/home/a & b/<c>.json",
  )
  @test.assert_eq(
    plist.contains("<string>/home/a &amp; b/&lt;c&gt;.json</string>"),
    true,
  )
  @test.assert_eq(plist.contains("/home/a & b/<c>.json"), false)
}
