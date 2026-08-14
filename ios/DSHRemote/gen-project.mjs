// gen-project.mjs — regenerates DSHRemote.xcodeproj from the source tree.
// Run: node gen-project.mjs  (from the ios/DSHRemote directory)
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = here; // ios/DSHRemote
const appDir = path.join(root, "DSHRemote");
const outDir = path.join(root, "DSHRemote.xcodeproj");

// Deterministic UUIDs: IDs must stay stable across regenerations so an
// open Xcode never sees the whole object graph change under it.
const uuid = (seed) =>
  crypto.createHash("sha1").update(seed).digest("hex").slice(0, 24).toUpperCase();

// --- collect sources & resources -------------------------------------------
function walk(dir, ext) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walk(p, ext));
    } else if (entry.name.endsWith(ext)) {
      out.push(p);
    }
  }
  return out;
}

const swiftFiles = walk(appDir, ".swift").sort();
const resources = walk(appDir, "").filter(
  (p) => p.includes("Assets.xcassets") && (p.endsWith(".xcassets") || p.endsWith(".json") || p.endsWith(".png"))
);
// Only the .xcassets bundle itself is a build resource.
const assetBundle = path.join(appDir, "Assets.xcassets");

// --- pbx objects ------------------------------------------------------------
const ids = {
  project: uuid("project"),
  mainGroup: uuid("mainGroup"),
  productsGroup: uuid("productsGroup"),
  appGroup: uuid("appGroup"),
  target: uuid("target"),
  productRef: uuid("productRef"),
  sourcesPhase: uuid("sourcesPhase"),
  frameworksPhase: uuid("frameworksPhase"),
  resourcesPhase: uuid("resourcesPhase"),
  projectConfigList: uuid("projectConfigList"),
  targetConfigList: uuid("targetConfigList"),
  debugProj: uuid("debugProj"),
  releaseProj: uuid("releaseProj"),
  debugTgt: uuid("debugTgt"),
  releaseTgt: uuid("releaseTgt"),
  infoRef: uuid("infoRef"),
  assetRef: uuid("assetRef"),
};

const fileRefs = {}; // absPath -> id
const buildFiles = {}; // absPath -> id

for (const f of swiftFiles) {
  const id = uuid("file:" + path.relative(appDir, f));
  fileRefs[f] = id;
  buildFiles[f] = uuid("build:" + path.relative(appDir, f));
}
fileRefs[assetBundle] = ids.assetRef;
buildFiles[assetBundle] = uuid("build:Assets.xcassets");
fileRefs[path.join(appDir, "Info.plist")] = ids.infoRef;

// --- serialization helpers --------------------------------------------------
const esc = (s) =>
  s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n");

function section(comment, body) {
  return `\n/* Begin ${comment} section */\n${body}\n/* End ${comment} section */\n`;
}

let out = `// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {
`;

// PBXBuildFile
let body = "";
for (const f of swiftFiles) {
  const rel = path.relative(appDir, f);
  body += `\t\t${buildFiles[f]} /* ${esc(rel)} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileRefs[f]} /* ${esc(rel)} */; };\n`;
}
{
  const rel = "Assets.xcassets";
  body += `\t\t${buildFiles[assetBundle]} /* ${rel} in Resources */ = {isa = PBXBuildFile; fileRef = ${ids.assetRef} /* ${rel} */; };\n`;
}
out += section("PBXBuildFile", body);

// PBXFileReference
body = `\t\t${ids.productRef} /* DSHRemote.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DSHRemote.app; sourceTree = BUILT_PRODUCTS_DIR; };\n`;
for (const f of swiftFiles) {
  const rel = path.relative(appDir, f);
  body += `\t\t${fileRefs[f]} /* ${esc(rel)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${esc(rel)}; sourceTree = "<group>"; };\n`;
}
body += `\t\t${ids.infoRef} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };\n`;
body += `\t\t${ids.assetRef} /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };\n`;
out += section("PBXFileReference", body);

// PBXFrameworksBuildPhase
out += section("PBXFrameworksBuildPhase", `\t\t${ids.frameworksPhase} /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};\n`);

// PBXGroup
body = `\t\t${ids.mainGroup} = {
			isa = PBXGroup;
			children = (
				${ids.appGroup} /* DSHRemote */,
				${ids.productsGroup} /* Products */,
			);
			sourceTree = "<group>";
		};\n`;
body += `\t\t${ids.productsGroup} /* Products */ = {
			isa = PBXGroup;
			children = (
				${ids.productRef} /* DSHRemote.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};\n`;
body += `\t\t${ids.appGroup} /* DSHRemote */ = {
			isa = PBXGroup;
			children = (\n`;
for (const f of [...swiftFiles, path.join(appDir, "Info.plist"), assetBundle]) {
  const rel = path.relative(appDir, f);
  body += `\t\t\t\t${fileRefs[f]} /* ${esc(rel)} */,\n`;
}
body += `\t\t\t);
			path = DSHRemote;
			sourceTree = "<group>";
		};\n`;
out += section("PBXGroup", body);

// PBXNativeTarget
out += section("PBXNativeTarget", `\t\t${ids.target} /* DSHRemote */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = ${ids.targetConfigList} /* Build configuration list for PBXNativeTarget "DSHRemote" */;
			buildPhases = (
				${ids.sourcesPhase} /* Sources */,
				${ids.frameworksPhase} /* Frameworks */,
				${ids.resourcesPhase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = DSHRemote;
			productName = DSHRemote;
			productReference = ${ids.productRef} /* DSHRemote.app */;
			productType = "com.apple.product-type.application";
		};\n`);

// PBXProject
out += section("PBXProject", `\t\t${ids.project} /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {
					${ids.target} = {
						CreatedOnToolsVersion = 16.0;
					};
				};
			};
			buildConfigurationList = ${ids.projectConfigList} /* Build configuration list for PBXProject "DSHRemote" */;
			compatibilityVersion = "Xcode 16.0";
			developmentRegion = zh_CN;
			hasScannedForEncodings = 0;
			knownRegions = (
				zh_CN,
				en,
				Base,
			);
			mainGroup = ${ids.mainGroup};
			productRefGroup = ${ids.productsGroup} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				${ids.target} /* DSHRemote */,
			);
		};\n`);

// PBXResourcesBuildPhase
out += section("PBXResourcesBuildPhase", `\t\t${ids.resourcesPhase} /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				${buildFiles[assetBundle]} /* DSHRemote/Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};\n`);

// PBXSourcesBuildPhase
body = `\t\t${ids.sourcesPhase} /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (\n`;
for (const f of swiftFiles) {
  const rel = path.relative(appDir, f);
  body += `\t\t\t\t${buildFiles[f]} /* ${esc(rel)} in Sources */,\n`;
}
body += `\t\t\t);
			runOnlyForDeploymentPostprocessing = 0;
		};\n`;
out += section("PBXSourcesBuildPhase", body);

// XCBuildConfiguration — project level
function projectSettings(config) {
  return `			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
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
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = ${config};
`;
}

out += section("XCBuildConfiguration", `\t\t${ids.debugProj} /* Debug */ = {
${projectSettings("Debug")}
		};\n` + `\t\t${ids.releaseProj} /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
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
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};\n`);

// XCBuildConfiguration — target level
function targetSettings(config) {
  return `			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = A57YNS9Z36;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = DSHRemote/Info.plist;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 0.8.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.dshremote.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = ${config};
`;
}

out += `\t\t${ids.debugTgt} /* Debug */ = {\n${targetSettings("Debug")}\n\t\t};\n`;
out += `\t\t${ids.releaseTgt} /* Release */ = {\n${targetSettings("Release")}\n\t\t};\n`;

// XCConfigurationList
out += section("XCConfigurationList", `\t\t${ids.projectConfigList} /* Build configuration list for PBXProject "DSHRemote" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				${ids.debugProj} /* Debug */,
				${ids.releaseProj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};\n` + `\t\t${ids.targetConfigList} /* Build configuration list for PBXNativeTarget "DSHRemote" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				${ids.debugTgt} /* Debug */,
				${ids.releaseTgt} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};\n`);

out += `\t};
	rootObject = ${ids.project} /* Project object */;
}
`;

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "project.pbxproj"), out);
console.log(`wrote ${path.join(outDir, "project.pbxproj")}`);
console.log(`  sources: ${swiftFiles.length} swift files, 1 asset catalog`);
