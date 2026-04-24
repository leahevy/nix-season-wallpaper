{ lib }:
rec {
  lowercase = lib.strings.toLower;

  require = condition: message: if condition then true else throw message;

  inherit (lib.lists)
    take
    sublist
    ;

  mod =
    a: b:
    assert builtins.isInt a;
    assert builtins.isInt b;
    assert b > 0;
    lib.trivial.mod a b;

  # Run a list of checks (expressions) and then return `value`.
  # Each check is forced via `builtins.seq` so they aren't skipped due to laziness.
  withChecks = checks: value: builtins.foldl' (acc: check: builtins.seq check acc) value checks;

  # Strict "for-each" that forces evaluation of `f` for every list element.
  forEach_ = list: f: builtins.foldl' (acc: x: builtins.seq (f x) acc) true list;

  # Strict "for-each" over an attrset's values (also passes the name).
  forAttrs_ = attrs: f: forEach_ (builtins.attrNames attrs) (name: f name attrs.${name});

  jsonTypeOf =
    value:
    if builtins.isAttrs value then
      "object"
    else if builtins.isList value then
      "array"
    else if builtins.isString value then
      "string"
    else if builtins.isInt value then
      "integer"
    else if builtins.isBool value then
      "boolean"
    else if value == null then
      "null"
    else
      "other";

  requireAttrs =
    name: value:
    require (builtins.isAttrs value) "${name} must be a JSON object, got ${jsonTypeOf value}";

  requireList =
    name: value:
    require (builtins.isList value) "${name} must be a JSON array, got ${jsonTypeOf value}";

  requireString =
    name: value: require (builtins.isString value) "${name} must be a string, got ${jsonTypeOf value}";

  requireInt =
    name: value: require (builtins.isInt value) "${name} must be an integer, got ${jsonTypeOf value}";

  requireAttrsWith =
    name: attrs: keys:
    let
      attrsCheck = requireAttrs name attrs;
      missing = builtins.filter (key: !(builtins.hasAttr key attrs)) keys;
    in
    builtins.seq attrsCheck (
      require (
        missing == [ ]
      ) "${name} is missing required keys: ${builtins.concatStringsSep ", " missing}"
    );

  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (builtins.attrNames attrs);

  sumList = values: builtins.foldl' (accumulator: value: accumulator + value) 0 values;

  absoluteValue = value: if value < 0 then -value else value;

  splitExtension =
    filename:
    let
      match = builtins.match "^(.*)\\.([^.]*)$" filename;
    in
    if match == null then
      null
    else
      {
        base = builtins.elemAt match 0;
        extension = lowercase (builtins.elemAt match 1);
      };

  seasonFromWallpaperKey =
    key:
    let
      match = builtins.match "^(winter|spring|summer|autumn)_.*$" key;
    in
    if match == null then null else builtins.elemAt match 0;
}
