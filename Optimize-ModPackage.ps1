Function Optimize-ModPackage {

    #Requires -Version 7
    [CmdletBinding(DefaultParameterSetName = 'Path')]

    <#
    .SYNOPSIS
        Optimizes a mod package by removing clutter.
    
    .PARAMETER Path
        Path to pre-extracted mod root directory.

    .PARAMETER SetPacker
        Sets a persistent path to the SCS Packer executable.
        Must be set per-session.

    .PARAMETER PackerPath
        Path to the SCS Packer executable.

    .PARAMETER ModPackage
        The .scs mod package to unpack.

    .PARAMETER Root
        Destination folder for unpacked files.

    .PARAMETER NoScrub
        Disables file scrubbing.

    .PARAMETER KeepEmpty
        Retains empty subdirectories.

    .PARAMETER NoAttribFix
        Disables fixing file and folder attributes.

    .PARAMETER NoUnitFix
        Disables automatic fixes of detected problems in unit files.

    .PARAMETER KeepForeign
        Retains foreign/invalid files.

    .PARAMETER NoBinaryCheck
        Disables the safeguard for binary data scrubbing.
        Note: Misidentification of binary files as plaintext may occur in rare circumstances.

    .PARAMETER NoManifestFix
        Disables mod manifest fixes, which include:
            - Icon file reference errors
            - Description file reference errors
            - Excess category definitions trimming

    .PARAMETER ScrubExtensions
        File extensions to target for scrubbing (default: .mat, .sui, .sii, .guids, .soundref).
        Note: Targeting .txt files is not recommended.

    .PARAMETER BufferLimit
        Limits I/O buffers during file unpacking.

    .PARAMETER Force
        Forces overwriting of files in the destination folder.

    .PARAMETER ForceAcceptModRoot
        Accepts any mod root structure, bypassing validation.

    .PARAMETER Repackage
        Repackages the mod into a HashFS v2 package after processing.

    .PARAMETER NoCompression
        Disables compression during repackaging (results in a larger file but faster process).

    .PARAMETER NoCleanup
        Retains unpacked files after repackaging.

    .INPUT
        System.IO.FileInfo
        System.IO.DirectoryInfo
    #>

    Param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'SetPacker', Position = 0)]
        # Valid if --- 1: Has 'Archive' attribute. 2: Exists. 3: Extension equals '.exe'. 4: Header equals 'MZ'
        [ValidateScript({
            [Byte[]]$fHead = [Byte[]]::New(2)
            If ([Bool]($_.Attributes.Value__ -bAnd 32) -And $_.Exists -And $_.Extension -eq '.exe') {
                [IO.FileStream]$Stream = [IO.File]::OpenRead($_.FullName)
                [Void]$Stream.Read($fHead, 0, 2)
                $Stream.Close()
            }
            [Char[]]$fHead -Join '' -ceq 'MZ'
        })]
        [IO.FileInfo]$SetPacker,

        [Parameter(ValueFromPipeline, ParameterSetName = 'Path', Position = 0)]
        # Valid if --- Has 'Directory' attribute. 2: Exists
        [ValidateScript({[Bool]($_.Attributes.Value__ -bAnd 16) -And $_.Exists})]
        [IO.DirectoryInfo]$Path,

        [Parameter(ParameterSetName = 'Extract')]
        [Alias('Packer')]
        [IO.FileInfo]$PackerPath,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Extract')]
        # Valid if --- 1: Has 'Archive' attribute. 2: Exists. 3: Header equals 'SCS#'
        [ValidateScript({
            [Byte[]]$fHead = [Byte[]]::New(4)
            If ([Bool]($_.Attributes.Value__ -bAnd 32) -And $_.Exists) {
                [IO.FileStream]$Stream = [IO.File]::OpenRead($_.FullName)
                [Void]$Stream.Read($fHead, 0, 4)
                $Stream.Close()
            }
            [Char[]]$fHead -Join '' -ceq 'SCS#'
        })]
        [Alias('Mod', 'File')]
        [IO.FileInfo]$ModPackage,

        [Parameter(ParameterSetName = 'Extract')]
        [IO.DirectoryInfo]$Root,

        [Parameter(ParameterSetName = 'Extract')]
        [Alias('Lim')]
        [UInt16]$BufferLimit,

        [Parameter(ParameterSetName = 'Extract')]
        [Alias('F')]
        [Switch]$Force,

        [Parameter(ParameterSetName = 'Extract')]
        [Alias('Repack')]
        [Switch]$Repackage,

        [Parameter(ParameterSetName = 'Extract')]
        [Alias('NoComp')]
        [Switch]$NoCompression,

        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$NoCleanup,

        # File extensions to scrub (Files containing binary data will be skipped by default regardless of extensions entered. Use -NoBinaryCheck to force.)
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [ValidateScript({ForEach ($Item in $_) {If ($Item -NotMatch '^\.[a-z0-9]+$') {$False; Break}} $True})]
        [String[]]$ScrubExtensions = @('.mat', '.sui', '.sii', '.guids', '.soundref'),
        
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$NoScrub,       # Disables file scrubbing

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$KeepEmpty,     # Disables empty subdirectory deletion

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$NoUnitFix,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$NoAttribFix,   # Disables attribute fixing

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$KeepForeign,   # Disables foreign file deletion

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$NoBinaryCheck, # Disables safeguard against binary data scrubbing

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Extract')]
        [Switch]$NoManifestFix  # Disables mod manifest fixing

    )

    If ($PSCmdlet.ParameterSetName -eq 'SetPacker') {

        If (!$SetPacker.Exists) {Throw [IO.IOException]::New("The specified SCS Packer path '$($SetPacker.FullName)' does not exist.")}
        ElseIf ($SetPacker.Extension -ne '.exe') {Throw [IO.IOException]::New("The specified SCS Packer path '$($SetPacker.FullName)' must be an executable.")}

        [String]$GLOBAL:PackerPath = ([IO.FileInfo]$SetPacker).FullName

        Write-Host -ForegroundColor Green "`n SCS Packer set to '$($GLOBAL:PackerPath.FullName)'`n New behavior: -PackerPath now overrides set value if provided."
        Return
    }

    If ($NoCompression.IsPresent -And !$Repackage.IsPresent) {
        Write-Host -NoNewline ' '
        Write-Warning -Message "Ignored parameter '-NoCompression': Not applicable."
    }

    If ($NoCleanup.IsPresent -And !$Repackage.IsPresent) {
        Write-Host -NoNewline ' '
        Write-Warning -Message "Ignored parameter '-NoCleanup': Not applicable."
    }

    # Show warning if user has entered .txt files for scrubbing
    If ('.txt' -In $ScrubExtensions) {
        Write-Host -NoNewline ' '
        Write-Warning -Message 'Scrubbing .txt files is not recommended as it may impact readability and structure. Press ''Y'' to continue.'
        If ($Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown').VirtualKeyCode -ne 89) {Throw 'Aborted by user.'}
    }

    # Remove any potential duplicates from target scrub extensions
    $ScrubExtensions = $ScrubExtensions | Select-Object -Unique

    # List of valid mod file formats - Because creators keep leaving random files everywhere...
    [String[]]$ProtectedExt = @(
        '.pma', '.pmc', '.bank',
        '.pmd', '.pmg', '.font',
        '.pia', '.pit', '.tobj',
        '.pim', '.pic', '.guids',
        '.ppd', '.pip', '.soundref',
        '.sui', '.sii', '.mask',
        '.txt', '.jpg', '.base',
        '.aux', '.btf', '.dds',
        '.sbd', '.mat', '.ogg',
        '.dmd', '.cfg', '.thumb',
        '.ogv'
    )
    [String[]]$ProtectedFiles = @(
        'material.db'
    )
        
    # Unused for the time being
    [String[]]$KnownRootItems = @(
        'ui',      'dlc',     'map',
        'unit',    'font',    'asset',
        'sound',   'model',   'video',
        'prefab',  'effect',  'system',
        'model2',  'umatlib', 'vehicle',
        'prefab2', 'automat', 'material',
        'contentbrowser'
    )
    
    [Int64]$TotalTrimmed = 0
    [Int32]$Iteration    = -1

    [String[]]$FixedAttribs    = @()
    [String[]]$FixedUnits      = @()
    [String[]]$FailedUnitFixes = @()
    [String[]]$DeletedDirs     = @()
    [String[]]$DeletedFiles    = @()

    #### EXTRACT MOD PACKAGE ####
    If ($PSCmdlet.ParameterSetName -eq 'Extract') {

        If ([String]::IsNullOrWhiteSpace($PackerPath) -Or 'PackerPath' -NotIn $PSBoundParameters.Keys) {
            If ([String]::IsNullOrWhiteSpace($GLOBAL:PackerPath)) {
                Throw [ArgumentException]::New('No packer executable is defined. Use -SetPacker <Path> to allow -PackerPath omission.')
            }
            [IO.FileInfo]$PackerPath = $GLOBAL:PackerPath
        }

        $PackerPath.Refresh()

        If (!$PackerPath.Exists) {Throw [IO.IOException]::New("The specified SCS Packer path '$($PackerPath.FullName)' $(('no longer exists', 'does not exist')['PackerPath' -In $PSBoundParameters.Keys]).")}
        ElseIf ($PackerPath.Extension -ne '.exe') {Throw [IO.IOException]::New("The specified SCS Packer path '$($PackerPath.FullName)' must be an executable.")}

        If ([String]::IsNullOrWhiteSpace($PackerPath) -Or 'PackerPath' -NotIn $PSBoundParameters.Keys) {Write-Host "`n Using Packer '$($PackerPath.Name)'."}

        If (!$ModPackage.Exists) {Throw [IO.IOException]::New("The specified mod package '$($ModPackage.FullName)' does not exist.")}

        If     ([String]::IsNullOrWhiteSpace($Root)) {[IO.DirectoryInfo]$Root = "$((Get-Location).Path)\$($ModPackage.BaseName)"}
        ElseIf (!$Root.Parent.Exists)                {Throw [IO.IOException]::New("The specified root directory '$($Root.FullName)' must have an existing parent.")}
        ElseIf (!$Root.Exists)                       {[Void][IO.Directory]::CreateDirectory($Root)}
        ElseIf (![String]::IsNullOrWhiteSpace($Root.GetFileSystemInfos()) -And !$Force.IsPresent) {
            Throw [IO.IOException]::New("Unable to extract - Root directory '$($Root.FullName)' is not empty. Use -Force to overwrite existing files.")
        }
        ElseIf (![String]::IsNullOrWhiteSpace($Root.GetFileSystemInfos()) -And $Force.IsPresent) {Remove-Item -Path "$($Root.FullName)\*" -Recurse -Force}

        $Root.Refresh()

        If ($Repackage.IsPresent) {[UInt64]$PackageStartSize = $ModPackage.Length}

        [String]$PackerCommand = ". `"$($PackerPath.FullName)`" extract `"$($ModPackage.Fullname)`" -root `"$($Root.FullName)`""
        If ($BufferLimit) {$PackerCommand += " -io-buffers-size `"$BufferLimit`""}

        Write-Host -NoNewline " Extracting '$($ModPackage.Name)' using $($PackerPath.BaseName)... "

        Try {
            [Void](Invoke-Expression $PackerCommand)
            If ($LASTEXITCODE -ne 0) {Throw 'Failed to extract package.'}
        }
        Catch {
            Write-Host ''
            Throw $_.Exception.Message
        }
        $Path = $Root
        Write-Host -ForegroundColor Green 'Success.'
        Write-Host "`n Using path '$($Root.Name)'."

    }
    ElseIf ([String]::IsNullOrWhiteSpace($Path)) {
        [IO.DirectoryInfo]$Path = (Get-Location).Path
        Write-Host "`n Using path '$($Path.Name)'."
    }
    ElseIf (!$Path.Exists) {Throw [IO.IOException]::New("The specified directory '$($Path.FullName)' does not exist.")}

    $Path.Refresh()

    [Hashtable]$GCIParams = @{
        Path       = $Path.Fullname
        Filter     = "*"
        Attributes = @('A', 'D', 'R', 'S', 'H')
        Recurse    = $True
    }

    [Hashtable]$TXTGCI = @{
        Path   = $Path.Fullname
        Filter = '*.txt'
        File   = $True
    }
    [Hashtable]$JPGGCI = @{
        Path   = $Path.Fullname
        Filter = '*.jpg'
        File   = $True
    }

    If ([IO.File]::Exists("$($Path.Fullname)\manifest.sii")) {

        [String]$ManifestData   = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes("$($Path.Fullname)\manifest.sii"))

        [String]$Descriptor     = [Regex]::Match($ManifestData, 'description_file: ?"(.*?)"').Groups[1].Value
        [String]$IconFile       = [Regex]::Match($ManifestData, 'icon: ?"(.*?)"').Groups[1].Value

        [String]$PackageName    = [Regex]::Match($ManifestData, 'display_name: ?"(.*?)"').Groups[1].Value
        [String]$PackageAuthor  = [Regex]::Match($ManifestData, 'author: ?"(.*?)"').Groups[1].Value
        [String]$PackageVersion = [Regex]::Match($ManifestData, 'package_version: ?"v?(.*?)"').Groups[1].Value

        [String[]]$Categories   = [Regex]::Matches($ManifestData, 'category\[\]: ?"(.*?)"') | ForEach-Object {$_.Groups[1].Value}

        [String]$_ManifestData  = $ManifestData

        If ($Categories.Count -gt 2) {

            Write-Host -ForegroundColor Yellow ' manifest.sii: Too many category definitions.'

            If (!$NoManifestFix.IsPresent) {
                ForEach ($ExcessCat in $Categories[2..($Categories.Count - 1)]) {
                    $ManifestData = $ManifestData -Replace " ?category\[\]: ?`"$ExcessCat`" ?", ' '
                    Write-Host -ForegroundColor Green "     Removed 'category[]: `"$Excesscat`"'"
                }
            }
        }

        If (![IO.File]::Exists("$($Path.FullName)\$Descriptor")) {

            Write-Host -ForegroundColor Yellow " manifest.sii: Referenced description file '$Descriptor' does not exist."

            [String[]]$Txts = (Get-ChildItem @TXTGCI).Name
            
            Switch ($Txts.Count) {
                0 {Break}
                1 {
                    If (!$NoManifestFix.IsPresent) {
                        [String]$_Descriptor = $Descriptor

                        $Descriptor   = $Txts[0]
                        $ManifestData = $ManifestData -Replace "( ?description_file: ?`")$_Descriptor(`" ?)", "`$1$Descriptor`$2"

                        Write-Host -ForegroundColor Green "     Changed description file to '$Descriptor'"
                    }
                    Break
                }
                Default {Break}
            }

        }
        If (![IO.File]::Exists("$($Path.FullName)\$IconFile")) {

            Write-Host -ForegroundColor Yellow " manifest.sii: Referenced icon file '$IconFile' does not exist."

            [String[]]$Jpgs = (Get-ChildItem @JPGGCI).Name

            Switch ($Jpgs.Count) {
                0 {Break}
                1 {
                    If (!$NoManifestFix.IsPresent) {
                        [String]$_IconFile = $IconFile

                        $IconFile     = $Jpgs[0]
                        $ManifestData = $ManifestData -Replace "( ?icon: ?`")$_IconFile(`" ?)", "`$1$IconFile`$2"

                        Write-Host -ForegroundColor Green "     Changed icon file to '$IconFile'"
                    }
                    Break
                }
                Default {Break}
            }
        }

        If ($ManifestData -ne $_ManifestData -And !$NoManifestFix.IsPresent) {
            Set-Content -Path "$($Path.Fullname)\manifest.sii" -Value $ManifestData -NoNewline -Force
        }

        Write-Host -NoNewline "`n Package name:      "
        Write-Host -ForegroundColor DarkCyan $PackageName
        Write-Host -NoNewline ' Package author(s): '
        Write-Host -ForegroundColor DarkCyan $PackageAuthor
        Write-Host -NoNewline ' Package version:   '
        Write-Host -ForegroundColor DarkCyan "v$PackageVersion`n"
    }
    Else {
        Write-Host -ForegroundColor Yellow ' Missing mod manifest (manifest.sii).'
    }

    Write-Host -NoNewline ' Building file list... '
    [IO.FileInfo[]]$Files = Get-ChildItem @GCIParams -File

    # Get amount of padding characters needed for file name and size display
    [Byte]$LongestName = ($Files | Where-Object {$_.Extension -In $ScrubExtensions} | ForEach-Object {[IO.Path]::GetRelativePath($Path.Fullname, $_.FullName)} | Sort-Object Length)[-1].Length + 1
    [Byte]$LongestSize = ($Files | Where-Object {$_.Extension -In $ScrubExtensions} | ForEach-Object {[String]$_.Length} | Sort-Object Length)[-1].Length + 3

    Write-Host -ForegroundColor Green "Done - $($Files.Count) files`n"

    # Iterate files
    Foreach ($File in $Files) {
        $Iteration++

        [Console]::Title = "$([Math]::Round(($TotalTrimmed / 1KB), 2)) kBs trimmed. | $([Math]::Round($Iteration / $Files.Count * 100))%"

        [Int64]$OrigSize  = $File.Length
        [String]$Relative = [IO.Path]::GetRelativePath($Path.Fullname, $File.FullName)

        # Foreign file deletion
        If (!$KeepForeign.IsPresent -And $File.Extension -NotIn $ProtectedExt -And $File.Name -NotIn $ProtectedFiles) {
            
            Write-Host -NoNewline -ForegroundColor Yellow "$(" [FOREIGN] $Relative".PadRight($LongestName) + "$(" : $OrigSize".PadRight($LongestSize) + " -> ")")"

            Try {
                Remove-Item $File.FullName -Force -ErrorAction Stop

                $DeletedFiles += $File.FullName

                $TotalTrimmed += $OrigSize
                Write-Host -ForegroundColor Green "-$OrigSize [DELETED]"

                Continue
            }
            Catch {Write-Host -ForegroundColor Red "$OrigSize [ERROR]"}

        }

        # Fix attributes
        If (!$NoAttribFix.IsPresent -And $File.Attributes -ne 'Archive') {
            $File.Attributes = [IO.FileAttributes]::Archive
            $File.Refresh()
            $FixedAttribs += $File.FullName
            Write-Host -ForegroundColor Green " Fixed attributes for '$Relative'"
        }

        #### PLAINTEXT FILE SCRUBBING ####
        If ($File.Extension -NotIn $ScrubExtensions) {Continue}

        # Check for binary data
        If (!$NoBinaryCheck.IsPresent) {If (0 -In [IO.File]::ReadAllBytes($File.FullName)) {Continue}}

        [String]$OutStr = " $Relative".PadRight($LongestName) + " : $OrigSize".PadRight($LongestSize) + ' -> '

        [Bool]$WriteBytes = $False

        # Try reading the file contents using ReadAllBytes()
        Try   {[String]$RawContent = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($File.FullName)); $WriteBytes = $True}

        # Use regular Get-Content (Slower) if ReadAllBytes() fails
        Catch {[String]$RawContent = Get-Content $File.FullName -Raw -Encoding UTF8}

        $RawContent = [Regex]::Replace($RawContent, '^\xEF\xBB\xBF', '')
        $RawContent = [Regex]::Replace($RawContent, '\/\*[\s\S]*\*\/', '')

        $RawContent = ($RawContent -Split "`n" | `
            Where-Object   {![String]::IsNullOrWhiteSpace($_) -And $_ -NotMatch '^\s*(?:#|\/\/)'} | `
            ForEach-Object {$_.TrimStart().TrimEnd()}
        ) -Join "`n"

        $RawContent = [Regex]::Replace($RawContent, '(?m)(?<!:".+)[ \t]*([\:,{}();])[ \t]*(?!"$?)', '$1')
        $RawContent = [Regex]::Replace($RawContent, '(?m)(?<=^\s*\})\s*(?=^\}$)', '')
        $RawContent = [Regex]::Replace($RawContent, '(?i)(?m)(?<=^(?:\w+:\.?[\w\.]+)|(?:SiiNunit))\s*(?=\{)', '')

        [Collections.Generic.List[String]]$Lines   = $RawContent -Split "`n"
        [Collections.Generic.List[String]]$Trimmed = @()

        #### Scrub all unnecessary whitespace and comments ####

        ForEach ($Line in $Lines) {

            [String]$Clean  = ''
            [Char]$Previous = $Null
            [Bool]$inQuotes = $False

            ForEach ($Char in [Collections.Generic.List[Char]]$Line) {

                # Don't trim on comment mark if it's part of a quoted string!
                If     ($Char -eq '"') {$inQuotes = !$inQuotes}
                ElseIf ($Char -eq '#') {If (!$inQuotes) {Break}}
                ElseIf ($Char -eq '/') {If ($Previous -eq '/' -And !$inQuotes) {$Clean = $Clean.SubString(0, $Clean.Length - 1); Break}}

                $Clean   += $Char
                $Previous = $Char
            }
            
            $Clean = $Clean

            $Trimmed.Add($Clean)

        }

        [String]$Content = $Trimmed -Join "`n" -Replace '\t+', ' '

        # Trim remaining whitespaces
        $RawContent = [Regex]::Replace($RawContent, '(?m)(?<=\w:)\s*(?=")', '')
        $RawContent = [Regex]::Replace($RawContent, '(?m)(?<=[\d"\]})])[ \t]*(?=\}+)', '')

        # Convert line endings
        $Content = [Regex]::Replace($Content, '\r\n|\r|\n', "`n")

        # Misplaced SII preprocessor directives
        ForEach ($Misplaced in [Regex]::Matches($Content, '(?<!\n)@include "\/*[\w\.]+(?:\/+[\w\.]+)*\.[a-z]+"(?!\n)')) {
            If (!$NoUnitFix.IsPresent) {

                [String]$FixedDirective = $Misplaced.Value

                If ([Regex]::Match($Content, "(?<!\n)$([Regex]::Escape($Misplaced.Value))")) {$FixedDirective = "`n$FixedDirective"}
                If ([Regex]::Match($Content, "$([Regex]::Escape($Misplaced.Value))(?!\n)"))  {$FixedDirective = "$FixedDirective`n"}

                $Content     = [Regex]::Replace($Content, [Regex]::Escape($Misplaced.Value), $FixedDirective)

                $FixedUnits += "'$Relative' ($($Misplaced.Index)+$($Misplaced.Length)) : Fixed misplaced SII preprocessor directive"
            }
            Else {$FailedUnitFixes += "'$Relative' ($($Misplaced.Index)+$($Misplaced.Length)) : Misplaced SII preprocessor directive"}
        }

        # Invalid directory separators
        ForEach ($InvalidSep in [Regex]::Matches($Content, '(?<=")(?:[a-z_]+\|)?\/*[\w\.]+(?:\/+[\w\.]+)*\.[a-z]+(?:#\w+(?:\/+\w+)*)?(?=")')) {
            If ($InvalidSep.Value -Match '\/{2,}') {
                If (!$NoUnitFix.IsPresent) {

                    $Content     = [Regex]::Replace($Content, [Regex]::Escape($InvalidSep.Value), [Regex]::Replace($InvalidSep.Value, '\/+', '/'))
                    $FixedUnits += "'$Relative' ($($InvalidSep.Index)+$($InvalidSep.Length)) : Fixed invalid directory separator"

                }
                Else {$FixedUnits += "'$Relative' ($($InvalidSep.Index)+$($InvalidSep.Length)) : Invalid directory separator"}
            }
        }

        $Content = ($Content -Split "`n" | `
            Where-Object   {![String]::IsNullOrWhiteSpace($_)} | `
            ForEach-Object {$_.TrimStart().TrimEnd()}
        ) -Join "`n"

        If ($File.Extension -In ('.sui', '.sii')) {
            $Content = [Regex]::Replace($Content, '(?<!@include "[\w\.\/]+")\r?\n(?!@include "[\w\.\/]+")', ' ')
            $Content = [Regex]::Replace($Content, '\{ ', '{')
            $Content = [Regex]::Replace($Content, ' (\} |\}$)', '$1')
            $Content = [Regex]::Replace($Content, '\)(?=[\w\[\]]+:)', ') ')
        }

        If ($WriteBytes) {
            [Byte[]]$ContentBytes = [Text.Encoding]::UTF8.GetBytes($Content)
            [IO.File]::WriteAllBytes($File.FullName, $ContentBytes)
        }
        Else {Set-Content -Value $Content -Path $File.FullName -Force -NoNewline -Encoding UTF8}

        $File.Refresh()

        [Int64]$NewSize  = $File.Length
        [Int64]$DiffSize = $OrigSize - $NewSize
        $TotalTrimmed   += $DiffSize

        Write-Host -ForegroundColor ("White", "Green")[$NewSize -lt $OrigSize] "$OutStr$NewSize ($DiffSize)"

    }

    $Iteration++

    [Console]::Title = "$([Math]::Round(($TotalTrimmed / 1KB), 2)) kBs trimmed. | $([Math]::Round(($Iteration / $Files.Count) * 100))%"

    Write-Host ''

    If (!$KeepEmpty.IsPresent -Or !$NoAttribFix.IsPresent) {

        Write-Host -NoNewline ' Building directory list... '

        [IO.DirectoryInfo[]]$Directories = Get-ChildItem @GCIParams -Directory # Get all directories

        Write-Host -ForegroundColor Green "Done - $($Directories.Count) directories"

        # Iterate directories
        ForEach ($Dir in $Directories) {

            [String]$Subdir = [IO.Path]::GetRelativePath($Path.Fullname, $Dir.FullName)

            # Empty subdir deletion
            If (!$KeepEmpty.IsPresent -And [String]::IsNullOrWhiteSpace($Dir.GetFileSystemInfos())) {
                Try {
                    [IO.DirectoryInfo]$_Dir = $Dir
                    While ([String]::IsNullOrWhiteSpace($_Dir.GetFileSystemInfos()) -And $_Dir.FullName -ne $Path.FullName) {

                        [String]$Subdir = [IO.Path]::GetRelativePath($Path.Fullname, $_Dir.FullName)
                        
                        Remove-Item $_Dir.Fullname -Force -ErrorAction Stop
                        $DeletedDirs += $_Dir.FullName

                        Write-Host -ForegroundColor Green " Deleted empty subdir '$Subdir'"

                        $_Dir = $_Dir.Parent.FullName

                    }
                    Continue
                }
                Catch {Write-Host -ForegroundColor Red " Failed to delete empty subdir '$Subdir'"}
            }

            # Fix directory attributes
            If (!$NoAttribFix.IsPresent -And $Dir.Attributes -ne 'Directory') {
                $Dir.Attributes = [IO.FileAttributes]::Directory
                $Dir.Refresh()
                $FixedAttribs  += $Dir.FullName
                Write-Host -ForegroundColor Green " Fixed attributes for '$Subdir'"
            }
        }
        Write-Host ''
    }

    [Console]::Title = "$([Math]::Round(($TotalTrimmed / 1KB), 2)) kBs trimmed. | 100%"

    #### REPACKAGE MOD ####
    If ($Repackage.IsPresent) {
        
        $Root.Refresh()
        
        [String]$PackerCommand = ". `"$($PackerPath.FullName)`" create `"$($ModPackage.FullName)`" -root `"$($Root.FullName)`""
        
        If ($NoCompression.IsPresent) {$PackerCommand += ' -nocompression'}

        Write-Host " Initial package size: $PackageStartSize"

        Write-Host -NoNewline " Repackaging '$($Root.Name)' as '$($ModPackage.BaseName)'... "

        Try {
            [Void](Invoke-Expression $PackerCommand)

            If ($LASTEXITCODE -ne 0) {Throw 'Failed to repackage.'}

            $Root.Refresh()
            $ModPackage.Refresh()
            [Int64]$PackageSizeDiff = $ModPackage.Length - $PackageStartSize

            Write-Host -ForegroundColor Green 'Success.'

            #### CLEANUP ####
            If (!$NoCleanup.IsPresent) {
                Write-Host -NoNewline ' Cleaning up... '
                Try {
                    Remove-Item -Path $Root.FullName -Recurse -Force -ErrorAction Stop
                    Write-Host -ForegroundColor Green 'Done.'
                }
                Catch {Write-Host -ForegroundColor Yellow "Cleanup failed. ($($_.Exception.Message))"}
            }
        }
        Catch {Write-Host -ForegroundColor Red $_.Exception.Message}
        Write-Host " Final package size:   $($ModPackage.Length)"

        Write-Host -ForegroundColor Green "`n FINAL SIZE DIFFERENCE: $PackageSizeDiff"
    }

    #### SUMMARY ####
    Write-Host "`n"

    If ($DeletedFiles.Count -gt 0) {
        Write-Host " Deleted files:"
        ForEach ($File in $DeletedFiles) {Write-Host -ForegroundColor Green "     $([IO.Path]::GetRelativePath($Path.FullName, $File))"}
    }

    If ($DeletedDirs.Count -gt 0) {
        Write-Host " Deleted directories:"
        ForEach ($Dir in $DeletedDirs) {Write-Host -ForegroundColor Green "     $([IO.Path]::GetRelativePath($Path.FullName, $Dir))"}
    }

    If ($FixedAttribs.Count -gt 0) {
        Write-Host " Fixed attributes:"
        ForEach ($Item in $FixedAttribs) {Write-Host -ForegroundColor Green "     $([IO.Path]::GetRelativePath($Path.FullName, $Item))"}
    }

    If ($FixedUnits.Count -gt 0) {
        Write-Host " Unit issues fixed:"
        ForEach ($Item in $FixedUnits) {Write-Host -ForegroundColor Green "     $Item"}
    }

    If ($FailedUnitFixes.Count -gt 0) {
        " Unfixed unit issues:"
        ForEach ($Item in $FailedUnitFixes) {Write-Host -ForegroundColor Red "    $Item"}
    }

    Write-Host -ForegroundColor Green "`n $([Math]::Round(($TotalTrimmed / 1KB), 2)) kBs trimmed! ($TotalTrimmed Bytes - $([Math]::Round(($TotalTrimmed / 1MB), 3)) MB)`n"
}
