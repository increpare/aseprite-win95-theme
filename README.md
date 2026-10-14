# Windows 95-inspired theme for Aseprite (vibe-coded)

<img width="2560" height="1393" alt="image" src="https://github.com/user-attachments/assets/85a7a149-cf77-4d73-b425-9c16da509773" />

A native Aseprite theme with silver panels, crisp bevels, recessed white fields,
classic gray tabs, and navy captions and selections. Tools and keyboard
shortcuts work as usual. No Aseprite source checkout or compilation is needed.

## Install

1. [Download windows-95.aseprite-extension](https://github.com/increpare/aseprite-win95-theme/releases/latest/download/windows-95.aseprite-extension).
2. Open it in Aseprite and install the extension.
3. Go to **Edit > Preferences > Theme**, choose **Windows 95**, and click **Select**.

Switch back to the default theme in the same preferences panel.
When updating, install the new extension and reselect the theme or restart Aseprite.

The theme uses Tahoma from your system, with Aseprite's bundled font as fallback.
No Microsoft fonts are included. Start with 100% screen and UI scaling; increase
screen scaling if you prefer larger controls. Existing font overrides in
Preferences take precedence. The outer operating-system window caption is not
controlled by the theme.

Developed against Aseprite 1.3.18.6 on Windows. The neutral panel colors and
document tabs were visually checked at 100% screen scaling, including switching
between two open documents. Other platforms, versions, and the full range of
display scales have not been verified.

## Design

- Panels, toolbars, dock separators, and tabs are neutral gray.
- Document tabs have clipped top corners and open bottom edges. The active tab
  joins the panel below; inactive tabs sit two pixels lower behind the page seam.
- White recessed surfaces indicate fields and lists; the canvas surround is darker gray.
- Navy marks captions and selections, rather than filling arbitrary panels.
- Bevels, dithered toggle faces, and dotted focus indicators distinguish control states.

Aseprite shares `workspace` across dock gaps, context bars, and animation controls.
It also uses `tab_active_face` behind both the palette and the right-hand tool strip.
Those shared colors stay neutral. The timeline's `timeline_none` overlay stays
transparent so it does not obscure selected rows or custom layer colors.

## Build the extension

On Windows, from this repository's root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

This regenerates `theme/theme.xml` and `theme/sheet.png`, then creates
`dist/windows-95.aseprite-extension`. It uses Windows PowerShell and the built-in
System.Drawing library; no package installation or full Aseprite checkout is needed.

Edit `scripts/build.ps1` for colors and control geometry, and `theme/package.json`
for extension metadata. Generated controls get independent atlas slots to avoid
overwriting other states that share coordinates in the original sheet.

`vendor/aseprite-default/` contains only the upstream theme definitions, artwork,
metadata, and license used as build inputs. See its [provenance note](vendor/aseprite-default/README.md).

## Credits and license

Adapted from Aseprite's default theme by **David Capello** and **Ilija Melentijevic**,
with **Nicolas Desilets** credited in the upstream theme metadata.
The theme and this adaptation are licensed under **CC BY 4.0**; see [LICENSE.txt](LICENSE.txt).
Changes include colors, control borders and states, font selection, and spacing.

Visual guidance came from the personal `win95-ui` reference collection (Vector95
and ProcGen FM). No code, fonts, or artwork from those applications is included.
This is an independent community theme, not an official Aseprite or Microsoft product.
