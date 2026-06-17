{
  description = "GitButler CLI (`but`) + agent skill, packaged for Nix dev shells";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # GitButler ships under an unfree license. Allow it here so
          # consuming flakes get the prebuilt package without touching
          # their own nixpkgs config.
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "gitbutler-cli" ];
        };

        lib = import ./nix/lib.nix { inherit pkgs; };
      in
      {
        inherit lib;

        packages = {
          default = lib.gitbutler-cli;
          gitbutler-cli = lib.gitbutler-cli;
          skill = lib.skill;
          cursor-cli-json = lib.cursorCliJson;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            lib.gitbutler-cli
            pkgs.nixfmt-rfc-style
          ];
        };
      }
    );

  nixConfig = {
    extra-substituters = [
      "https://devenv.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    allow-unfree = true;
  };
}
