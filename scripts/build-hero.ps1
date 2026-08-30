param(
    [string]$InputPath = (Join-Path $PSScriptRoot '..\assets\neural-midnight-hero.png'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\assets\neural-midnight-hero.svg')
)

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$pngBytes = [System.IO.File]::ReadAllBytes($resolvedInput)
$pngBase64 = [Convert]::ToBase64String($pngBytes)

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1983 793" role="img" aria-labelledby="title description">
  <title id="title">Neural Midnight</title>
  <desc id="description">A dark two-dimensional illustration of a learner connected to neural networks, software, and data, with subtle animated data pulses.</desc>
  <style>
    .flow-line { fill: none; stroke-linecap: round; stroke-width: 2; opacity: .46; }
    .pulse { fill: #22d3ee; }
    .pulse-violet { fill: #a78bfa; }
    .node { fill: none; stroke-width: 2; transform-box: fill-box; transform-origin: center; animation: node-pulse 4.8s ease-in-out infinite; }
    .node.delay-1 { animation-delay: -1.6s; }
    .node.delay-2 { animation-delay: -3.2s; }
    .scan { animation: scan 8s ease-in-out infinite; }
    @keyframes node-pulse { 0%, 100% { opacity: .25; transform: scale(.82); } 50% { opacity: .9; transform: scale(1.12); } }
    @keyframes scan { 0%, 100% { opacity: 0; transform: translateX(-220px); } 18%, 82% { opacity: .42; } 50% { opacity: .65; transform: translateX(1980px); } }
    @media (prefers-reduced-motion: reduce) { .motion { display: none; } .node, .scan { animation: none; } }
  </style>

  <rect width="1983" height="793" fill="#050816" />
  <image width="1983" height="793" preserveAspectRatio="xMidYMid slice" href="data:image/png;base64,$pngBase64" />

  <g class="motion" aria-hidden="true">
    <path id="path-a" class="flow-line" stroke="#22d3ee" d="M92 311 C285 311 315 395 515 395 S745 323 941 323" />
    <path id="path-b" class="flow-line" stroke="#7c3aed" d="M905 481 C1122 481 1190 418 1375 418 S1608 328 1865 328" />
    <path id="path-c" class="flow-line" stroke="#a78bfa" d="M268 591 C430 591 485 523 641 523 S831 606 1003 606" />

    <circle class="pulse" r="5">
      <animateMotion dur="6.8s" repeatCount="indefinite" rotate="auto"><mpath href="#path-a" /></animateMotion>
    </circle>
    <circle class="pulse-violet" r="4">
      <animateMotion dur="7.9s" begin="-3s" repeatCount="indefinite" rotate="auto"><mpath href="#path-b" /></animateMotion>
    </circle>
    <circle class="pulse-violet" r="4">
      <animateMotion dur="8.7s" begin="-5s" repeatCount="indefinite" rotate="auto"><mpath href="#path-c" /></animateMotion>
    </circle>

    <circle class="node" cx="837" cy="92" r="12" stroke="#22d3ee" />
    <circle class="node delay-1" cx="937" cy="264" r="13" stroke="#22d3ee" />
    <circle class="node delay-2" cx="1760" cy="171" r="11" stroke="#a78bfa" />
    <circle class="node delay-1" cx="1732" cy="575" r="10" stroke="#22d3ee" />

    <rect class="scan" x="0" y="70" width="2" height="650" fill="#22d3ee" opacity="0" />
  </g>
</svg>
"@

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.File]::WriteAllText($resolvedOutput, $svg, [System.Text.UTF8Encoding]::new($false))
Write-Output "Built $resolvedOutput"
