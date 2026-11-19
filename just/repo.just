# Eval nixos configs
[group('repo')]
verify host='':
    #!/usr/bin/env sh
    untracked=$(git -C {{ nixops_path }} ls-files --others --exclude-standard -- '*.nix')
    [ -n "$untracked" ] && printf 'untracked .nix (git add before trusting results):\n%s\n' "$untracked"
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    for kind in nixos home; do
      nix eval --json "{{ nixops_path }}#${kind}Configurations" --apply builtins.attrNames \
        | jq -r --arg k "$kind" --arg h {{ quote(host) }} '.[] | select($h == "" or . == $h or endswith("@" + $h)) | "\($k) \(.)"'
    done | nl -w2 -nrz -s' ' | xargs -r -P4 -L1 sh -c '
      case $2 in
        nixos) attr="nixosConfigurations.\"$3\".config.system.build.toplevel.drvPath" ;;
        home) attr="homeConfigurations.\"$3\".activationPackage.drvPath" ;;
      esac
      if err=$(nix eval "{{ nixops_path }}#$attr" 2>&1 >/dev/null); then echo "$3 ✓"
      else touch "$0/failed"; printf "%s ✗\n%s\n" "$3" "$(printf "%s\n" "$err" | tail -n 20)"; fi >"$0/$1"
    ' "$tmp"
    set -- "$tmp"/[0-9]*
    [ -e "$1" ] || { echo "no config for '{{ host }}'" >&2; exit 1; }
    [ -e "$tmp/failed" ] && { cat "$tmp"/[0-9]*; exit 1; }
    echo 'all configs ✓'

# Format nix files
[group('repo')]
fmt +files:
    nix fmt -- {{ files }}

# Verify, format check, build flake checks
[group('repo')]
check: verify
    nix fmt -- --check {{ nixops_path }}
    nix eval --json {{ nixops_path }}#checks.{{ system }} --apply builtins.attrNames \
      | jq -r '.[] | "{{ nixops_path }}#checks.{{ system }}.\(.)"' | xargs -r nix build --no-link

# Diff flake.lock inputs against base (index by default); fails on unsigned or rewound git inputs
[group('repo')]
lock-review base=":":
    #!/usr/bin/env sh
    set -o pipefail
    cd {{ nixops_path }}
    fpr=$(git config user.signingkey)
    cache=${XDG_CACHE_HOME:-$HOME/.cache}/nix/gitv3
    red= off=
    { [ -t 1 ] || [ -n "${CLICOLOR_FORCE-}" ]; } && [ -z "${NO_COLOR-}" ] && red=$(printf '\033[31m') off=$(printf '\033[0m')
    git show "{{ base }}flake.lock" | jq -r --slurpfile new flake.lock '
      .nodes as $old | $new[0].nodes | keys[] as $k
      | .[$k].locked as $n | ($old[$k].locked // {}) as $o
      | select($n.rev != null and $n.rev != $o.rev)
      | [$k, $n.type, $n.url // "-", $o.rev // "-", $n.rev] | @tsv' | {
    bad=
    while IFS="$(printf '\t')" read -r name type url old new; do
      printf '%s %.12s → %.12s\n' "$name" "$old" "$new"
      [ "$type" = git ] || continue
      repo=$cache/$(nix hash convert --hash-algo sha256 --to nix32 "$(printf %s "$url" | sha256sum | cut -d' ' -f1)")
      range="$old..$new"; [ "$old" = - ] && range="-1 $new"
      if ! { git -C "$repo" cat-file -e "$new^{commit}" && { [ "$old" = - ] || git -C "$repo" cat-file -e "$old^{commit}"; }; } 2>/dev/null; then
        echo "  ${red}NOT IN NIX GIT CACHE: cannot verify; fetch as $(id -un) with: frame update $name${off}"; bad=1
      elif [ "$old" != - ] && ! git -C "$repo" merge-base --is-ancestor "$old" "$new"; then
        echo "  ${red}NOT A DESCENDANT: history rewound or force-pushed${off}"; bad=1
      else
        git -C "$repo" log --format='%G?%x09%GP%x09%h %an %s' $range | awk -F'\t' -v f="$fpr" -v r="$red" -v o="$off" '
          { ok = f != "" && $1 == "G" && $2 == f; print (ok ? "  ok  " $3 : r "  BAD " $1 " " $3 o) }
          !ok { bad = 1 } END { exit bad }' || bad=1
      fi
    done
    [ -z "$bad" ]
    }

# Update flake input(s)
[group('repo')]
update *inputs:
    nix flake update --flake {{ nixops_path }} {{ inputs }}
