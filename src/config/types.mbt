///|
pub struct Config {
  hooks : Array[Hook]
} derive(Eq, Debug)

///|
pub struct Hook {
  name : String?
  matcher : Matcher?
  action : Action
} derive(Eq, Debug)

///|
pub struct Matcher {
  pattern : String
  flags : String?
} derive(Eq, Debug)

///|
pub enum Action {
  Replace(pattern~ : String, replacement~ : String, flags~ : String?)
  Pipe(run~ : Array[String], timeout_ms~ : Int?, on_error~ : OnError)
  Exec(run~ : Array[String], timeout_ms~ : Int?, on_error~ : OnError)
} derive(Eq, Debug)

///|
pub enum OnError {
  Skip
  Abort
} derive(Eq, Debug)

///|
pub(all) suberror ConfigError {
  ConfigError(String)
}
