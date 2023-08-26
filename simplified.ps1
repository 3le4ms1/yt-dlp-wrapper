$local:ErrorActionPreference = "Stop"

# main

if ($args[1] -eq $null) {
    write-host "First Argument:  " $args[0]
    write-host "Second Argument: " $args[1]
    write-host -fore RED "ERROR: Not enough parameters"
    exit 1
} else {
    if($args[0] -eq "-mp3") {
        write-host "Downloading mp3: $($args[1])"
        & yt-dlp -x --audio-format mp3 -f "ba" --embed-metadata
    --embed-thumbnail $args[1] -o ".\%(title)s.%(ext)s"
        . mv "./*.mp3" "./mp3/"
    } elseif ($args[0] -eq "-mp4") {
        write-host "Downloading mp4: $($args[1])"
        & yt-dlp --embed-metadata --embed-thumbnail -f
    "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" $args[1] -o
    ".\%(title)s.%(ext)s"
        . mv "./*.mp4" "./mp4/"
    } else {
        write-host -fore RED "ERROR: Option not recognized"
    }
}
