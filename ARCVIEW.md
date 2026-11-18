# ArcView

ArcView is the OKYPY (State Health Services Organisation, Cyprus) desktop DICOM viewer.
It is a customised distribution of [Weasis](https://github.com/nroduit/Weasis), integrated with the OKYPY dcm4chee PACS.

All ArcView changes are kept small and listed below, so that new Weasis releases can be merged from upstream.

## Customisations

| File | Change |
|------|--------|
| `weasis-distributions/script/prepare-input-site.sh` | New. Weasis deployment hook, run before packaging: sets the name ArcView, uses `~/.arcview` for user data (separate from a Weasis install), presets the OKYPY PACS list, sets the macOS bundle id `cy.okypy.arcview` and the ArcView icon names. |
| `.github/workflows/build-installer.yml` | Installer name ArcView; Apple signing and notarization only when the signing secrets exist (unsigned builds otherwise); passes the `ARCVIEW_DICOM_NODES` secret to the hook; builds the two macOS installers by default. |
| `weasis-dicom/weasis-dicom-qr/.../DicomQrView.java` | C-GET is the default retrieve method (no AE registration of the workstation needed on the PACS). |

## PACS list

The PACS list is **not** in this public repository. It is stored in the repository secret `ARCVIEW_DICOM_NODES`
(Settings → Secrets and variables → Actions) in the Weasis `dicomNodes.xml` format:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<nodes>
  <node description="Hospital PACS" type="DICOM" usageType="BOTH" tsuid="NONE"
        aeTitle="AETITLE" hostname="10.0.0.1" port="11112"></node>
</nodes>
```

To add a hospital: edit the secret, then run the installer workflow again.
Users can still add their own PACS in Preferences → DICOM node list.

## Building the installers

Actions → **Build installers** → Run workflow. The default platforms are `macosx-x86-64,macosx-aarch64`
(Intel and Apple Silicon Macs). The installers are attached to the run as artifacts.

Without an Apple Developer ID the installers are unsigned: macOS blocks the first launch, and the user allows it once
in System Settings → Privacy & Security → **Open Anyway**.
To sign and notarize, add the secrets `MACOS_CERTIFICATE_DEVELOPMENT`, `MACOS_CERTIFICATE_INSTALLER`,
`MACOS_CERTIFICATE_PWD`, `APPLE_DEVELOPER_AC_USERNAME`, `APPLE_TEAM_ID` and `WEASIS_PWD` (app-specific password).

## Known limits

- ArcView and a stock Weasis both register the `weasis://` link; on a Mac with both, macOS picks one.
- The Intel macOS installer is built on JDK 26; future Java releases drop Intel Macs.
