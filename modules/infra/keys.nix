# @desc: Public SSH/GPG keys
{user, ...}: {
  flake.keys = {
    ${user.name} = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILZNRa1SOMF0p7tASJFpNYrP7IoYG4/raJegYGM8hxrqAAAACXNzaDpsaWFuYQ== 2026@yk1"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMw7e8H4N/lw+9npl/dbhTc50I8n4+737mDB0UNG0xCwAAAACXNzaDpsaWFuYQ== 2026@yk2"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIGQuyOOQP4VCHH/ynAAh9C3f9Ck8mFIu5Lk431ptmjWaAAAACXNzaDpsaWFuYQ== 2026@yk3"
    ];
    hosts.m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEVbfbtER3foygqQS+WfewJ3LaGNtc1PRossXVAIilG3";
    # nixBuilder.framework = "TODO";
    wireguard = {
      offsite = {
        offsite-1 = "TODO";
        offsite-1-unlock = "TODO";
        framework = "TODO";
        opnsense = "TODO";
      };
      home.opnsense = "10x88z88CTIbcM+q+c39BZWqzg3hb8o7Z0xzffEfuHw=";
    };
    "${user.name}Gpg" = ''

      -----BEGIN PGP PUBLIC KEY BLOCK-----

      mDMEapICQhYJKwYBBAHaRw8BAQdAoG+DdC8c+fGwRpG6fb9I5qN7zu9pVhZqrZsh
      4UomxVa0GExpYW5hIDxsaWFuYUBsaWFuYXMub3JnPoiQBBMWCgA4FiEEI0hSTgvH
      La0WOOx57uS35JlBsAkFAmqSAkICGwEFCwkIBwIGFQoJCAsCBBYCAwECHgECF4AA
      CgkQ7uS35JlBsAnKgAEA0P8qFjfudeYZ6owrI1iaOotFFgAkSUum59xt5+fKsyQB
      ALjESMMqNOGKO2sgGH2QTn/in5obcrxavsDpHflzWU8LiHUEEBYKAB0WIQTE4dO7
      L2kHCZjOGYHcA9/regpxDQUCapIYkQAKCRDcA9/regpxDZUpAQDW3viWLICMiKXf
      P5RV/3aJ/LXJ3xXRTsc4rlHxyYeKaAEA+8JatuEvC91rub4Nv9QjM6VNNBPJ5lkI
      Qa7UqJ+QIwy4MwRqkgMhFgkrBgEEAdpHDwEBB0DGzF5I84g/LKnE+C43PiLwUmhM
      r+d/AtcwmaqRSflSwIj1BBgWCgAmFiEEI0hSTgvHLa0WOOx57uS35JlBsAkFAmqS
      AyECGwIFCQPCZwAAgQkQ7uS35JlBsAl2IAQZFgoAHRYhBEy0IBcQ1LaLTTr80Fq2
      IaELwM4dBQJqkgMhAAoJEFq2IaELwM4dpVQA/1ubAm8kRFwDC8rag4w5PRn3cp4p
      lY0QeSXyZsGeeztOAQDy72gdmjt3s6Zu0X9In5IY6KUHeMeIKBNbtetIZQ+SC2Ff
      AQDdeqlEIkH/pwcdRf6/S0NU02IPR7/opMYTBY0KA4BOgAEAr92RX4R/3QitIo0N
      e6aRdhHK7OtiZ8VO+fGhWkBWUwO4OARqkgNKEgorBgEEAZdVAQUBAQdA9SxZL47h
      jx4zNtwvuIsJ7/oi1q4/A1X/+HfJIStRCW8DAQgHiH4EGBYKACYWIQQjSFJOC8ct
      rRY47Hnu5LfkmUGwCQUCapIDSgIbDAUJA8JnAAAKCRDu5LfkmUGwCfoLAQCpPGnR
      8g6bgOYDEwA6Rg7IKWNOBgHdFqphCjzDLR6wngEAn18IYip8tq9wgF/CWCzbts7T
      dmE4vFWVGXS7Z7xD+gq4MwRqkgNeFgkrBgEEAdpHDwEBB0AWgzy7/eZlqNqJbWzL
      Ud2hwijPcarlGG1amArnw+yeAYh+BBgWCgAmFiEEI0hSTgvHLa0WOOx57uS35JlB
      sAkFAmqSA14CGyAFCQPCZwAACgkQ7uS35JlBsAlCyQEAvH4m2fyO33qB4dS9+6Fr
      3e8IP9KJ5hsRjx8ynr6WoZ8BALd1tJg8CI58bVkOpeffGmWKbzDqdI8iHe38YGzE
      n7YP
      =lOD3
      -----END PGP PUBLIC KEY BLOCK-----
    '';
    maxine = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIH1DudmoKZzEukU5A0ZTc5lmFl2ZARgXwejLG0oLkIKLF8I3pMVtauKDkjd5lA5zHLZ0dsyl0GjSVNP0JMfV0su2Db8DGajjfFSHuaUc70WoMCAQfspsOlnyrjNsKaB4CQJVVVaIHgJPJglQ1yQm7uJSLawyePZ3Nh3A+sCzLnlsT6W3hLJvQcEEznYiLUrAfrs5H9PIGUe7x301BijQLtv3ZqocoeiBO2v//iCcZ07PrpUZE8boBT8v5tj9vwM0TrtQI3TKlsa2F+9BXq7pgHHLdS+LmAi5R3aLDGf5y73SUaXPCQxDmm0m2HRF2VnJF9H6yTApswBxLqvQ/KMw+6OfHJ3bRbXnhnC/n2K20P3xi083bwexbEHRG4Gd4U1qbW/2jk002R6V2AE351wsEaBfmPLM+70sgIWTWtx8FbJOYlRBhpVooaXO7aHvuyGDySPcYFAanj0NRj6bBuLa1Uou/yEXQaUb6tov/ADDWmZLF/6Wnes8hRf0ws+7XBj0= maxine@frame";
  };
}
