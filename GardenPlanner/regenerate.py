#!/usr/bin/env python3
import os, uuid

SRC_DIR = "GardenPlanner"  # The source code lives in GardenPlanner/GardenPlanner/
OUT_PROJ = "GardenPlanner.xcodeproj/project.pbxproj"

if not os.path.isdir(SRC_DIR):
    print(f"ERROR: {SRC_DIR} not found")
    exit(1)

def uid():
    return uuid.uuid4().hex[:24]

# Gather ALL files recursively
swift_files = sorted([f for f in os.listdir(SRC_DIR) if f.endswith('.swift')])
swift_files = [f for f in swift_files if f != '.DS_Store']

resource_files = []
for f in os.listdir(SRC_DIR):
    fp = os.path.join(SRC_DIR, f)
    if f.endswith(('.plist', '.json')):
        resource_files.append(f)

print(f"Top-level Swift: {len(swift_files)}")
print(f"Top-level Resources: {len(resource_files)}")

# Also get subdirectory Swift files
sub_swift = []
for root, dirs, files in os.walk(SRC_DIR):
    for f in files:
        if f.endswith('.swift') and f != '.DS_Store':
            sub_swift.append(f)
sub_swift = sorted(sub_swift)
print(f"Subdirectory Swift: {len(sub_swift)}")
all_swift = swift_files + sub_swift
print(f"Total Swift: {len(all_swift)}")

# UUID mapping
swift_map = {f: uid() for f in all_swift}
resource_map = {f: uid() for f in resource_files}

lines = []
def w(s):
    lines.append(s)

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {}")
w("\tobjectVersion = 56;")
w("\tobjects = {")

# --- PBXBuildFile section ---
w("\n/* Begin PBXBuildFile section */")
for f in all_swift:
    bid = uid()
    fid = swift_map[f]
    name = os.path.splitext(f)[0]
    w(f"\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid}_ref; }};")

for f in resource_files:
    bid = uid()
    fid = resource_map[f]
    w(f"\t{bid} /* {f} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid}_ref; }};")
w("/* End PBXBuildFile section */\n")

# --- PBXFileReference section ---
w("/* Begin PBXFileReference section */")
for f in all_swift:
    fid = swift_map[f]
    name = os.path.splitext(f)[0]
    w(f"\t{fid}_ref /* {name}.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}.swift; sourceTree = \"<group>\"; }};")

for f in resource_files:
    fid = resource_map[f]
    ft = '.text.plist.xml' if f.endswith('.plist') else 'text.json'
    w(f"\t{fid}_ref /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {f}; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */\n")

# --- PBXGroup section ---
w("/* Begin PBXGroup section */")

proj_gid = uid()
root_gid = uid()
src_gid = uid()
res_gid = uid()

# Project file group
w(f"\t{proj_gid} /* GardenPlanner.xcodeproj */ = {{")
w(f"\t\tisa = PBXGroup;")
w(f"\t\tchildren = ({root_gid});")
w(f"\t\tname = GardenPlanner.xcodeproj;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

# Main GardenPlanner group
w(f"\t{root_gid} /* GardenPlanner */ = {{")
w(f"\t\tisa = PBXGroup;")
w(f"\t\tchildren = ({src_gid}, {res_gid});")
w(f"\t\tname = GardenPlanner;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

# Sources group
w(f"\t{src_gid} /* Sources */ = {{")
w(f"\t\tisa = PBXGroup;")
src_children = ', '.join([f"{swift_map[f]}_ref" for f in all_swift])
w(f"\t\tchildren = ({src_children});")
w(f"\t\tname = Sources;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

# Resources group
w(f"\t{res_gid} /* Resources */ = {{")
w(f"\t\tisa = PBXGroup;")
res_children = ', '.join([f"{resource_map[f]}_ref" for f in resource_files])
w(f"\t\tchildren = ({res_children});")
w(f"\t\tname = Resources;")
w(f"\t\tsourceTree = \"<group>\";")
w(f"\t}};")

w("/* End PBXGroup section */\n")

# --- PBXNativeTarget ---
target_id = uid()
app_ref_id = uid()
debug_cfg_id = uid()
release_cfg_id = uid()
config_list_id = uid()
sources_phase_id = uid()
resources_phase_id = uid()
main_group_id = uid()

w("/* Begin PBXNativeTarget section */")
w(f"\t{target_id} /* GardenPlanner */ = {{")
w(f"\t\tisa = PBXNativeTarget;")
w(f"\t\tbuildConfigurationList = {config_list_id};")
w(f"\t\tbuildPhases = ({sources_phase_id}, {resources_phase_id});")
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

# --- PBXProject ---
w("/* Begin PBXProject section */")
w(f"\t{main_group_id} /* Project object */ = {{")
w(f"\t\tisa = PBXProject;")
w(f"\t\tattributes = {{")
w(f"\t\t\tBuildIndependentTargetsInParallel = 1;")
w(f"\t\t\tDevelopmentRegion = en;")
w(f"\t\t}};")
w(f"\t\tdebugConfigurationList = {config_list_id};")
w(f"\t\tmainGroup = {root_gid};")
w(f"\t\tprojectRoot = \"\";")
w(f"\t\ttargets = ({target_id});")
w(f"\t}};")
w("/* End PBXProject section */\n")

# --- Sources Build Phase ---
src_build_refs = ', '.join([uid() for _ in all_swift])
w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t{sources_phase_id} = {{")
w(f"\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\tbuildActionMask = 2147483647;")
w(f"\t\tfiles = ({src_build_refs});")
w(f"\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t}};")
w("/* End PBXSourcesBuildPhase section */\n")

# --- Resources Build Phase ---
res_build_refs = ', '.join([uid() for _ in resource_files])
w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t{resources_phase_id} = {{")
w(f"\t\tisa = PBXResourcesBuildPhase;")
w(f"\t\tbuildActionMask = 2147483647;")
w(f"\t\tfiles = ({res_build_refs});")
w(f"\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t}};")
w("/* End PBXResourcesBuildPhase section */\n")

# --- XCBuildConfiguration (Debug + Release) ---
w("/* Begin XCBuildConfiguration section */")

# Debug config settings
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
    'COPY_PHASE_STRIP = NO;',
    'DEBUG_INFORMATION_FORMAT = dwarf;',
    'ENABLE_STRICT_OBJC_MSGSEND = YES;',
    'ENABLE_TESTABILITY = YES;',
    'GCC_C_LANGUAGE_STANDARD = gnu17;',
    'GCC_DYNAMIC_NO_PIC = NO;',
    'GCC_OPTIMIZATION_LEVEL = 0;',
    'GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1",);',
    'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    'MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;',
    'MTL_FAST_MATH = YES;',
    'ONLY_ACTIVE_ARCH = YES;',
    'SDKROOT = iphoneos;',
    'SUPPORTED_PLATFORMS = iphoneos;',
]
w(f"\t{debug_cfg_id} /* Debug */ = {{")
w(f"\t\tisa = XCBuildConfiguration;")
w(f"\t\tbuildSettings = {{")
w('\t\t' + '\n\t\t'.join(debug_settings))
w('\t};')
w('\t\tname = Debug;')
w('\t};')

# Release config settings
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
    'COPY_PHASE_STRIP = NO;',
    'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
    'ENABLE_NS_ASSERTIONS = NO;',
    'ENABLE_STRICT_OBJC_MSGSEND = YES;',
    'GCC_C_LANGUAGE_STANDARD = gnu17;',
    'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    'MTL_FAST_MATH = YES;',
    'SDKROOT = iphoneos;',
    'SUPPORTED_PLATFORMS = iphoneos;',
]
w(f"\t{release_cfg_id} /* Release */ = {{")
w(f"\t\tisa = XCBuildConfiguration;")
w(f"\t\tbuildSettings = {{")
w('\t\t' + '\n\t\t'.join(release_settings))
w('\t};')
w('\t\tname = Release;')
w('\t};')
w("/* End XCBuildConfiguration section */\n")

# --- XCConfigurationList ---
w("/* Begin XCConfigurationList section */")

target_settings = [
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
w(f"\t\tisa = XCConfigurationList;")
w(f"\t\tbuildConfigurations = ({debug_cfg_id}, {release_cfg_id});")
w('\t\tbuildSettings = {')
w('\t\t' + '\n\t\t'.join(target_settings))
w('\t};')
w(f'\t\tname = Debug;')
w('\t};')

w("/* End XCConfigurationList section */\n")

# Close
w("};")
w(f'rootObject = "{main_group_id}"; /* Project object */')
w("}")

output = '\n'.join(lines)
os.makedirs(os.path.dirname(OUT_PROJ), exist_ok=True)
with open(OUT_PROJ, 'w') as f:
    f.write(output)

opens = output.count('{')
closes = output.count('}')
print(f"Generated: {os.path.abspath(OUT_PROJ)}")
print(f"Total Swift: {len(all_swift)}, Resources: {len(resource_files)}")
print(f"Braces: {opens} open, {closes} close -> {'BALANCED' if opens==closes else 'MISMATCH!'}")
