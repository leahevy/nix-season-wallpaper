{
  utils,
  dates,
  config,
  files,
  handlers,
}:
rec {
  inherit (utils)
    lowercase
    require
    sumList
    seasonFromWallpaperKey
    ;

  inherit (dates)
    seasonOf
    absoluteDayNumber
    seasonContext
    dayPositionInSeason
    festivalDateToYear
    ;

  inherit (config)
    styleOf
    positions
    seasonConfigOf
    numberedDirectionsForCount
    festivalPadding
    ;

  inherit (files)
    sourceWallpaperDirectory
    processedWallpaperDirectory
    sourceWallpaperFiles
    processedWallpaperFiles
    buildImageResult
    ;

  positionOf =
    key:
    let
      season = seasonFromWallpaperKey key;
      numberedMatch = builtins.match "^[^_]+_([0-9]+)$" key;
    in
    if numberedMatch != null && season != null then
      let
        index = builtins.fromJSON (builtins.elemAt numberedMatch 0);
        count = validateSeasonNumbering season;
        directions = numberedDirectionsForCount count;
      in
      if index <= builtins.length directions then builtins.elemAt directions (index - 1) else "center"
    else if builtins.hasAttr key positions then
      positions.${key}
    else
      "center";

  festivalRangeToPositions =
    context: festival:
    let
      startYear = festivalDateToYear context festival.startMonth;
      endYear = festivalDateToYear context festival.endMonth;
      rawStart =
        absoluteDayNumber startYear festival.startMonth festival.startDay
        - absoluteDayNumber context.seasonStart.year context.seasonStart.month context.seasonStart.day
        + 1;
      rawEnd =
        absoluteDayNumber endYear festival.endMonth festival.endDay
        - absoluteDayNumber context.seasonStart.year context.seasonStart.month context.seasonStart.day
        + 1;
      start = rawStart - festivalPadding.before;
      end = rawEnd + festivalPadding.after;
    in
    if start < 1 || end > context.seasonLength || start > end then
      throw "invalid padded festival range `${festival.name}` for season `${context.season}`"
    else
      {
        inherit (festival) name;
        inherit start end;
      };

  festiveRanges =
    context:
    let
      resolvedFestivals = utils.mapAttrsToList (
        name: festival: handlers.resolveFestival context name festival
      ) context.config.festivals;
      ranges = map (festival: festivalRangeToPositions context festival) resolvedFestivals;
    in
    builtins.sort (
      left: right: if left.start == right.start then left.end < right.end else left.start < right.start
    ) ranges;

  festiveNameAt =
    context: dayPosition:
    let
      matchingRanges = builtins.filter (range: dayPosition >= range.start && dayPosition <= range.end) (
        festiveRanges context
      );
    in
    if matchingRanges == [ ] then null else (builtins.head matchingRanges).name;

  intervalLength = interval: interval.end - interval.start + 1;

  normalIntervals =
    context:
    let
      step =
        state: festiveRange:
        let
          start = state.previousEnd + 1;
          end = festiveRange.start - 1;
          nextIntervals =
            if start <= end then state.intervals ++ [ { inherit start end; } ] else state.intervals;
        in
        {
          previousEnd = festiveRange.end;
          intervals = nextIntervals;
        };

      baseState = builtins.foldl' step {
        previousEnd = 0;
        intervals = [ ];
      } (festiveRanges context);
    in
    if baseState.previousEnd < context.seasonLength then
      baseState.intervals
      ++ [
        {
          start = baseState.previousEnd + 1;
          end = context.seasonLength;
        }
      ]
    else
      baseState.intervals;

  numberedWallpaperNumbersForSeason =
    season:
    let
      pattern = "^${season}_([0-9]+)$";
      keys = builtins.attrNames sourceWallpaperFiles;
      numbers = map (key: builtins.fromJSON (builtins.elemAt (builtins.match pattern key) 0)) (
        builtins.filter (key: builtins.match pattern key != null) keys
      );
    in
    builtins.sort builtins.lessThan numbers;

  validateSeasonNumbering =
    season:
    let
      numbers = numberedWallpaperNumbersForSeason season;
      count = builtins.length numbers;
      expected = builtins.genList (index: index + 1) count;
      festivalCount = builtins.length (builtins.attrNames (seasonConfigOf season).festivals);
    in
    utils.withChecks [
      (require (count > 0) "season `${season}` has no numbered wallpapers")
      (require (
        numbers == expected
      ) "season `${season}` must provide contiguous numbered wallpapers starting at 1")
      (require (
        festivalCount == 0 || count >= festivalCount + 1
      ) "season `${season}` needs at least festivals + 1 numbered wallpapers")
    ] count;

  allocateExtraCounts =
    lengths: extraCount:
    let
      lengthCount = builtins.length lengths;
      totalLength = sumList lengths;
      quotients = map (length: builtins.floor (extraCount * length / totalLength)) lengths;
      remainders = map (length: utils.mod (extraCount * length) totalLength) lengths;
      baseAllocated = sumList quotients;
      leftovers = extraCount - baseAllocated;
      ranked =
        builtins.sort
          (
            left: right:
            if left.remainder == right.remainder then
              left.index < right.index
            else
              left.remainder > right.remainder
          )
          (
            builtins.genList (index: {
              inherit index;
              remainder = builtins.elemAt remainders index;
            }) lengthCount
          );
    in
    builtins.genList (
      index:
      let
        quota = builtins.elemAt quotients index;
        bonus = if builtins.any (entry: entry.index == index) (utils.take leftovers ranked) then 1 else 0;
      in
      quota + bonus
    ) lengthCount;

  wallpaperCountPerInterval =
    context: intervals:
    let
      intervalCount = builtins.length intervals;
      numberedCount = validateSeasonNumbering context.season;
      baseCounts = builtins.genList (_: 1) intervalCount;
      extraCounts =
        if numberedCount == intervalCount then
          builtins.genList (_: 0) intervalCount
        else
          allocateExtraCounts (map intervalLength intervals) (numberedCount - intervalCount);
    in
    builtins.genList (
      index: builtins.elemAt baseCounts index + builtins.elemAt extraCounts index
    ) intervalCount;

  phaseSizes =
    totalLength: phaseCount:
    let
      baseSize = builtins.floor (totalLength / phaseCount);
      remainingDays = utils.mod totalLength phaseCount;
    in
    builtins.genList (index: if index < remainingDays then baseSize + 1 else baseSize) phaseCount;

  makeBuckets =
    let
      makeLocalBuckets =
        start: sizes: wallpaperNumber:
        if sizes == [ ] then
          [ ]
        else
          let
            currentSize = builtins.head sizes;
            stop = start + currentSize - 1;
          in
          [
            {
              start = start;
              end = stop;
              number = wallpaperNumber;
            }
          ]
          ++ makeLocalBuckets (stop + 1) (builtins.tail sizes) (wallpaperNumber + 1);

      go =
        intervals: counts: wallpaperNumber:
        if intervals == [ ] then
          [ ]
        else
          let
            currentInterval = builtins.head intervals;
            currentCount = builtins.head counts;
            localBuckets =
              makeLocalBuckets currentInterval.start (phaseSizes (intervalLength currentInterval) currentCount)
                wallpaperNumber;
          in
          localBuckets
          ++ go (builtins.tail intervals) (builtins.tail counts) (wallpaperNumber + currentCount);
    in
    intervals: counts: go intervals counts 1;

  normalBuckets =
    context:
    let
      intervals = normalIntervals context;
      counts = wallpaperCountPerInterval context intervals;
    in
    makeBuckets intervals counts;

  normalWallpaperNumberAt =
    context: dayPosition:
    let
      matchingBuckets = builtins.filter (
        bucket: dayPosition >= bucket.start && dayPosition <= bucket.end
      ) (normalBuckets context);
    in
    if matchingBuckets == [ ] then
      throw "no normal wallpaper bucket matched season position ${toString dayPosition}"
    else
      toString (builtins.head matchingBuckets).number;

  buildResolvedResult =
    date: resolvedKey:
    let
      lowercaseKey = lowercase resolvedKey;
      festivalName =
        let
          match = builtins.match "^(winter|spring|summer|autumn)_(.*)$" resolvedKey;
        in
        if match == null then
          null
        else
          let
            rest = builtins.elemAt match 1;
            isNumbered = builtins.match "^[0-9]+$" rest != null;
          in
          if isNumbered then null else rest;
      sourceFile =
        sourceWallpaperFiles.${lowercaseKey}
          or (throw "source wallpaper `${resolvedKey}` not found in ${toString sourceWallpaperDirectory}");

      widescreenResult = buildImageResult sourceWallpaperDirectory sourceFile "widescreen";

      normalResult =
        if builtins.hasAttr lowercaseKey processedWallpaperFiles then
          let
            processedFile = processedWallpaperFiles.${lowercaseKey};
          in
          buildImageResult processedWallpaperDirectory processedFile "normal"
        else
          widescreenResult;

      resolvedSeason =
        let
          wallpaperSeason = seasonFromWallpaperKey resolvedKey;
        in
        if wallpaperSeason != null then wallpaperSeason else seasonOf date;
    in
    {
      widescreen = widescreenResult;
      normal = normalResult;
      metadata = {
        season = resolvedSeason;
        style = styleOf resolvedSeason;
        positionPerson = positionOf resolvedKey;
        wallpaperKey = resolvedKey;
        festival = festivalName;
      };
    };
}
