{ utils, dates }:
rec {
  # Resolve Easter Sunday for a given year.
  easterDate =
    year:
    let
      a = utils.mod year 19;
      b = builtins.floor (year / 100);
      c = utils.mod year 100;
      d = builtins.floor (b / 4);
      e = utils.mod b 4;
      f = builtins.floor ((b + 8) / 25);
      g = builtins.floor ((b - f + 1) / 3);
      h = utils.mod (19 * a + b - d - g + 15) 30;
      i = builtins.floor (c / 4);
      k = utils.mod c 4;
      l = utils.mod (32 + 2 * e + 2 * i - h - k) 7;
      correction = builtins.floor ((a + 11 * h + 22 * l) / 451);
      n = h + l - 7 * correction + 114;
    in
    {
      month = builtins.floor (n / 31);
      day = utils.mod n 31 + 1;
    };

  resolveFestival =
    context: name: festival:
    let
      easter = easterDate context.seasonYear;
    in
    {
      inherit name;
      startMonth = easter.month;
      startDay = easter.day;
      endMonth = easter.month;
      endDay = easter.day;
    };
}
