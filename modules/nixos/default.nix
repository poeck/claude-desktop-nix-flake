{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude-desktop;
in
{
  options.programs.claude-desktop = {
    enable = lib.mkEnableOption "Claude Desktop";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-desktop or (pkgs.callPackage ../../pkgs/claude-desktop { });
      defaultText = lib.literalExpression "pkgs.claude-desktop";
      description = "Claude Desktop package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    xdg.portal.enable = lib.mkDefault true;
    xdg.portal.extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
  };
}
