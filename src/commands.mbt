///|
async fn check(config : String?) -> Unit raise {
  let compiled = load_compiled(config)
  log_notices(compiled.notices()[:])
  log_info("config is valid")
}

///|
fn positional_text(parts : Array[String]) -> String? {
  match parts {
    [] => None
    _ => Some(parts.join(" "))
  }
}

///|
async fn evaluate(args : Array[String], config : String?) -> Unit raise {
  let input = match positional_text(args) {
    Some(t) => t
    None => @stdio.stdin.read_all().text()
  }
  println(load_compiled(config).run(input))
}
