///|
test "config path resolution precedence" {
  @test.assert_eq(
    resolve_config_path(Some("/x"), Some("/y"), Some("/z"), Some("/h")),
    Some("/x"),
  )
  @test.assert_eq(
    resolve_config_path(None, Some("/y"), Some("/z"), Some("/h")),
    Some("/y"),
  )
  @test.assert_eq(
    resolve_config_path(None, None, Some("/z"), Some("/h")),
    Some("/z/cbhook/config.json"),
  )
  @test.assert_eq(
    resolve_config_path(None, None, None, Some("/h")),
    Some("/h/.config/cbhook/config.json"),
  )
  @test.assert_eq(resolve_config_path(None, None, None, None), None)
}

///|
test "empty strings are treated as unset" {
  @test.assert_eq(
    resolve_config_path(Some(""), Some("/y"), Some("/z"), Some("/h")),
    Some("/y"),
  )
  @test.assert_eq(
    resolve_config_path(None, Some(""), Some("/z"), Some("/h")),
    Some("/z/cbhook/config.json"),
  )
  @test.assert_eq(
    resolve_config_path(None, None, Some(""), Some("/h")),
    Some("/h/.config/cbhook/config.json"),
  )
  @test.assert_eq(resolve_config_path(None, None, None, Some("")), None)
}
