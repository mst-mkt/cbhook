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
  configFile = format.generate "cbhook-config.json" cfg.settings;
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

    settings = lib.mkOption {
      type = format.type;
      default = {
        hooks = [ ];
      };
      example = lib.literalExpression ''
        {
          log_level = "info";
          hooks = [
            {
              action = {
                type = "replace";
                pattern = "(https?://)x\\.com\\b";
                "with" = "$1twitter.com";
              };
            }
          ];
        }
      '';
      description = ''
        cbhook configuration. Written verbatim to a JSON config file and passed
        to `cbhook watch --config`. See `cbhook schema` for the schema.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];
        xdg.configFile."cbhook/config.json".source = configFile;
      }

      (lib.mkIf pkgs.stdenv.isLinux {
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

      (lib.mkIf pkgs.stdenv.isDarwin {
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
