///|
fn is_pkl(path : String) -> Bool {
  path.has_suffix(".pkl")
}

///|
fn diag_messages(diags : Array[@pkl.Diagnostic]) -> String {
  diags.map(fn(d) { d.message }).join("\n")
}

// pkl evaluates with full host access (e.g. `read("env:…")`) by design; this
// is intentionally not sandboxed since a cbhook config can already run
// arbitrary commands via its exec/pipe actions, so it is trusted regardless.

///|
fn pkl_to_json(source : String) -> String raise {
  match @pkl.eval_source(source) {
    @pkl.EvalOk(v) => @pkl.render_value_as_json(v)
    @pkl.EvalError(diags) =>
      raise ConfigError("invalid pkl config:\n\{diag_messages(diags)}")
  }
}

///|
pub fn parse_file(path : String, source : String) -> Config raise {
  if is_pkl(path) {
    parse(pkl_to_json(source))
  } else {
    parse(source)
  }
}
