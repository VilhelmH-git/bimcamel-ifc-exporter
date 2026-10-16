# BIMuttern — Navisworks → IFC exporter

`BIMuttern.bundle/` is a Navisworks plug-in bundle for Navisworks Manage and Simulate 2024-2027.
Colleagues get it through BoomerHubb, which installs and updates it. To install by hand:

1. Close Navisworks.
2. Copy the whole **`BIMuttern.bundle`** folder into your per-user plug-ins folder:

   ```
   %AppData%\Autodesk\ApplicationPlugins\
   ```

   (that is, `C:\Users\<you>\AppData\Roaming\Autodesk\ApplicationPlugins\BIMuttern.bundle`)
3. Start Navisworks. The **BIMuttern** ribbon tab appears.

If Navisworks reports `PLUGIN_LOAD_02` / `0x80131515`, Windows kept the browser's "downloaded file"
mark on the DLLs. Clear it in PowerShell with
`Get-ChildItem "$env:APPDATA\Autodesk\ApplicationPlugins\BIMuttern.bundle" -Recurse -File | Unblock-File`.

BIMuttern has its own DLL, bundle folder, plugin ids and ribbon tab, so it can be installed next to
the original BIMCamel IFC Exporter without either replacing the other.

## Why one DLL per year

A Navisworks plug-in must be **compiled against the API of the release it runs in**: 2024 uses
`Autodesk.Navisworks.Api` v21, 2025 v22, 2026 v23, 2027 v24. A DLL built against one year still
loads in the others, but its ribbon tab silently fails to appear. So each year folder holds its
own build of `BIMuttern.dll`, and `PackageContents.xml` points each Navisworks release at its folder.

## Origin

BIMuttern is a fork of the [BIMCamel IFC Exporter](https://github.com/mrshoma99-rgb/bimcamel-ifc-exporter)
by BIMCamel, under the MIT licence (see `LICENSE`). Source and changes:
https://github.com/VilhelmH-git/bimcamel-ifc-exporter
