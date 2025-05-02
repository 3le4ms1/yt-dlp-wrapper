$local:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Global Variables

$script:arguments = $args

$script:current_link   = ""
$script:current_index  = 0
$script:current_format = ""

$script:help_header = "usage: ./script.ps1 <fmt> <media_link> ... [<fmt> <media_link> ...] ..."

$script:option_list = @(
    [Tuple]::Create("mp3",
                    @"
yt-dlp -x --audio-format mp3 -f "ba" --embed-metadata --embed-thumbnail #current_link -o ".\%(playlist_index)s %(title)s.%(ext)s"
"@),
    [Tuple]::Create("mp4",
                    @"
yt-dlp --embed-metadata --embed-thumbnail -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" #current_link -o ".\%(title)s.%(ext)s"
"@)
)
$script:passed_arguments=""

$script:dependencies = @("ffmpeg", "yt-dlp")

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
            write-host -fore GRAY       $("[>_>] "     + $($message))
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
                # clear useless signature arguments from yt link
                $link = "$($script:current_link)"
                $link = $link -replace "\?si=[a-zA-Z0-9]*", ""
                # media download
                $yt_command = $tuple.item2 -replace "#current_link", "'$link'"
                if (eval_command($yt_command)) {
                    print_message MSG_INFO "Media downloaded successfully"
                } else {
                    print_message MSG_ERROR "Unable to download Media"
                }
                fix_file_names;
                mv_files;
                break;
            }
        }
    }
}

# fix file name altered in case of playlist_index not present.
# Automatically, yt-dlp adds to the string `NA ' replacing the field playlist_index
# TODO: fix edge case when $file.Name contains `'' and
function fix_file_names {
    [OutputType([void])]
    $files = ls -Filter "NA *.mp3"
    foreach($file in $files) {
        $command = "Move-Item '$($file.Name)' '"
        $command += $($file.Name -replace "^NA ") + "'"
        if (eval_command($command)) {
            print_message MSG_INFO "File renamed successfully"
        } else {
            print_message MSG_INFO "File not renamed successfully: $file.Name"
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
    $mv_command = "Move-Item ./*.$ext_clean ./$ext_clean/"
    try{
        if (eval_command($mv_command)) {
            print_message MSG_INFO "Cleaned the mess"
        }

    } catch {
        # file with same name exists in destination folder
        print_message MSG_ERROR "Mess is still here. Trying to fix"
        print_message MSG_WARNING "Salting file name"
        $child = Get-Childitem "*.$ext_clean"
        $file = $child.Name
        $chars = "0123456789ABCDEF".ToCharArray()
        $salt = ""
        for ($i = 0; $i -lt 5; $i++) {
            $salt += $chars[(Get-Random $chars.Length)]
        }
        $file_new_name = $file -replace ".$ext_clean", " - $salt.$ext_clean"
        if (eval_command "Move-Item $file $file_new_name") {
            if (eval_command($mv_command)) {
                print_message MSG_INFO "Cleaned the mess"
            } else {
                print_message MSG_ERROR "Ness is still here. Unable to fix automatically"
            }
        }
    }
}

# checks a command and evaluates it
function eval_command {
    [OutputType([Boolean])]
    param([string]$command)

    $command_and_args = $command
    if ($command.StartsWith("yt-dlp")) {
        $command_and_args = $command + $script:passed_arguments
    }

    print_message MSG_INFO $("Executing command: $command_and_args")
    Invoke-Expression "$command_and_args"
    return $?
}

# checks if a flag given is a valid file format
function check_format {
    [OutputType([Boolean])]
    param([String]$ext_flag)
    foreach ($tuple in $script:option_list) {
        if($ext_flag -eq ("-" + $tuple.Item1)) {
           return $true;
        }
    }
    return $false;
}

function print_help_message {
    [OutputType([void])]
    param()
    $help_message = @"
${script:help_header}
Where fmt is the output format of the media conversion.

Misc Arguments:
  -h|--help  display this help message
  -xXXX      pass argument XXX directly to yt-dlp
  -X         reset arguments passed directly to yt-dlp

Formats:
The formats currently supported are the following:
  -mp3       lossy audio format
  -mp4       lossy video format

The quality of the final media should be the best yt-dlp can generate.
"@
    write-host $help_message
}

# checks if the first argument is a file format, and skips until it finds a
# valid one
function check_begin_arguments {
    [OutputType([void])]
    param()
    if($script:arguments.length -eq 0) {
        print_message MSG_ERROR "Not enough parameters"
        print_message MSG_INFO  ${script:help_header}
        print_message MSG_INFO  "usage: In alternative provide parameter --help or -help to print help message"
        exit 1
    }
    elseif(($script:arguments[0] -eq "--help") -or
           ($script:arguments[0] -eq "-help")) {
        print_help_message;
        exit 0
    }
    elseif(-not $(check_format($script:arguments[0]))) {
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
        $arg = $script:arguments[$script:current_index]
        if(check_format($arg)) {
            # file format case
            $script:current_format = $arg
            print_message MSG_INFO "Extension set: $script:current_format"
        } elseif($arg.StartsWith("-x")) {
            $script:passed_arguments+=" " + $arg.Remove(0, 2) + " "
        } elseif($arg -eq "-X") {
            $script:passed_arguments = ""
        } else {
            # media link case
            $script:current_link = $arg
            download_media;
        }
        $script:current_index++
    }
    check_last_argument;
}

function check_dependencies {
    foreach ($dep in $script:dependencies) {
        $check = $false
        try {
            $check = Test-Path (get-command $dep).Source
        } catch {}
        if (-not $check) {
            print_message MSG_ERROR "$dep not found on PATH"
            print_message MSG_ERROR "Abort"
            exit 1
        }
    }
}

# writes the startup message
function presentation {
    [OutputType([void])]
    param()
    $intro = @"
       _                _  _
      | |_             | || |
 _   _|  _| ______  _ _| || | _ _ _
| | | | |  |______||  _  || ||  _  |
| |_| | |_         | |_| || || |_| |
 \__  |\__|        |_ _ _||_||  _ _|
 ___| |                      | |
 \___/                       |_|
"@;
    write-host -fore RED $intro
    write-host ""
}

# Main
function _main {
    param()
    try {
        $error.clear()
        presentation;
        print_message MSG_INFO "Program terminated successfully"
        check_dependencies;
        main_loop;
        print_message MSG_INFO "Program terminated successfully"
    } catch {
        print_message MSG_WARNING $_
        print_message MSG_WARNING "Line: $($_.InvocationInfo.ScriptLineNumber)"
        print_message MSG_WARNING "Program terminated abnormally"
        $error.clear()
    }

    exit 0
}

_main;
