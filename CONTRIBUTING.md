# Contributing

Contributions and hardware reports are welcome. Keep the XP-330B USB scope clear and document evidence before adding another model or transport.

For a code change, explain the user-visible problem and expected result, run the build and test scripts on macOS, and include a hardware check when the change affects paper movement, bitmap format or media dimensions. Add a behavior test for a bug fix. Keep synthetic fixture data and examples free of account details, order identifiers and proprietary SDK content.

Use the CUPS raster API, validate new options and input bounds, keep pixel padding white, and avoid shell execution inside the filter. Installer changes must preserve other queues and remain usable without a connected device. Respect the installed root-owned helper boundary; do not fix permissions with chmod 777 or weaken macOS security.

Project contributions are made under the MIT license. Do not copy vendor binaries, PPDs, SDK source or manuals into this repository without an explicit redistribution license. Link to official documents when discussing protocol behavior.

For help, use GitHub Issues with a minimal, non-sensitive reproduction. For a security issue involving unsafe administrator execution or a buffer error, prefer GitHub's private vulnerability reporting when available; do not include credentials or private print content in public reports.
