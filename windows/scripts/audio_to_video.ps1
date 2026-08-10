param(
        [string]$Image,
        [switch]$Combine
)

$ErrorActionPreference = "Stop"

if (-not $Image) {
        Write-Host "Usage: script.ps1 <image> [-Combine]"
        exit 1
}

# GPU and encoder
$gpu = (Get-WmiObject Win32_VideoController).Name

if ($gpu -like "*NVIDIA*") {
        $encoder = "h264_nvenc"
        $quality = @("-rc:v", "vbr_hq", "-cq", "19", "-b:v", "0")
}
elseif ($gpu -like "*AMD*") {
        $encoder = "h264_amf"
        $quality = @("-rc:v", "cqp", "-qp", "19")
}
else {
        $encoder = "libx264"
        $quality = @("-crf", "18", "-preset", "slow", "-tune", "stillimage")
}

Write-Host "using encoder for $gpu"

# audio formats
$supported = ".wav", ".flac", ".mp3", ".ogg"

$audioFiles = Get-ChildItem -File | Where-Object {
        $_.Extension.ToLower() -in $supported
} | Sort-Object Name | Where-Object {

        $probe = ffprobe -v error `
                -select_streams a `
                -show_entries stream=codec_type `
                -of csv=p=0 `
                $_.FullName 2>$null

        if ($probe -eq "audio") {
                $true
        }
}


if ($Combine) {

        if ($audioFiles.Count -eq 0) {
                Write-Host "No audio files found."
                exit 1
        }

        Write-Host "Combining $($audioFiles.Count) audio files..."

        $ffmpegInputs = @()
        $concatParts = @()

        for ($i = 0; $i -lt $audioFiles.Count; $i++) {

                $ffmpegInputs += "-i"
                $ffmpegInputs += $audioFiles[$i].FullName

                $concatParts += "[$($i + 1):a]"
        }

        $filter = ($concatParts -join "") + "concat=n=$($audioFiles.Count):v=0:a=1[outa]"

        $output = "combined.mkv"

        & ffmpeg -hide_banner -loglevel error -y `
                -loop 1 -framerate 25 -i $Image `
                @ffmpegInputs `
                -filter_complex $filter `
                -map 0:v -map "[outa]" `
                -c:v $encoder @quality -pix_fmt yuv420p `
                -vf "scale='min(1920,iw*1080/ih)':'min(1080,ih*1920/iw)':force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
                -c:a aac -b:a 256k `
                -shortest `
                "$output"

        Write-Host "Created $output"
        return
}


foreach ($file in Get-ChildItem -File) {

        if ($file.Extension.ToLower() -notin $supported) { continue }

        $audio = $file.FullName
        $output = [System.IO.Path]::ChangeExtension($audio, ".mkv")

        Write-Host "Processing $audio..."

        & ffmpeg -hide_banner -loglevel error -y `
                -loop 1 -framerate 25 -i $Image -i "$audio" `
                -map 0:v -map 1:a `
                -c:v $encoder @quality -pix_fmt yuv420p `
                -vf "scale='min(1920,iw*1080/ih)':'min(1080,ih*1920/iw)':force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
                -c:a aac -b:a 256k `
                -shortest -vsync 2 `
                "$output"

        Write-Host "Converted $audio to $output"
}

Write-Host "All files done!"
