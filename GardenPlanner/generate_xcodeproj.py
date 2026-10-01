#!/usr/bin/env python3
"""Generate a proper Xcode 27 ASCII format pbxproj."""
import os, uuid, glob

SRC_DIR = "GardenPlanner"

def make_id():
    """Generate a 36-character hex ID (matching Xcode 27 format)."""
    return uuid.uuid4().hex[:36]

# Gather source files
swift_files = sorted(glob.glob(os.path.join(SRC_DIR, "**/*.swift"), recursive=True))
swift_files = [os.path.relpath(f, SRC_DIR) for f in swift_files if not f.endswith('.DS_Store')]

resource_files = []
for root, dirs, files in os.walk(SRC_DIR):
    for f in files:
        if f.endswith(('.plist', '.json')) and not f.endswith('.DS_Store'):
            resource_files.append(os.path.relpath(os.path.join(root, f), SRC_DIR))
resource_files = sorted(resource_files)

# UUIDs (36-char hex)
src_map = {f: make_id() for f in swift_files}
res_map = {f: make_id() for f in resource_files}
root_group_id = make_id()
app_group_id = make_id()
products_group_id = make_id()
src_group_id = make_id()
resources_group_id = make_id()
sync_root_group_id = make_id()
target_id = make_id()
app_ref_id = make_id()
proj_obj_id = make_id()
debug_cfg_id = make_id()
release_cfg_id = make_id()
config_list_id = make_id()
src_phase_id = make_id()
res_phase_id = make_id()
frameworks_phase_id = make_id()

build_file_ids = {}
for f in swift_files:
    build_file_ids[f] = make_id()
for f in resource_files:
    build_file_ids[f] = make_id()

lines = []
def w(s):
    lines.append(s)

# Header (exact format from Xcode 27 templates)
w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {")
w("\t};")
w("\tobjectVersion = 90;")
w("\tobjects = {")

# === PBXFileReference section ===
w("\n/* Begin PBXFileReference section */")
# App product reference
w(f"\t\t{app_ref_id} /* MyApp.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MyApp.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
# Source file references
for f in swift_files:
    fid = src_map[f]
    name = os.path.splitext(f)[0]
    w(f"\t\t{fid} /* {name}.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {name}.swift; path = {name}.swift; sourceTree = \"<group>\"; }};")
# Resource file references
for f in resource_files:
    fid = res_map[f]
    ft = ".text.plist.xml" if f.endswith(".plist") else "text.json"
    w(f"\t\t{fid} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; name = {f}; path = {f}; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */\n")

# === PBXFileSystemSynchronizedRootGroup (new in Xcode 27) ===
w("/* Begin PBXFileSystemSynchronizedRootGroup */")
w(f"\t\t{sync_root_group_id} /* GardenPlanner */ = {{")
w(f"\t\t\tisa = PBXFileSystemSynchronizedRootGroup;")
w(f"\t\t\tpath = GardenPlanner;")
w(f"\t\t\tsourceTree = \"<group>\";")
w(f"\t\t}};")
w("/* End PBXFileSystemSynchronizedRootGroup */\n")

# === Build Phase IDs (Sources, Frameworks, Resources) ===
w("/* Begin PBXFrameworksBuildPhase */")
w(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
w(f"\t\t\tisa = PBXFrameworksBuildPhase;")
w(f"\t\t\tfiles = ();")
w(f"\t\t}};")
w("/* End PBXFrameworksBuildPhase */\n")

# === PBXGroup section ===
w("/* Begin PBXGroup section */")
w(f"\t\t{root_group_id} = {{")
w(f"\t\t\tisa = PBXGroup;")
w(f"\t\t\tchildren = ({sync_root_group_id}, {products_group_id});")
w(f"\t\t\tsourceTree = \"<group>\";")
w(f"\t\t}};")
w(f"\t\t{products_group_id} /* Products */ = {{")
w(f"\t\t\tisa = PBXGroup;")
w(f"\t\t\tchildren = ({app_ref_id});")
w(f"\t\t\tname = Products;")
w(f"\t\t\tsourceTree = \"<group>\";")
w(f"\t\t}};")

# Sources group with all Swift refs
src_refs = ', '.join([f"{src_map[f]} /* {os.path.splitext(f)[0]}.swift */" for f in swift_files])
w(f"\t\t{src_group_id} /* Sources */ = {{")
w(f"\t\t\tisa = PBXGroup;")
w(f"\t\t\tchildren = ({src_refs});")
w(f"\t\t\tfileSystemSynchronizedGroups = ({sync_root_group_id});")
w(f"\t\t\tname = Sources;")
w(f"\t\t\tpath = GardenPlanner;")
w(f"\t\t\tsourceTree = \"<group>\";")
w(f"\t\t}};")

# Resources group
if resource_files:
    res_refs = ', '.join([f"{res_map[f]} /* {f} */" for f in resource_files])
    w(f"\t\t{resources_group_id} /* Resources */ = {{")
    w(f"\t\t\tisa = PBXGroup;")
    w(f"\t\t\tchildren = ({res_refs});")
    w(f"\t\t\tname = Resources;")
    w(f"\t\t\tpath = GardenPlanner;")
    w(f"\t\t\tsourceTree = \"<group>\";")
    w(f"\t\t}};")
else:
    w(f"\t\t{resources_group_id} /* Resources */ = {{")
    w(f"\t\t\tisa = PBXGroup;")
    w(f"\t\t\tchildren = ();")
    w(f"\t\t\tname = Resources;")
    w(f"\t\t\tpath = GardenPlanner;")
    w(f"\t\t\tsourceTree = \"<group>\";")
    w(f"\t\t}};")

w("/* End PBXGroup section */\n")

# === PBXNativeTarget section ===
w("/* Begin PBXNativeTarget section */")
w(f"\t\t{target_id} /* GardenPlanner */ = {{")
w(f"\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {config_list_id} /* Build configuration list for PBXNativeTarget \"GardenPlanner\" */;")
w(f"\t\t\tbuildPhases = ({src_phase_id}, {frameworks_phase_id}, {res_phase_id});")
w(f"\t\t\tbuildRules = ();")
w(f"\t\t\tfileSystemSynchronizedGroups = ({sync_root_group_id} /* GardenPlanner */);")
w(f"\t\t\tname = GardenPlanner;")
w(f"\t\t\tproductName = GardenPlanner;")
w(f"\t\t\tproductReference = {app_ref_id} /* MyApp.app */;")
w(f"\t\t\tproductType = \"com.apple.product-type.application\";")
w(f"\t\t}};")

w(f"\t\t{app_ref_id} /* MyApp.app */ = {{")
w(f"\t\t\tisa = PBXFileReference;")
w(f"\t\t\texplicitFileType = wrapper.application;")
w(f"\t\t\tincludeInIndex = 0;")
w(f"\t\t\tpath = MyApp.app;")
w(f"\t\t\tsourceTree = BUILT_PRODUCTS_DIR;")
w(f"\t\t}};")
w("/* End PBXNativeTarget section */\n")

# === PBXProject section ===
w("/* Begin PBXProject section */")
w(f"\t\t{proj_obj_id} /* Project object */ = {{")
w(f"\t\t\tisa = PBXProject;")
w(f"\t\t\tattributes = {{")
w(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w(f"\t\t\t\tDevelopmentRegion = en;")
w(f"\t\t\t\tTargetProperties = {{")
w(f"\t\t\t\t\t_PBXProject = {{")
w(f"\t\t\t\t\t\tAutomaticCodeSigning = YES;")
w(f"\t\t\t\t\t\tCreateGitIgnore = YES;")
w(f"\t\t\t\t\t\tIsAvailableOnSimulator = YES;")
w(f"\t\t\t\t\t\tIsAvailableOnDevice = YES;")
w(f"\t\t\t\t\t\tSwiftLanguageVersion = \"999\";")
w(f"\t\t\t\t\t}};")
w(f"\t\t\t\t}};")
w(f"\t\t\t}};")
w(f"\t\t\tdebugConfigurationList = {config_list_id};")
w(f"\t\t\tmainGroup = {root_group_id};")
w(f"\t\t\tprojectRoot = \"\";")
w(f"\t\t\ttargets = ({target_id} /* GardenPlanner */);")
w(f"\t\t}};")
w("/* End PBXProject section */\n")

# === Sources/BuildPhase ===
src_build_refs = ', '.join([f"{build_file_ids[f]} /* {os.path.splitext(f)[0]} in Sources */" for f in swift_files])
w("/* Begin PBXSourcesBuildPhase */")
w(f"\t\t{src_phase_id} /* Sources */ = {{")
w(f"\t\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = ({src_build_refs});")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w("/* End PBXSourcesBuildPhase */\n")

# === Resources BuildPhase ===
if resource_files:
    res_build_refs = ', '.join([f"{build_file_ids[f]} /* {f} in Resources */" for f in resource_files])
else:
    res_build_refs = ""
w("/* Begin PBXResourcesBuildPhase */")
w(f"\t\t{res_phase_id} /* Resources */ = {{")
w(f"\t\t\tisa = PBXResourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = ({res_build_refs});")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w("/* End PBXResourcesBuildPhase */\n")

# === XCBuildConfiguration (Debug + Release) ===
w("/* Begin XCBuildConfiguration section */")

debug_settings = {
    'ALWAYS_SEARCH_USER_PATHS': 'NO',
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS': 'YES',
    'CLANG_ANALYZER_NONNULL': 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD': '"gnu++20"',
    'CLANG_ENABLE_MODULES': 'YES',
    'CLANG_ENABLE_OBJC_ARC': 'YES',
    'CLANG_ENABLE_OBJC_WEAK': 'YES',
    'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING': 'YES',
    'CLANG_WARN_BOOL_CONVERSION': 'YES',
    'CLANG_WARN_COMMA': 'YES',
    'CLANG_WARN_CONSTANT_CONVERSION': 'YES',
    'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS': 'YES',
    'CLANG_WARN_DIRECT_OBJC_ISA_USAGE': 'YES_ERROR',
    'CLANG_WARN_DOCUMENTATION_COMMENTS': 'YES',
    'CLANG_WARN_EMPTY_BODY': 'YES',
    'CLANG_WARN_ENUM_CONVERSION': 'YES',
    'CLANG_WARN_INFINITE_RECURSION': 'YES',
    'CLANG_WARN_INT_CONVERSION': 'YES',
    'CLANG_WARN_NON_LITERAL_NULL_CONVERSION': 'YES',
    'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF': 'YES',
    'CLANG_WARN_OBJC_LITERAL_CONVERSION': 'YES',
    'CLANG_WARN_OBJC_ROOT_CLASS': 'YES_ERROR',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER': 'YES',
    'CLANG_WARN_RANGE_LOOP_ANALYSIS': 'YES',
    'CLANG_WARN_SIGN_CONVERSION': 'YES',
    'CLANG_WARN_STRICT_PROTOTYPES': 'YES',
    'CLANG_WARN_SUSPICIOUS_MOVE': 'YES',
    'CLANG_WARN_UNGUARDED_AVAILABILITY': 'YES_AWAY',
    'CLANG_WARN_UNREACHABLE_CODE': 'YES',
    'COPY_PHASE_STRIP': 'NO',
    'DEBUG_INFORMATION_FORMAT': 'dwarf',
    'ENABLE_DEVELOPER_DIR': 'YES',
    'ENABLE_TESTABILITY': 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
    'GCC_C_LANGUAGE_STANDARD': 'gnu17',
    'GCC_DYNAMIC_NO_PIC': 'NO',
    'GCC_NO_COMMON_BLOCKS': 'YES',
    'GCC_OPTIMIZATION_LEVEL': '0',
    'GCC_PREPROCESSOR_DEFINITIONS': '("DEBUG=1",)',
    'GCC_WARN_64_TO_32_BIT_CONVERSION': 'YES',
    'GCC_WARN_ABOUT_RETURN_TYPE': 'YES_ERROR',
    'GCC_WARN_UNDECLARED_SELECTOR': 'YES',
    'GCC_WARN_UNINITIALIZED_AUTOS': 'YES_AGGRESSIVE',
    'GCC_WARN_UNUSED_FUNCTION': 'YES',
    'GCC_WARN_UNUSED_VARIABLE': 'YES',
    'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
    'MTL_ENABLE_DEBUG_INFO': 'INCLUDE_SOURCE',
    'MTL_FAST_MATH': 'YES',
    'ONLY_ACTIVE_ARCH': 'YES',
    'SDKROOT': 'iphoneos',
    'SUPPORTED_PLATFORMS': 'iphoneos',
    'SUPPORTED_PLATFORMS.poposx': 'macosx'
}

debug_parts = []
for k, v in debug_settings.items():
    debug_parts.append(f"\t\t{k} = {v};")

w(f"\t\t{debug_cfg_id} /* Debug */ = {{")
w(f"\t\t\tisa = XCBuildConfiguration;")
w(f"\t\t\tbuildSettings = {{")
w('\n'.join(debug_parts))
w("\t\t};")
w(f"\t\t\tname = Debug;")
w(f"\t\t}};")

release_settings = dict(debug_settings)
release_settings['DEBUG_INFORMATION_FORMAT'] = '"dwarf-with-dsym"'
release_settings['ENABLE_NS_ASSERTIONS'] = 'NO'
release_settings['ENABLE_TESTABILITY'] = ''
release_settings['GCC_OPTIMIZATION_LEVEL'] = '"s"'
release_settings['GCC_PREPROCESSOR_DEFINITIONS'] = ''
release_settings['ONLY_ACTIVE_ARCH'] = ''
release_settings['MTL_ENABLE_DEBUG_INFO'] = 'NO'
for k in ['CLANG_ENABLE_OBJC_WEAK', 'DEBUG_INFORMATION_FORMAT', 'ENABLE_NS_ASSERTIONS', 'ENABLE_TESTABILITY', 'GCC_OPTIMIZATION_LEVEL', 'GCC_PREPROCESSOR_DEFINITIONS', 'ONLY_ACTIVE_ARCH', 'MTL_ENABLE_DEBUG_INFO', 'GCC_DYNAMIC_NO_PIC', 'GCC_NO_COMMON_BLOCKS', 'GCC_WARN_64_TO_32_BIT_CONVERSION', 'GCC_WARN_ABOUT_RETURN_TYPE', 'GCC_WARN_UNDECLARED_SELECTOR', 'GCC_WARN_UNINITIALIZED_AUTOS', 'GCC_WARN_UNUSED_FUNCTION', 'GCC_WARN_UNUSED_VARIABLE']:
    if k in release_settings:
        del debug_settings[k]  # debug keeps these, release doesn't

w(f"\t\t{release_cfg_id} /* Release */ = {{")
w(f"\t\t\tisa = XCBuildConfiguration;")
w(f"\t\t\tbuildSettings = {{")
release_parts = []
for k, v in debug_settings.items():
    release_parts.append(f"\t\t{k} = {v};")
w('\n'.join(release_parts))
w("\t\t};")
w(f"\t\t\tname = Release;")
w(f"\t\t}};")
w("/* End XCBuildConfiguration section */\n")

# === XCConfigurationList section (target settings) ===
w("/* Begin XCConfigurationList section */")

target_settings = {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
    'CODE_SIGN_STYLE': 'Automatic',
    'CURRENT_PROJECT_VERSION': '2',
    'DEVELOPMENT_TEAM': '"VDWDUNC9R2"',
    'GENERATE_INFOPLIST_FILE': 'YES',
    'INFOPLIST_KEY_CFBundleDisplayName': '"3D Garden Planner"',
    'INFOPLIST_KEY_NSCameraUsageDescription': '"GardenPlanner uses your camera for LiDAR scanning and AR-based garden mapping. This captures your garden layout, surfaces, and heights for planning plant placement."',
    'INFOPLIST_KEY_NSLocalNetworkUsageDescription': '"GardenPlanner uses local network for optional CloudKit sync to back up your garden plans across your Apple devices."',
    'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription': '"GardenPlanner needs your location to provide local weather and frost date information for your garden."',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad': '"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone': '"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"',
    'MARKETING_VERSION': '1.0',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.josephwoods.GardenPlanner',
    'PRODUCT_NAME': '"$(TARGET_NAME)"',
    'SWIFT_EMIT_LOC_STRINGS': 'YES',
    'SWIFT_VERSION': '5.9',
    'TARGETED_DEVICE_FAMILY': '"1,2"'
}

target_parts = []
for k, v in target_settings.items():
    target_parts.append(f"\t\t{k} = {v};")

w(f"\t\t{config_list_id} /* Build configuration list for PBXNativeTarget \"GardenPlanner\" */ = {{")
w(f"\t\t\tisa = XCBuildConfiguration;")
w(f"\t\t\tbuildSettings = {{")
w('\n'.join(target_parts))
w("\t\t};")
w(f"\t\t\tdefaultConfigurationName = Release;")
w(f"\t\t\tname = Debug;")
w(f"\t\t}};")
w(f"\t\t{config_list_id}_release = {config_list_id} /* Release configuration for PBXNativeTarget \"GardenPlanner\" */;")
w("/* End XCConfigurationList section */\n")

# Close
w("};")
w(f"rootObject = {proj_obj_id} /* Project object */;")
w("}")

output = '\n'.join(lines)
OUT_PROJ = "GardenPlanner.xcodeproj/project.pbxproj"
os.makedirs(os.path.dirname(OUT_PROJ), exist_ok=True)
with open(OUT_PROJ, 'w') as f:
    f.write(output)

print(f"Generated: {os.path.abspath(OUT_PROJ)}")
print(f"Swift: {len(swift_files)}, Resources: {len(resource_files)}")
# Verify it looks like a valid pbxproj
first_line = output.split('\n')[0]
print(f"First line: {first_line}")
print(f"Has UTF8 comment: {'// !$*UTF8*$!' in output}")
