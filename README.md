# TypeCoverFix

Fixes the classic Surface Type Cover problem where the keyboard works only
intermittently or drops out completely (backlight dies, keys stop responding).

## What it does

1. Turns off **USB selective suspend** for the active power plan — on both AC and battery.
   (`powercfg /setacvalueindex` + `/setdcvalueindex`, subgroup *USB settings*)
2. Disables per-device power management (`SelectiveSuspendEnabled`,
   `EnhancedPowerManagementEnabled`, `AllowIdleIrpInD3`) for:
   - the Surface Type Cover (`VID_045E&PID_07E8`)
   - the USB hubs it is attached through (`VID_05E3&PID_0610`, `VID_05E3&PID_0626`)
   - the USB root hub
3. Restarts the cover device so the new settings apply immediately.
4. Prints the resulting device tree (`status`, `ConfigManagerErrorCode`) so you can
   see whether the cover is healthy.

## Usage

Download `TypeCoverFix.exe` from Releases, double-click it, accept the UAC prompt.
It applies the settings, prints a report and writes `type-cover-fix.log` next to
the exe. Nothing is installed, no services are created, nothing runs at startup.

To roll back: Device Manager -> your USB hub / Type Cover -> *Properties* ->
*Power Management* -> tick *Allow the computer to turn off this device*, and
`powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1`.

## Requirements

- Windows 10 / 11
- .NET Framework 4.x (built in since Windows 8)
- Administrator rights (the launcher elevates itself)

## Build from source

```
build.bat
```

`build.bat` calls the C# compiler that ships with Windows (.NET Framework 4.x, no SDK needed)
and embeds `TypeCoverFix.ps1` into `build\TypeCoverFix.exe` as a resource. The prebuilt
binary is committed as `TypeCoverFix.exe` for convenience.

## Notes

If the cover still drops out after this, the usual remaining causes are physical:
dirty pogo contacts (clean with 70%+ isopropyl alcohol), a stale embedded controller
state (power + volume-up for 15 s), or a cracked flex cable inside the cover.

## License

MIT
