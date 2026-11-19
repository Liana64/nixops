# @desc: sops-nix secrets from the PQ-encrypted secretstore repo
{user, ...}: {
  flake.modules.nixos.secrets = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    # cache identity in the kernel user keyring; born in @s (possessed, so
    # setperm is allowed) then published to @u with uid-scope perms — session
    # keyrings differ per tab/launcher lineage, @u reaches them all
    editorKey = pkgs.writeShellScript "sops-editor-key" ''
      keyctl=${pkgs.keyutils}/bin/keyctl
      "$keyctl" pipe %user:sops-editor 2>/dev/null && exit
      id=$(${pkgs.age}/bin/age -d "$HOME/.config/sops/age/nix.age") || exit 1
      kid=$(printf %s "$id" | "$keyctl" padd user sops-editor @s)
      "$keyctl" setperm "$kid" 0x3f3f0000
      "$keyctl" link "$kid" @u && "$keyctl" unlink "$kid" @s
      "$keyctl" timeout "$kid" 300
      printf %s "$id"
    '';
    sopsStore = pkgs.runCommand "sops-store" {buildInputs = [pkgs.makeWrapper];} ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.sops}/bin/sops $out/bin/sops-store \
        --set-default SOPS_AGE_KEY_CMD ${editorKey}
    '';
    ageKeys = ["milberry"];
  in {
    imports = [inputs.sops-nix.nixosModules.sops];

    options.machineSecrets = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Workstation secrets beyond the login hash.";
    };

    config = {
      sops.defaultSopsFile = "${inputs.secrets}/${config.networking.hostName}.yaml";
      sops.package = inputs.sops-nix.packages.${pkgs.stdenv.hostPlatform.system}.sops-install-secrets;
      sops.age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
      sops.age.sshKeyPaths = [];
      sops.gnupg.sshKeyPaths = [];

      users.mutableUsers = false;
      users.users.${user.name}.hashedPasswordFile = config.sops.secrets."users/${user.name}/password".path;

      sops.secrets = lib.mkMerge [
        {"users/${user.name}/password".neededForUsers = true;}
        (lib.mkIf config.machineSecrets ({
            "network/wireguard/private-key" = {};
            "network/wireguard/preshared-key" = {};
            "network/wireguard/endpoint" = {};
            "network/wireguard/trusted-networks" = {
              path = "/var/secrets/wireguard/trusted-networks";
              mode = "0400";
            };
            "network/nm-secret-key" = {
              path = "/var/lib/NetworkManager/secret_key";
              mode = "0600";
              restartUnits = ["NetworkManager.service"];
            };
            "services/ai-router/gateway-key" = {
              path = "/var/secrets/eek/gateway-key";
              owner = user.name;
              mode = "0400";
            };
            "machine/syncthing/gui-passwd" = {
              path = "/var/secrets/syncthing/gui-passwd";
              owner = user.name;
              mode = "0400";
            };
          }
          // lib.genAttrs (map (k: "cryptography/age/${k}") ageKeys) (name: {
            path = "${config.users.users.${user.name}.home}/.config/sops/age/${baseNameOf name}.key";
            owner = user.name;
            mode = "0400";
          })))
      ];

      environment.systemPackages = [sopsStore];
    };
  };
}
