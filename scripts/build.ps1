# Rebuild the native theme atlas and XML from Aseprite's default theme.
# Run from any directory with Windows PowerShell (System.Drawing is built in).
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'vendor/aseprite-default'
$output = Join-Path $root 'theme'
$null = New-Item -ItemType Directory -Force $output
[xml]$theme = Get-Content -LiteralPath (Join-Path $source 'theme.xml') -Raw
$theme.theme.SetAttribute('name', 'Windows 95')
$theme.theme.SetAttribute('screenscaling', '1')
$theme.theme.SetAttribute('uiscaling', '1')

# Use installed fonts, never redistribute Microsoft's font files. The fallback
# keeps this theme usable on systems without Tahoma.
$fonts = $theme.SelectSingleNode('/theme/fonts')
$fonts.RemoveAll()
foreach ($spec in @(@('default', '11'), @('mini', '10'))) {
    $font = $theme.CreateElement('font')
    foreach ($pair in @(@('id',$spec[0]), @('name',"Windows 95 $($spec[0])"), @('type','truetype'), @('file','tahoma.ttf'), @('size',$spec[1]), @('antialias','false'))) {
        $font.SetAttribute($pair[0], $pair[1])
    }
    if ($spec[0] -eq 'mini') { $font.SetAttribute('mnemonics','off') }
    $fallback = $theme.CreateElement('fallback')
    $fallback.SetAttribute('font', 'Aseprite')
    $null = $font.AppendChild($fallback)
    $null = $fonts.AppendChild($font)
}
$colors = @{
    disabled='808080'; face='c0c0c0'; hot_face='c0c0c0'; selected='000080';
    separator_label='000000'; textbox_code_face='dfdfdf'; entry_suffix='808080';
    link_text='000080'; link_hover='0000ff'; button_selected_text='000000';
    check_hot_face='c0c0c0'; check_focus_face='c0c0c0'; radio_hot_face='c0c0c0'; radio_focus_face='c0c0c0';
    menuitem_normal_face='c0c0c0'; menuitem_hot_text='ffffff'; menuitem_hot_face='000080';
    menuitem_highlight_face='000080'; window_face='c0c0c0'; window_titlebar_face='000080';
    editor_face='808080'; editor_sprite_bottom_border='000000'; editor_view_face='808080';
    listitem_selected_face='000080'; tab_active_face='c0c0c0'; tab_active_text='000000'; tooltip_face='ffffe1';
    filelist_selected_row_face='000080'; filelist_disabled_row_text='808080';
    workspace='c0c0c0'; workspace_text='000000'; workspace_link='000080'; workspace_link_hover='0000ff';
    timeline_normal='c0c0c0'; timeline_hover='dfdfdf'; timeline_active='000080';
    timeline_active_hover='000080'; timeline_clicked='000080'; timeline_padding='c0c0c0';
    timeline_band_highlight='dfdfdf'; timeline_band_bg='808080';
    status_bar_text='000000'; status_bar_face='c0c0c0'; flag_normal='c0c0c0'; flag_clicked='000080'
}
foreach ($c in $theme.theme.colors.color) {
    if ($colors.ContainsKey($c.id)) { $c.SetAttribute('value', '#' + $colors[$c.id]) }
}
foreach ($dim in $theme.theme.dimensions.dim) {
    switch ($dim.id) {
        scrollbar_size { $dim.SetAttribute('value','16') }
        tabs_width { $dim.SetAttribute('value','120') }
        tabs_height { $dim.SetAttribute('value','22') }
        context_bar_height { $dim.SetAttribute('value','24') }
        timeline_base_size { $dim.SetAttribute('value','16') }
    }
}

function Color([string]$hex) { [Drawing.ColorTranslator]::FromHtml('#' + $hex) }
$face = Color 'c0c0c0'; $white = Color 'ffffff'; $light = Color 'dfdfdf'
$shadow = Color '808080'; $black = Color '000000'; $navy = Color '000080'
$original = [Drawing.Bitmap]::new((Join-Path $source 'sheet.png'))
$atlas = [Drawing.Bitmap]::new(512, 1024)
$g = [Drawing.Graphics]::FromImage($atlas)
$g.DrawImageUnscaled($original, 0, 0)
$g.Dispose()
# Shared chrome is neutral. Selection/caption colors are assigned to specific
# parts below, never inferred just from a source pixel's blue-gray color.
# In particular, workspace fills docks and context bars, and tab_active_face
# also fills the entire palette and tool strip in the native renderer.
$palette = @{
    'd3cbbe'='c0c0c0'; '968275'='808080'; 'faf0e6'='ffffff'; 'ffebb6'='c0c0c0';
    '7c909f'='c0c0c0'; '7d929e'='c0c0c0'; '655561'='808080'; 'ff5555'='000080';
    '99b3c2'='dfdfdf'; '536069'='808080'; 'ffff7d'='ffffe1'; 'c6c6c6'='c0c0c0'
}
for ($y=0; $y -lt $original.Height; $y++) {
    for ($x=0; $x -lt $original.Width; $x++) {
        $c = $original.GetPixel($x,$y)
        $key = '{0:x2}{1:x2}{2:x2}' -f $c.R,$c.G,$c.B
        if ($c.A -gt 0 -and $palette.ContainsKey($key)) { $atlas.SetPixel($x,$y,(Color $palette[$key])) }
    }
}
$original.Dispose()
$script:slot = 0
function Paint-Part($part, [string]$kind, [Drawing.Color]$fill) {
    if ($part.HasAttribute('w')) { $w=[int]$part.w; $h=[int]$part.h }
    else { $w=[int]$part.w1+[int]$part.w2+[int]$part.w3; $h=[int]$part.h1+[int]$part.h2+[int]$part.h3 }
    # Give every replacement its own slot: the original atlas intentionally
    # aliases some controls, which must not make unrelated states overwrite.
    $px=($script:slot % 16)*32; $py=320+[int][Math]::Floor($script:slot/16)*32
    $script:slot++
    if ($w -gt 32 -or $h -gt 32 -or $py+$h -gt $atlas.Height) { throw "Atlas overflow: $($part.id)" }
    $part.SetAttribute('x', [string]$px); $part.SetAttribute('y',[string]$py)
    for ($yy=0; $yy -lt $h; $yy++) {
        for ($xx=0; $xx -lt $w; $xx++) {
            $c=$fill
            if ($kind -eq 'checker' -and ($xx+$yy)%2 -eq 0) { $c=$white }
            if ($kind -in @('raised','focus','sunken','latched','latchedfocus','window','check','checked')) {
                $tl1=$white; $tl2=$light; $br1=$black; $br2=$shadow
                if ($kind -in @('sunken','latched','latchedfocus','check','checked')) { $tl1=$shadow; $tl2=$black; $br1=$white; $br2=$light }
                if ($kind -in @('latched','latchedfocus') -and ($xx+$yy)%2 -eq 0) { $c=$white }
                if ($xx -eq 1 -or $yy -eq 1) { $c=$tl2 }
                if ($xx -eq $w-2 -or $yy -eq $h-2) { $c=$br2 }
                if ($xx -eq 0 -or $yy -eq 0) { $c=$tl1 }
                if ($xx -eq $w-1 -or $yy -eq $h-1) { $c=$br1 }
                if ($kind -in @('focus','latchedfocus') -and ($xx -eq 3 -or $xx -eq $w-4 -or $yy -eq 3 -or $yy -eq $h-4) -and $xx -ge 3 -and $xx -le $w-4 -and $yy -ge 3 -and $yy -le $h-4 -and ($xx+$yy)%2 -eq 0) { $c=$black }
                if ($kind -eq 'window' -and $xx -ge 3 -and $xx -lt $w-3 -and $yy -ge 3 -and $yy -lt [int]$part.h1-1) { $c=$navy }
                if ($kind -eq 'checked' -and (($xx -ge 3 -and $xx -le 5 -and ($yy -eq $xx+2 -or $yy -eq $xx+3)) -or ($xx -ge 6 -and $xx -le 9 -and ($yy -eq 12-$xx -or $yy -eq 13-$xx)))) { $c=$black }
            }
            if ($kind -in @('radio','radioselected')) {
                $distance=($xx-6)*($xx-6)+($yy-6)*($yy-6)
                $c=[Drawing.Color]::Transparent
                if ($distance -le 36) { $c=$white; if ($xx+$yy -lt 12) { $c=$shadow } }
                if ($distance -le 23) { $c=$light; if ($xx+$yy -lt 12) { $c=$black } }
                if ($distance -le 15) { $c=$fill }
                if ($kind -eq 'radioselected' -and $distance -le 4) { $c=$black }
            }
            if ($kind -eq 'dots') {
                $c=[Drawing.Color]::Transparent
                if (($xx -eq 0 -or $xx -eq $w-1 -or $yy -eq 0 -or $yy -eq $h-1) -and ($xx+$yy)%2 -eq 0) { $c=$black }
            }
            if ($kind -eq 'horizontal') { if ($yy -eq 2) {$c=$shadow}; if ($yy -eq 3) {$c=$white} }
            if ($kind -eq 'vertical') { if ($xx -eq 2) {$c=$shadow}; if ($xx -eq 3) {$c=$white} }
            # Document tabs are open-bottom page dividers, not four-sided
            # push buttons. Inactive tabs sit two pixels below the active tab.
            if ($kind -in @('tabactive','tabinactive')) {
                $top=0; if ($kind -eq 'tabinactive') { $top=2 }
                $c=$face
                if ($yy -ge $top+2) {
                    $c=$fill
                    if ($xx -eq 0) { $c=$white }
                    if ($xx -eq 1) { $c=$light }
                    if ($xx -eq $w-2) { $c=$shadow }
                    if ($xx -eq $w-1) { $c=$black }
                }
                if ($yy -eq $top -and $xx -ge 2 -and $xx -le $w-3) { $c=$white }
                if ($yy -eq $top+1) {
                    if ($xx -eq 1) { $c=$white }
                    if ($xx -ge 2 -and $xx -le $w-3) { $c=$light }
                    if ($xx -eq $w-2) { $c=$black }
                }
            }
            # The page seam runs under inactive tabs and empty strip only.
            # The active tab interrupts it to connect with the panel below.
            if ($kind -eq 'tabseam') {
                if ($yy -eq 0) { $c=$white }
                if ($yy -eq 1) { $c=$light }
            }
            $atlas.SetPixel($px+$xx,$py+$yy,$c)
        }
    }
}
foreach ($part in $theme.theme.parts.part) {
    $id=$part.id
    if ($id -eq 'window') { $part.SetAttribute('h1','21') }
    if ($id -match '^window_button_') { $part.SetAttribute('w','14'); $part.SetAttribute('h','14') }
    if ($id -match '^(button_(normal|hot|focused|selected)|toolbutton_|buttonset_item_|drop_down_button_|window_button_)') {
        $kind='raised'
        if ($id -match 'focused') { $kind='focus' }
        if ($id -match 'selected|pushed') { $kind='sunken' }
        if ($id -match 'active' -or $id -eq 'toolbutton_hot') { $kind='latched' }
        Paint-Part $part $kind $face
    }
    elseif ($id -match '^(check|radio)_(normal|selected|disabled)$') {
        $part.SetAttribute('w','13'); $part.SetAttribute('h','13')
        $fill=$white; if ($id -match 'disabled') { $fill=$face }
        $kind='check'; if ($id -eq 'check_selected') { $kind='checked' }
        if ($id -match '^radio') { $kind='radio'; if ($id -eq 'radio_selected') { $kind='radioselected' } }
        Paint-Part $part $kind $fill
    }
    elseif ($id -match '^sunken') { Paint-Part $part 'sunken' $white }
    elseif ($id -eq 'window') { Paint-Part $part 'window' $face }
    elseif ($id -eq 'menu') { Paint-Part $part 'raised' $face }
    elseif ($id -in @('check_focus','radio_focus')) { Paint-Part $part 'dots' $face }
    elseif ($id -match '^(mini_|transparent_)?scrollbar_bg') { Paint-Part $part 'checker' $face }
    elseif ($id -match '^(mini_|transparent_)?scrollbar_thumb') { Paint-Part $part 'raised' $face }
    elseif ($id -in @('tab_normal','tab_active')) {
        $fill=Color 'b0b0b0'; $kind='tabinactive'
        if ($id -eq 'tab_active') { $fill=$face; $kind='tabactive' }
        Paint-Part $part $kind $fill
    }
    elseif ($id -eq 'tab_bottom_normal') { Paint-Part $part 'tabseam' $face }
    elseif ($id -in @('tab_bottom_active','tab_filler')) { Paint-Part $part 'flat' $face }
    elseif ($id -match '^tab_icon_bg') { Paint-Part $part 'raised' $face }
    elseif ($id -match '^editor_(normal|selected)$') { Paint-Part $part 'sunken' $shadow }
    elseif ($id -eq 'separator_horz') { Paint-Part $part 'horizontal' $face }
    elseif ($id -eq 'separator_vert') { Paint-Part $part 'vertical' $face }
    elseif ($id -match '^(mini_)?slider_(full|empty)(_focused)?$') {
        $fill=$white; if ($id -match 'full') { $fill=$navy }
        Paint-Part $part 'sunken' $fill
    }
    # timeline_none is a transparent text overlay, not an unselected gray cell.
    # Keeping the original preserves selection and user-defined layer colors.
    elseif ($id -match '^timeline_(normal|hover|active|active_hover|clicked|focused)$') {
        $fill=$face; if ($id -match 'active|clicked|focused') { $fill=$navy }
        Paint-Part $part 'raised' $fill
    }
    elseif ($id -match '^timeline_padding') { Paint-Part $part 'flat' $face }
}
# Button sets use selected for their persistent value, capture for a press.
# Keep their focus and pointer states separate, including selected + hover.
$buttonset=$theme.SelectSingleNode('/theme/styles/style[@id="buttonset_item"]')
foreach ($layer in @($buttonset.ChildNodes)) { $null=$buttonset.RemoveChild($layer) }
foreach ($spec in @(@('buttonset_item_normal',''), @('buttonset_item_hot','mouse'), @('buttonset_item_focused','focus'), @('buttonset_item_active','selected'), @('buttonset_item_active','selected mouse'), @('buttonset_item_hot_focused','selected focus'), @('buttonset_item_pushed','capture selected'), @('buttonset_item_pushed','mouse capture'))) {
    $layer=$theme.CreateElement('background-border'); $layer.SetAttribute('part',$spec[0])
    if ($spec[1]) { $layer.SetAttribute('state',$spec[1]) }
    $null=$buttonset.AppendChild($layer)
}
Paint-Part ($theme.SelectSingleNode('/theme/parts/part[@id="buttonset_item_hot_focused"]')) 'latchedfocus' $face
$theme.SelectSingleNode('/theme/styles/style[@id="window_with_title"]').SetAttribute('border-top','23')
foreach ($style in $theme.theme.styles.style | Where-Object { $_.id -in @('check_box','radio_button') }) {
    foreach ($label in $style.SelectNodes('text')) { $label.SetAttribute('x','18') }
}
# Neutral tabs use black glyphs; navy is reserved for captions and selection.
foreach ($style in $theme.theme.styles.style | Where-Object { $_.id -in @('tab_close_icon','tab_modified_icon','tab_home') }) {
    foreach ($icon in $style.SelectNodes('icon')) { $icon.SetAttribute('color','text') }
}
$theme.SelectSingleNode('/theme/styles/style[@id="separator_in_view_reverse"]/text').SetAttribute('color','text')
$theme.SelectSingleNode('/theme/styles/style[@id="workspace_check_box"]/text').SetAttribute('x','18')
# Black glyphs remain legible on pressed gray controls (list selections
# intentionally retain their white glyphs on navy).
foreach ($part in $theme.theme.parts.part | Where-Object { $_.id -match '^(combobox_arrow_.*|arrow_circle_cw|newfolder|drop_pixels_.*)_selected$' }) {
    for ($y=[int]$part.y; $y -lt [int]$part.y+[int]$part.h; $y++) {
        for ($x=[int]$part.x; $x -lt [int]$part.x+[int]$part.w; $x++) {
            if ($atlas.GetPixel($x,$y).A -gt 0) { $atlas.SetPixel($x,$y,$black) }
        }
    }
}
# Hovering recent-file rows uses the same selection colors as the menu.
foreach ($style in $theme.theme.styles.style | Where-Object { $_.id -in @('recent_file','recent_file_detail','news_item','news_item_detail') }) {
    $text = $theme.CreateElement('text'); $text.SetAttribute('color','selected_text')
    $text.SetAttribute('state','mouse'); $text.SetAttribute('align','left'); $text.SetAttribute('x','2')
    $null=$style.AppendChild($text)
}
$atlas.Save((Join-Path $output 'sheet.png'), [Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()
$settings=[Xml.XmlWriterSettings]::new(); $settings.Indent=$true; $settings.IndentChars='    '
$settings.Encoding=[Text.UTF8Encoding]::new($false)
$writer=[Xml.XmlWriter]::Create((Join-Path $output 'theme.xml'),$settings)
$theme.Save($writer); $writer.Dispose()
Copy-Item -LiteralPath (Join-Path $source 'LICENSE.txt') -Destination (Join-Path $output 'LICENSE.txt')
$build=Join-Path $root 'dist'
$null=New-Item -ItemType Directory -Force $build
$package=Join-Path $build 'windows-95.aseprite-extension'
# Only replace our generated archive, never a directory or installed theme.
if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package }
[IO.Compression.ZipFile]::CreateFromDirectory($output,$package)
Write-Output "Generated $($script:slot) native control parts; packaged $package"
