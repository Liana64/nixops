# @desc: Shell aliases (rust-tool replacements)
{user, ...}: {
  flake.modules.homeManager.aliases = {
    config,
    lib,
    osConfig,
    flakePath,
    ...
  }: let
    software = "${config.home.homeDirectory}/Projects/Software";
    drafts = "${software}/drafts";
    mirrors = "/mnt/m1/shared/Mirrors";
    edit = dir: "cd ${dir} && hx .";
    ceremony = "d=$(mktemp -d /run/user/$UID/ceremony.XXX) && cd \"$d\"";
    city = lib.last (lib.splitString "/" (osConfig.time.timeZone or ""));

    editors = {
      vi = "hx";
      vim = "hx";
      n = "hx";
    };

    ls = {
      l = "eza -la --git --group-directories-first";
      ll = "eza -la --git --group-directories-first";
      ls = "eza";
      l1 = "eza -1";
    };

    grep = {
      ug = "rg";
      grep = "rg";
      egrep = "rg -E";
      fgrep = "rg -F";
      xzgrep = "rg -z";
      xzegrep = "rg -zE";
      xzfgrep = "rg -zF";
    };

    personal = {
      f = "frame";
      k = "kubectl";
      inherit ceremony;
      ceremony-age = "${ceremony} && mkdir -p var/lib/sops-nix && age-keygen -pq -o var/lib/sops-nix/key.txt";
      ops = edit flakePath;
      docs = edit "${software}/docs";
      drafts = edit drafts;
      notes = edit "${drafts}/notes";
      projects = edit "${drafts}/projects";
      clip = "wl-copy";
      myip = "curl ifconfig.me -j";
      weather = "curl wttr.in/${city}";
    };

    ai = {
      haiku = "claude --model haiku --effort high";
      sonnet = "claude --model sonnet --effort high";
      opus = "claude --model opus";
      opusm = "claude --model opus --effort medium";
      fable = "claude --model fable";
      fablex = "claude --model fable --effort xhigh";
      resume = "claude --resume";
      cont = "claude --continue";
    };

    containers = {
      claw = "kubectl exec -it deploy/claude-clode -- claude";
      blog = "kubectl rollout restart deployment blog -n default";
    };

    rust-tools = {
      tree = "eza --tree";

      # This makes cat require "cat -p" for standard output, otherwise it gets piped to less
      cat = "bat";
      catp = "bat -p";

      df = "duf";
      diff = "difft";
      du = "dust";

      top = "btop";
      htop = "btop";

      rustscan = "rustscan --no-banner";
    };

    networking = {
      fastping = "ping -c 100 -i 0.2";
      ports = "ss -tunapl";
      listening = "ss -tlnp";
      netstat = "ss";
      webmirror = "wget -m -np --no-if-modified-since -w 0.5 -P ${mirrors}";
    };

    utility = {
      bc = "numbat";
      h = "history";
      j = "jobs -l";
      uu = "uuidgen -r | tr '[:lower:]' '[:upper:]'";
    };

    crypto = {
      gpg-encrypt = "gpg -c --no-symkey-cache --cipher-algo=AES256";
      gpg-decrypt = "gpg -d";
      sign = "gpg -esa --default-recipient-self --comment \"Sealed by ${user.email}\"";
      rotate-sops = "for f in *.yaml; do sops-store updatekeys \"$f\"; done";
    };

    git = {
      g = "git";
      gl = "git pull";
      gd = "git diff";
      lg = "lazygit";
    };

    darwin = {
      flushdns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
    };

    aliases = editors // ls // grep // personal // ai // containers // rust-tools // networking // utility // crypto // git // darwin;

    randomFn = ''
      random() {
        local set='A-Za-z0-9_\055'
        head -c "''${1:-32}" /dev/urandom | LC_ALL=C tr '\0-\377' "$set$set$set$set"
        echo
      }
    '';

    statusFn = ''
      status() {
        kubectl create configmap blog-status -n default \
          --from-literal=now.txt="''${*:+now: $*}" \
          --dry-run=client -o yaml | kubectl apply -n default -f -
      }
    '';

    shellFns = randomFn + statusFn;

    nuShadowedBuiltins = ["ls" "du"];
    nuZshBound = ["j" "ops"];
    nuAliases =
      lib.filterAttrs (
        name: value:
          !(lib.elem name (nuShadowedBuiltins ++ nuZshBound))
          && builtins.match ".*[|;$].*" value == null
      )
      aliases
      // {
        l = "ls";
        ll = "ls -l";
      };

    helpText = lib.concatStringsSep "\\n" (
      lib.mapAttrsToList (name: value: "  ${name} = ${value}") aliases
    );
  in {
    programs.bash.shellAliases = aliases // {aliases = "echo -e '${helpText}'";};
    programs.zsh.shellAliases = aliases // {aliases = "echo -e '${helpText}'";};
    programs.bash.initExtra = shellFns;
    programs.zsh.initContent = shellFns;
    programs.nushell.shellAliases = nuAliases;
  };
}
