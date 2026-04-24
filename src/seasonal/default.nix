{
  utils,
  dates,
  config,
  files,
  handlers,
}:
let
  numbering = import ./numbering.nix {
    inherit
      utils
      dates
      config
      files
      handlers
      ;
  };

  placement = import ./placement.nix {
    inherit
      utils
      dates
      config
      files
      numbering
      ;
  };
in
rec {
  inherit (numbering)
    validateSeasonNumbering
    buildResolvedResult
    ;

  resolveWallpaperBySeason =
    source:
    let
      date = dates.resolveDate source;
      numberedCount = validateSeasonNumbering (dates.seasonOf date);
      candidateKeys = placement.wallpaperKeyCandidates date;
      resolvedKey = placement.firstExistingWallpaperKey candidateKeys;
    in
    builtins.seq numberedCount (buildResolvedResult date resolvedKey);
}
