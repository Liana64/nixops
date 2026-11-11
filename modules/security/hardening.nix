# @desc: Kernel hardening: shared baseline + desktop extras
{...}: {
  flake.modules.nixos.hardening = {
    config,
    lib,
    ...
  }: let
    inherit (config.hardening) lockdown;
  in {
    options.hardening.lockdown = lib.mkOption {
      type = lib.types.enum ["none" "integrity" "confidentiality"];
      default = "integrity";
    };

    config = {
      security = {
        polkit.enable = true;
        protectKernelImage = true;
      };

      boot.kernelParams =
        [
          "debugfs=off"
          "randomize_kstack_offset=on"
          "vsyscall=none"
          "proc_mem.force_override=ptrace"
        ]
        ++ lib.optional (lockdown != "none") "lockdown=${lockdown}";

      boot.blacklistedKernelModules = [
        # Obscure network protocols
        "ax25"
        "netrom"
        "rose"

        # Old or rare or insufficiently audited filesystems
        "adfs"
        "affs"
        "bfs"
        "befs"
        "cramfs"
        "efs"
        "erofs"
        "exofs"
        "freevxfs"
        "f2fs"
        "hfs"
        "hpfs"
        "jfs"
        "minix"
        "nilfs2"
        "ntfs"
        "omfs"
        "qnx4"
        "qnx6"
        "sysv"
        "ufs"
      ];

      boot.kernel.sysctl = {
        # Kernel info leaks
        "kernel.kptr_restrict" = 2;
        "kernel.dmesg_restrict" = 1;
        "kernel.printk" = "3 3 3 3";
        "kernel.yama.ptrace_scope" = 2;
        "kernel.kexec_load_disabled" = 1;
        "kernel.sysrq" = 4;

        # Network
        "net.ipv4.tcp_syncookies" = true;
        "net.ipv4.tcp_rfc1337" = true;
        "net.ipv4.conf.all.accept_redirects" = false;
        "net.ipv4.conf.all.secure_redirects" = false;
        "net.ipv4.conf.all.send_redirects" = false;
        "net.ipv4.conf.all.accept_source_route" = false;
        "net.ipv4.conf.default.accept_redirects" = false;
        "net.ipv4.conf.default.secure_redirects" = false;
        "net.ipv4.conf.default.send_redirects" = false;
        "net.ipv4.conf.default.accept_source_route" = false;

        "net.ipv6.conf.all.accept_redirects" = false;
        "net.ipv6.conf.all.accept_source_route" = false;
        "net.ipv6.conf.default.accept_redirects" = false;
        "net.ipv6.conf.default.accept_source_route" = false;

        "net.ipv4.icmp_echo_ignore_broadcasts" = true;

        # Filesystem
        "fs.protected_hardlinks" = 1;
        "fs.protected_symlinks" = 1;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;
        "fs.suid_dumpable" = 0;
      };
    };
  };

  flake.modules.nixos.hardeningWorkstation = {...}: {
    security.rtkit.enable = true;

    boot.kernelParams = [
      "slab_nomerge"
      "init_on_alloc=1"
      "init_on_free=1"
      "page_alloc.shuffle=1"
      "ia32_emulation=0"
    ];

    boot.kernel.sysctl = {
      "net.core.bpf_jit_harden" = 2;
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.ipv4.conf.all.log_martians" = true;
      "net.ipv4.conf.all.rp_filter" = true;
      "net.ipv4.conf.default.log_martians" = true;
      "net.ipv4.conf.default.rp_filter" = true;
    };
  };
}
