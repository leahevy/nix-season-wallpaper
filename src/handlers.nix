{
  self,
  utils,
  dates,
}:
let
  handlerDirectory = ./handlers;

  handlerFiles = builtins.filter (
    name:
    let
      split = utils.splitExtension name;
    in
    split != null && split.extension == "nix"
  ) (builtins.attrNames (builtins.readDir handlerDirectory));

  handlerModules = builtins.listToAttrs (
    map (
      filename:
      let
        split = utils.splitExtension filename;
        path = handlerDirectory + "/${filename}";
      in
      {
        name = split.base;
        value = import path { inherit utils dates; };
      }
    ) handlerFiles
  );
in
{
  resolveFestival =
    context: name: festival:
    if builtins.hasAttr "handler" festival then
      let
        handlerName = festival.handler;
        handler = handlerModules.${handlerName} or (throw "unknown festival handler `${handlerName}`");
      in
      handler.resolveFestival context name festival
    else
      festival // { inherit name; };
}
