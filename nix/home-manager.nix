self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.cbhook;
  format = pkgs.formats.json { };
  cbhook = import ./lib.nix lib;
  configFile = format.generate "cbhook-config.json" (
    cbhook.toConfig { inherit (cfg) hooks log_level; }
  );

  matcherType = lib.types.submodule {
    options = {
      pattern = lib.mkOption {
        type = lib.types.str;
        description = "Regular expression that gates the hook.";
      };
      flags = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Regex flags, e.g. \"i\".";
      };
    };
  };

  commandActionType = lib.types.submodule {
    options = {
      run = lib.mkOption {
        type = lib.types.nonEmptyListOf lib.types.str;
        description = "Command and arguments.";
      };
      timeout_ms = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.int (x: x >= 0));
        default = null;
        description = "Timeout in milliseconds (0 means no limit).";
      };
      on_error = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "skip"
            "abort"
          ]
        );
        default = null;
        description = "On failure: \"skip\" (default) keeps the text, \"abort\" stops the pipeline.";
      };
    };
  };

  actionType = lib.types.attrTag {
    replace = lib.mkOption {
      description = "Replace regex matches in the clipboard text.";
      type = lib.types.submodule {
        options = {
          pattern = lib.mkOption {
            type = lib.types.str;
            description = "Regular expression to match.";
          };
          replacement = lib.mkOption {
            type = lib.types.str;
            description = "Replacement text (JSON `with`); supports $1, \${name}, $$.";
          };
          flags = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Regex flags, e.g. \"i\".";
          };
        };
      };
    };
    pipe = lib.mkOption {
      description = "Rewrite the clipboard with the command's stdout.";
      type = commandActionType;
    };
    exec = lib.mkOption {
      description = "Run the command for its side effects (stdout ignored).";
      type = commandActionType;
    };
  };

  hookType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional hook name.";
      };
      match = lib.mkOption {
        type = lib.types.nullOr matcherType;
        default = null;
        description = "Optional matcher; the hook only runs when it matches.";
      };
      action = lib.mkOption {
        type = actionType;
        description = "The action to apply (exactly one of replace/pipe/exec).";
      };
    };
  };
in
{
  options.programs.cbhook = {
    enable = lib.mkEnableOption "the cbhook clipboard watcher";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "cbhook.packages.\${system}.default";
      description = "The cbhook package to use.";
    };

    log_level = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "debug"
          "info"
          "warn"
        ]
      );
      default = null;
      description = "Logging verbosity (defaults to info).";
    };

    hooks = lib.mkOption {
      type = lib.types.listOf hookType;
      default = [ ];
      example = lib.literalExpression ''
        [
          {
            match.pattern = "(https?://)x\\.com\\b";
            action.replace = {
              pattern = "(https?://)x\\.com\\b";
              replacement = "$1twitter.com";
            };
          }
        ]
      '';
      description = "Ordered clipboard-rewrite hooks.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];
        xdg.configFile."cbhook/config.json".source = configFile;
      }

      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        systemd.user.services.cbhook = {
          Unit = {
            Description = "cbhook clipboard watcher";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${cfg.package}/bin/cbhook watch --config ${configFile}";
            Restart = "on-failure";
            PassEnvironment = [
              "WAYLAND_DISPLAY"
              "DISPLAY"
            ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })

      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        launchd.agents.cbhook = {
          enable = true;
          config = {
            ProgramArguments = [
              "${cfg.package}/bin/cbhook"
              "watch"
              "--config"
              "${configFile}"
            ];
            RunAtLoad = true;
            KeepAlive = {
              SuccessfulExit = false;
            };
          };
        };
      })
    ]
  );
}
