# Store listings

One file per language, ready to paste into Play Console (Grow > Store presence > Main store listing,
then "Manage translations") and App Store Connect (App Information and the version page, per
localization). Each field's limit is in its heading; `check.py` checks them all.

- Play: app name 30, short description 80, full description 4000.
- App Store: name 30, subtitle 30, promotional text 170, description 4000, keywords 100
  (comma-separated, no spaces after commas; words already in the name or subtitle needn't repeat).

The listings say only what the app does today. Change them when the app changes, and have a native
speaker read a translation before it goes live.
