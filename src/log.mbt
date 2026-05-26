///|
let active_level : Ref[@config.LogLevel] = { val: @config.Info }

///|
let flag_level : Ref[@config.LogLevel?] = { val: None }

///|
fn level_rank(level : @config.LogLevel) -> Int {
  match level {
    @config.Debug => 0
    @config.Info => 1
    @config.Warn => 2
  }
}

///|
fn effective_level(
  flag : @config.LogLevel?,
  config : @config.LogLevel?,
) -> @config.LogLevel {
  match flag {
    Some(l) => l
    None =>
      match config {
        Some(l) => l
        None => @config.Info
      }
  }
}

///|
fn set_flag_level(verbose : Bool, quiet : Bool) -> Unit {
  flag_level.val = if verbose {
    Some(@config.Debug)
  } else if quiet {
    Some(@config.Warn)
  } else {
    None
  }
  active_level.val = effective_level(flag_level.val, None)
}

///|
fn apply_config_level(config_level : @config.LogLevel?) -> Unit {
  active_level.val = effective_level(flag_level.val, config_level)
}

///|
fn should_emit(msg_level : @config.LogLevel, active : @config.LogLevel) -> Bool {
  level_rank(msg_level) >= level_rank(active)
}

///|
async fn emit(level : @config.LogLevel, msg : String) -> Unit {
  if should_emit(level, active_level.val) {
    @stdio.stderr.write(@utf8.encode("cbhook: \{msg}\n"))
  }
}

///|
async fn log_debug(msg : String) -> Unit {
  emit(@config.Debug, msg)
}

///|
async fn log_info(msg : String) -> Unit {
  emit(@config.Info, msg)
}

///|
async fn log_warn(msg : String) -> Unit {
  emit(@config.Warn, msg)
}

///|
async fn log_notices(notices : ArrayView[String]) -> Unit {
  match notices {
    [] => ()
    [n, .. rest] => {
      log_info("notice: \{n}")
      log_notices(rest)
    }
  }
}
