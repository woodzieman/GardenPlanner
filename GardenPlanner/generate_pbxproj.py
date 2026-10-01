#!/usr/bin/env python3
import os, uuid, glob

SRC_DIR = "GardenPlanner"
OUT_PROJ = "GardenPlanner.xcodeproj/project.pbxproj"

if not os.path.isdir(SRC_DIR):
    print(f"ERROR: {SRC_DIR} not found")
    exit(1)

def uid():
    return uuid.uuid4().hex[:24]

swift_files = sorted(glob.glob(os.path.join(SRC_DIR, "**/*.swift"), recursive=True))
swift_files = [os.path.relpath(f, SRC_DIR) for f in swift_files if not f.endswith('.DS_Store')]

# Resources - use os.walk to ensure we find them
resource_files = []
for root, dirs, files in os.walk(SRC_DIR):
    for f in files:
        if f.endswith(('.plist', '.json')) and not f.endswith('.DS_Store'):
            resource_files.append(os.path.relpath(os.path.join(root, f), SRC_DIR))
resource_files = sorted(resource_files)

print(f"Swift files ({len(swift_files)})")
print(f"Resources ({len(resource_files)}): {resource_files}")

swift_map = {f: uid() for f in swift_files}
resource_map = {f: uid() for f in resource_files}

project_group_id = uid()
app_group_id = uid()
sources_group_id = uid()
resources_group_id = uid()
target_id = uid()
app_ref_id = uid()
proj_obj_id = uid()
debug_cfg_id = uid()
release_cfg_id = uid()
config_list_id = uid()
src_phase_id = uid()
res_phase_id = uid()

build_file_ids = {}
for f in swift_files:
    build_file_ids[f] = uid()
for f in resource_files:
    build_file_ids[f] = uid()

lines = []
def w(s):
    lines.append(s)

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {};")
w("\tobjectVersion = 56;")
w("\tobjects = {")

# === PBXBuildFile section ===
w("\n/* Begin PBXBuildFile section */")
for f in swift_files:
    bid = build_file_ids[f]
    fid = swift_map[f]
    name = os.path.splitext(f)[0]
    w(f"\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid}_ref; }};")
for f in resource_files:
    bid = build_file_ids[f]
    fid = resource_map[f]
    w(f"\t{bid} /* {f} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid}_ref; }};")
w("/* End PBXBuildFile section */\n")

# === PBXFileReference section ===
w("/* Begin PBXFileReference section */")
for f in swift_files:
    fid = swift_map[f]
    name = os.path.splitext(f)[0]
    w(f"\t{fid}_ref /* {name}.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}.swift; sourceTree = \"<group>\"; }};")
for f in resource_files:
    fid = resource_map[f]
    ft = '.text.plist.xml' if f.endswith('.plist') else 'text.json'
    w(f"\t{fid}_ref /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {f}; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */\n")

# === PBXGroup section ===
w("/* Begin PBXGroup section */")
w(f"\t{project_group_id} /* GardenPlanner.xcodeproj */ = {{")
w(f"\t\tisa = PBXGroup;")
w(f"\t\tchildren = ({app_group_id});")
w(f"\t\tname = GardenPlanner.xcodeproj;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

w(f"\t{app_group_id} /* GardenPlanner */ = {{")
w(f"\t\tisa = PBXGroup;")
w(f"\t\tchildren = ({sources_group_id}, {resources_group_id});")
w(f"\t\tname = GardenPlanner;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

w(f"\t{sources_group_id} /* Sources */ = {{")
w(f"\t\tisa = PBXGroup;")
src_refs = ', '.join([f"{swift_map[f]}_ref" for f in swift_files])
w(f"\t\tchildren = ({src_refs});")
w(f"\t\tname = Sources;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

w(f"\t{resources_group_id} /* Resources */ = {{")
w(f"\t\tisa = PBXGroup;")
if resource_files:
    res_refs = ', '.join([f"{resource_map[f]}_ref" for f in resource_files])
    w(f"\t\tchildren = ({res_refs});")
else:
    w(f"\t\tchildren = ();")
w(f"\t\tname = Resources;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

w("/* End PBXGroup section */\n")

# === PBXNativeTarget section ===
w("/* Begin PBXNativeTarget section */")
w(f"\t{target_id} /* GardenPlanner */ = {{")
w(f"\t\tisa = PBXNativeTarget;")
w(f"\t\tbuildConfigurationList = {config_list_id};")
w(f"\t\tbuildPhases = ({src_phase_id}, {res_phase_id});")
w(f"\t\tbuildRules = ()")
w(f"\t\tdependencies = ()")
w(f"\t\tname = GardenPlanner;")
w(f"\t\tproductReference = {app_ref_id};")
w(f"\t\tproductType = \"com.apple.product-type.application\";")
w(f"\t}};")

w(f"\t{app_ref_id} /* GardenPlanner.app */ = {{")
w(f"\t\tisa = PBXFileReference;")
w(f"\t\texplicitFileType = \"wrapper.application\";")
w(f"\t\tname = GardenPlanner.app;")
w(f"\t\tpath = GardenPlanner/GardenPlanner.app;")
w(f"\t\tsourceTree = BUILT_PRODUCTS_DIR;")
w(f"\t}};")
w("/* End PBXNativeTarget section */\n")

# === PBXProject section ===
w("/* Begin PBXProject section */")
w(f"\t{proj_obj_id} /* Project object */ = {{")
w(f"\t\tisa = PBXProject;")
w(f"\t\tattributes = {{")
w(f"\t\t\tBuildIndependentTargetsInParallel = 1;")
w(f"\t\t\tDevelopmentRegion = en;")
w(f"\t\t}};")
w(f"\t\tdebugConfigurationList = {config_list_id};")
w(f"\t\tmainGroup = {app_group_id};")
w(f"\t\tprojectRoot = \"\";")
w(f"\t\ttargets = ({target_id});")
w(f"\t}};")
w("/* End PBXProject section */\n")

# === Sources Build Phase ===
w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t{src_phase_id} = {{")
w(f"\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\tbuildActionMask = 2147483647;")
src_bfr = ', '.join([f"{build_file_ids[f]}" for f in swift_files])
w(f"\t\tfiles = ({src_bfr});")
w(f"\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t}};")
w("/* End PBXSourcesBuildPhase section */\n")

# === Resources Build Phase ===
w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t{res_phase_id} = {{")
w(f"\t\tisa = PBXResourcesBuildPhase;")
w(f"\t\tbuildActionMask = 2147483647;")
if resource_files:
    res_bfr = ', '.join([f"{build_file_ids[f]}" for f in resource_files])
    w(f"\t\tfiles = ({res_bfr});")
else:
    w(f"\t\tfiles = ();")
w(f"\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t}};")
w("/* End PBXResourcesBuildPhase section */\n")

# === XCBuildConfiguration (Debug + Release) ===
w("/* Begin XCBuildConfiguration section */")

debug_settings = [
    'ALWAYS_SEARCH_USER_PATHS = NO;',
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
    'CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
    'CLANG_ENABLE_MODULES = YES;',
    'CLANG_ENABLE_OBJC_ARC = YES;',
    'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;',
    'CLANG_WARN_BOOL_CONVERSION = YES;',
    'CLANG_WARN_COMMA = YES;',
    'CLANG_WARN_CONSTANT_CONVERSION = YES;',
    'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;',
    'CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;',
    'CLANG_WARN_DOCUMENTATION_COMMENTS = YES;',
    'CLANG_WARN_EMPTY_BODY = YES;',
    'CLANG_WARN_ENUM_CONVERSION = YES;',
    'CLANG_WARN_INFINITE_RECURSION = YES;',
    'CLANG_WARN_INT_CONVERSION = YES;',
    'CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;',
    'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;',
    'CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;',
    'CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;',
    'CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;',
    'CLANG_WARN_SIGN_CONVERSION = YES;',
    'CLANG_WARN_STRICT_PROTOTYPES = YES;',
    'CLANG_WARN_SUSPICIOUS_MOVE = YES;',
    'CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AWAY;',
    'CLANG_WARN_UNREACHABLE_CODE = YES;',
    'CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;',
    'COPY_PHASE_STRIP = NO;',
    'DEBUG_INFORMATION_FORMAT = dwarf;',
    'ENABLE_STRICT_OBJC_MSGSEND = YES;',
    'ENABLE_TESTABILITY = YES;',
    'ENABLE_USER_SCRIPT_SANDBOXING = YES;',
    'GCC_C_LANGUAGE_STANDARD = gnu17;',
    'GCC_DYNAMIC_NO_PIC = NO;',
    'GCC_NO_COMMON_BLOCKS = YES;',
    'GCC_OPTIMIZATION_LEVEL = 0;',
    'GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1",);',
    'GCC_WARN_64_TO_32_BIT_CONVERSION = YES;',
    'GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;',
    'GCC_WARN_UNDECLARED_SELECTOR = YES;',
    'GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;',
    'GCC_WARN_UNUSED_FUNCTION = YES;',
    'GCC_WARN_UNUSED_VARIABLE = YES;',
    'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    'MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;',
    'MTL_FAST_MATH = YES;',
    'ONLY_ACTIVE_ARCH = YES;',
    'SDKROOT = iphoneos;',
    'SUPPORTED_PLATFORMS = iphoneos;',
    'SUPPORTED_PLATFORMS.poposx = macosx;',
]
w(f"\t{debug_cfg_id} /* Debug */ = {{")
w(f"\t\tisa = XCBuildConfiguration;")
w(f"\t\tbuildSettings = {{")
w('\t\t' + '\n\t\t'.join(debug_settings))
w('\t};')
w('\t\tname = Debug;')
w('\t}};')

release_settings = [
    'ALWAYS_SEARCH_USER_PATHS = NO;',
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
    'CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
    'CLANG_ENABLE_MODULES = YES;',
    'CLANG_ENABLE_OBJC_ARC = YES;',
    'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;',
    'CLANG_WARN_BOOL_CONVERSION = YES;',
    'CLANG_WARN_COMMA = YES;',
    'CLANG_WARN_CONSTANT_CONVERSION = YES;',
    'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;',
    'CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;',
    'CLANG_WARN_DOCUMENTATION_COMMENTS = YES;',
    'CLANG_WARN_EMPTY_BODY = YES;',
    'CLANG_WARN_ENUM_CONVERSION = YES;',
    'CLANG_WARN_INFINITE_RECURSION = YES;',
    'CLANG_WARN_INT_CONVERSION = YES;',
    'CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;',
    'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;',
    'CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;',
    'CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;',
    'CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;',
    'CLANG_WARN_SIGN_CONVERSION = YES;',
    'CLANG_WARN_STRICT_PROTOTYPES = YES;',
    'CLANG_WARN_SUSPICIOUS_MOVE = YES;',
    'CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AWAY;',
    'CLANG_WARN_UNREACHABLE_CODE = YES;',
    'CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;',
    'COPY_PHASE_STRIP = NO;',
    'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
    'ENABLE_NS_ASSERTIONS = NO;',
    'ENABLE_STRICT_OBJC_MSGSEND = YES;',
    'ENABLE_USER_SCRIPT_SANDBOXING = YES;',
    'GCC_C_LANGUAGE_STANDARD = gnu17;',
    'GCC_DYNAMIC_NO_PIC = NO;',
    'GCC_NO_COMMON_BLOCKS = YES;',
    'GCC_WARN_64_TO_32_BIT_CONVERSION = YES;',
    'GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;',
    'GCC_WARN_UNDECLARED_SELECTOR = YES;',
    'GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;',
    'GCC_WARN_UNUSED_FUNCTION = YES;',
    'GCC_WARN_UNUSED_VARIABLE = YES;',
    'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    'MTL_ENABLE_DEBUG_INFO = NO;',
    'MTL_FAST_MATH = YES;',
    'SDKROOT = iphoneos;',
    'SUPPORTED_PLATFORMS = iphoneos;',
    'SUPPORTED_PLATFORMS.poposx = macosx;',
]
w(f"\t{release_cfg_id} /* Release */ = {{")
w(f"\t\tisa = XCBuildConfiguration;")
w(f"\t\tbuildSettings = {{")
w('\t\t' + '\n\t\t'.join(release_settings))
w('\t};')
w('\t\tname = Release;')
w('\t}};')
w("/* End XCBuildConfiguration section */\n")

# === XCConfigurationList section (the TARGET config) ===
w("/* Begin XCConfigurationList section */")

target_build_settings = [
    'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
    'CODE_SIGN_STYLE = Automatic;',
    'CURRENT_PROJECT_VERSION = 2;',
    'DEVELOPMENT_TEAM = "VDWDUNC9R2";',
    'GENERATE_INFOPLIST_FILE = YES;',
    'INFOPLIST_KEY_CFBundleDisplayName = "3D Garden Planner";',
    'INFOPLIST_KEY_NSCameraUsageDescription = "GardenPlanner uses your camera for LiDAR scanning and AR-based garden mapping. This captures your garden layout, surfaces, and heights for planning plant placement.";',
    'INFOPLIST_KEY_NSLocalNetworkUsageDescription = "GardenPlanner uses local network for optional CloudKit sync to back up your garden plans across your Apple devices.";',
    'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "GardenPlanner needs your location to provide local weather and frost date information for your garden.";',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
    'MARKETING_VERSION = 1.0;',
    'PRODUCT_BUNDLE_IDENTIFIER = com.josephwoods.GardenPlanner;',
    'PRODUCT_NAME = "$(TARGET_NAME)"',
    'SWIFT_EMIT_LOC_STRINGS = YES;',
    'SWIFT_VERSION = 5.9;',
    'TARGETED_DEVICE_FAMILY = "1,2";',
]

w(f"\t{config_list_id} /* Build configuration list for PBXNativeTarget \"GardenPlanner\" */ = {{")
w(f"\t\tisa = XCBuildConfiguration;")
w(f"\t\tbuildSettings = {{")
w('\t\t' + '\n\t\t'.join(target_build_settings))
w('\t};')
w(f'\t\tname = Debug;')
w('\t};')

w(f"\t{config_list_id}_release = {config_list_id}")
w("/* End XCConfigurationList section */\n")

# Close
w("};")
w(f'rootObject = "{proj_obj_id}"; /* Project object */')
w("}")

# Remove any extra "};" before rootObject by ensuring proper structure
# Fix the last part of the file to have proper closure
content = '\n'.join(lines)
# Find the rootObject line and fix surrounding structure
parts = content.rsplit('\n', 2)  # split off last 2 lines (rootObject and final })
# The second-to-last should be rootObject, the last should be }
if len(parts) >= 2:
    rootobj_line = parts[-2].strip()
    final_brace = parts[-1].strip()
    # Remove extra }; before rootObject
    fixed = '\n'.join(parts[:-2]).rstrip()
    if fixed.endswith('};'):
        fixed = fixed[:-2].rstrip()  # remove the extra };
    fixed = fixed + '\n' + rootobj_line + '\n' + final_brace + '\n'
else:
    fixed = content

os.makedirs(os.path.dirname(OUT_PROJ), exist_ok=True)
with open(OUT_PROJ, 'w') as f:
    f.write(fixed)

opens = content.count('{')
closes = content.count('}')
print(f"\nGenerated: {os.path.abspath(OUT_PROJ)}")
print(f"Swift: {len(swift_files)}, Resources: {len(resource_files)}")
print(f"Braces: {opens} open, {closes} close -> {'BALANCED' if opens==closes else 'MISMATCH!'}")
