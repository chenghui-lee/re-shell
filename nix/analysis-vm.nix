{ modulesPath, pkgs, ... }:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  networking.hostName = "re-analysis";
  system.stateVersion = "25.11";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Console-only login; no password-authenticated network service.
  users.users.analyst = {
    isNormalUser = true;
    initialHashedPassword = "";
    extraGroups = [ "wheel" ];
  };
  services.getty.autologinUser = "analyst";
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages =
    (import ./debug-tools.nix { inherit pkgs; })
    ++ (with pkgs; [
      file
      binutils-unwrapped-all-targets
      gcc
      python3
      git
    ]);

  virtualisation = {
    graphics = false;
    memorySize = 4096;
    cores = 2;
    diskSize = 16384;
    # The runner exports SHARED_DIR at /tmp/shared. Never share the repo root.
    # Restrict guest-initiated networking; this is an analysis appliance.
    restrictNetwork = true;
  };
}
