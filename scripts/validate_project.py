"""Portable structural validation; this does not compile Swift or replace Xcode tests."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "Siaft.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
info = plistlib.loads((ROOT / "Siaft/Info.plist").read_bytes())
assert info["SiaftBffBaseURL"] == "$(SIAFT_BFF_BASE_URL)"
assert "NSAppTransportSecurity" not in info
for source in list(ROOT.glob("Siaft/**/*.swift")) + list(ROOT.glob("SiaftTests/**/*.swift")):
    assert source.relative_to(ROOT).as_posix() in project, source
for font in info["UIAppFonts"]:
    path = ROOT / "Siaft/Resources/Fonts" / font
    assert path.is_file()
    assert path.relative_to(ROOT).as_posix() in project
    data = path.read_bytes()
    tables = struct.unpack_from(">H", data, 4)[0]
    for index in range(tables):
        tag, _, offset, _ = struct.unpack_from(">4sIII", data, 12 + index * 16)
        if tag == b"name":
            _, count, strings = struct.unpack_from(">HHH", data, offset)
            names = []
            for entry in range(count):
                platform, _, _, name_id, length, start = struct.unpack_from(">HHHHHH", data, offset + 6 + entry * 12)
                if name_id == 6:
                    raw = data[offset + strings + start:offset + strings + start + length]
                    names.append(raw.decode("utf-16-be" if platform in [0, 3] else "mac_roman"))
            assert names, path
            print(f"Font {font}: {sorted(set(names))}")
for manifest in ROOT.glob("Siaft/Resources/Assets.xcassets/**/Contents.json"):
    value = json.loads(manifest.read_text())
    for image in value.get("images", []):
        if "filename" in image:
            assert (manifest.parent / image["filename"]).is_file()
image = ROOT / "Siaft/Resources/Assets.xcassets/LoginFinances.imageset/login-finances.png"
assert hashlib.sha256(image.read_bytes()).hexdigest() == "4f29052a2f63789df1494722a931329a33bbaf62124353d257860908588ce70f"
ids = re.findall(r"^  ([A-F0-9]{24}) =", project, flags=re.MULTILINE)
assert len(ids) == len(set(ids)), "Duplicate project IDs"
references = re.findall(r"\b[A-F0-9]{24}\b", project)
assert set(references) <= set(ids), "Unresolved project references"
scheme = ET.parse(ROOT / "Siaft.xcodeproj/xcshareddata/xcschemes/Siaft.xcscheme")
for reference in scheme.findall(".//BuildableReference"):
    assert reference.attrib["BlueprintIdentifier"] in ids
tests = sum(len(re.findall(r"func test\w+\(", p.read_text())) for p in ROOT.glob("SiaftTests/*.swift"))
print(f"PASS: plist, resources, project references, shared scheme and {tests} declared tests.")
print("Swift compilation, XCTest execution and simulator validation still require macOS/Xcode.")
