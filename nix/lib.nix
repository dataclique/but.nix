{ pkgs }:

let
  inherit (pkgs) lib;

  gitbutler-cli = import ./gitbutler.nix {
    inherit pkgs;
    inherit (pkgs) lib;
  };

  # Build the gitbutler agent skill from the shared base, splicing in a
  # repo-specific "## This Repository" section via `repoNotes`. Pass the full
  # markdown block (heading included) ending in a trailing blank line; leave it
  # empty for the generic skill.
  mkSkill =
    {
      repoNotes ? "",
    }:
    let
      base = builtins.readFile ../skill/SKILL.md;
      text = builtins.replaceStrings [ "@REPO_NOTES@" ] [ repoNotes ] base;
    in
    pkgs.writeTextFile {
      name = "gitbutler-skill";
      destination = "/SKILL.md";
      inherit text;
    };

  skill = mkSkill { };

  # Shell snippet that symlinks the skill derivation into each editor's
  # `skills/gitbutler` directory. Idempotent and safe to run on every shell
  # entry: it only touches a path that is absent or already a symlink, and
  # skips editors whose base directory does not exist.
  installSkillScript =
    {
      repoNotes ? "",
      editors ? [
        ".claude"
        ".cursor"
      ],
    }:
    let
      skillDrv = mkSkill { inherit repoNotes; };
      installOne = base: ''_butnix_install_skill ${lib.escapeShellArg base} "${skillDrv}"'';
    in
    ''
      _butnix_install_skill() {
        local base="$1" skill="$2"
        [ -d "$base" ] || return 0
        mkdir -p "$base/skills"
        local link="$base/skills/gitbutler"
        if [ -L "$link" ] || [ ! -e "$link" ]; then
          ln -sfn "$skill" "$link"
        else
          echo "but.nix: $link is a real path, not a symlink; leaving it alone." >&2
        fi
      }
      ${lib.concatMapStringsSep "\n" installOne editors}
      unset -f _butnix_install_skill
    '';

  # devenv module that drops `but` on PATH and installs the skill on shell
  # entry. Import it into a `devenv.lib.mkShell` modules list, passing the
  # repo's own `repoNotes`.
  devenvModule =
    {
      repoNotes ? "",
      editors ? [
        ".claude"
        ".cursor"
      ],
    }:
    { ... }:
    {
      packages = [ gitbutler-cli ];
      enterShell = installSkillScript { inherit repoNotes editors; };
    };
in
{
  inherit
    gitbutler-cli
    mkSkill
    skill
    installSkillScript
    devenvModule
    ;
}
