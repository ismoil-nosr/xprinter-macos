#!/usr/bin/env python3
"""Generate an Installer distribution with a minimum supported macOS version."""
import sys
from pathlib import Path
from xml.sax.saxutils import escape

version, target = sys.argv[1:]
Path(target).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Open Xprinter {escape(version)}</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <license file="LICENSE.txt" mime-type="text/plain"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <allowed-os-versions><os-version min="14.0"/></allowed-os-versions>
  <domains enable_localSystem="true" enable_currentUserHome="false" enable_anywhere="false"/>
  <choices-outline><line choice="main"/></choices-outline>
  <choice id="main" visible="false"><pkg-ref id="com.ismoilnosr.openxprinter"/></choice>
  <pkg-ref id="com.ismoilnosr.openxprinter" version="{escape(version)}" onConclusion="none">OpenXprinter-component.pkg</pkg-ref>
</installer-gui-script>
''', encoding='utf-8')
