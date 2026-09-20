# Roundel

Roundel is a tiny, private macOS menu bar app for marking the days on which you did something. Use it for climbing, running, strength training, meditation, or anything else worth remembering.

Roundel 是一個極簡、重視隱私的 macOS menu bar 日期標記工具。你可以用它記錄抱石、跑步、重訓、冥想，或任何想持續做的事。

A roundel is a plain filled circle used as an emblem — on flags, aircraft and transit signs. One roundel per day, accumulating into a year.

Roundel 指的是圓形徽記：旗幟、機徽、地鐵標誌上那種純粹的圓。每天一枚，積累成一整年。

## Features / 功能

- Click a date to mark or unmark it / 點擊日期即可標記或取消
- Browse previous and future months / 切換前後月份
- Local-only storage with no account or network access / 資料只存在本機，無帳號、無連線
- English interface / 英文介面
- Native SwiftUI interface / 原生 SwiftUI 介面

## Requirements / 系統需求

- macOS 14 or later
- Xcode 15 or later for development

## Build

Open `Roundel.xcodeproj` in Xcode and run the `Roundel` scheme, or use:

```sh
xcodebuild \
  -project Roundel.xcodeproj \
  -scheme Roundel \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Create a DMG

For a local, ad-hoc signed test build:

```sh
./scripts/build-dmg.sh
```

For a public release, first create a **Developer ID Application** certificate and a `notarytool` keychain profile, then run:

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="roundel" \
./scripts/build-dmg.sh
```

Create the notarization profile once with `xcrun notarytool store-credentials`. The generated DMG and SHA-256 checksum are written to `dist/`.

## Publish on GitHub

After authenticating GitHub CLI, create the public repository and first release with:

```sh
gh auth login
gh repo create Roundel --public --source=. --remote=origin --push
gh release create v0.1.0 \
  dist/Roundel-0.1.0.dmg \
  dist/Roundel-0.1.0.dmg.sha256 \
  --title "Roundel 0.1.0" \
  --generate-notes
```

Only publish the DMG after building it with a Developer ID Application identity and notarizing it. The ad-hoc local-test DMG should not be offered as a public release.

## Data

Marked days are stored as a plain CSV file, `roundel.csv`, inside the app's sandbox container — the same format the Dashboard exports, so there is one format rather than a database plus an interchange file. A day is stored as a Gregorian `YYYY-MM-DD` value so that travelling across time zones does not move the mark to another day. If the file ever becomes unreadable it is set aside as `roundel-unreadable-<timestamp>.csv` rather than overwritten, so the contents stay recoverable.

Roundel does not request network access and does not collect analytics.

## License

[MIT](LICENSE)
