$local:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Global Variables

$script:arguments = $args

$script:current_link   = ""
$script:current_index  = 0
$script:current_format = ""

$script:option_list = @(
    [Tuple]::Create("mp3",
                    @"
yt-dlp -x --audio-format mp3 -f "ba" --embed-metadata --embed-thumbnail #current_link -o ".\%(title)s.%(ext)s"
"@),
    [Tuple]::Create("mp4",
                    @"
yt-dlp --embed-metadata --embed-thumbnail -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" #current_link -o ".\%(title)s.%(ext)s"
"@)
)

enum Message_Type {
    MSG_INFO
    MSG_WARNING
    MSG_ERROR
    MSG_DEBUG
}

# Functions
# utility function, used to print messages on the console
function print_message {
    param([Message_Type]$type, [String]$message)
    switch ($type) {
        MSG_INFO {
            write-host -fore CYAN       $("[INFO] "    + $($message))
        }
        MSG_WARNING {
            write-host -fore DARKYELLOW $("[WARNING] " + $($message))
        }
        MSG_ERROR {
            write-host -fore RED        $("[ERROR] "   + $($message))
        }
        MSG_DEBUG {
            write-host -fore MAGENTA    $("[DEBUG] "   + $($message))
        }
        default {
            write-host -fore GRAY       $("[_] "       + $($message))
        }
    }
}

# manages the media download, checking if the link given is a valid one (at
# least if it isn't a malformed flag), and managing all the downloaded media in
# separate directories
function download_media {
    param()
    if($script:current_link[0] -eq '-') {
        # invalid link
        print_message MSG_WARNING "Possible broken link: $($script:current_link)"
        print_message MSG_WARNING "Continuing on next item..."
    } else {
        foreach ($tuple in $script:option_list) {
            if($script:current_format -eq "-" + $tuple.item1) {
                # media download
                $yt_command = $tuple.item2 -replace "#current_link", $script:current_link
                eval_command($yt_command)
                print_message MSG_INFO "Media downloaded successfully"
                mv_files;
                break
            }
        }
    }
}

# separates the files in different directories, according to their file type
function mv_files {
    [OutputType([void])]
    param()
    $ext_len = $script:current_format.length - 1
    $ext_clean = $script:current_format.substring(1, $ext_len)
    $is_path = Test-Path "./$ext_clean"
    if(-not $is_path) {
        print_message MSG_INFO "Creating directory: ./$ext_clean"
        $null = New-Item -ItemType Directory -Path "./$ext_clean"
    }
    $mv_command ="Move-Item ./*.$ext_clean ./$ext_clean/"
    eval_command($mv_command)
}

# checks a command and evaluates it
function eval_command {
    [OutputType([void])]
    param([string]$command)
    if ($command[0] -eq '"') {
        print_message MSG_INFO $("Executing command: " + $command)
        Invoke-Expression "& $command"
    }
    else {
        print_message MSG_INFO $("Executing command: " + $command)
        Invoke-Expression $command
    }
}

# checks if a flag given is a valid file format
function check_format {
    [OutputType([Boolean])]
    param([String]$ext)
    foreach ($tuple in $script:option_list) {
        if($ext -eq "-" + $tuple.Item1) {
           return $true;
        }
    }
    return $false;
}

# checks if the first argument is a file format, and skips until it finds a
# valid one
function check_begin_arguments {
    [OutputType([void])]
    param()
    if($script:arguments.length -le 1) {
        print_message MSG_ERROR "Not enough parameters"
        print_message MSG_INFO "Usage: -<fmt> <video link>"
        exit 1
    }
    if(-not $(check_format($script:arguments[0]))) {
        print_message MSG_WARNING "No format found to start with"
        print_message MSG_WARNING "Skipping links until valid format"
        skip_until_valid_format;
        if($script:current_index -gt $($script:arguments.length - 1)) {
            print_message MSG_ERROR "No valid format found"
            exit 2
        }
    }
}

# skips the arguments until it finds a valid file format
function skip_until_valid_format {
    [OutputType([Boolean])]
    param()
    while($script:current_index -lt $($script:arguments.length)) {
        if(check_format $script:arguments[$script:current_index]) {
            break
        } else {
            print_message MSG_WARNING "Skipped link: $($script:arguments[$script:current_index])"
            $script:current_index++
        }
    }
}

# checks if the last argument is a standalone file format
function check_last_argument {
    [OutputType([void])]
    param()
    if(check_format($($script:arguments[$script:current_index - 1]))) {
        print_message MSG_WARNING "Ignoring last element as is a valid format"
    }
}

# main loop of the execution, goes one by one on the arguments given by the user
# and does all the necessary checks by the function calls
function main_loop {
    [OutputType([void])]
    param()

    check_begin_arguments;
    while($script:current_index -le $($script:arguments.length - 1)) {
        if(check_format($script:arguments[$script:current_index])) {
            # file format case
            $script:current_format = $script:arguments[$script:current_index]
        } else {
            # video link case
            $script:current_link = $script:arguments[$script:current_index]
            download_media;
        }
        $script:current_index++
    }
    check_last_argument;
}

# writes the startup message
function presentation {
    [OutputType([void])]
    param()
    $intro = @"
   ______            ______            ______
  /\_____\          /\_____\          /\_____\          ____
 _\ \__/_/_         \ \__/_/_         \ \__/_/         /\___\
/\_\ \_____\        /\ \_____\        /\ \___\        /\ \___\
\ \ \/ / / /        \ \/ / / /        \ \/ / /        \ \/ / /
 \ \/ /\/ /          \/_/\/ /          \/_/_/          \/_/_/
  \/_/\/_/              \/_/
"@
    write-host -fore RED $intro
    write-host ""
    write-host ""
}

# Main
function main {
    param()
    presentation;
    main_loop;
    print_message MSG_INFO "Program terminated successfully"
    exit 0
}

main;
