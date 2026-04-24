{
  self,
  lib,
  wallpapersSrc,
}:
let
  utils = import ./utils.nix { inherit lib; };
  dates = import ./dates.nix { inherit utils lib; };
  config = import ./config.nix {
    inherit utils;
    configRoot = wallpapersSrc;
  };
  files = import ./files.nix {
    inherit self utils;
    wallpapersRoot = wallpapersSrc;
  };
  handlers = import ./handlers.nix { inherit self utils dates; };
  seasonal = import ./seasonal {
    inherit
      utils
      dates
      config
      files
      handlers
      ;
  };
  daily = import ./daily.nix {
    inherit
      utils
      dates
      config
      files
      seasonal
      ;
  };
in
{
  inherit (seasonal) resolveWallpaperBySeason;
  inherit (daily) resolveDailyWallpaper;
}
