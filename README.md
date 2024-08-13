# Optimize-ModPackage
A PowerShell function for optimizing, repairing and repackaging SCS mod packages in raw/extracted, ZipFS (soon™) and HashFS formats.

### This is a work in progress - Here be bugs and critters, so make sure to make a backup before processing a mod!

Requires PowerShell 7.0 or higher.

For automatic unpacking and repackaging of HashFS v2 packages you'll require the SCS Packer executable:

[https://download.eurotrucksimulator2.com/scs_packer_1_50.zip](https://download.eurotrucksimulator2.com/scs_packer_1_50.zip)

## Synopsis
Optimizes a mod package by removing clutter.

## Parameters

### Path
Path to pre-extracted mod root directory.

### SetPacker
Sets a persistent path to the SCS Packer executable. Must be set per-session.

### PackerPath
Path to the SCS Packer executable.

### ModPackage
The .scs mod package to unpack.

### Root
Destination folder for unpacked files.

### NoScrub
Disables file scrubbing.

### KeepEmpty
Retains empty subdirectories.

### NoAttribFix
Disables fixing file and folder attributes.

### NoUnitFix
Disables automatic fixes of detected problems in unit files.

### KeepForeign
Retains foreign/invalid files.

### NoBinaryCheck
Disables the safeguard for binary data scrubbing.
Note: Misidentification of binary files as plaintext may occur in rare circumstances.

### NoManifestFix
Disables mod manifest fixes, which include:
- Icon file reference errors
- Description file reference errors
- Excess category definitions trimming

### ScrubExtensions
File extensions to target for scrubbing (default: .mat, .sui, .sii, .guids, .soundref).
Note: Targeting .txt files is not recommended.

### BufferLimit
Limits I/O buffers during file unpacking.

### Force
Forces overwriting of files in the destination folder.

### ForceAcceptModRoot
Accepts any mod root structure, bypassing validation.

### Repackage
Repackages the mod into a HashFS v2 package after processing.

### NoCompression
Disables compression during repackaging (results in a larger file but faster process).

### NoCleanup
Retains unpacked files after repackaging.

## Input
- System.IO.FileInfo
- System.IO.DirectoryInfo
