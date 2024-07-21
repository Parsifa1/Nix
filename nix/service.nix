{pkgs, ...}: {
  services = {
    pcscd.enable = true;
    xserver.enable = true;
    openssh = {
      enable = true;
      ports = [14514];
      settings = {
        ClientAliveInterval = 60;
        ClientAliveCountMax = 3;
      };
      extraConfig = "AcceptEnv TERM_PROGRAM_VERSION WEZTERM_REMOTE_PANE TERM COLORTERM TERM_PROGRAM WSLENV";
    };
  };
  systemd.services = {
    "serial-getty@ttyS0".enable = false;
    "serial-getty@hvc0".enable = false;
    "getty@tty1".enable = false;
    "autovt@".enable = false;
    nix-daemon.environment = {
      https_proxy = "socks5h://localhost:7890";
      http_proxy = "socks5h://localhost:7890";
    };
    systemd-resolved.enable = false;
    systemd-udevd.enable = false;
    firewall.enable = false;
    network-mirrored = {
      description = "network-mirrored";
      enable = true;
      wants = ["network-pre.target"];
      wantedBy = ["multi-user.target"];
      before = ["network-pre.target" "shutdown.target"];
      serviceConfig = {
        User = "root";
        ExecStart = [
          ''
            /bin/sh -ec '\
            [ -x /usr/bin/wslinfo ] && [ "$(/usr/bin/wslinfo --networking-mode)" = "mirrored" ] || exit 0;\
            echo "\
            add chain   ip nat WSLPREROUTING { type nat hook prerouting priority dstnat - 1; policy accept; };\
            insert rule ip nat WSLPREROUTING iif loopback0  ip daddr 127.0.0.1 counter dnat to 127.0.0.1 comment mirrored;\
            "|${pkgs.nftables}/bin/nft -f -\
            '
          ''
        ];

        ExecStop = [
          ''
            /bin/sh -ec '\
              [ -x /usr/bin/wslinfo ] && [ "$(/usr/bin/wslinfo --networking-mode)" = "mirrored" ] || exit 0;\
              for chain in "ip nat WSLPREROUTING";\
              do\
                handle=$(${pkgs.nftables}/bin/nft -a list chain $chain | sed -En "s/^.*comment \\"mirrored\\" # handle ([0-9]+)$/\\1/p");\
                for n in $handle; do echo "delete rule $chain handle $n"; done;\
              done|${pkgs.nftables}/bin/nft -f -\
            '
          ''
        ];
        RemainAfterExit = "yes";
      };
    };
  };
}
