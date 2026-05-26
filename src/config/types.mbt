///|
pub(all) struct Config {
  hooks : Array[Hook]
  log_level : LogLevel?
} derive(Eq, Debug)

///|
pub(all) enum LogLevel {
  Debug
  Info
  Warn
} derive(Eq, Debug)

///|
pub(all) struct Hook {
  name : String?
  matcher : Matcher?
  action : Action
} derive(Eq, Debug)

///|
pub(all) struct Matcher {
  pattern : String
  flags : String?
} derive(Eq, Debug)

///|
pub(all) enum Action {
  Replace(pattern~ : String, replacement~ : String, flags~ : String?)
  Pipe(run~ : Array[String], timeout_ms~ : Int?, on_error~ : OnError)
  Exec(run~ : Array[String], timeout_ms~ : Int?, on_error~ : OnError)
} derive(Eq, Debug)

///|
pub(all) enum OnError {
  Skip
  Abort
} derive(Eq, Debug)

///|
pub(all) suberror ConfigError {
  ConfigError(String)
}
