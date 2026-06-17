# but.nix

A shared, reusable home for the [GitButler](https://gitbutler.com) CLI (`but`)
Nix derivation and the gitbutler agent skill. Consuming repos add this as a
flake input to get the `but` binary on their dev shell `PATH` and the
gitbutler skill auto-installed for their coding agents — no copies to keep in
sync.

## What it provides

- `packages.<system>.gitbutler-cli` — the `but` binary (unfree; allowed inside
  this flake so consumers don't have to touch their own nixpkgs config).
  Cross-platform (macOS aarch64/x86_64, Linux aarch64/x86_64).
- `packages.<system>.skill` — the generic gitbutler skill as a derivation
  (`$out/SKILL.md`).
- `lib.<system>`:
  - `gitbutler-cli` — the package.
  - `mkSkill { repoNotes ? "" }` — build the skill with a repo-specific
    `## This Repository` section spliced in.
  - `skill` — the generic skill (`mkSkill { }`).
  - `installSkillScript { repoNotes ? "", editors ? [".claude" ".cursor"] }` —
    a shell snippet that symlinks the skill into each editor's
    `skills/gitbutler` directory.
  - `cursor-cli-json` — a derivation containing `.cursor/cli.json` with
    granular Cursor agent permissions for `but`.
  - `installCursorCliScript { }` — symlinks that file to `.cursor/cli.json`
    when the repo does not already have one.
  - `devenvModule { repoNotes ? "", editors ? [".claude" ".cursor"] }` — a
    [devenv](https://devenv.sh) module that adds `but` to `packages` and runs
    the install script on `enterShell`.

## Use it in a devenv dev shell

Add the input:

```nix
inputs.but.url = "git+ssh://git@github.com/data-cartel/but.nix.git";
inputs.but.inputs.nixpkgs.follows = "nixpkgs";
```

Add the module to your `devenv.lib.mkShell` modules list, passing your repo's
hooks/conventions as `repoNotes`:

```nix
modules = [
  (but.lib.${system}.devenvModule {
    repoNotes = ''
      ## This Repository

      - **Pre-commit hooks:** `but commit` runs nixfmt, rustfmt, ...
      - **Commit messages:** conventional, lowercase — `feat:`, `fix:`, ...
      - **Branch names:** `<type>/<kebab-description>`.

    '';
  })
  # ... your other modules ...
];
```

The skill symlink is generated, so gitignore it:

```gitignore
# .claude/skills is a plain directory:
/.claude/skills/gitbutler

# or, if .claude/skills and .cursor/skills are symlinks to ai/skills:
/ai/skills/gitbutler
```

If the repo already has a `.cursor/cli.json`, merge
`but.lib.<system>.cursorPermissionAllow` into its `permissions.allow` list
instead of relying on the auto-symlink.

`repoNotes` must be the full markdown block — heading included — ending in a
blank line. Leave it out for the generic skill.

## Not using devenv?

Use the pieces directly: add `but.packages.<system>.gitbutler-cli` to your
shell's packages and run `but.lib.<system>.installSkillScript { ... }` and
`but.lib.<system>.installCursorCliScript { }` from your shell hook.

## Bumping GitButler

Edit `version`/`build` and the per-platform `hash`es in `nix/gitbutler.nix`,
then bump the flake input in each consuming repo (`nix flake update but`).
