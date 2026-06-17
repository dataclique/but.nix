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

  # Cursor agent shell permissions installed into consuming repos via
  # `.cursor/cli.json`.
  cursorPermissionAllow = [
    "Shell(git:diff*)"
    "Shell(git:log*)"
    "Shell(git:status*)"
    "Shell(git:show*)"
    "Shell(git:fetch*)"
    "Shell(git:branch*)"
    "Shell(git:ls-tree*)"
    "Shell(git:grep*)"
    "Shell(git:rev-parse*)"
    "Shell(git:merge-base*)"
    "Shell(git:blame*)"
    "Shell(but:status*)"
    "Shell(but:diff*)"
    "Shell(but:show*)"
    "Shell(but:branch list*)"
    "Shell(but:branch show*)"
    "Shell(but:pull --check*)"
    "Shell(but:resolve status*)"
    "Shell(but:skill check*)"
    "Shell(but:commit*)"
    "Shell(but:branch new*)"
    "Shell(but:branch delete*)"
    "Shell(but:apply*)"
    "Shell(but:unapply*)"
    "Shell(but:amend*)"
    "Shell(but:rub*)"
    "Shell(but:squash*)"
    "Shell(but:move*)"
    "Shell(but:reword*)"
    "Shell(but:absorb*)"
    "Shell(but:uncommit*)"
    "Shell(but:stage*)"
    "Shell(but:pick*)"
    "Shell(but:pull*)"
    "Shell(but:resolve*)"
    "Shell(but:clean*)"
    "Shell(but:setup*)"
    "Shell(but:undo*)"
    "Shell(but:redo*)"
    "Shell(but:oplog*)"
    "Shell(but:push*)"
    "Shell(but:pr*)"
  ];

  cursorCliJson = pkgs.writeTextFile {
    name = "but-cursor-cli";
    destination = "/cli.json";
    text = builtins.toJSON {
      permissions = {
        allow = cursorPermissionAllow;
        deny = [ ];
      };
    };
  };

  # Symlinks `.cursor/cli.json` into the repo when absent.
  installCursorCliScript =
    { }:
    let
      cliDrv = cursorCliJson;
      installOne = ''_butnix_install_cursor_cli "${cliDrv}"'';
    in
    ''
      _butnix_install_cursor_cli() {
        local src="$1" dst=".cursor/cli.json"
        [ -e "$dst" ] && return 0
        mkdir -p .cursor
        ln -sfn "$src" "$dst"
      }
      ${installOne}
      unset -f _butnix_install_cursor_cli
    '';

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
      enterShell =
        installSkillScript { inherit repoNotes editors; }
        + installCursorCliScript { };
    };
in
{
  inherit
    gitbutler-cli
    mkSkill
    skill
    cursorPermissionAllow
    cursorCliJson
    installSkillScript
    installCursorCliScript
    devenvModule
    ;
}
