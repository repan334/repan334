param(
    [string]$LogoPath = (Join-Path $PSScriptRoot '..\assets\reyy-logo-source.png'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\assets\reyy-ai-system-preview-v1.gif')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Clamp-Unit([double]$Value) {
    return [Math]::Max(0.0, [Math]::Min(1.0, $Value))
}

function Ease-Out-Cubic([double]$Value) {
    $t = Clamp-Unit $Value
    return 1.0 - [Math]::Pow(1.0 - $t, 3.0)
}

function Smooth-Step([double]$Value) {
    $t = Clamp-Unit $Value
    return $t * $t * (3.0 - (2.0 * $t))
}

function With-Alpha([System.Drawing.Color]$Color, [double]$Alpha) {
    $a = [int][Math]::Round(255.0 * (Clamp-Unit $Alpha))
    return [System.Drawing.Color]::FromArgb($a, $Color.R, $Color.G, $Color.B)
}

function New-RoundedRectanglePath(
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Radius
) {
    $diameter = $Radius * 2.0
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-Gif-AnimationMetadata(
    [string]$Path,
    [System.UInt16]$Delay
) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 14 -or [System.Text.Encoding]::ASCII.GetString($bytes, 0, 3) -ne 'GIF') {
        throw "The generated file is not a valid GIF: $Path"
    }

    $packed = $bytes[10]
    $cursor = 13
    if (($packed -band 0x80) -ne 0) {
        $globalColors = [Math]::Pow(2, (($packed -band 0x07) + 1))
        $cursor += [int](3 * $globalColors)
    }
    $extensionInsertionPoint = $cursor
    $controlExtensions = 0

    while ($cursor -lt $bytes.Length) {
        $marker = $bytes[$cursor]
        if ($marker -eq 0x3B) { break }

        if ($marker -eq 0x21) {
            if (($cursor + 1) -ge $bytes.Length) { throw 'Truncated GIF extension.' }
            $label = $bytes[$cursor + 1]
            if ($label -eq 0xF9) {
                if (($cursor + 7) -ge $bytes.Length -or $bytes[$cursor + 2] -ne 4) { throw 'Invalid GIF graphic control extension.' }
                $bytes[$cursor + 3] = [byte](($bytes[$cursor + 3] -band 0xE3) -bor 0x08)
                $bytes[$cursor + 4] = [byte]($Delay -band 0xFF)
                $bytes[$cursor + 5] = [byte](($Delay -shr 8) -band 0xFF)
                $controlExtensions++
                $cursor += 8
                continue
            }

            $cursor += 2
            while ($cursor -lt $bytes.Length) {
                $blockSize = [int]$bytes[$cursor]
                $cursor++
                if ($blockSize -eq 0) { break }
                $cursor += $blockSize
            }
            continue
        }

        if ($marker -eq 0x2C) {
            if (($cursor + 9) -ge $bytes.Length) { throw 'Truncated GIF image descriptor.' }
            $imagePacked = $bytes[$cursor + 9]
            $cursor += 10
            if (($imagePacked -band 0x80) -ne 0) {
                $localColors = [Math]::Pow(2, (($imagePacked -band 0x07) + 1))
                $cursor += [int](3 * $localColors)
            }
            $cursor++
            while ($cursor -lt $bytes.Length) {
                $blockSize = [int]$bytes[$cursor]
                $cursor++
                if ($blockSize -eq 0) { break }
                $cursor += $blockSize
            }
            continue
        }

        throw "Unexpected GIF block marker 0x$($marker.ToString('X2')) at byte $cursor."
    }

    if ($controlExtensions -eq 0) { throw 'The GIF contains no graphic control extensions.' }

    $loopExtension = [byte[]]@(
        0x21,0xFF,0x0B,
        0x4E,0x45,0x54,0x53,0x43,0x41,0x50,0x45,0x32,0x2E,0x30,
        0x03,0x01,0x00,0x00,0x00
    )
    $result = [System.Collections.Generic.List[byte]]::new($bytes.Length + $loopExtension.Length)
    $result.AddRange([byte[]]$bytes[0..($extensionInsertionPoint - 1)])
    $result.AddRange($loopExtension)
    $result.AddRange([byte[]]$bytes[$extensionInsertionPoint..($bytes.Length - 1)])
    [System.IO.File]::WriteAllBytes($Path, $result.ToArray())
}

function Draw-Polyline-Progress(
    [System.Drawing.Graphics]$Graphics,
    [System.Drawing.Pen]$Pen,
    [System.Drawing.PointF[]]$Points,
    [double]$Progress
) {
    $target = Clamp-Unit $Progress
    if ($target -le 0.0) { return }

    $lengths = [System.Collections.Generic.List[double]]::new()
    $total = 0.0
    for ($i = 0; $i -lt ($Points.Count - 1); $i++) {
        $dx = $Points[$i + 1].X - $Points[$i].X
        $dy = $Points[$i + 1].Y - $Points[$i].Y
        $length = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
        $lengths.Add($length)
        $total += $length
    }

    $remaining = $total * $target
    for ($i = 0; $i -lt $lengths.Count; $i++) {
        if ($remaining -le 0.0) { break }
        $segment = $lengths[$i]
        if ($remaining -ge $segment) {
            $Graphics.DrawLine($Pen, $Points[$i], $Points[$i + 1])
            $remaining -= $segment
        }
        else {
            $ratio = $remaining / $segment
            $endX = $Points[$i].X + (($Points[$i + 1].X - $Points[$i].X) * $ratio)
            $endY = $Points[$i].Y + (($Points[$i + 1].Y - $Points[$i].Y) * $ratio)
            $Graphics.DrawLine($Pen, $Points[$i], [System.Drawing.PointF]::new($endX, $endY))
            break
        }
    }
}

function Get-Point-On-Polyline(
    [System.Drawing.PointF[]]$Points,
    [double]$Progress
) {
    $target = Clamp-Unit $Progress
    $lengths = [System.Collections.Generic.List[double]]::new()
    $total = 0.0
    for ($i = 0; $i -lt ($Points.Count - 1); $i++) {
        $dx = $Points[$i + 1].X - $Points[$i].X
        $dy = $Points[$i + 1].Y - $Points[$i].Y
        $length = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
        $lengths.Add($length)
        $total += $length
    }

    $remaining = $total * $target
    for ($i = 0; $i -lt $lengths.Count; $i++) {
        if ($remaining -le $lengths[$i]) {
            $ratio = if ($lengths[$i] -eq 0.0) { 0.0 } else { $remaining / $lengths[$i] }
            return [System.Drawing.PointF]::new(
                $Points[$i].X + (($Points[$i + 1].X - $Points[$i].X) * $ratio),
                $Points[$i].Y + (($Points[$i + 1].Y - $Points[$i].Y) * $ratio)
            )
        }
        $remaining -= $lengths[$i]
    }
    return $Points[-1]
}

function Draw-Icon(
    [System.Drawing.Graphics]$Graphics,
    [string]$Kind,
    [float]$X,
    [float]$Y,
    [double]$Alpha,
    [System.Drawing.Color]$Accent,
    [System.Drawing.Font]$CodeFont
) {
    $lineColor = With-Alpha $Accent $Alpha
    $mutedColor = With-Alpha ([System.Drawing.ColorTranslator]::FromHtml('#64748B')) $Alpha
    $pen = [System.Drawing.Pen]::new($lineColor, 2.2)
    $mutedPen = [System.Drawing.Pen]::new($mutedColor, 1.6)
    $brush = [System.Drawing.SolidBrush]::new($lineColor)
    try {
        switch ($Kind) {
            'code' {
                $Graphics.DrawString('</>', $CodeFont, $brush, $X, $Y + 8)
            }
            'data' {
                $funnel = [System.Drawing.PointF[]]@(
                    [System.Drawing.PointF]::new($X + 3, $Y + 5),
                    [System.Drawing.PointF]::new($X + 49, $Y + 5),
                    [System.Drawing.PointF]::new($X + 32, $Y + 25),
                    [System.Drawing.PointF]::new($X + 32, $Y + 43),
                    [System.Drawing.PointF]::new($X + 21, $Y + 49),
                    [System.Drawing.PointF]::new($X + 21, $Y + 25),
                    [System.Drawing.PointF]::new($X + 3, $Y + 5)
                )
                $Graphics.DrawLines($pen, $funnel)
                $Graphics.FillEllipse($brush, $X + 6, $Y + 12, 5, 5)
                $Graphics.FillEllipse($brush, $X + 19, $Y + 12, 5, 5)
                $Graphics.FillEllipse($brush, $X + 32, $Y + 12, 5, 5)
            }
            'evaluation' {
                $Graphics.DrawLine($mutedPen, $X + 5, $Y + 48, $X + 50, $Y + 48)
                $Graphics.DrawLine($mutedPen, $X + 5, $Y + 48, $X + 5, $Y + 6)
                $Graphics.FillRectangle($brush, $X + 12, $Y + 31, 7, 17)
                $Graphics.FillRectangle($brush, $X + 24, $Y + 21, 7, 27)
                $Graphics.FillRectangle($brush, $X + 36, $Y + 11, 7, 37)
                $Graphics.DrawLines($pen, [System.Drawing.PointF[]]@(
                    [System.Drawing.PointF]::new($X + 32, $Y + 11),
                    [System.Drawing.PointF]::new($X + 39, $Y + 18),
                    [System.Drawing.PointF]::new($X + 52, $Y + 3)
                ))
            }
            'neural' {
                $nodes = @(
                    @([float]($X + 6), [float]($Y + 13)), @([float]($X + 6), [float]($Y + 41)),
                    @([float]($X + 27), [float]($Y + 7)), @([float]($X + 27), [float]($Y + 27)), @([float]($X + 27), [float]($Y + 47)),
                    @([float]($X + 50), [float]($Y + 18)), @([float]($X + 50), [float]($Y + 38))
                )
                foreach ($left in 0..1) {
                    foreach ($middle in 2..4) {
                        $Graphics.DrawLine($mutedPen, $nodes[$left][0], $nodes[$left][1], $nodes[$middle][0], $nodes[$middle][1])
                    }
                }
                foreach ($middle in 2..4) {
                    foreach ($right in 5..6) {
                        $Graphics.DrawLine($mutedPen, $nodes[$middle][0], $nodes[$middle][1], $nodes[$right][0], $nodes[$right][1])
                    }
                }
                foreach ($node in $nodes) { $Graphics.FillEllipse($brush, $node[0] - 3, $node[1] - 3, 7, 7) }
            }
            'regression' {
                $Graphics.DrawLine($mutedPen, $X + 4, $Y + 49, $X + 53, $Y + 49)
                $Graphics.DrawLine($mutedPen, $X + 4, $Y + 49, $X + 4, $Y + 5)
                $Graphics.DrawLine($pen, $X + 8, $Y + 42, $X + 51, $Y + 10)
                foreach ($point in @(@(12,38),@(18,32),@(26,35),@(32,24),@(39,20),@(47,14))) {
                    $Graphics.FillEllipse($brush, $X + $point[0] - 2, $Y + $point[1] - 2, 5, 5)
                }
            }
            'classification' {
                foreach ($point in @(@(8,12),@(20,22),@(9,36))) {
                    $Graphics.FillEllipse($brush, $X + $point[0], $Y + $point[1], 8, 8)
                }
                foreach ($point in @(@(36,9),@(47,22),@(37,37))) {
                    $Graphics.FillRectangle($brush, $X + $point[0], $Y + $point[1], 8, 8)
                }
                $Graphics.DrawLine($mutedPen, $X + 29, $Y + 3, $X + 29, $Y + 51)
            }
        }
    }
    finally {
        $pen.Dispose()
        $mutedPen.Dispose()
        $brush.Dispose()
    }
}

function Draw-Card(
    [System.Drawing.Graphics]$Graphics,
    [pscustomobject]$Card,
    [double]$Progress,
    [System.Drawing.Font]$TitleFont,
    [System.Drawing.Font]$DetailFont,
    [System.Drawing.Font]$CodeFont
) {
    $alpha = Smooth-Step $Progress
    if ($alpha -le 0.0) { return }

    $direction = if ($Card.Side -eq 'left') { -1.0 } else { 1.0 }
    $offset = [float]($direction * (1.0 - $alpha) * 18.0)
    $x = [float]($Card.X + $offset)
    $y = [float]$Card.Y

    $surface = With-Alpha ([System.Drawing.ColorTranslator]::FromHtml('#0B1026')) (0.94 * $alpha)
    $border = With-Alpha ([System.Drawing.ColorTranslator]::FromHtml('#312E81')) $alpha
    $titleColor = With-Alpha ([System.Drawing.ColorTranslator]::FromHtml('#E2E8F0')) $alpha
    $detailColor = With-Alpha ([System.Drawing.ColorTranslator]::FromHtml('#94A3B8')) $alpha
    $accent = [System.Drawing.ColorTranslator]::FromHtml($Card.Accent)

    $surfaceBrush = [System.Drawing.SolidBrush]::new($surface)
    $borderPen = [System.Drawing.Pen]::new($border, 1.5)
    $titleBrush = [System.Drawing.SolidBrush]::new($titleColor)
    $detailBrush = [System.Drawing.SolidBrush]::new($detailColor)
    $accentPen = [System.Drawing.Pen]::new((With-Alpha $accent $alpha), 3.0)
    $cardPath = New-RoundedRectanglePath $x $y 350 100 14
    try {
        $Graphics.FillPath($surfaceBrush, $cardPath)
        $Graphics.DrawPath($borderPen, $cardPath)
        $Graphics.DrawLine($accentPen, $x + 1.5, $y + 14, $x + 1.5, $y + 86)
        Draw-Icon $Graphics $Card.Icon ($x + 24) ($y + 22) $alpha $accent $CodeFont
        $Graphics.DrawString($Card.Title, $TitleFont, $titleBrush, $x + 99, $y + 23)
        $Graphics.DrawString($Card.Detail, $DetailFont, $detailBrush, $x + 100, $y + 58)
    }
    finally {
        $surfaceBrush.Dispose()
        $borderPen.Dispose()
        $titleBrush.Dispose()
        $detailBrush.Dispose()
        $accentPen.Dispose()
        $cardPath.Dispose()
    }
}

$canvasWidth = 1400
$canvasHeight = 620
$width = 1120
$height = 496
$frameCount = 30
$frameDelay = [System.UInt16]12

$background = [System.Drawing.ColorTranslator]::FromHtml('#050816')
$gridColor = [System.Drawing.ColorTranslator]::FromHtml('#172554')
$cyan = [System.Drawing.ColorTranslator]::FromHtml('#22D3EE')
$violet = [System.Drawing.ColorTranslator]::FromHtml('#7C3AED')

$cards = @(
    [pscustomobject]@{ X=45; Y=45; Side='left'; Title='SOURCE CODE'; Detail='build / test / iterate'; Icon='code'; Accent='#22D3EE' },
    [pscustomobject]@{ X=45; Y=260; Side='left'; Title='DATA PREPARATION'; Detail='clean / transform / prepare'; Icon='data'; Accent='#22D3EE' },
    [pscustomobject]@{ X=45; Y=475; Side='left'; Title='MODEL EVALUATION'; Detail='measure / validate / improve'; Icon='evaluation'; Accent='#A78BFA' },
    [pscustomobject]@{ X=1005; Y=45; Side='right'; Title='NEURAL NETWORKS'; Detail='layers / signals / learning'; Icon='neural'; Accent='#7C3AED' },
    [pscustomobject]@{ X=1005; Y=260; Side='right'; Title='LINEAR REGRESSION'; Detail='features / fit / prediction'; Icon='regression'; Accent='#22D3EE' },
    [pscustomobject]@{ X=1005; Y=475; Side='right'; Title='CLASSIFICATION'; Detail='classes / labels / categories'; Icon='classification'; Accent='#A78BFA' }
)

$paths = @(
    [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(610,270),[System.Drawing.PointF]::new(540,270),[System.Drawing.PointF]::new(540,95),[System.Drawing.PointF]::new(395,95)),
    [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(610,310),[System.Drawing.PointF]::new(520,310),[System.Drawing.PointF]::new(395,310)),
    [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(610,350),[System.Drawing.PointF]::new(540,350),[System.Drawing.PointF]::new(540,525),[System.Drawing.PointF]::new(395,525)),
    [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(790,270),[System.Drawing.PointF]::new(860,270),[System.Drawing.PointF]::new(860,95),[System.Drawing.PointF]::new(1005,95)),
    [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(790,310),[System.Drawing.PointF]::new(880,310),[System.Drawing.PointF]::new(1005,310)),
    [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(790,350),[System.Drawing.PointF]::new(860,350),[System.Drawing.PointF]::new(860,525),[System.Drawing.PointF]::new(1005,525))
)

$resolvedLogo = (Resolve-Path -LiteralPath $LogoPath).Path
$logo = [System.Drawing.Bitmap]::FromFile($resolvedLogo)
$titleFont = [System.Drawing.Font]::new('Segoe UI Semibold', 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$detailFont = [System.Drawing.Font]::new('Segoe UI', 14, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$codeFont = [System.Drawing.Font]::new('Consolas', 25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$encoder = [System.Windows.Media.Imaging.GifBitmapEncoder]::new()

try {
    for ($frameIndex = 0; $frameIndex -lt $frameCount; $frameIndex++) {
        # Keep the full system readable in every frame. Only the signal packets and
        # orbit nodes move, so the first-frame preview never looks blank or broken.
        $time = $frameIndex / [double]$frameCount
        $logoProgress = 1.0

        $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
            $graphics.Clear($background)
            $graphics.ScaleTransform($width / [float]$canvasWidth, $height / [float]$canvasHeight)

            $gridBrush = [System.Drawing.SolidBrush]::new((With-Alpha $gridColor 0.34))
            try {
                for ($gx = 20; $gx -lt $canvasWidth; $gx += 40) {
                    for ($gy = 20; $gy -lt $canvasHeight; $gy += 40) {
                        $graphics.FillEllipse($gridBrush, $gx, $gy, 2, 2)
                    }
                }
            }
            finally { $gridBrush.Dispose() }

            for ($index = 0; $index -lt $cards.Count; $index++) {
                $accent = if (($index % 2) -eq 0) { $cyan } else { $violet }
                $branchPen = [System.Drawing.Pen]::new((With-Alpha $accent 0.82), 2.0)
                try {
                    $branchPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                    $branchPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                    Draw-Polyline-Progress $graphics $branchPen $paths[$index] 1.0
                }
                finally { $branchPen.Dispose() }

                Draw-Card $graphics $cards[$index] 1.0 $titleFont $detailFont $codeFont

                $travel = ($time + ($index * 0.13)) % 1.0
                $packet = Get-Point-On-Polyline $paths[$index] $travel
                $packetBrush = [System.Drawing.SolidBrush]::new((With-Alpha $accent 0.95))
                try { $graphics.FillEllipse($packetBrush, $packet.X - 3, $packet.Y - 3, 7, 7) }
                finally { $packetBrush.Dispose() }
            }

            if ($logoProgress -gt 0.0) {
                $logoScale = 0.82 + (0.18 * $logoProgress)
                $logoSize = [float](180.0 * $logoScale)
                $logoX = [float](700.0 - ($logoSize / 2.0))
                $logoY = [float](310.0 - ($logoSize / 2.0))
                $plateSize = [float](216.0 * $logoScale)
                $plateX = [float](700.0 - ($plateSize / 2.0))
                $plateY = [float](310.0 - ($plateSize / 2.0))

                $plateBrush = [System.Drawing.SolidBrush]::new((With-Alpha ([System.Drawing.ColorTranslator]::FromHtml('#0B1026')) (0.98 * $logoProgress)))
                $ringPen = [System.Drawing.Pen]::new((With-Alpha $cyan $logoProgress), 2.5)
                try {
                    $graphics.FillEllipse($plateBrush, $plateX, $plateY, $plateSize, $plateSize)
                    $graphics.DrawEllipse($ringPen, $plateX, $plateY, $plateSize, $plateSize)
                }
                finally {
                    $plateBrush.Dispose()
                    $ringPen.Dispose()
                }

                $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
                try {
                    $attributes.SetColorKey(
                        [System.Drawing.Color]::FromArgb(242,242,242),
                        [System.Drawing.Color]::FromArgb(255,255,255)
                    )
                    $matrix = [System.Drawing.Imaging.ColorMatrix]::new()
                    $matrix.Matrix33 = [float]$logoProgress
                    $attributes.SetColorMatrix($matrix)
                    $destination = [System.Drawing.Rectangle]::new([int]$logoX, [int]$logoY, [int]$logoSize, [int]$logoSize)
                    $graphics.DrawImage($logo, $destination, 34, 54, 390, 390, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
                }
                finally { $attributes.Dispose() }

                $orbitAngle = $time * [Math]::PI * 2.0
                for ($orbitIndex = 0; $orbitIndex -lt 3; $orbitIndex++) {
                    $angle = $orbitAngle + (($orbitIndex * 2.0 * [Math]::PI) / 3.0)
                    $orbitX = 700.0 + ([Math]::Cos($angle) * ($plateSize / 2.0))
                    $orbitY = 310.0 + ([Math]::Sin($angle) * ($plateSize / 2.0))
                    $orbitBrush = [System.Drawing.SolidBrush]::new((With-Alpha $(if ($orbitIndex -eq 1) { $violet } else { $cyan }) $logoProgress))
                    try { $graphics.FillEllipse($orbitBrush, [float]($orbitX - 3.5), [float]($orbitY - 3.5), 7, 7) }
                    finally { $orbitBrush.Dispose() }
                }
            }
        }
        finally { $graphics.Dispose() }

        $memory = [System.IO.MemoryStream]::new()
        try {
            $bitmap.Save($memory, [System.Drawing.Imaging.ImageFormat]::Png)
            $memory.Position = 0
            $decoder = [System.Windows.Media.Imaging.PngBitmapDecoder]::new(
                $memory,
                [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
                [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            )
            $source = $decoder.Frames[0]
            $metadata = [System.Windows.Media.Imaging.BitmapMetadata]::new('gif')
            $metadata.SetQuery('/grctlext/Delay', $frameDelay)
            $metadata.SetQuery('/grctlext/Disposal', [byte]2)
            if ($frameIndex -eq 0) {
                $metadata.SetQuery('/appext/Application', [System.Text.Encoding]::ASCII.GetBytes('NETSCAPE2.0'))
                $metadata.SetQuery('/appext/Data', [byte[]]@(3,1,0,0))
            }
            $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create($source, $null, $metadata, $null)
            $encoder.Frames.Add($frame)
        }
        finally {
            $memory.Dispose()
            $bitmap.Dispose()
        }
    }

    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutput)
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $file = [System.IO.File]::Open($resolvedOutput, [System.IO.FileMode]::Create)
    try { $encoder.Save($file) }
    finally { $file.Dispose() }

    Set-Gif-AnimationMetadata $resolvedOutput $frameDelay

    Write-Output "Built $resolvedOutput"
}
finally {
    $logo.Dispose()
    $titleFont.Dispose()
    $detailFont.Dispose()
    $codeFont.Dispose()
}
