{
  utils,
  dates,
  config,
  files,
  numbering,
}:
rec {
  inherit (utils) seasonFromWallpaperKey;
  inherit (dates)
    seasonOf
    seasonContext
    dayPositionInSeason
    resolveDate
    ;
  inherit (files) hasMatchingSourceWallpaper;
  inherit (numbering)
    festiveNameAt
    normalWallpaperNumberAt
    validateSeasonNumbering
    ;

  primaryWallpaperKey =
    date:
    let
      context = (seasonContext date) // {
        config = config.seasonConfigOf (seasonOf date);
      };
      dayPosition = dayPositionInSeason date;
      festiveName = festiveNameAt context dayPosition;
    in
    if festiveName != null then
      "${context.season}_${festiveName}"
    else
      "${context.season}_${normalWallpaperNumberAt context dayPosition}";

  # Fallback split that only uses the count of numbered wallpapers.
  simpleNumberedWallpaperKey =
    date:
    let
      season = seasonOf date;
      count = validateSeasonNumbering season;
      context = seasonContext date;
      dayPosition = dayPositionInSeason date;
      bucket = builtins.floor (((dayPosition - 1) * count) / context.seasonLength) + 1;
      clampedBucket = if bucket > count then count else bucket;
    in
    "${season}_${toString clampedBucket}";

  secondWallpaperKey =
    date:
    let
      season = seasonOf date;
      count = validateSeasonNumbering season;
      selected = if count >= 2 then 2 else 1;
    in
    "${season}_${toString selected}";

  firstExistingWallpaperKey =
    keys:
    if keys == [ ] then
      "fallback"
    else
      let
        currentKey = builtins.head keys;
      in
      if hasMatchingSourceWallpaper currentKey then
        currentKey
      else
        firstExistingWallpaperKey (builtins.tail keys);

  wallpaperKeyCandidates =
    date:
    let
      primaryResult = builtins.tryEval (primaryWallpaperKey date);
      simpleResult = builtins.tryEval (simpleNumberedWallpaperKey date);
      secondResult = builtins.tryEval (secondWallpaperKey date);
    in
    (if primaryResult.success then [ primaryResult.value ] else [ ])
    ++ (if simpleResult.success then [ simpleResult.value ] else [ ])
    ++ (if secondResult.success then [ secondResult.value ] else [ ])
    ++ [ "fallback" ];
}
