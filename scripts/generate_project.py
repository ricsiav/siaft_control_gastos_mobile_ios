"""Generate the checked-in Xcode project using Python's standard library only."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()


def quoted(value):
    return json.dumps(str(value), ensure_ascii=False)


def generate():
    objects = {}

    def add(key, isa, **fields):
        objects[uid(key)] = "isa = " + isa + "; " + " ".join(f"{k} = {v};" for k, v in fields.items())
        return uid(key)

    def array(items):
        return "(" + ", ".join(items) + ")"

    def settings(values):
        return "{ " + " ".join(f"{k} = {quoted(v)};" for k, v in values.items()) + " }"

    sources = sorted(ROOT.glob("Siaft/**/*.swift"))
    tests = sorted(ROOT.glob("SiaftTests/**/*.swift"))
    resources = sorted(ROOT.glob("Siaft/Resources/Fonts/*.ttf")) + sorted(ROOT.glob("Siaft/Resources/Licenses/*")) + [ROOT / "Siaft/Resources/Assets.xcassets"]
    all_refs = []

    def phase_files(paths, kind):
        entries = []
        for path in paths:
            relative = path.relative_to(ROOT).as_posix()
            file_type = {".swift": "sourcecode.swift", ".ttf": "file", ".txt": "text", ".xcassets": "folder.assetcatalog"}[path.suffix]
            ref = add(relative, "PBXFileReference", lastKnownFileType=quoted(file_type), path=quoted(relative), sourceTree=quoted("SOURCE_ROOT"))
            all_refs.append(ref)
            entries.append(add("build:" + relative, "PBXBuildFile", fileRef=ref))
        return add(kind, "PBXSourcesBuildPhase" if kind.endswith("sources") else "PBXResourcesBuildPhase", buildActionMask="2147483647", files=array(entries), runOnlyForDeploymentPostprocessing="0")

    source_phase = phase_files(sources, "app:sources")
    test_phase = phase_files(tests, "test:sources")
    resource_phase = phase_files(resources, "app:resources")
    framework_phase = add("app:frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files="()", runOnlyForDeploymentPostprocessing="0")
    test_framework_phase = add("test:frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files="()", runOnlyForDeploymentPostprocessing="0")
    config_ref = add("config", "PBXFileReference", lastKnownFileType="text.xcconfig", path=quoted("Config/App.xcconfig"), sourceTree=quoted("SOURCE_ROOT"))
    plist_ref = add("plist", "PBXFileReference", lastKnownFileType="text.plist.xml", path=quoted("Siaft/Info.plist"), sourceTree=quoted("SOURCE_ROOT"))
    app_product = add("app:product", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex="0", path="Siaft.app", sourceTree="BUILT_PRODUCTS_DIR")
    test_product = add("test:product", "PBXFileReference", explicitFileType="wrapper.cfbundle", includeInIndex="0", path="SiaftTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    products = add("products", "PBXGroup", children=array([app_product, test_product]), name="Products", sourceTree=quoted("<group>"))
    main = add("main", "PBXGroup", children=array(all_refs + [config_ref, plist_ref, products]), sourceTree=quoted("<group>"))

    def configuration_list(key, extra, base=False):
        configurations = []
        for name in ["Debug", "Release"]:
            values = dict(extra)
            values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if name == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if name == "Debug" else "dwarf-with-dsym"})
            if name == "Debug":
                values.update({"ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "ONLY_ACTIVE_ARCH": "YES"})
            fields = dict(buildSettings=settings(values), name=name)
            if base:
                fields["baseConfigurationReference"] = config_ref
            configurations.append(add(key + name, "XCBuildConfiguration", **fields))
        return add(key + "configs", "XCConfigurationList", buildConfigurations=array(configurations), defaultConfigurationIsVisible="0", defaultConfigurationName="Release")

    project_configs = configuration_list("project", {"SDKROOT": "iphoneos", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0"})
    app_configs = configuration_list("app", {"PRODUCT_NAME": "Siaft", "INFOPLIST_FILE": "Siaft/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"}, base=True)
    test_configs = configuration_list("test", {"PRODUCT_NAME": "SiaftTests", "PRODUCT_BUNDLE_IDENTIFIER": "net.siaft.controlgastos.ios.tests", "GENERATE_INFOPLIST_FILE": "YES", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Siaft.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Siaft", "BUNDLE_LOADER": "$(TEST_HOST)", "TARGETED_DEVICE_FAMILY": "1,2", "CODE_SIGN_STYLE": "Automatic", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"})
    app_target = add("app:target", "PBXNativeTarget", buildConfigurationList=app_configs, buildPhases=array([source_phase, framework_phase, resource_phase]), buildRules="()", dependencies="()", name="Siaft", productName="Siaft", productReference=app_product, productType=quoted("com.apple.product-type.application"))
    proxy = add("proxy", "PBXContainerItemProxy", containerPortal=uid("project"), proxyType="1", remoteGlobalIDString=app_target, remoteInfo="Siaft")
    dependency = add("dependency", "PBXTargetDependency", target=app_target, targetProxy=proxy)
    test_target = add("test:target", "PBXNativeTarget", buildConfigurationList=test_configs, buildPhases=array([test_phase, test_framework_phase]), buildRules="()", dependencies=array([dependency]), name="SiaftTests", productName="SiaftTests", productReference=test_product, productType=quoted("com.apple.product-type.bundle.unit-test"))
    add("project", "PBXProject", attributes="{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }", buildConfigurationList=project_configs, compatibilityVersion=quoted("Xcode 14.0"), developmentRegion="es", hasScannedForEncodings="0", knownRegions="(es, en, Base)", mainGroup=main, productRefGroup=products, projectDirPath='""', projectRoot='""', targets=array([app_target, test_target]))
    project = ROOT / "Siaft.xcodeproj"
    project.mkdir(exist_ok=True)
    content = "// !$*UTF8*$!\n{\n archiveVersion = 1;\n classes = {};\n objectVersion = 56;\n objects = {\n"
    content += "\n".join(f"  {key} = {{ {value} }};" for key, value in objects.items())
    content += f"\n }};\n rootObject = {uid('project')};\n}}\n"
    (project / "project.pbxproj").write_text(content, encoding="utf-8")

    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")
    def reference(parent, target, name):
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=target, BuildableName=name, BlueprintName="SiaftTests" if name.endswith("xctest") else "Siaft", ReferencedContainer="container:Siaft.xcodeproj")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    reference(entry, app_target, "Siaft.app")
    test = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    testables = ET.SubElement(test, "Testables")
    reference(ET.SubElement(testables, "TestableReference", skipped="NO"), test_target, "SiaftTests.xctest")
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", allowLocationSimulation="YES")
    reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), app_target, "Siaft.app")
    profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    reference(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), app_target, "Siaft.app")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    path = project / "xcshareddata/xcschemes/Siaft.xcscheme"
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(scheme)
    ET.ElementTree(scheme).write(path, encoding="utf-8", xml_declaration=True)
    print(f"Generated Xcode project: {len(sources)} app sources, {len(tests)} test sources, {len(resources)} resources.")


if __name__ == "__main__":
    generate()
