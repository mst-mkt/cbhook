///|
async fn load_compiled(config : String?) -> @engine.Compiled raise {
  let path = require_config_path(config)
  let source = try @fs.read_file(path).text() catch {
    _ => raise @config.ConfigError("cannot read config file: \{path}")
  }
  let cfg = @config.parse_file(path, source)
  apply_config_level(cfg.log_level)
  @engine.compile(cfg)
}
