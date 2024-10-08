# Optimize-ModPackage
A PowerShell function for optimizing, repairing and repackaging SCS mod packages in raw/extracted, ZipFS (soon™) and HashFS formats.

This is a standalone function for now until I wrap it in a module.
___
## IMPORTANT:
### In its current state, the unit scrubbing feature is often overly aggressive and may break several unit files while processing a mod.
### It is recommended to use the `-NoScrub` parameter to skip the scrubbing step entirely. Continue using the feature at your own risk.
___

### This is a work in progress - Here be bugs and critters, so make sure to make a backup before processing a mod!

Requires PowerShell 7.0 or higher.

For automatic unpacking and repackaging of HashFS v2 packages you'll require the SCS Packer executable:

[https://download.eurotrucksimulator2.com/scs_packer_1_50.zip](https://download.eurotrucksimulator2.com/scs_packer_1_50.zip)
___

# Setup guide

1. Download `Optimize-ModPackage.ps1` to any location. (A dedicated directory is recommended).
2. Open PowerShell 7 (`pwsh.exe`) and set the working directory to the directory containing the script if needed.
3. Load the function into memory by executing `. '.\Optimize-ModPackage.ps1'`
4. You are now set up and ready. For usage instructions use `Get-Help Optimize-ModPackage` or keep on reading.
___

## Synopsis
Optimizes a mod package by removing clutter.

## Syntax
```
Optimize-ModPackage [[-Path] <IO.DirectoryInfo>] [-ScrubExtensions <String[]>] [-NoScrub] [-KeepEmpty] [-NoUnitFix] [-NoAttribFix] [-KeepForeign] [-NoBinaryCheck] [-NoManifestFix]

Optimize-ModPackage [-SetPacker] <IO.FileInfo>

Optimize-ModPackage -TargetFiles <IO.FileInfo[]>

Optimize-ModPackage -ModPackage <IO.FileInfo> [-PackerPath <IO.FileInfo>] [-Root <IO.DirectoryInfo>] [-BufferLimit <UInt16>] [-Force] [-Repackage] [-NoCompression] [-NoCleanup] [-ScrubExtensions <String[]>] [-NoScrub] [-KeepEmpty] [-NoUnitFix] [-NoAttribFix] [-KeepForeign] [-NoBinaryCheck] [-NoManifestFix]
```

## Parameters

### Path <IO.DirectoryInfo>
Path to pre-extracted mod root directory.
```
Required?                    false
Position?                    0
Alias
Default value
Accept pipeline input?       true (ByValue)
Accept wildcard characters?  false
```

### SetPacker <IO.FileInfo>
Sets a persistent path to the SCS Packer executable. Must be set per-session.
```
Required?                    true
Position?                    0
Alias
Default value                
Accept pipeline input?       true (ByValue)
Accept wildcard characters?  false
```

### PackerPath <IO.FileInfo>
Path to the SCS Packer executable.
```
Required?                    false
Position?                    Named
Alias                        Packer
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### ModPackage <IO.FileInfo>
The mod package to unpack.
```
Required?                    true
Position?                    Named
Alias                        Mod, File
Default value                
Accept pipeline input?       true (ByValue)
Accept wildcard characters?  false
```

### TargetFiles <IO.FileInfo[]>
The mod packages to process. (Does nothing for the time being - Work in progress)
```
Required?                    true
Position?                    Named
Alias                        
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### Root <IO.DirectoryInfo>
Destination folder for unpacked files.
```
Required?                    false
Position?                    Named
Alias                        
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoScrub <>
Disables file scrubbing.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### KeepEmpty <>
Retains empty subdirectories.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoAttribFix <>
Disables fixing file and folder attributes.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoUnitFix <>
Disables automatic fixes of detected problems in unit files.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### KeepForeign <>
Retains foreign/invalid files.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoBinaryCheck <>
Disables the safeguard for binary data scrubbing.
Note: Misidentification of binary files as plaintext may occur in rare circumstances.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoManifestFix <>
Disables mod manifest fixes, which include:
- Icon file reference errors
- Description file reference errors
- Excess category definitions trimming
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### ScrubExtensions <String[]>
File extensions to target for scrubbing (default: .mat, .sui, .sii, .guids, .soundref).
Note: Targeting .txt files is not recommended.
```
Required?                    false
Position?                    Named
Alias                        Exts
Default value                @('.mat', '.sui', '.sii', '.guids', '.soundref')
Accept pipeline input?       false
Accept wildcard characters?  false
```

### BufferLimit <UInt16>
Limits I/O buffers during file unpacking.
```
Required?                    false
Position?                    Named
Alias                        Lim
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### Force <>
Forces overwriting of files in the destination folder.
```
Required?                    false
Position?                    Named
Alias                        F
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### Repackage <>
Repackages the mod into a HashFS v2 package after processing.
```
Required?                    false
Position?                    Named
Alias                        Repack
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoCompression <>
Disables compression during repackaging (results in a larger file but faster process).
```
Required?                    false
Position?                    Named
Alias                        NoComp
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### NoCleanup <>
Retains unpacked files after repackaging.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```

### Version <>
Returns the current version of the function.
```
Required?                    false
Position?                    Named
Alias
Default value                
Accept pipeline input?       false
Accept wildcard characters?  false
```
