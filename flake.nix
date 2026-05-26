{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    moonbit-skills = {
      url = "git+https://github.com/moonbitlang/skills?submodules=1";
      flake = false;
    };
    moon-registry = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      moonbit-overlay,
      agent-skills,
      moonbit-skills,
      moon-registry,
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
      homeManagerModules = {
        cbhook = import ./nix/home-manager.nix self;
        default = self.homeManagerModules.cbhook;
      };

      overlays.default = final: _prev: {
        cbhook = final.callPackage ./nix/package.nix { inherit moon-registry; };
      };

      checks = forAllSystems (pkgs: {
        cbhook = self.packages.${pkgs.stdenv.hostPlatform.system}.cbhook;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      packages = forAllSystems (
        pkgs:
        let
          cbhook = pkgs.callPackage ./nix/package.nix { inherit moon-registry; };
        in
        {
          default = cbhook;
          inherit cbhook;
        }
      );

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
            claude = agentLib.defaultLocalTargets.claude // {
              enable = true;
            };
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.moonbit-bin.moonbit.latest
              pkgs.xclip
              pkgs.wl-clipboard
            ];
            shellHook = agentLib.mkShellHook { inherit pkgs bundle targets; };
          };
        }
      );
    };
}
