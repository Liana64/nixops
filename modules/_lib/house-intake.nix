# @desc: house file promotion — read-only scan, copy-only promotion into ~/<xdg user dir>, never overwriting; PDF hand-off into a viewer house
{
  pkgs,
  lib,
  hardening,
  config,
}: rec {
  dirs =
    map (lib.removePrefix "${config.home.homeDirectory}/")
    (lib.filter (d: d != null) (with config.xdg.userDirs; [download documents pictures (extraConfig.XDG_REFERENCE_DIR or null)]));

  houses = lib.attrNames (lib.filterAttrs (_: h: h.enable && h.exportDesktopEntries) (config.housing.houses or {}));

  pdfStage = "house-pdf";

  cleanName = ''
    clean() {
      printf '%s' "$1" | tr -d '\000-\037\177' |
        LC_ALL=C sed -e 's/\xe2\x80[\x8e\x8f\xa8-\xae]//g' -e 's/\xe2\x81[\xa6-\xa9]//g' -e 's/\xd8\x9c//g'
    }
  '';

  intake = pkgs.writeShellApplication {
    name = "house-intake";
    runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.gnused pkgs.util-linux];
    text = ''
      mode=$1
      house=$2
      src=$HOME/houses/$house
      state=''${XDG_STATE_HOME:-$HOME/.local/state}/house-intake/$house
      ledger=$state/ledger
      dirs=(${lib.escapeShellArgs dirs})
      failed=0

      real() {
        [ -d "$src/$1" ] && [ ! -L "$src/$1" ] && cd -P -- "$src/$1" && [ "$(pwd -P)" = "$src/$1" ]
      }

      ${cleanName}

      promote() {
        local f=$1 dst=$2 name base ext t tmp i=1
        name=$(clean "''${f#./}")
        [ -n "$name" ] || name=unnamed
        base=''${name%.*}
        ext=''${name:''${#base}}
        [ -n "$base" ] || { base=$name; ext=; }
        t=$dst/$name
        tmp=$(mktemp -p "$dst" .intake.XXXXXX) || return 1
        if ! cp -P --reflink=always --remove-destination -- "$f" "$tmp" || [ -L "$tmp" ] || [ ! -f "$tmp" ]; then
          rm -f -- "$tmp"
          return 1
        fi
        chmod 0600 -- "$tmp"
        until mv --update=none-fail -T -- "$tmp" "$t" 2>/dev/null; do
          i=$((i + 1))
          [ "$i" -le 999 ] || { rm -f -- "$tmp"; return 1; }
          t="$dst/$base ($i)$ext"
        done
      }

      case $mode in
      paths)
        for p in "$src" "$state"; do
          [ -d "$p" ] && printf '%s\n' "$p"
        done
        for d in "''${dirs[@]}"; do
          real "$d" && printf '%s\n' "$src/$d"
        done
        exit 0
        ;;
      list) ;;
      promote | dismiss)
        exec 9>>"$state/lock"
        flock 9
        ;;
      *) exit 64 ;;
      esac

      declare -A seen=() keep=()
      if [ -f "$ledger" ]; then
        while IFS= read -r k; do
          [ -n "$k" ] && seen[$k]=1
        done <"$ledger"
      fi
      scanned=" "

      for d in "''${dirs[@]}"; do
        real "$d" || continue
        scanned+="$d "
        while IFS= read -r -d "" key && IFS= read -r -d "" f; do
          key="$d $key"
          if [ -n "''${seen[$key]:-}" ]; then
            keep[$key]=1
            continue
          fi
          case $mode in
          list) printf 'pending\t%s/%s\n' "$d" "$(clean "''${f#./}")" ;;
          promote) promote "$f" "$HOME/$d" && keep[$key]=1 || failed=1 ;;
          dismiss) keep[$key]=1 ;;
          esac
        done < <(find . -mindepth 1 -maxdepth 1 -type f -links 1 ! -name '.*' ! -name '*.part' ! -name '*.crdownload' -printf '%i %s %T@\0%p\0')
        if [ "$mode" = list ]; then
          printf 'skipped\t%s\n' "$(find . -mindepth 1 -maxdepth 1 ! -name '.*' ! -name '*.part' ! -name '*.crdownload' \( ! -type f -o -links +1 \) -printf . | wc -c)"
        fi
      done

      [ "$mode" != list ] || exit 0
      {
        for k in "''${!keep[@]}"; do
          printf '%s\n' "$k"
        done
        for k in "''${!seen[@]}"; do
          case $scanned in *" ''${k%% *} "*) ;; *) printf '%s\n' "$k" ;; esac
        done
      } >"$ledger.tmp"
      mv -f -T -- "$ledger.tmp" "$ledger"
      exit "$failed"
    '';
  };

  service = {
    mode,
    home ? "%h",
    state ? "%S",
    house ? "%i",
  }:
    hardening.airgapped
    // {
      Type = "oneshot";
      ExecStart = "${lib.getExe intake} ${mode} ${house}";
      Environment = "XDG_STATE_HOME=${state}";
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = "-${home}/houses/${house}";
      BindPaths = ["${state}/house-intake/${house}"] ++ lib.optionals (mode == "promote") (map (d: "${home}/${d}") dirs);
    };

  openPdf = {
    name,
    launch,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.libnotify];
      text = ''
        ${cleanName}

        fail() {
          notify-send -a ${lib.escapeShellArg name} "PDF not opened" "$1"
          exit 1
        }

        [ "$#" -eq 1 ] || fail "expected one file"
        [ -f "$1" ] && [ -r "$1" ] || fail "not a readable file"
        exec 3<"$1"
        fd=/proc/$$/fd/3
        [ -f "$fd" ] || fail "not a regular file"
        grep -qa -m1 -- '%PDF-' < <(head -c 1024 "$fd") || fail "not a PDF"

        stage=''${XDG_RUNTIME_DIR:?}/${pdfStage}
        mkdir -m 0700 "$stage" 2>/dev/null || [ -d "$stage" ]
        find "$stage" -mindepth 1 -maxdepth 1 -type d -mmin +720 -exec rm -rf -- {} +
        dir=$(mktemp -d -p "$stage")
        base=$(clean "$(basename -- "$1")")
        case $base in "" | .*) base=document ;; esac
        case $base in *.[Pp][Dd][Ff]) ;; *) base=$base.pdf ;; esac
        cp -- "$fd" "$dir/$base" || fail "copy failed"
        chmod 0400 -- "$dir/$base"
        exec ${launch} "$dir/$base"
      '';
    };

  houseOpen = {
    name,
    launch,
    dirs,
    drop,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.gnused pkgs.libnotify];
      text = ''
        ${cleanName}

        args=()
        for f; do
          real=$(realpath -e -- "$f") && [ -f "$real" ] || {
            notify-send -a ${lib.escapeShellArg name} "Not opened" "$f"
            continue
          }
          case $real in
          ${lib.concatMapStringsSep " | " (d: "${lib.escapeShellArg d}/*") dirs}) args+=("$real") ;;
          *)
            base=$(clean "$(basename -- "$real")")
            case $base in "" | .*) base=document ;; esac
            stem=''${base%.*}
            ext=''${base:''${#stem}}
            t=${lib.escapeShellArg drop}/$base
            i=1
            while [ -e "$t" ]; do
              i=$((i + 1))
              t=${lib.escapeShellArg drop}/"$stem ($i)$ext"
            done
            cp -n -- "$real" "$t" || continue
            notify-send -a ${lib.escapeShellArg name} "Copied to Shared drop" "$(basename -- "$t")"
            args+=("$t")
            ;;
          esac
        done
        [ "''${#args[@]}" -gt 0 ] || exit 1
        exec ${launch} "''${args[@]}"
      '';
    };
}
