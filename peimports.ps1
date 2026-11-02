# Lists the DLLs imported by PE files (static + delay load).
param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Files)
foreach ($f in $Files) {
    $b = [IO.File]::ReadAllBytes($f)
    $pe = [BitConverter]::ToInt32($b, 0x3c)
    $nsec = [BitConverter]::ToUInt16($b, $pe + 6)
    $optSize = [BitConverter]::ToUInt16($b, $pe + 20)
    $opt = $pe + 24
    $magic = [BitConverter]::ToUInt16($b, $opt)
    $dd = $opt + $(if ($magic -eq 0x20b) { 112 } else { 96 })
    $sec = $opt + $optSize
    function Off([uint32]$rva) {
        for ($i = 0; $i -lt $nsec; $i++) {
            $s = $sec + 40 * $i
            $va = [BitConverter]::ToUInt32($b, $s + 12)
            $sz = [Math]::Max([BitConverter]::ToUInt32($b, $s + 8), [BitConverter]::ToUInt32($b, $s + 16))
            if ($rva -ge $va -and $rva -lt $va + $sz) { return $rva - $va + [BitConverter]::ToUInt32($b, $s + 20) }
        }
        return -1
    }
    function Str([int]$o) { $e = $o; while ($b[$e] -ne 0) { $e++ }; [Text.Encoding]::ASCII.GetString($b, $o, $e - $o) }
    $names = @()
    foreach ($k in @(@(1, 20, 12), @(13, 32, 4))) { # import dir (entry 1, 20 byte descr, name at 12), delay (13, 32, 4)
        $rva = [BitConverter]::ToUInt32($b, $dd + 8 * $k[0])
        if ($rva -eq 0) { continue }
        $o = Off $rva
        while ($true) {
            $n = [BitConverter]::ToUInt32($b, $o + $k[2])
            if ($n -eq 0) { break }
            $names += (Str (Off $n)) + $(if ($k[0] -eq 13) { ' (delay)' } else { '' })
            $o += $k[1]
        }
    }
    "$([IO.Path]::GetFileName($f)): $($names -join ', ')"
}
