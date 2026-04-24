{
  description = "wallpaper resolver";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    wallpapers = {
      url = "github:leahevy/wallpapers/main";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      wallpapers,
    }:
    let
      exports = import ./src {
        inherit self;
        lib = nixpkgs.lib;
        wallpapersSrc = wallpapers;
      };
    in
    {
      inherit (exports)
        resolveWallpaperBySeason
        resolveDailyWallpaper
        ;
    };
}
