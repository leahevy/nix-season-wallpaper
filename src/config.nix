{
  configRoot,
  utils,
}:
rec {
  inherit (utils)
    require
    requireAttrs
    requireList
    requireString
    requireInt
    requireAttrsWith
    mapAttrsToList
    ;

  readJson = path: builtins.fromJSON (builtins.readFile path);

  validateStyles =
    styles:
    let
      seasons = [
        "winter"
        "spring"
        "summer"
        "autumn"
      ];
    in
    utils.withChecks [
      (requireAttrs "config/styles.json" styles)
      (utils.forEach_ seasons (
        season:
        requireString "config/styles.json.${season}" (
          styles.${season} or (throw "config/styles.json is missing key `${season}`")
        )
      ))
    ] styles;

  validatePositions =
    positions:
    utils.withChecks [
      (requireAttrs "config/positions.json" positions)
      (utils.forEach_ (builtins.attrNames positions) (
        key: requireString "config/positions.json.${key}" positions.${key}
      ))
    ] positions;

  validateDefaultDirectionList =
    key: directions:
    utils.withChecks [
      (requireList "config/defaults.json.numberedPositions.${key}" directions)
      (utils.forEach_ directions (
        direction:
        require (builtins.elem direction [
          "left"
          "center"
          "right"
        ]) "config/defaults.json.numberedPositions.${key} may only contain left, center, or right"
      ))
    ] directions;

  validateDefaults =
    defaults:
    utils.withChecks [
      (requireAttrs "config/defaults.json" defaults)
      (requireAttrsWith "config/defaults.json" defaults [
        "festivalPadding"
        "numberedPositions"
      ])
      (requireAttrsWith "config/defaults.json.festivalPadding" defaults.festivalPadding [
        "before"
        "after"
      ])
      (requireInt "config/defaults.json.festivalPadding.before" defaults.festivalPadding.before)
      (requireInt "config/defaults.json.festivalPadding.after" defaults.festivalPadding.after)
      (require (
        defaults.festivalPadding.before >= 0
      ) "config/defaults.json.festivalPadding.before must be >= 0")
      (require (
        defaults.festivalPadding.after >= 0
      ) "config/defaults.json.festivalPadding.after must be >= 0")
      (requireAttrs "config/defaults.json.numberedPositions" defaults.numberedPositions)
      (utils.forAttrs_ defaults.numberedPositions validateDefaultDirectionList)
    ] defaults;

  validateFestival =
    season: name: festival:
    let
      prefix = "config/seasons.json.${season}.festivals.${name}";
      hasHandler = builtins.hasAttr "handler" festival;
    in
    utils.withChecks (
      [
        (requireAttrs prefix festival)
      ]
      ++ (
        if hasHandler then
          [
            (requireString "${prefix}.handler" festival.handler)
          ]
        else
          [
            (requireAttrsWith prefix festival [
              "startMonth"
              "startDay"
              "endMonth"
              "endDay"
            ])
            (requireInt "${prefix}.startMonth" festival.startMonth)
            (requireInt "${prefix}.startDay" festival.startDay)
            (requireInt "${prefix}.endMonth" festival.endMonth)
            (requireInt "${prefix}.endDay" festival.endDay)
            (require (
              festival.startMonth >= 1 && festival.startMonth <= 12
            ) "${prefix}.startMonth must be between 1 and 12")
            (require (
              festival.endMonth >= 1 && festival.endMonth <= 12
            ) "${prefix}.endMonth must be between 1 and 12")
            (require (
              festival.startDay >= 1 && festival.startDay <= 31
            ) "${prefix}.startDay must be between 1 and 31")
            (require (
              festival.endDay >= 1 && festival.endDay <= 31
            ) "${prefix}.endDay must be between 1 and 31")
          ]
      )
    ) festival;

  validateSeasonEntry =
    season: entry:
    utils.withChecks [
      (requireAttrsWith "config/seasons.json.${season}" entry [ "festivals" ])
      (requireAttrs "config/seasons.json.${season}.festivals" entry.festivals)
      (utils.forAttrs_ entry.festivals (name: festival: validateFestival season name festival))
    ] entry;

  validateSeasons =
    seasons:
    let
      seasonNames = [
        "winter"
        "spring"
        "summer"
        "autumn"
      ];
    in
    utils.withChecks [
      (requireAttrs "config/seasons.json" seasons)
      (utils.forEach_ seasonNames (
        season:
        validateSeasonEntry season (
          seasons.${season} or (throw "config/seasons.json is missing key `${season}`")
        )
      ))
    ] seasons;

  styles = validateStyles (readJson (configRoot + /config/styles.json));
  positions = validatePositions (readJson (configRoot + /config/positions.json));
  defaults = validateDefaults (readJson (configRoot + /config/defaults.json));
  seasons = validateSeasons (readJson (configRoot + /config/seasons.json));

  styleOf = season: styles.${season} or (throw "no style mapping for season `${season}`");

  seasonConfigOf = season: seasons.${season} or (throw "no season mapping for season `${season}`");

  numberedDirectionsForCount =
    count:
    let
      key = toString count;
      directions = defaults.numberedPositions.${key} or [ ];
    in
    if directions == [ ] then
      builtins.genList (_: "center") count
    else if builtins.length directions == count then
      directions
    else
      builtins.genList (
        index: if index < builtins.length directions then builtins.elemAt directions index else "center"
      ) count;

  inherit (defaults) festivalPadding;
}
