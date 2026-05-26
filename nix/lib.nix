lib:
let
  inherit (lib) optionalAttrs;

  mkMatch = m: { inherit (m) pattern; } // optionalAttrs (m.flags != null) { inherit (m) flags; };

  mkAction =
    a:
    if a ? replace then
      {
        type = "replace";
        inherit (a.replace) pattern replacement;
      }
      // optionalAttrs (a.replace.flags != null) { inherit (a.replace) flags; }
    else if a ? pipe then
      {
        type = "pipe";
        inherit (a.pipe) run;
      }
      // optionalAttrs (a.pipe.timeout_ms != null) { inherit (a.pipe) timeout_ms; }
      // optionalAttrs (a.pipe.on_error != null) { inherit (a.pipe) on_error; }
    else
      {
        type = "exec";
        inherit (a.exec) run;
      }
      // optionalAttrs (a.exec.timeout_ms != null) { inherit (a.exec) timeout_ms; }
      // optionalAttrs (a.exec.on_error != null) { inherit (a.exec) on_error; };

  mkHook =
    h:
    optionalAttrs (h.name != null) { inherit (h) name; }
    // optionalAttrs (h.match != null) { match = mkMatch h.match; }
    // {
      action = mkAction h.action;
    };
in
{
  inherit mkHook mkAction;

  toConfig =
    {
      hooks,
      log_level,
    }:
    { hooks = map mkHook hooks; } // optionalAttrs (log_level != null) { inherit log_level; };
}
