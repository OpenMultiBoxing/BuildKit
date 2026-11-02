# Builds the single exe from runtime-zip.exe (KitCreator zip-storage kit) + OpenMultiBoxing.vfs, signable with
# Authenticode (the Metakit runtime.exe + sdx wrap can't be: its VFS must end the file).
#   build.ps1 -Out OpenMultiBoxing-v1.2.3.exe -Version v1.2.3
# The vfs app/ must already have OpenMultiBoxing.tcl. Strings come from OpenMultiBoxing.vfs/tclkit.inf.
param(
    [Parameter(Mandatory)][string]$Out,
    [string]$Version = 'dev',
    [string]$Runtime = "$PSScriptRoot\runtime9.exe",
    [string]$Vfs = "$PSScriptRoot\OpenMultiBoxing.vfs",
    [string]$Icon = "$PSScriptRoot\OpenMultiBoxing_RR\OpenMultiBoxing.ico",
    [string]$Manifest = "$PSScriptRoot\app9.manifest"
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class WobRes {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr LoadLibraryEx(string file, IntPtr h, uint flags);
    [DllImport("kernel32.dll")]
    static extern bool FreeLibrary(IntPtr h);
    delegate bool EnumNamesProc(IntPtr h, IntPtr type, IntPtr name, IntPtr param);
    delegate bool EnumLangsProc(IntPtr h, IntPtr type, IntPtr name, ushort lang, IntPtr param);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool EnumResourceNames(IntPtr h, IntPtr type, EnumNamesProc cb, IntPtr param);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool EnumResourceLanguages(IntPtr h, IntPtr type, IntPtr name, EnumLangsProc cb, IntPtr param);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr BeginUpdateResource(string file, bool deleteExisting);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint size);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool UpdateResource(IntPtr h, IntPtr type, string name, ushort lang, byte[] data, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool EndUpdateResource(IntPtr h, bool discard);

    const int RT_ICON = 3, RT_GROUP_ICON = 14, RT_VERSION = 16, RT_MANIFEST = 24;
    const ushort LANG = 0x409;

    // (type, name: int id or string, lang) of the resources we replace
    static List<Tuple<int, object, ushort>> Existing(string file) {
        var res = new List<Tuple<int, object, ushort>>();
        IntPtr h = LoadLibraryEx(file, IntPtr.Zero, 0x22); // LOAD_LIBRARY_AS_DATAFILE | AS_IMAGE_RESOURCE
        if (h == IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
        try {
            foreach (int t in new[] { RT_ICON, RT_GROUP_ICON, RT_VERSION, RT_MANIFEST }) {
                EnumResourceNames(h, (IntPtr)t, (hm, ty, nm, p) => {
                    object name = ((long)nm >> 16) == 0 ? (object)(int)(long)nm : Marshal.PtrToStringUni(nm);
                    EnumResourceLanguages(hm, ty, nm, (hm2, ty2, nm2, lang, p2) => {
                        res.Add(Tuple.Create(t, name, lang));
                        return true;
                    }, IntPtr.Zero);
                    return true;
                }, IntPtr.Zero);
            }
        } finally {
            FreeLibrary(h);
        }
        return res;
    }

    static void Update(IntPtr h, int type, object name, ushort lang, byte[] data) {
        uint n = data == null ? 0u : (uint)data.Length;
        bool ok = name is string ? UpdateResource(h, (IntPtr)type, (string)name, lang, data, n)
                                 : UpdateResource(h, (IntPtr)type, (IntPtr)(int)name, lang, data, n);
        if (!ok) {
            var err = new System.ComponentModel.Win32Exception();
            throw new Exception(string.Format("{0} resource {1}/{2}/{3}: {4}", data == null ? "deleting" : "adding",
                                              type, name, lang, err.Message));
        }
    }

    // Replaces all icons, version info and manifest of the exe.
    public static void Apply(string file, byte[] manifest, byte[] ico, string[] keys, string[] values, ushort[] ver) {
        var old = Existing(file);
        IntPtr h = BeginUpdateResource(file, false);
        if (h == IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
        try {
            foreach (var r in old) Update(h, r.Item1, r.Item2, r.Item3, null);
            Update(h, RT_MANIFEST, 1, LANG, manifest);
            // .ico: ICONDIR + 16 byte entries (with file offsets); group: same header + 14 byte entries (with ids)
            int count = BitConverter.ToUInt16(ico, 4);
            var grp = new MemoryStream();
            grp.Write(ico, 0, 6);
            for (int i = 0; i < count; i++) {
                int e = 6 + 16 * i;
                int size = BitConverter.ToInt32(ico, e + 8), offset = BitConverter.ToInt32(ico, e + 12);
                var img = new byte[size];
                Array.Copy(ico, offset, img, 0, size);
                Update(h, RT_ICON, i + 1, LANG, img);
                grp.Write(ico, e, 12);
                grp.Write(BitConverter.GetBytes((ushort)(i + 1)), 0, 2);
            }
            Update(h, RT_GROUP_ICON, 1, LANG, grp.ToArray());
            Update(h, RT_VERSION, 1, LANG, VersionInfo(keys, values, ver));
        } catch {
            EndUpdateResource(h, true);
            throw;
        }
        if (!EndUpdateResource(h, false)) throw new System.ComponentModel.Win32Exception();
    }

    // VS_VERSIONINFO tree node: wLength, wValueLength, wType, key, pad, value, pad, children
    static byte[] Node(string key, int type, byte[] value, int valueLength, params byte[][] children) {
        var m = new MemoryStream();
        var w = new BinaryWriter(m);
        w.Write((ushort)0);
        w.Write((ushort)valueLength);
        w.Write((ushort)type);
        w.Write(Encoding.Unicode.GetBytes(key + "\0"));
        if (value != null) {
            Align(w);
            w.Write(value);
        }
        foreach (var c in children) {
            Align(w);
            w.Write(c);
        }
        w.Flush();
        var b = m.ToArray();
        BitConverter.GetBytes((ushort)b.Length).CopyTo(b, 0);
        return b;
    }

    static void Align(BinaryWriter w) {
        while (w.BaseStream.Length % 4 != 0) w.Write((byte)0);
    }

    static byte[] VersionInfo(string[] keys, string[] values, ushort[] v) {
        var f = new MemoryStream();
        var w = new BinaryWriter(f);
        uint ms = ((uint)v[0] << 16) | v[1], ls = ((uint)v[2] << 16) | v[3];
        foreach (uint x in new uint[] { 0xFEEF04BD, 0x10000, ms, ls, ms, ls, 0x3F, 0, 0x40004, 1, 0, 0, 0 }) w.Write(x);
        w.Flush();
        var strings = new byte[keys.Length][];
        for (int i = 0; i < keys.Length; i++)
            strings[i] = Node(keys[i], 1, Encoding.Unicode.GetBytes(values[i] + "\0"), values[i].Length + 1);
        var table = Node("040904b0", 1, null, 0, strings);
        var translation = Node("Translation", 0, new byte[] { 0x09, 0x04, 0xb0, 0x04 }, 4);
        return Node("VS_VERSION_INFO", 0, f.ToArray(), 52,
                    Node("StringFileInfo", 1, null, 0, table),
                    Node("VarFileInfo", 1, null, 0, translation));
    }
}
'@

# .NET resolves relative paths from the process' directory, not the PowerShell one
$Out, $Runtime, $Vfs, $Icon, $Manifest = $Out, $Runtime, $Vfs, $Icon, $Manifest |
    ForEach-Object { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_) }
$bytes = [IO.File]::ReadAllBytes($Runtime)
# The kit's zip: from its end of central directory record (last "PK\5\6")
$eocd = -1
for ($i = $bytes.Length - 22; $i -ge 0; $i--) {
    if ($bytes[$i] -eq 0x50 -and $bytes[$i + 1] -eq 0x4b -and $bytes[$i + 2] -eq 5 -and $bytes[$i + 3] -eq 6) {
        $eocd = $i
        break
    }
}
if ($eocd -lt 0) { throw "no zip in $Runtime" }
$base = $eocd - [BitConverter]::ToUInt32($bytes, $eocd + 12) - [BitConverter]::ToUInt32($bytes, $eocd + 16)

# Exe part, with its boot zip::EndOfArchive (tclvfs) fixed: when the end of the zip isn't in the file's last 512
# bytes (i.e. once signed, with the signature after it), it reads 540 byte chunks but computed the offset with 512,
# so all entries were 28 bytes off and the kit couldn't start. Same length replacement.
$latin1 = [Text.Encoding]::GetEncoding(28591)
$stub = $latin1.GetString($bytes, 0, $base)
$bug = 'set seekstart [expr {[tell $fd] - 512}]'
$fix = 'set seekstart [expr {[tell $fd] -$len}]'
$at = $stub.IndexOf($bug)
if ($at -lt 0 -or $stub.IndexOf($bug, $at + 1) -ge 0) {
    # Tcl 9 runtime: zipfs, no tclvfs code
    if ($stub.IndexOf($fix) -lt 0 -and $stub.IndexOf('zip::EndOfArchive') -ge 0) {
        throw "zip::EndOfArchive code to fix not found once in $Runtime"
    }
} else {
    $stub = $stub.Substring(0, $at) + $fix + $stub.Substring($at + $bug.Length)
}
[IO.File]::WriteAllBytes($Out, $latin1.GetBytes($stub))

# Resources (on the exe part only: updating resources drops anything appended to an exe)
$info = [ordered]@{}
foreach ($l in Get-Content (Join-Path $Vfs 'tclkit.inf')) {
    if ($l -match '^\s*(\w+)\s+"(.*)"\s*$') { $info[$Matches[1]] = $Matches[2] }
}
$name = $info['ProductName']
$info['ProductVersion'] = $Version
$info['FileVersion'] = $Version
$info['InternalName'] = $name
$info['OriginalFilename'] = [IO.Path]::GetFileName($Out)
[ushort[]]$nums = 0, 0, 0, 0
if ($Version -match '^v?(\d+)\.(\d+)\.(\d+)') { $nums = [ushort]$Matches[1], [ushort]$Matches[2], [ushort]$Matches[3], 0 }
[WobRes]::Apply($Out, [IO.File]::ReadAllBytes($Manifest), [IO.File]::ReadAllBytes($Icon),
    [string[]]$info.Keys, [string[]]$info.Values, $nums)

# One zip: the kit's files (Tcl/Tk libraries, boot.tcl) + the vfs, appended to the exe part
$old = New-Object IO.Compression.ZipArchive((New-Object IO.MemoryStream(, $bytes[$base..($bytes.Length - 1)])), 'Read')
$zip = New-Object IO.MemoryStream
$new = New-Object IO.Compression.ZipArchive($zip, 'Create', $true)
$root = (Resolve-Path $Vfs).Path.TrimEnd('\') + '\'
$files = [ordered]@{}
Get-ChildItem $Vfs -Recurse -File | ForEach-Object { $files[$_.FullName.Substring($root.Length).Replace('\', '/')] = $_.FullName }
foreach ($e in $old.Entries) {
    if ($files.Contains($e.FullName)) { continue }
    $n = $new.CreateEntry($e.FullName, 'Optimal')
    $n.LastWriteTime = $e.LastWriteTime
    if (-not $e.FullName.EndsWith('/')) {
        $s = $e.Open()
        $d = $n.Open()
        $s.CopyTo($d)
        $d.Close()
        $s.Close()
    }
}
foreach ($k in $files.Keys) {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($new, $files[$k], $k, 'Optimal') | Out-Null
}
$new.Dispose()
$fs = [IO.File]::Open($Out, 'Append')
$zip.WriteTo($fs)
$fs.Close()
"Built $Out ($name $Version)"
