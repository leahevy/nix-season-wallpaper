{ utils }:
rec {
  inherit (utils) require;

  resolveDate =
    source:
    if
      builtins.hasAttr "year" source && builtins.hasAttr "month" source && builtins.hasAttr "day" source
    then
      {
        inherit (source) year month day;
      }
    else if builtins.hasAttr "lastModifiedDate" source then
      {
        year = builtins.fromJSON (builtins.substring 0 4 source.lastModifiedDate);
        month = builtins.fromJSON (builtins.substring 4 2 source.lastModifiedDate);
        day = builtins.fromJSON (builtins.substring 6 2 source.lastModifiedDate);
      }
    else
      throw "expected either { year, month, day } or an attrset with lastModifiedDate";

  seasonOf =
    date:
    if
      builtins.elem date.month [
        12
        1
        2
      ]
    then
      "winter"
    else if
      builtins.elem date.month [
        3
        4
        5
      ]
    then
      "spring"
    else if
      builtins.elem date.month [
        6
        7
        8
      ]
    then
      "summer"
    else
      "autumn";

  isLeapYear = year: (utils.mod year 4 == 0 && utils.mod year 100 != 0) || (utils.mod year 400 == 0);

  daysInMonth =
    year: month:
    if
      builtins.elem month [
        1
        3
        5
        7
        8
        10
        12
      ]
    then
      31
    else if
      builtins.elem month [
        4
        6
        9
        11
      ]
    then
      30
    else if month == 2 then
      (if isLeapYear year then 29 else 28)
    else
      throw "invalid month `${toString month}`";

  # Convert a calendar date to a day number within the year.
  dayOfYear =
    year: month: day:
    let
      previousMonths = builtins.genList (index: index + 1) (month - 1);
    in
    day
    + builtins.foldl' (
      accumulator: currentMonth: accumulator + daysInMonth year currentMonth
    ) 0 previousMonths;

  # Convert a calendar date to a stable absolute day number across years.
  absoluteDayNumber =
    year: month: day:
    let
      yearMinusOne = year - 1;
    in
    365 * yearMinusOne + builtins.floor (yearMinusOne / 4) - builtins.floor (yearMinusOne / 100)
    + builtins.floor (yearMinusOne / 400)
    + dayOfYear year month day;

  seasonContext =
    date:
    let
      season = seasonOf date;
      seasonYear =
        if
          season == "winter"
          && builtins.elem date.month [
            1
            2
          ]
        then
          date.year - 1
        else
          date.year;
      seasonStart =
        if season == "winter" then
          {
            year = seasonYear;
            month = 12;
            day = 1;
          }
        else if season == "spring" then
          {
            year = seasonYear;
            month = 3;
            day = 1;
          }
        else if season == "summer" then
          {
            year = seasonYear;
            month = 6;
            day = 1;
          }
        else
          {
            year = seasonYear;
            month = 9;
            day = 1;
          };
      seasonLength =
        if season == "winter" then
          daysInMonth seasonYear 12 + daysInMonth (seasonYear + 1) 1 + daysInMonth (seasonYear + 1) 2
        else if season == "spring" then
          daysInMonth seasonYear 3 + daysInMonth seasonYear 4 + daysInMonth seasonYear 5
        else if season == "summer" then
          daysInMonth seasonYear 6 + daysInMonth seasonYear 7 + daysInMonth seasonYear 8
        else
          daysInMonth seasonYear 9 + daysInMonth seasonYear 10 + daysInMonth seasonYear 11;
    in
    {
      inherit
        season
        seasonYear
        seasonStart
        seasonLength
        ;
    };

  # Compute the 1-based offset of a date inside its season.
  dayPositionInSeason =
    date:
    let
      context = seasonContext date;
    in
    absoluteDayNumber date.year date.month date.day
    - absoluteDayNumber context.seasonStart.year context.seasonStart.month context.seasonStart.day
    + 1;

  festivalDateToYear =
    context: month:
    if
      context.season == "winter"
      && builtins.elem month [
        1
        2
      ]
    then
      context.seasonYear + 1
    else
      context.seasonYear;
}
