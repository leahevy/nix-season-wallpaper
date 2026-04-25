# nix-season-wallpaper

Nix flake that resolves a wallpaper for a given date (based on season or random).

## Exports
- `resolveWallpaperBySeason`: seasonal resolver (festivals + numbering).
- `resolveDailyWallpaper`: deterministic daily rotation.
- `fallback`: direct fallback wallpaper (attrset with `normal` + `widescreen`).

Both functions accept a date attrset: `{ year, month, day }`.

## Wallpapers source

- Wallpapers are fetched via the flake input `wallpapers`.
- Expected layout inside that repo: `./wallpapers/widescreen` and `./wallpapers/normal`.

## License

See `LICENSE`.
