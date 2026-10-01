#!/usr/bin/env python3
"""
Regenerates GardenPlanner/GardenPlanner.xcodeproj/project.pbxproj.

Scans the app source folder and writes a complete, valid pbxproj:
  - all .swift files in the Sources build phase
  - plants.json + Assets.xcassets in the Resources build phase
  - Info.plist generated from INFOPLIST_KEY_* (no static Info.plist file)
  - CloudKit entitlements referenced by the target
  - proper project/target XCConfigurationLists (objectVersion 56)

Run from anywhere:  python3 regenerate_pbxproj.py
"""

import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
APP_DIR_NAME = "GardenPlanner"
SRC_DIR = os.path.join(ROOT, APP_DIR_NAME, APP_DIR_NAME)
PROJECT_FILE = os.path.join(ROOT, APP_DIR_NAME, f"{APP_DIR_NAME}.xcodeproj", "project.pbxproj")

TEAM_ID = "VDWDUNC9R2"
BUNDLE_ID = "com.josephwoods.GardenPlanner"
MARKETING_VERSION = "2.0.0"
CURRENT_PROJECT_VERSION = "3"
DEPLOYMENT_TARGET = "17.0"

INFOPLIST_KEYS = [
    ("CFBundleDisplayName", '"3D Garden Planner"'),
    ("NSCameraUsageDescription", '"Garden Planner uses the camera for LiDAR scanning, AR mapping, and seed-packet barcode scanning. Scans stay on your device."'),
    ("NSLocalNetworkUsageDescription", '"Garden Planner uses the local network for optional CloudKit sync to back up garden plans across your Apple devices."'),
    ("NSLocationWhenInUseUsageDescription", '"Garden Planner uses your location for local weather forecasts and frost-date alerts in your garden."'),
    ("NSMotionUsageDescription", '"Garden Planner uses motion and orientation data to stabilize LiDAR/AR garden scans."'),
    ("NSPhotoLibraryAddUsageDescription", '"Garden Planner can save your labeled garden map and journal photos to your Photos library."'),
    ("UIApplicationSceneManifest_Generation", "YES"),
    ("UIApplicationSupportsMultipleScenes", "NO"),
    ("UILaunchScreen_Generation", "YES"),
    ("UISupportedInterfaceOrientations", '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
    ("UISupportedInterfaceOrientations_iPad", '"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"'),
]

BASE_SETTINGS = """\
		ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
		CLANG_ANALYZER_NONNULL = YES;
		CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
		CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
		CLANG_ENABLE_MODULES = YES;
		CLANG_ENABLE_OBJC_ARC = YES;
		CLANG_ENABLE_OBJC_WEAK = YES;
		CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
		CLANG_WARN_BOOL_CONVERSION = YES;
		CLANG_WARN_COMMA = YES;
		CLANG_WARN_CONSTANT_CONVERSION = YES;
		CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
		CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
		CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
		CLANG_WARN_EMPTY_BODY = YES;
		CLANG_WARN_ENUM_CONVERSION = YES;
		CLANG_WARN_INT_CONVERSION = YES;
		CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
		CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
		CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
		CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
		CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
		CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
		CLANG_WARN_SIGN_CONVERSION = YES;
		CLANG_WARN_STRICT_PROTOTYPES = YES;
		CLANG_WARN_SUSPICIOUS_MOVE = YES;
		CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
		CLANG_WARN_UNREACHABLE_CODE = YES;
		CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
		ENABLE_USER_SCRIPT_SANDBOXING = YES;
		GCC_C_LANGUAGE_STANDARD = gnu17;
		GCC_NO_COMMON_BLOCKS = YES;
		GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
		GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
		GCC_WARN_UNDECLARED_SELECTOR = YES;
		GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
		GCC_WARN_UNUSED_FUNCTION = YES;
		GCC_WARN_UNUSED_VARIABLE = YES;
		IPHONEOS_DEPLOYMENT_TARGET = {deployment_target};
		SDKROOT = iphoneos;
		SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";"""


def fid(*parts):
    """Stable 24-hex pbxproj ID derived from a path/key."""
    return hashlib.md5("|".join(parts).encode()).hexdigest()[:24]


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def project_settings_body(debug):
    lines = [BASE_SETTINGS.format(deployment_target=DEPLOYMENT_TARGET)]
    lines.append(f'\t\tDEVELOPMENT_TEAM = "{TEAM_ID}";')
    lines.append("\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
    lines.append(f"\t\tMTL_ENABLE_DEBUG_INFO = {'INCLUDE_SOURCE' if debug else 'NO'};")
    lines.append("\t\tMTL_FAST_MATH = YES;")
    if debug:
        lines.append("\t\tCOPY_PHASE_STRIP = NO;")
        lines.append("\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
        lines.append("\t\tENABLE_TESTABILITY = YES;")
        lines.append("\t\tGCC_OPTIMIZATION_LEVEL = 0;")
        lines.append('\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1",);')
        lines.append("\t\tONLY_ACTIVE_ARCH = YES;")
    else:
        lines.append('\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
        lines.append("\t\tENABLE_NS_ASSERTIONS = NO;")
    return "\n".join(lines)


def target_settings_body():
    lines = [BASE_SETTINGS.format(deployment_target=DEPLOYMENT_TARGET)]
    lines.append("\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    lines.append(f"\t\tCODE_SIGN_ENTITLEMENTS = {APP_DIR_NAME}/{APP_DIR_NAME}.entitlements;")
    lines.append("\t\tCODE_SIGN_STYLE = Automatic;")
    lines.append(f"\t\tCURRENT_PROJECT_VERSION = {CURRENT_PROJECT_VERSION};")
    lines.append(f'\t\tDEVELOPMENT_TEAM = "{TEAM_ID}";')
    lines.append("\t\tGENERATE_INFOPLIST_FILE = YES;")
    for key, value in INFOPLIST_KEYS:
        lines.append(f"\t\tINFOPLIST_KEY_{key} = {value};")
    lines.append(f"\t\tMARKETING_VERSION = {MARKETING_VERSION};")
    lines.append(f"\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};")
    lines.append('\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
    lines.append("\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\tSWIFT_VERSION = 5.9;")
    lines.append('\t\tTARGETED_DEVICE_FAMILY = "1,2";')
    return "\n".join(lines)


def xcconfig_block(conf_id, name, settings_body):
    return (
        f"\t{conf_id} /* {name} */ = {{\n"
        "\t\tisa = XCBuildConfiguration;\n"
        "\t\tbuildSettings = {\n"
        f"{settings_body}\n"
        "\t\t};\n"
        f"\t\tname = {name};\n"
        "\t};"
    )


def write_scheme(xcodeproj_dir, name, target_id):
    """Write a shared scheme so the project builds from the CLI. Stable IDs keep it valid."""
    scheme_path = os.path.join(xcodeproj_dir, "xcshareddata", "xcschemes", f"{name}.xcscheme")
    def ref():
        return (
            '         <BuildableReference\n'
            '            BuildableIdentifier = "primary"\n'
            f'            BlueprintIdentifier = "{target_id}"\n'
            f'            BuildableName = "{name}.app"\n'
            f'            BlueprintName = "{name}"\n'
            '            ReferencedContainer = "container:GardenPlanner.xcodeproj">\n'
            '         </BuildableReference>'
        )
    content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeCheck = "2700"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
{ref()}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{ref().replace('         <','          <',1).replace('         </','          </',1)}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
{ref().replace('         <','          <',1).replace('         </','          </',1)}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    os.makedirs(os.path.dirname(scheme_path), exist_ok=True)
    with open(scheme_path, "w") as f:
        f.write(content)


def main():
    if not os.path.isdir(SRC_DIR):
        sys.exit(f"Source dir not found: {SRC_DIR}")

    swift_files = []
    for root, dirs, files in os.walk(SRC_DIR):
        dirs[:] = sorted(d for d in dirs if d != ".git")
        for f in sorted(files):
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(root, f), SRC_DIR).replace(os.sep, "/")
                swift_files.append(rel)
    swift_files.sort()
    if not swift_files:
        sys.exit("No Swift files found.")

    resource_files = []
    if os.path.isdir(os.path.join(SRC_DIR, "Assets.xcassets")):
        resource_files.append("Assets.xcassets")
    if os.path.isfile(os.path.join(SRC_DIR, "plants.json")):
        resource_files.append("plants.json")
    entitlements = f"{APP_DIR_NAME}.entitlements"

    file_refs = {}
    build_files = {}

    def add_file_ref(rel, ftype):
        # `path` is relative to the group that owns this reference, so use the
        # basename (each ref is only ever listed from its own directory group).
        ref_id = fid("ref", rel)
        file_refs[ref_id] = (rel, f'lastKnownFileType = {ftype}; path = {esc(os.path.basename(rel))}; sourceTree = "<group>";')
        return ref_id

    def add_build_file(rel, phase, ref_id):
        bid = fid("build", rel, phase)
        build_files[bid] = (f"{os.path.basename(rel)} in {phase}", f'isa = PBXBuildFile; fileRef = {ref_id};')
        return bid

    for rel in swift_files:
        add_file_ref(rel, "sourcecode.swift")
        add_build_file(rel, "GardenPlanner in Sources", fid("ref", rel))
    for rel in resource_files:
        ftype = "folder.assetcatalog" if rel.endswith(".xcassets") else "text.json"
        add_file_ref(rel, ftype)
        add_build_file(rel, "GardenPlanner in Resources", fid("ref", rel))
    add_file_ref(entitlements, "text.plist.entitlements")

    app_ref = fid("ref", f"{APP_DIR_NAME}.app")
    file_refs[app_ref] = (
        f"{APP_DIR_NAME}.app",
        'explicitFileType = "wrapper.application"; includeInIndex = 0; path = '
        f"{APP_DIR_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR;",
    )

    # Group layout
    g_main = fid("group", "main")
    g_app = fid("group", APP_DIR_NAME)
    g_products = fid("group", "Products")
    sub_dirs = sorted({rel.split("/")[0] for rel in swift_files if "/" in rel})
    g_sub = {d: fid("group", d) for d in sub_dirs}

    top_children = [fid("ref", r) for r in swift_files if "/" not in r]
    sub_children = {d: [fid("ref", r) for r in swift_files if "/" in r and r.split("/")[0] == d] for d in sub_dirs}
    res_children = [fid("ref", r) for r in resource_files] + [fid("ref", entitlements)]

    target_id = fid("target", APP_DIR_NAME)
    project_id = fid("project", APP_DIR_NAME)
    phase_src = fid("phase", "Sources")
    phase_res = fid("phase", "Resources")
    cfglist_project = fid("cfglist", "project")
    cfglist_target = fid("cfglist", "target")
    conf_proj_debug = fid("conf", "project", "Debug")
    conf_proj_release = fid("conf", "project", "Release")
    conf_tgt_debug = fid("conf", "target", "Debug")
    conf_tgt_release = fid("conf", "target", "Release")

    src_phase_ids = [fid("build", r, "GardenPlanner in Sources") for r in swift_files]
    res_phase_ids = [fid("build", r, "GardenPlanner in Resources") for r in resource_files]

    out = []
    w = out.append
    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w("")

    w("/* Begin PBXBuildFile section */")
    for bid in sorted(build_files):
        comment, attrs = build_files[bid]
        w(f"\t{bid} /* {comment} */ = {{{attrs}}};")
    w("/* End PBXBuildFile section */")
    w("")

    w("/* Begin PBXFileReference section */")
    for ref_id in sorted(file_refs):
        comment, attrs = file_refs[ref_id]
        w(f"\t{ref_id} /* {comment} */ = {{isa = PBXFileReference; {attrs}}};")
    w("/* End PBXFileReference section */")
    w("")

    w("/* Begin PBXGroup section */")
    w(f"\t{g_main} = {{")
    w("\t\tisa = PBXGroup;")
    w(f"\t\tchildren = ({g_app}, {g_products});")
    w('\t\tsourceTree = "<group>";')
    w("\t};")
    w(f"\t{g_app} /* {APP_DIR_NAME} */ = {{")
    w("\t\tisa = PBXGroup;")
    children = [fid("ref", "GardenPlanner.swift")] + [g_sub[d] for d in sub_dirs] + res_children
    w("\t\tchildren = (" + ", ".join(children) + ");")
    w(f"\t\tpath = {APP_DIR_NAME};")
    w('\t\tsourceTree = "<group>";')
    w("\t};")
    for d in sub_dirs:
        w(f"\t{g_sub[d]} /* {d} */ = {{")
        w("\t\tisa = PBXGroup;")
        w("\t\tchildren = (" + ", ".join(sub_children[d]) + ");")
        w(f"\t\tpath = {d};")
        w('\t\tsourceTree = "<group>";')
        w("\t};")
    w(f"\t{g_products} /* Products */ = {{")
    w("\t\tisa = PBXGroup;")
    w(f"\t\tchildren = ({app_ref});")
    w("\t\tname = Products;")
    w('\t\tsourceTree = "<group>";')
    w("\t};")
    w("/* End PBXGroup section */")
    w("")

    w("/* Begin PBXNativeTarget section */")
    w(f"\t{target_id} /* {APP_DIR_NAME} */ = {{")
    w("\t\tisa = PBXNativeTarget;")
    w(f"\t\tbuildConfigurationList = {cfglist_target};")
    w(f"\t\tbuildPhases = ({phase_src}, {phase_res});")
    w("\t\tbuildRules = ();")
    w("\t\tdependencies = ();")
    w(f"\t\tname = {APP_DIR_NAME};")
    w(f"\t\tproductName = {APP_DIR_NAME};")
    w(f"\t\tproductReference = {app_ref};")
    w('\t\tproductType = "com.apple.product-type.application";')
    w("\t};")
    w("/* End PBXNativeTarget section */")
    w("")

    w("/* Begin PBXProject section */")
    w(f"\t{project_id} /* Project object */ = {{")
    w("\t\tisa = PBXProject;")
    w("\t\tattributes = {")
    w("\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\tLastSwiftUpdateCheck = 2700;")
    w("\t\t\tLastUpgradeCheck = 2700;")
    w("\t\t};")
    w(f"\t\tbuildConfigurationList = {cfglist_project};")
    w('\t\tcompatibilityVersion = "Xcode 14.0";')
    w("\t\tdevelopmentRegion = en;")
    w("\t\thasScannedForEncodings = 0;")
    w("\t\tknownRegions = (")
    w("\t\t\ten,")
    w("\t\t\tBase,")
    w("\t\t);")
    w(f"\t\tmainGroup = {g_main};")
    w(f"\t\tproductRefGroup = {g_products};")
    w('\t\tprojectRoot = "";')
    w(f"\t\ttargets = ({target_id} );")
    w("\t};")
    w("/* End PBXProject section */")
    w("")

    w("/* Begin PBXResourcesBuildPhase section */")
    w(f"\t{phase_res} = {{")
    w("\t\tisa = PBXResourcesBuildPhase;")
    w("\t\tbuildActionMask = 2147483647;")
    w("\t\tfiles = (" + ", ".join(res_phase_ids) + ");")
    w("\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w("")

    w("/* Begin PBXSourcesBuildPhase section */")
    w(f"\t{phase_src} = {{")
    w("\t\tisa = PBXSourcesBuildPhase;")
    w("\t\tbuildActionMask = 2147483647;")
    w("\t\tfiles = (" + ", ".join(src_phase_ids) + ");")
    w("\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w("")

    w("/* Begin XCBuildConfiguration section */")
    w(xcconfig_block(conf_proj_debug, "Debug", project_settings_body(True)))
    w(xcconfig_block(conf_proj_release, "Release", project_settings_body(False)))
    w(xcconfig_block(conf_tgt_debug, "Debug", target_settings_body()))
    w(xcconfig_block(conf_tgt_release, "Release", target_settings_body()))
    w("/* End XCBuildConfiguration section */")
    w("")

    w("/* Begin XCConfigurationList section */")
    w(f"\t{cfglist_project} /* Build configuration list for PBXProject {APP_DIR_NAME} */ = {{")
    w("\t\tisa = XCConfigurationList;")
    w(f"\t\tbuildConfigurations = ({conf_proj_debug}, {conf_proj_release});")
    w("\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\tdefaultConfigurationName = Release;")
    w("\t};")
    w(f"\t{cfglist_target} /* Build configuration list for PBXNativeTarget {APP_DIR_NAME} */ = {{")
    w("\t\tisa = XCConfigurationList;")
    w(f"\t\tbuildConfigurations = ({conf_tgt_debug}, {conf_tgt_release});")
    w("\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\tdefaultConfigurationName = Release;")
    w("\t};")
    w("/* End XCConfigurationList section */")
    w("\t};")
    w(f"\trootObject = {project_id} /* Project object */;")
    w("}")

    os.makedirs(os.path.dirname(PROJECT_FILE), exist_ok=True)
    with open(PROJECT_FILE, "w") as f:
        f.write("\n".join(out) + "\n")
    write_scheme(os.path.dirname(PROJECT_FILE), APP_DIR_NAME, target_id)
    print(f"Wrote {PROJECT_FILE}")
    print(f"  {len(swift_files)} Swift files, {len(resource_files)} resources")
    for s in swift_files:
        print("   -", s)


if __name__ == "__main__":
    main()
