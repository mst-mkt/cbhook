{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    moonbit-skills = {
      url = "git+https://github.com/moonbitlang/skills?submodules=1";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      moonbit-overlay,
      agent-skills,
      moonbit-skills,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ moonbit-overlay.overlays.default ];
            }
          )
        );
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          agentLib = agent-skills.lib.agent-skills;
          sources = {
            moonbit = {
              path = moonbit-skills;
              subdir = "skills";
              filter.maxDepth = 1;
            };
          };
          catalog = agentLib.discoverCatalog sources;
          allowlist = agentLib.allowlistFor {
            inherit catalog sources;
            enable = [
              "moonbit-orientation"
              "moonbit-agent-guide"
              "moonbit-spec-test-development"
              "moonbit-refactoring"
            ];
          };
          selection = agentLib.selectSkills {
            inherit catalog allowlist sources;
            skills = { };
          };
          bundle = agentLib.mkBundle { inherit pkgs selection; };
          targets = {
            claude = agentLib.defaultLocalTargets.claude // { enable = true; };
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.moonbit-bin.moonbit.latest
              pkgs.xclip # Linux X11
              pkgs.wl-clipboard # Linux Wayland (wl-copy / wl-paste)
            ];
            shellHook = agentLib.mkShellHook { inherit pkgs bundle targets; };
          };
        }
      );
    };
}
