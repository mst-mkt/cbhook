///|
test "config location precedence" {
  @test.assert_eq(
    resolve_config_location(Some("/x"), Some("/y"), Some("/z"), Some("/h")),
    Some(Explicit("/x")),
  )
  @test.assert_eq(
    resolve_config_location(None, Some("/y"), Some("/z"), Some("/h")),
    Some(Explicit("/y")),
  )
  @test.assert_eq(
    resolve_config_location(None, None, Some("/z"), Some("/h")),
    Some(Default("/z/cbhook")),
  )
  @test.assert_eq(
    resolve_config_location(None, None, None, Some("/h")),
    Some(Default("/h/.config/cbhook")),
  )
  @test.assert_eq(resolve_config_location(None, None, None, None), None)
}

///|
test "empty strings are treated as unset" {
  @test.assert_eq(
    resolve_config_location(Some(""), Some("/y"), Some("/z"), Some("/h")),
    Some(Explicit("/y")),
  )
  @test.assert_eq(
    resolve_config_location(None, Some(""), Some("/z"), Some("/h")),
    Some(Default("/z/cbhook")),
  )
  @test.assert_eq(
    resolve_config_location(None, None, Some(""), Some("/h")),
    Some(Default("/h/.config/cbhook")),
  )
  @test.assert_eq(resolve_config_location(None, None, None, Some("")), None)
}

///|
test "default_config_file prefers pkl and falls back to json" {
  @test.assert_eq(
    default_config_file("/h/.config/cbhook", true),
    "/h/.config/cbhook/config.pkl",
  )
  @test.assert_eq(
    default_config_file("/h/.config/cbhook", false),
    "/h/.config/cbhook/config.json",
  )
}
