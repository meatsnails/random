$ErrorActionPreference = "Stop"

if (-not $args[0]) {
        Write-Host "Please provide an image."
        exit 1
}

$image = $args[0]

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

foreach ($file in Get-ChildItem -File) {

        if ($file.Extension.ToLower() -notin $supported) { continue }

        $audio = $file.FullName
        $output = [System.IO.Path]::ChangeExtension($audio, ".mkv")

        Write-Host "Processing $audio..."

        & ffmpeg -hide_banner -loglevel error -y `
                -loop 1 -framerate 25 -i $image -i "$audio" `
                -map 0:v -map 1:a `
                -c:v $encoder @quality -pix_fmt yuv420p `
                -vf "scale='min(1920,iw*1080/ih)':'min(1080,ih*1920/iw)':force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
                -c:a aac -b:a 256k `
                -shortest -vsync 2 `
                "$output"

        Write-Host "Converted $audio to $output"
}

Write-Host "All files done!"
