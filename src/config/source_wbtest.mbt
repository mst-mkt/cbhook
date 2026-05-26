///|
test "is_pkl detects the .pkl extension" {
  @test.assert_eq(is_pkl("a/b.pkl"), true)
  @test.assert_eq(is_pkl("a/b.json"), false)
  @test.assert_eq(is_pkl("nopkl"), false)
  @test.assert_eq(is_pkl("a.pkl/b.json"), false)
  @test.assert_eq(is_pkl("a.PKL"), false)
}

///|
test "diag_messages joins multiple diagnostics with newlines" {
  let diags = [
    @pkl.Diagnostic::{ message: "first", start: 0, end: 0 },
    @pkl.Diagnostic::{ message: "second", start: 1, end: 2 },
  ]
  @test.assert_eq(diag_messages(diags), "first\nsecond")
}

///|
test "parse_file parses a .json source directly" {
  let src =
    #|{ "hooks": [] }
  @test.assert_eq(parse_file("x.json", src).hooks.length(), 0)
}

///|
test "parse_file evaluates a .pkl source into a Config" {
  let src =
    #|hooks = new Listing {
    #|  new Mapping {
    #|    ["action"] = new Mapping {
    #|      ["type"] = "replace"
    #|      ["pattern"] = "a"
    #|      ["with"] = "b"
    #|    }
    #|  }
    #|}
  let cfg = parse_file("x.pkl", src)
  @test.assert_eq(cfg.hooks.length(), 1)
  @test.assert_eq(
    cfg.hooks[0].action,
    Replace(pattern="a", replacement="b", flags=None),
  )
}

///|
test "parse_file renders a pkl pipe action with a Listing run array" {
  let src =
    #|hooks = new Listing {
    #|  new Mapping {
    #|    ["action"] = new Mapping {
    #|      ["type"] = "pipe"
    #|      ["run"] = new Listing { "tr"; "a"; "b" }
    #|    }
    #|  }
    #|}
  @test.assert_eq(
    parse_file("x.pkl", src).hooks[0].action,
    Pipe(run=["tr", "a", "b"], timeout_ms=None, on_error=Skip),
  )
}

///|
test "pkl log_level carries through to Config" {
  let src =
    #|hooks = new Listing {}
    #|log_level = "debug"
  @test.assert_eq(parse_file("x.pkl", src).log_level, Some(Debug))
}

///|
test "pkl that evaluates but is structurally invalid surfaces a config error" {
  let src =
    #|hooks = "nope"
  let msg = try {
    parse_file("x.pkl", src) |> ignore
    "no error"
  } catch {
    ConfigError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("config.hooks"), true)
}

///|
test "parse_file raises ConfigError on invalid pkl syntax" {
  let msg = try {
    parse_file("x.pkl", "hooks = new Listing {") |> ignore
    "no error"
  } catch {
    ConfigError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("invalid pkl config"), true)
}
