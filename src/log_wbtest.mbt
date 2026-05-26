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

///|
test "set_flag_level maps -v/-q to the active level (verbose wins)" {
  set_flag_level(true, false)
  @test.assert_eq(active_level.val, @config.Debug)
  set_flag_level(false, true)
  @test.assert_eq(active_level.val, @config.Warn)
  set_flag_level(true, true)
  @test.assert_eq(active_level.val, @config.Debug)
  set_flag_level(false, false)
  @test.assert_eq(active_level.val, @config.Info)
}

///|
test "apply_config_level uses config only when no flag is set" {
  set_flag_level(false, false)
  apply_config_level(Some(@config.Warn))
  @test.assert_eq(active_level.val, @config.Warn)
  set_flag_level(true, false)
  apply_config_level(Some(@config.Warn))
  @test.assert_eq(active_level.val, @config.Debug)
  set_flag_level(false, false)
  apply_config_level(None)
}
