// gen-project.mjs — regenerate DSHRemoteMac.xcodeproj from the source tree.
// Run: node gen-project.mjs  (from the macos/DSHRemoteMac directory)
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const appDir = path.join(here, "DSHRemoteMac");
const outDir = path.join(here, "DSHRemoteMac.xcodeproj");

// Deterministic UUIDs: IDs must stay stable across regenerations so an
// open Xcode never sees the whole object graph change under it.
const uuid = (seed) =>
  crypto.createHash("sha1").update(seed).digest("hex").slice(0, 24).toUpperCase();

function walk(dir, ext) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p, ext));
    else if (entry.name.endsWith(ext)) out.push(p);
  }
  return out;
}

const swiftFiles = walk(appDir, ".swift").sort();
const bridgeDir = path.join(appDir, "Resources", "bridge");
const assetBundle = path.join(appDir, "Assets.xcassets");

const ids = {
  project: uuid("project"), mainGroup: uuid("mainGroup"), productsGroup: uuid("productsGroup"), appGroup: uuid("appGroup"),
  target: uuid("target"), productRef: uuid("productRef"), sourcesPhase: uuid("sourcesPhase"), frameworksPhase: uuid("frameworksPhase"),
  resourcesPhase: uuid("resourcesPhase"), projectConfigList: uuid("projectConfigList"), targetConfigList: uuid("targetConfigList"),
  debugProj: uuid("debugProj"), releaseProj: uuid("releaseProj"), debugTgt: uuid("debugTgt"), releaseTgt: uuid("releaseTgt"),
  infoRef: uuid("infoRef"), bridgeRef: uuid("bridgeRef"), assetRef: uuid("assetRef"),
};

const fileRefs = {};
const buildFiles = {};
for (const f of swiftFiles) {
  fileRefs[f] = uuid("file:" + path.relative(appDir, f));
  buildFiles[f] = uuid("build:" + path.relative(appDir, f));
}
buildFiles[bridgeDir] = uuid("build:Resources/bridge");
buildFiles[assetBundle] = uuid("build:Assets.xcassets");

const esc = (s) => s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n");
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
body += `\t\t${buildFiles[bridgeDir]} /* bridge in Resources */ = {isa = PBXBuildFile; fileRef = ${ids.bridgeRef} /* bridge */; };\n`;
body += `\t\t${buildFiles[assetBundle]} /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = ${ids.assetRef} /* Assets.xcassets */; };\n`;
out += section("PBXBuildFile", body);

// PBXFileReference
body = `\t\t${ids.productRef} /* DSHRemoteMac.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DSHRemoteMac.app; sourceTree = BUILT_PRODUCTS_DIR; };\n`;
for (const f of swiftFiles) {
  const rel = path.relative(appDir, f);
  body += `\t\t${fileRefs[f]} /* ${esc(rel)} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${esc(rel)}; sourceTree = "<group>"; };\n`;
}
body += `\t\t${ids.infoRef} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };\n`;
body += `\t\t${ids.bridgeRef} /* bridge */ = {isa = PBXFileReference; lastKnownFileType = folder; path = Resources/bridge; sourceTree = "<group>"; };\n`;
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
				${ids.appGroup} /* DSHRemoteMac */,
				${ids.productsGroup} /* Products */,
			);
			sourceTree = "<group>";
		};\n`;
body += `\t\t${ids.productsGroup} /* Products */ = {
			isa = PBXGroup;
			children = (
				${ids.productRef} /* DSHRemoteMac.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};\n`;
body += `\t\t${ids.appGroup} /* DSHRemoteMac */ = {
			isa = PBXGroup;
			children = (\n`;
for (const f of [...swiftFiles, path.join(appDir, "Info.plist")]) {
  const rel = path.relative(appDir, f);
  body += `\t\t\t\t${fileRefs[f]} /* ${esc(rel)} */,\n`;
}
// Resources group holding the bridge folder
body += `\t\t\t\t${ids.bridgeRef} /* bridge */,\n`;
body += `\t\t\t\t${ids.assetRef} /* Assets.xcassets */,\n`;
body += `\t\t\t);
			path = DSHRemoteMac;
			sourceTree = "<group>";
		};\n`;
out += section("PBXGroup", body);

// PBXNativeTarget
out += section("PBXNativeTarget", `\t\t${ids.target} /* DSHRemoteMac */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = ${ids.targetConfigList} /* Build configuration list for PBXNativeTarget "DSHRemoteMac" */;
			buildPhases = (
				${ids.sourcesPhase} /* Sources */,
				${ids.frameworksPhase} /* Frameworks */,
				${ids.resourcesPhase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = DSHRemoteMac;
			productName = DSHRemoteMac;
			productReference = ${ids.productRef} /* DSHRemoteMac.app */;
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
			buildConfigurationList = ${ids.projectConfigList} /* Build configuration list for PBXProject "DSHRemoteMac" */;
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
				${ids.target} /* DSHRemoteMac */,
			);
		};\n`);

// PBXResourcesBuildPhase
out += section("PBXResourcesBuildPhase", `\t\t${ids.resourcesPhase} /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				${buildFiles[bridgeDir]} /* bridge in Resources */,
				${buildFiles[assetBundle]} /* Assets.xcassets in Resources */,
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

function projectSettings(config) {
  return `			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_UNREACHABLE_CODE = YES;
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
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = ${config};
`;
}

out += section("XCBuildConfiguration",
  `\t\t${ids.debugProj} /* Debug */ = {\n${projectSettings("Debug")}\n\t\t};\n` +
  `\t\t${ids.releaseProj} /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_UNREACHABLE_CODE = YES;
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
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};\n`);

function targetSettings(config) {
  return `			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = A57YNS9Z36;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = DSHRemoteMac/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 0.8.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.dshremote.mac;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = ${config};
`;
}

out += `\t\t${ids.debugTgt} /* Debug */ = {\n${targetSettings("Debug")}\n\t\t};\n`;
out += `\t\t${ids.releaseTgt} /* Release */ = {\n${targetSettings("Release")}\n\t\t};\n`;

out += section("XCConfigurationList",
  `\t\t${ids.projectConfigList} /* Build configuration list for PBXProject "DSHRemoteMac" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				${ids.debugProj} /* Debug */,
				${ids.releaseProj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};\n` +
  `\t\t${ids.targetConfigList} /* Build configuration list for PBXNativeTarget "DSHRemoteMac" */ = {
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
console.log(`  sources: ${swiftFiles.length} swift files + bridge folder resource`);
