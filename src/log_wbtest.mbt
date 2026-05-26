///|
test "effective_level prefers the flag, then config, then info" {
  @test.assert_eq(
    effective_level(Some(@config.Debug), Some(@config.Warn)),
    @config.Debug,
  )
  @test.assert_eq(effective_level(None, Some(@config.Warn)), @config.Warn)
  @test.assert_eq(effective_level(None, None), @config.Info)
}

///|
test "level_rank orders debug < info < warn" {
  @test.assert_eq(level_rank(@config.Debug) < level_rank(@config.Info), true)
  @test.assert_eq(level_rank(@config.Info) < level_rank(@config.Warn), true)
}

///|
test "should_emit gates messages below the active level" {
  @test.assert_eq(should_emit(@config.Debug, @config.Info), false)
  @test.assert_eq(should_emit(@config.Info, @config.Info), true)
  @test.assert_eq(should_emit(@config.Warn, @config.Info), true)
  @test.assert_eq(should_emit(@config.Info, @config.Warn), false)
  @test.assert_eq(should_emit(@config.Debug, @config.Debug), true)
}
