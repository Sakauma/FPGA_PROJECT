param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Read-ByteText {
    param([string]$Path)
    $enc = [System.Text.Encoding]::GetEncoding(28591)
    return $enc.GetString([System.IO.File]::ReadAllBytes($Path))
}

function Require-Match {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )
    if ($Text -notmatch $Pattern) {
        throw "FAIL: $Message"
    }
}

function Require-NoMatch {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )
    if ($Text -match $Pattern) {
        throw "FAIL: $Message"
    }
}

$topPath = Join-Path $RepoRoot "20_HDL/22_User/EB4110/SRIO_VIDEO/eb4110_video_srio_top.v"
$videoPath = Join-Path $RepoRoot "20_HDL/22_User/SRIO_2_BRAM/SRIO_2_Video.v"

$top = Read-ByteText $topPath
$video = Read-ByteText $videoPath

Require-Match $top "\.srio_t_axis_tuser\s*\(\s*video_t_tuser\s*\)" "video_t_tuser is not connected from srio_video_frame_d_speed"
Require-Match $top "assign\s+video_t_tkeep\s*=\s*8'hFF\s*;" "video_t_tkeep is not fixed to 8'hFF"
Require-NoMatch $top "assign\s+video_t_tuser\s*=" "video_t_tuser has a top-level override instead of using SRIO_2_Video output"
Require-Match $top "\.s_axis_iotx_tkeep\s*\(\s*\{\s*video_t_tkeep\s*," "SRIO IP input keep does not include video_t_tkeep"
Require-Match $top "\.s_axis_iotx_tuser\s*\(\s*\{\s*video_t_tuser\s*," "SRIO IP input user does not include video_t_tuser"
Require-Match $video "assign\s+SRIO_T_axis_tuser\s*=\s*32'h0001000a\s*;" "SRIO_2_Video does not drive expected video tuser"

Write-Host "PASS: SRIO output contract wiring"
