_nh verb host:
    #!/usr/bin/env sh
    set -e
    h={{ host }}
    b=
    read -r sys cache <<EOF
    $(nix eval --raw "{{ nixops_path }}#nixosConfigurations.${h:-$(hostname)}.config" --apply 'c: "${c.nixpkgs.hostPlatform.system} ${toString c.nix.settings.extra-substituters}"')
    EOF
    [ "$sys" = x86_64-linux ] && b={{ m1 }}
    [ -z "$h" ] && [ -n "$b" ] && ! curl -sfm 2 -o /dev/null "$cache/nix-cache-info" && b= && echo "nix-cache unreachable, building locally" >&2
    set -- {{ nixops_path }} --diff always
    [ -n "$h" ] && set -- "$@" -H "$h" --target-host "{{ user }}@$h.{{ mgmt }}" && b=${b:-{{ user }}@$h.{{ mgmt }}}
    [ -n "$b" ] && set -- "$@" --build-host "$b" --use-substitutes
    set -- nh os {{ verb }} "$@"
    command -v rebuild-track >/dev/null && set -- rebuild-track "${h:-$(hostname)} {{ verb }}" "$@"
    exec "$@"

_lock-check:
    #!/usr/bin/env sh
    j="{{ just_executable() }} -f {{ justfile() }}"
    tty= red= off=
    [ -t 1 ] && tty=1
    [ -t 2 ] && [ -z "${NO_COLOR-}" ] && red=$(printf '\033[31m') off=$(printf '\033[0m')
    out=$(CLICOLOR_FORCE=$tty $j lock-review HEAD:) || { printf '%s\n' "$out"; echo "${red}flake.lock: git input failed verification${off}" >&2; exit 1; }
    git -C {{ nixops_path }} diff --quiet -- flake.lock && exit 0
    $j lock-review
    echo "${red}flake.lock has unreviewed changes: review, then git add flake.lock${off}" >&2
    exit 1

# Build and diff, local or remote
[group('deploy')]
build host='': (_nh "build" host)

# Build and switch, local or remote
[group('deploy')]
switch host='': _lock-check (_nh "switch" host)

# Build host's system and disko script on m1, pushing both to the cache
[group('deploy')]
prebuild host:
    #!/usr/bin/env sh
    set -e
    f={{ nixops_path }}#nixosConfigurations.{{ host }}
    [ "$(nix eval --raw "$f.config.nixpkgs.hostPlatform.system")" = x86_64-linux ] || exit 0
    nix build --no-link --eval-store auto --store ssh-ng://{{ m1 }} "$f.config.system.build.toplevel" "$f.config.system.build.diskoScript"

# Wipe and install host with the cwd included as --extra-files
[confirm("wipe + install now?")]
[group('deploy')]
install host ip *args: _lock-check (prebuild host)
    #!/usr/bin/env sh
    set -eu
    d={{ invocation_directory() }}
    die() { echo "$*" >&2; exit 1; }
    k=$d/var/lib/sops-nix/key.txt
    [ -f "$k" ] || die "missing $k"
    c=
    set -- {{ args }}
    for a do shift; [ "$a" = --check ] && c=1 || set -- "$@" "$a"; done
    if [ -n "$c" ]; then
        f=$(nix eval --raw {{ nixops_path }}#nixosConfigurations.{{ host }}.config.sops.defaultSopsFile)
        h=$(env -i PATH="$PATH" HOME="$d" SOPS_AGE_KEY_FILE="$k" sops -d --extract '["users"]["{{ user }}"]["password"]' "$f" 2>/dev/null) \
            || die "key.txt cannot decrypt $f"
        trap 'stty echo' EXIT
        stty -echo
        printf '{{ user }}@{{ host }} password: '
        read -r p
        stty echo
        echo
        [ "$(printf %s "$p" | mkpasswd -s -S "$h" 2>/dev/null)" = "$h" ] || die "password does not match $f"
    fi
    nix run nixpkgs#nixos-anywhere -- --flake {{ nixops_path }}#{{ host }} --build-on remote --extra-files "$d" "$@" root@{{ ip }}
