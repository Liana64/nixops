# @desc: Firefox
{user, ...}: {
  flake.modules.homeManager.firefox = {
    inputs,
    pkgs,
    lib,
    config,
    colors,
    ...
  }: let
    inherit (config.firefox) role;

    # D-Bus remoting is keyed on profile name; distinct names keep houses from handing URLs to each other.
    profile =
      if role == "secure"
      then user.name
      else role;

    search =
      if role == "ephemeral"
      then "ddg"
      else "kagi";

    platforms = [
      "google.com"
      "youtube.com"
      "youtu.be"
      "facebook.com"
      "instagram.com"
      "whatsapp.com"
      "messenger.com"
      "threads.com"
      "microsoftonline.com"
      "live.com"
      "office.com"
      "microsoft365.com"
      "teams.microsoft.com"
      "outlook.com"
      "sharepoint.com"
      "linkedin.com"
      "amazon.com"
      "zoom.us"
      "zoom.com"
    ];

    trustedSites = [];

    roleSettings = {
      secure = {
        "permissions.default.camera" = 2;
        "permissions.default.microphone" = 2;
        "media.eme.enabled" = false;
        "media.peerconnection.enabled" = false;
      };
      public = {
        "permissions.default.desktop-notification" = 0;
        "media.eme.enabled" = true;
      };
      ephemeral = {
        "browser.startup.homepage" = "about:blank";
        "browser.privatebrowsing.autostart" = true;
        "media.eme.enabled" = false;
        "media.peerconnection.enabled" = false;
        "media.navigator.enabled" = false;
        "network.manage-offline-status" = false;

        # Fingerprinting
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.letterboxing" = true;
        "privacy.resistFingerprinting.block_mozAddonManager" = true;
        "privacy.spoof_english" = 2;
        "webgl.disabled" = true;
        "dom.webgpu.enabled" = false;
        "dom.gamepad.enabled" = false;
        "device.sensors.enabled" = false;
        "beacon.enabled" = false;

        # Exploit surface
        "javascript.options.ion" = false;
        "javascript.options.baselinejit" = false;
        "javascript.options.wasm" = false;
        "security.OCSP.require" = true;
        "security.cert_pinning.enforcement_level" = 2;
        "security.ssl.require_safe_negotiation" = true;
      };
    };

    ublock = pkgs.fetchurl {
      url = "https://github.com/gorhill/uBlock/releases/download/1.75.0/uBlock0_1.75.0.firefox.signed.xpi";
      hash = "sha256-W3RBWGBFY3BkS9gPFhJehlsObDVrtd/PuEBpln6qUoc=";
    };

    # medium mode on top of the stock rules, which adminSettings replaces wholesale
    ublockMediumMode = lib.concatStringsSep "\n" [
      "behind-the-scene * * noop"
      "behind-the-scene * image noop"
      "behind-the-scene * 3p noop"
      "behind-the-scene * inline-script noop"
      "behind-the-scene * 1p-script noop"
      "behind-the-scene * 3p-script noop"
      "behind-the-scene * 3p-frame noop"
      "* * 3p-script block"
      "* * 3p-frame block"
    ];
  in {
    options.firefox = {
      role = lib.mkOption {
        type = lib.types.enum ["secure" "public" "ephemeral"];
        default = "secure";
      };
      portalFilePicker = lib.mkEnableOption "the portal file chooser";
    };

    config.programs.firefox = {
      enable = true;
      package = let
        pkgsFirefox = inputs.nixpkgs-firefox.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
        (pkgsFirefox.wrapFirefox.override {udev = import ../_lib/udev-chase.nix pkgsFirefox;}) pkgsFirefox.firefox-unwrapped {};
      # nixpkgs firefox sets MOZ_LEGACY_PROFILES, so it reads ~/.mozilla/firefox.
      # stateVersion 26.05 would otherwise default this to the XDG path the browser ignores.
      configPath = ".mozilla/firefox";
      policies = {
        "3rdparty".Extensions."uBlock0@raymondhill.net" = {
          userSettings = [
            ["advancedUserEnabled" "true"]
            ["uiTheme" "dark"]
            ["popupPanelSections" "31"]
          ];
          toAdd.trustedSiteDirectives = trustedSites;
          adminSettings = lib.mkIf (role == "ephemeral") {dynamicFilteringString = ublockMediumMode;};
        };
        ExtensionSettings = lib.mkIf (role == "ephemeral") {
          "uBlock0@raymondhill.net" = {
            installation_mode = "force_installed";
            install_url = "file://${ublock}";
            private_browsing = true;
          };
        };
        WebsiteFilter = lib.mkIf (role == "secure") {
          # Block = map (domain: "*://*.${domain}/*") platforms;
          Exceptions = ["*://www.google.com/recaptcha/*"];
        };
      };
      profiles.${profile} = {
        search = {
          force = true;
          default = search;
          privateDefault = search;
          order = [search];
          engines = {
            kagi = {
              name = "Kagi";
              urls = [{template = "https://kagi.com/search?q={searchTerms}";}];
              icon = "https://kagi.com/favicon.ico";
            };
            github = {
              name = "GitHub";
              urls = [{template = "https://github.com/search?q={searchTerms}&type=repositories";}];
              icon = "https://github.com/favicon.ico";
              definedAliases = ["@gh"];
            };
            flathub = {
              name = "Flathub";
              urls = [{template = "https://flathub.org/en/apps/search?q={searchTerms}";}];
              icon = "https://dl.flathub.org/assets/_next/public/favicon.svg";
              definedAliases = ["@fh"];
            };
            kubesearch = {
              name = "Kubesearch";
              urls = [{template = "https://kubesearch.dev/#{searchTerms}";}];
              definedAliases = ["@ku"];
            };
            nixpkgs = {
              name = "Nix Packages";
              urls = [{template = "https://search.nixos.org/packages?query={searchTerms}";}];
              icon = "https://nixos.org/favicon.ico";
              definedAliases = ["@nx"];
            };
            nixoptions = {
              name = "Nix Options";
              urls = [{template = "https://search.nixos.org/options?channel=26.05&query={searchTerms}";}];
              icon = "https://nixos.org/favicon.ico";
              definedAliases = ["@no"];
            };
            opensecrets = {
              name = "Open Secrets";
              urls = [{template = "https://www.opensecrets.org/search?q={searchTerms}";}];
              definedAliases = ["@os"];
            };
            "123ATC" = {
              name = "123ATC";
              urls = [{template = "https://123atc.com/facility/{searchTerms}";}];
              definedAliases = ["@123"];
            };
            intel = {
              name = "Intel ARK";
              urls = [{template = "https://www.intel.com/content/www/us/en/search.html#q={searchTerms}&cf-tabfilter=Products";}];
              definedAliases = ["@it"];
            };
            amd = {
              name = "AMD";
              urls = [{template = "https://www.amd.com/en/search/site-search.html#q={searchTerms}";}];
              definedAliases = ["@am"];
            };
            rhel-10 = {
              name = "RHEL 10";
              urls = [{template = "https://docs.redhat.com/search/?p=1&rows=10&documentKind=Documentation&src=scoped&q={searchTerms}&product=Red+Hat+Enterprise+Linux&documentation_version=%26Red+Hat+Enterprise+Linux%2610";}];
              definedAliases = ["@rh10"];
            };
            rhel-09 = {
              name = "RHEL 9";
              urls = [{template = "https://docs.redhat.com/search/?p=1&rows=10&documentKind=Documentation&src=scoped&q={searchTerms}&product=Red+Hat+Enterprise+Linux&documentation_version=%26Red+Hat+Enterprise+Linux%269";}];
              definedAliases = ["@rh9"];
            };
            rhel-08 = {
              name = "RHEL 8";
              urls = [{template = "https://docs.redhat.com/search/?p=1&rows=10&documentKind=Documentation&src=scoped&q={searchTerms}&product=Red+Hat+Enterprise+Linux&documentation_version=%26Red+Hat+Enterprise+Linux%268";}];
              definedAliases = ["@rh8"];
            };
            rfc = {
              name = "RFC";
              urls = [{template = "https://www.rfc-editor.org/search/?q={searchTerms}";}];
              definedAliases = ["@rfc"];
            };
            protondb = {
              name = "ProtonDB";
              urls = [{template = "https://www.protondb.com/search?q={searchTerms}";}];
              definedAliases = ["@pr"];
            };
            bing.metaData.hidden = true;
          };
        };
        #bookmarks = {};
        settings =
          {
            # Required for sidebery customization
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

            # General settings
            "browser.startup.homepage" = "bookmarks.labs.lianas.org";
            "browser.aboutConfig.showWarning" = false;

            # Disable firefox init
            "browser.disableResetPrompt" = true;
            "browser.download.panel.shown" = true;
            "browser.feeds.showFirstRunUI" = false;
            "browser.messaging-system.whatsNewPanel.enabled" = false;
            "browser.rights.3.shown" = true;
            "browser.shell.checkDefaultBrowser" = false;
            "browser.shell.defaultBrowserCheckCount" = 1;
            "browser.startup.homepage_override.mstone" = "ignore";
            "browser.uitour.enabled" = false;
            "startup.homepage_override_url" = "";
            "trailhead.firstrun.didSeeAboutWelcome" = true;
            "browser.bookmarks.restore_default_bookmarks" = false;
            "browser.bookmarks.addedImportButton" = true;

            "browser.download.useDownloadDir" = false;

            # Disable home activity stream page
            "browser.newtabpage.activity-stream.feeds.topsites" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
            "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts" = false;
            "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
            "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
            "browser.newtabpage.activity-stream.showWeather" = false;

            # Disable telemetry
            "app.shield.optoutstudies.enabled" = false;
            "browser.discovery.enabled" = false;
            "browser.urlbar.suggest.quicksuggest.all" = false;
            "browser.urlbar.suggest.quicksuggest.sponsored" = false;
            "browser.newtabpage.activity-stream.feeds.telemetry" = false;
            "browser.newtabpage.activity-stream.telemetry" = false;
            "browser.ping-centre.telemetry" = false;
            "datareporting.healthreport.service.enabled" = false;
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            "datareporting.sessions.current.clean" = true;
            "devtools.onboarding.telemetry.logged" = false;
            "toolkit.telemetry.archive.enabled" = false;
            "toolkit.telemetry.bhrPing.enabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.firstShutdownPing.enabled" = false;
            "toolkit.telemetry.hybridContent.enabled" = false;
            "toolkit.telemetry.newProfilePing.enabled" = false;
            "toolkit.telemetry.prompted" = 2;
            "toolkit.telemetry.rejected" = true;
            "toolkit.telemetry.reportingpolicy.firstRun" = false;
            "toolkit.telemetry.server" = "";
            "toolkit.telemetry.shutdownPingSender.enabled" = false;
            "toolkit.telemetry.unified" = false;
            "toolkit.telemetry.unifiedIsOptIn" = false;
            "toolkit.telemetry.updatePing.enabled" = false;

            # Disable fx accounts
            "identity.fxaccounts.enabled" = false;

            # Harden
            "privacy.trackingprotection.enabled" = true;
            "dom.security.https_only_mode" = true;
            "signon.rememberSignons" = false;
            "signon.autofillForms" = false;
            "signon.generation.enabled" = false;
            "signon.management.page.breach-alerts.enabled" = false;
            "extensions.formautofill.addresses.enabled" = false;
            "extensions.formautofill.creditCards.enabled" = false;
            "extensions.formautofill.available" = "off";
            "browser.contentblocking.category" = "strict";
            "privacy.fingerprintingProtection" = true;
            "privacy.globalprivacycontrol.enabled" = true;
            "privacy.query_stripping.strip_on_share.enabled" = true;
            "privacy.userContext.enabled" = true;
            "privacy.userContext.ui.enabled" = true;
            "network.http.referer.XOriginTrimmingPolicy" = 2;
            "network.auth.subresource-http-auth-allow" = 1;
            "network.IDN_show_punycode" = true;
            "browser.xul.error_pages.expert_bad_cert" = true;
            "pdfjs.enableScripting" = false;
            "browser.download.start_downloads_in_tmp_dir" = true;
            "browser.download.manager.addToRecentDocs" = false;
            "security.tls.enable_0rtt_data" = false;
            "network.trr.mode" = 5;
            "network.dns.disablePrefetch" = true;
            "network.prefetch-next" = false;
            "network.predictor.enabled" = false;
            "network.http.speculative-parallel-limit" = 0;
            "browser.urlbar.speculativeConnect.enabled" = false;
            "media.peerconnection.ice.default_address_only" = true;
            "app.normandy.enabled" = false;
            "app.normandy.api_url" = "";
            "breakpad.reportURL" = "";
            "browser.tabs.crashReporting.sendReport" = false;
            "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
            "network.captive-portal-service.enabled" = false;
            "network.connectivity-service.enabled" = false;
            "captivedetect.canonicalURL" = "";
            "browser.safebrowsing.downloads.remote.enabled" = false;
            "dom.private-attribution.submission.enabled" = false;
            "extensions.pocket.enabled" = false;
            "browser.ml.enable" = false;
            "browser.ml.chat.enabled" = false;
            "browser.urlbar.quicksuggest.enabled" = false;
            "browser.formfill.enable" = false;
            "extensions.getAddons.showPane" = false;
            "extensions.htmlaboutaddons.recommendations.enabled" = false;
            "permissions.default.geo" = 2;
            "permissions.default.desktop-notification" = 2;
            "permissions.default.xr" = 2;
            "dom.vr.enabled" = false;
            "media.autoplay.default" = 5;

            # Remove close button
            "browser.tabs.inTitlebar" = 0;

            # Smooth scrolling
            "general.smoothScroll" = true;
            "general.smoothScroll.msdPhysics.enabled" = true;
            "mousewheel.min_line_scroll_amount" = 30;

            # Enable GPU acceleration
            "gfx.webrender.all" = true;
            "media.ffmpeg.vaapi.enabled" = true;
            "widget.dmabuf.force-enabled" = true;

            # Reduce iGPU usage
            "ui.prefersReducedMotion" = 1;

            # Follow compositor vsync, i.e. the sway output mode
            "layout.frame_rate" = -1;

            # default 0.002
            "apz.fling_friction" = "0.003";

            # default 0.5
            "apz.fling_min_velocity_threshold" = "1.0";

            # Vertical tabs
            "sidebar.verticalTabs" = true;
            "sidebar.revamp" = true;
            "sidebar.main.tools" = "history,bookmarks";

            # Wayland popup/menu fixes
            "widget.wayland.use-move-to-rect" = true;
            "widget.gtk.ignore-bogus-leave-notify" = 1;
            "widget.use-xdg-desktop-portal.file-picker" =
              if config.firefox.portalFilePicker
              then 1
              else 0;
            "widget.use-xdg-desktop-portal.mime-handler" = 0;
          }
          // roleSettings.${role};
        #restrictedDomainsList = [
        #  "accounts-static.cdn.mozilla.net"
        #  "accounts.firefox.com"
        #  "addons.cdn.mozilla.net"
        #  "addons.mozilla.org"
        #  "api.accounts.firefox.com"
        #  "beta.foldingathome.org"
        #  "cloud.tenjin-dk.com"
        #  "content.cdn.mozilla.net"
        #  "discovery.addons.mozilla.org"
        #  "install.mozilla.org"
        #  "media.tenjin-dk.com"
        #  "media.tenjin.com"
        #  "metrics.tenjin-dk.com"
        #  "metrics.tenjin.com"
        #  "oauth.accounts.firefox.com"
        #  "private.tenjin.com"
        #  "profile.accounts.firefox.com"
        #  "public.tenjin.com"
        #  "support.mozilla.org"
        #  "sync.services.mozilla.com"
        #];

        # Sidebery customization
        userChrome = ''
          :root {
            --toolbar-bgcolor: ${colors.darker} !important;
            --lwt-accent-color: ${colors.darker} !important;
            --newtab-background-color: ${colors.darker} !important;
            --sidebar-background-color: ${colors.darker} !important;
          }

          #sidebar-container,
          #sidebar-launcher-splitter {
            display: none !important;
          }

          /* Hide sidebar-panel-header (sidebar.revamp: true) */
          #sidebar-panel-header {
            display: none;
          }

          /* Sidebery styles applied globally (title preface gate removed) */
          #TabsToolbar > * { display: none !important; }
          #nav-bar { border-color: transparent !important; }

          #sidebar-box { padding: 0 !important; }
          #sidebar-box #sidebar {
            box-shadow: none !important;
            border: none !important;
            outline: none !important;
            border-radius: 0 !important;
          }
          #sidebar-splitter {
            --splitter-width: 3px !important;
            min-width: var(--splitter-width) !important;
            width: var(--splitter-width) !important;
            padding: 0 !important;
            margin: 0 calc(-1*var(--splitter-width) + 1px) 0 0 !important;
            border: 0 !important;
            opacity: 0 !important;
          }
          #sidebar-header { display: none !important; }

          .urlbarView-row[selected],
          .urlbarView-row[selected] .urlbarView-title,
          .urlbarView-row[selected] .urlbarView-url,
          .urlbarView-row[selected] .urlbarView-title-separator,
          .urlbarView-row[selected] .urlbarView-action,
          .urlbarView-row[selected] .urlbarView-secondary-action {
            background-color: ${colors.highlight} !important;
            color: ${colors.darker} !important;
          }

          #urlbar-input::selection,
          #urlbar .urlbar-input-box ::selection {
            background-color: ${colors.highlight} !important;
            color: ${colors.darker} !important;
          }
        '';

        # Sidebery renders in an extension document and sets --s-* inline on #root/body.
        userContent = ''
          @-moz-document url-prefix("moz-extension://") {
            :root, body, #root {
              --s-frame-bg: ${colors.darker} !important;
              --s-frame-fg: ${colors.foreground} !important;
              --s-toolbar-bg: ${colors.darker} !important;
              --s-toolbar-fg: ${colors.tan} !important;
              --s-toolbar-border: ${colors.gray} !important;
              --s-act-el-bg: ${colors.mbg} !important;
              --s-act-el-fg: ${colors.white} !important;
              --s-act-el-border: ${colors.highlight} !important;
              --s-accent: ${colors.highlight} !important;
              --s-popup-bg: ${colors.background} !important;
              --s-popup-fg: ${colors.foreground} !important;
              --s-popup-border: ${colors.gray} !important;
            }
          }
        '';
      };
    };

    #home = {
    #  persistence = {
    #    # Comment to disable persistence
    #    "/persist".directories = [ ".mozilla/firefox" ];
    #  };
    #};

    config.xdg.configFile."xfce4/helpers.rc".text = ''
      WebBrowser=firefox
    '';
  };
}
