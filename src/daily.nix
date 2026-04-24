{
  utils,
  dates,
  config,
  files,
  seasonal,
}:
rec {
  inherit (utils)
    lowercase
    seasonFromWallpaperKey
    ;

  inherit (dates)
    resolveDate
    seasonOf
    absoluteDayNumber
    ;

  inherit (config)
    styleOf
    ;

  inherit (files)
    sourceWallpaperFiles
    ;

  eligibleDailyWallpaperKeys = builtins.sort builtins.lessThan (
    builtins.filter (key: key != "fallback") (builtins.attrNames sourceWallpaperFiles)
  );

  # Choose a deterministic daily wallpaper while avoiding adjacent repeats.
  dailyWallpaperKey =
    date:
    let
      count = builtins.length eligibleDailyWallpaperKeys;
      dayNumber = absoluteDayNumber date.year date.month date.day;
      step = if count <= 1 then 0 else count - 1;
      offset = 17;
      index =
        if count == 0 then
          null
        else if count == 1 then
          0
        else
          utils.mod (dayNumber * step + offset) count;
    in
    if count == 0 then "fallback" else builtins.elemAt eligibleDailyWallpaperKeys index;

  resolveDailyWallpaper =
    source:
    let
      date = resolveDate source;
      resolvedKey = dailyWallpaperKey date;
      result = seasonal.buildResolvedResult date resolvedKey;
    in
    result
    // {
      metadata = result.metadata // {
        festival = null;
      };
    };
}
