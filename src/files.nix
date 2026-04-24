{
  self,
  utils,
  wallpapersRoot,
}:
rec {
  inherit (utils)
    lowercase
    splitExtension
    ;

  sourceWallpaperDirectory = wallpapersRoot + /wallpapers/widescreen;
  processedWallpaperDirectory = wallpapersRoot + /wallpapers/normal;

  collectFiles =
    directory:
    if !(builtins.pathExists directory) then
      { }
    else
      let
        entries = builtins.readDir directory;
        filenames = builtins.attrNames entries;
        validFilenames = builtins.filter (
          filename:
          let
            split = splitExtension filename;
          in
          entries.${filename} == "regular"
          && split != null
          && builtins.elem split.extension [
            "jpg"
            "jpeg"
            "png"
          ]
        ) filenames;
      in
      builtins.listToAttrs (
        map (
          filename:
          let
            split = splitExtension filename;
          in
          {
            name = lowercase split.base;
            value = {
              relativeName = filename;
              extension = split.extension;
            };
          }
        ) validFilenames
      );

  sourceWallpaperFiles = collectFiles sourceWallpaperDirectory;

  processedWallpaperFiles =
    if builtins.pathExists processedWallpaperDirectory then
      collectFiles processedWallpaperDirectory
    else
      { };

  hasMatchingSourceWallpaper = key: builtins.hasAttr (lowercase key) sourceWallpaperFiles;

  buildImageResult =
    directory: fileInfo: storeNamePrefix:
    let
      sourcePath = directory + "/${fileInfo.relativeName}";
      storeName =
        if storeNamePrefix == null then
          lowercase fileInfo.relativeName
        else
          "${storeNamePrefix}-${lowercase fileInfo.relativeName}";
    in
    {
      path = builtins.path {
        path = sourcePath;
        name = storeName;
      };
      name = fileInfo.relativeName;
      extension = fileInfo.extension;
    };
}
