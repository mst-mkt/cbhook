///|
async test "load_compiled raises ConfigError for an unreadable path" {
  let msg = try {
    load_compiled(Some("/no/such/cbhook/file.json")) |> ignore
    "no error"
  } catch {
    @config.ConfigError(m) => m
    e => "other: \{e}"
  }
  @test.assert_eq(msg.contains("cannot read config file"), true)
}
