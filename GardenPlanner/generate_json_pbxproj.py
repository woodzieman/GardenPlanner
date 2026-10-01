#!/usr/bin/env python3
"""Generate a JSON-format pbxproj for Xcode 27."""
import os, uuid, json, glob

SRC_DIR = "GardenPlanner"

def uid():
    return uuid.uuid4().hex[:24]

# Gather source files
swift_files = sorted(glob.glob(os.path.join(SRC_DIR, "**/*.swift"), recursive=True))
swift_files = [os.path.relpath(f, SRC_DIR) for f in swift_files if not f.endswith('.DS_Store')]

resource_files = []
for root, dirs, files in os.walk(SRC_DIR):
    for f in files:
        if f.endswith(('.plist', '.json')) and not f.endswith('.DS_Store'):
            resource_files.append(os.path.relpath(os.path.join(root, f), SRC_DIR))
resource_files = sorted(resource_files)

print(f"Swift files: {len(swift_files)}")
print(f"Resources: {len(resource_files)}")

swift_map = {f: uid() for f in swift_files}
resource_map = {f: uid() for f in resource_files}

# IDs
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

# Build file and reference IDs
all_swift_ids = {}
all_resource_ids = {}

for f in swift_files:
    all_swift_ids[f] = {"file_ref": uid(), "build_file": uid()}
for f in resource_files:
    all_resource_ids[f] = {"file_ref": uid(), "build_file": uid()}

def make_object_id(name, suffix):
    return uid()

# Create the JSON structure
# Xcode 27 uses a flat JSON format for pbxproj
pbxproj = {
    "archiveVersion": 1,
    "classes": {},
    "objectVersion": 56,
    "objects": {},
    "rootObject": proj_obj_id
}

# === PBXBuildFile objects ===
for f in swift_files:
    bid = all_swift_ids[f]["build_file"]
    fid = all_swift_ids[f]["file_ref"]
    name = os.path.splitext(f)[0]
    pbxproj["objects"][bid] = {
        "isa": "PBXBuildFile",
        "fileRef": f"{fid}_ref"
    }

for f in resource_files:
    bid = all_resource_ids[f]["build_file"]
    fid = all_resource_ids[f]["file_ref"]
    pbxproj["objects"][bid] = {
        "isa": "PBXBuildFile",
        "fileRef": f"{fid}_ref"
    }

# === PBXFileReference objects ===
for f in swift_files:
    fid = all_swift_ids[f]["file_ref"]
    name = os.path.splitext(f)[0]
    pbxproj["objects"][f"{fid}_ref"] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.swift",
        "path": f"{name}.swift",
        "sourceTree": "<group>"
    }

for f in resource_files:
    fid = all_resource_ids[f]["file_ref"]
    ft = ".text.plist.xml" if f.endswith(".plist") else "text.json"
    pbxproj["objects"][f"{fid}_ref"] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": ft,
        "path": f,
        "sourceTree": "<group>"
    }

# === PBXGroup objects ===
pbxproj["objects"][project_group_id] = {
    "isa": "PBXGroup",
    "children": [app_group_id],
    "name": "GardenPlanner.xcodeproj",
    "sourceTree": "<group>"
}

pbxproj["objects"][app_group_id] = {
    "isa": "PBXGroup",
    "children": [sources_group_id, resources_group_id],
    "name": "GardenPlanner",
    "sourceTree": "<group>"
}

pbxproj["objects"][sources_group_id] = {
    "isa": "PBXGroup",
    "children": [f"{swift_map[f]}" for f in swift_files],
    "name": "Sources",
    "sourceTree": "<group>"
}

# Actually need the _ref suffix
pbxproj["objects"][sources_group_id] = {
    "isa": "PBXGroup",
    "children": [f"{all_swift_ids[f]['file_ref']}_ref" for f in swift_files],
    "name": "Sources",
    "sourceTree": "<group>"
}

if resource_files:
    pbxproj["objects"][resources_group_id] = {
        "isa": "PBXGroup",
        "children": [f"{all_resource_ids[f]['file_ref']}_ref" for f in resource_files],
        "name": "Resources",
        "sourceTree": "<group>"
    }
else:
    pbxproj["objects"][resources_group_id] = {
        "isa": "PBXGroup",
        "children": [],
        "name": "Resources",
        "sourceTree": "<group>"
    }

# === PBXNativeTarget ===
pbxproj["objects"][target_id] = {
    "isa": "PBXNativeTarget",
    "buildConfigurationList": config_list_id,
    "buildPhases": [src_phase_id, res_phase_id],
    "buildRules": [],
    "dependencies": [],
    "name": "GardenPlanner",
    "productReference": app_ref_id,
    "productType": "com.apple.product-type.application"
}

pbxproj["objects"][app_ref_id] = {
    "isa": "PBXFileReference",
    "explicitFileType": "wrapper.application",
    "name": "GardenPlanner.app",
    "path": "GardenPlanner/GardenPlanner.app",
    "sourceTree": "BUILT_PRODUCTS_DIR"
}

# === PBXProject ===
pbxproj["objects"][proj_obj_id] = {
    "isa": "PBXProject",
    "attributes": {
        "BuildIndependentTargetsInParallel": 1,
        "DevelopmentRegion": "en"
    },
    "debugConfigurationList": config_list_id,
    "mainGroup": app_group_id,
    "projectRoot": "",
    "targets": [target_id]
}

# === Build Phases ===
src_build_refs = [all_swift_ids[f]["build_file"] for f in swift_files]
res_build_refs = [all_resource_ids[f]["build_file"] for f in resource_files]

pbxproj["objects"][src_phase_id] = {
    "isa": "PBXSourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": src_build_refs,
    "runOnlyForDeploymentPostprocessing": 0
}

pbxproj["objects"][res_phase_id] = {
    "isa": "PBXResourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": res_build_refs,
    "runOnlyForDeploymentPostprocessing": 0
}

# === XCBuildConfiguration (Debug + Release) ===
debug_settings = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_SIGN_CONVERSION": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AWAY",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1"],
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SUPPORTED_PLATFORMS": ["iphoneos"],
    "SUPPORTED_PLATFORMS.poposx": "macosx"
}

pbxproj["objects"][debug_cfg_id] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": debug_settings,
    "name": "Debug"
}

release_settings = dict(debug_settings)
release_settings["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"
release_settings["ENABLE_NS_ASSERTIONS"] = "NO"
release_settings["ENABLE_TESTABILITY"] = None
release_settings["GCC_OPTIMIZATION_LEVEL"] = None
release_settings["GCC_PREPROCESSOR_DEFINITIONS"] = None
release_settings["ONLY_ACTIVE_ARCH"] = None
release_settings["MTL_ENABLE_DEBUG_INFO"] = "NO"
for k in ["GCC_DYNAMIC_NO_PIC", "GCC_NO_COMMON_BLOCKS", "GCC_WARN_64_TO_32_BIT_CONVERSION", 
           "GCC_WARN_ABOUT_RETURN_TYPE", "GCC_WARN_UNDECLARED_SELECTOR", 
           "GCC_WARN_UNINITIALIZED_AUTOS", "GCC_WARN_UNUSED_FUNCTION", "GCC_WARN_UNUSED_VARIABLE"]:
    release_settings.pop(k, None)

pbxproj["objects"][release_cfg_id] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": release_settings,
    "name": "Release"
}

# === XCConfigurationList (target-level config) ===
target_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "2",
    "DEVELOPMENT_TEAM": "VDWDUNC9R2",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "3D Garden Planner",
    "INFOPLIST_KEY_NSCameraUsageDescription": "GardenPlanner uses your camera for LiDAR scanning and AR-based garden mapping. This captures your garden layout, surfaces, and heights for planning plant placement.",
    "INFOPLIST_KEY_NSLocalNetworkUsageDescription": "GardenPlanner uses local network for optional CloudKit sync to back up your garden plans across your Apple devices.",
    "INFOPLIST_KEY_NSLocationWhenInUseUsageDescription": "GardenPlanner needs your location to provide local weather and frost date information for your garden.",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.josephwoods.GardenPlanner",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.9",
    "TARGETED_DEVICE_FAMILY": "1,2"
}

pbxproj["objects"][config_list_id] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": target_settings,
    "name": "Debug"
}

# Release references Debug config
pbxproj[f"{config_list_id}_release"] = config_list_id

# Write the JSON file
OUT_PROJ = "GardenPlanner.xcodeproj/project.pbxproj"
os.makedirs(os.path.dirname(OUT_PROJ), exist_ok=True)
with open(OUT_PROJ, 'w') as f:
    json.dump(pbxproj, f, indent='\t')

print(f"Generated JSON-format pbxproj: {os.path.abspath(OUT_PROJ)}")
print(f"Swift: {len(swift_files)}, Resources: {len(resource_files)}")
print(f"Total objects: {len(pbxproj['objects'])}")
