#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/.build/ui-tests"
PROJECT_PATH="$PROJECT_DIR/JarvisUITest.xcodeproj"
SCHEME_DIR="$PROJECT_PATH/xcshareddata/xcschemes"
DERIVED_DATA="$PROJECT_DIR/DerivedData"

mkdir -p "$PROJECT_PATH" "$SCHEME_DIR"

cat > "$PROJECT_PATH/project.pbxproj" <<'PBX'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		000000000000000000000101 /* JarvisOnboardingUITests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 000000000000000000000201 /* JarvisOnboardingUITests.swift */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		000000000000000000000301 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 000000000000000000000001 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 000000000000000000000401;
			remoteInfo = Jarvis;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		000000000000000000000201 /* JarvisOnboardingUITests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ../../Tests/JarvisUITests/JarvisOnboardingUITests.swift; sourceTree = SOURCE_ROOT; };
		000000000000000000000501 /* Jarvis.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Jarvis.app; sourceTree = BUILT_PRODUCTS_DIR; };
		000000000000000000000502 /* JarvisUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = JarvisUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		000000000000000000000601 = {
			isa = PBXGroup;
			children = (
				000000000000000000000701 /* Tests */,
				000000000000000000000702 /* Products */,
			);
			sourceTree = "<group>";
		};
		000000000000000000000701 /* Tests */ = {
			isa = PBXGroup;
			children = (
				000000000000000000000201 /* JarvisOnboardingUITests.swift */,
			);
			name = Tests;
			sourceTree = "<group>";
		};
		000000000000000000000702 /* Products */ = {
			isa = PBXGroup;
			children = (
				000000000000000000000501 /* Jarvis.app */,
				000000000000000000000502 /* JarvisUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		000000000000000000000401 /* Jarvis */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000000000000000000901 /* Build configuration list for PBXNativeTarget "Jarvis" */;
			buildPhases = (
				000000000000000000000801 /* Copy SwiftPM executable */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Jarvis;
			productName = Jarvis;
			productReference = 000000000000000000000501 /* Jarvis.app */;
			productType = "com.apple.product-type.application";
		};
		000000000000000000000402 /* JarvisUITests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 000000000000000000000902 /* Build configuration list for PBXNativeTarget "JarvisUITests" */;
			buildPhases = (
				000000000000000000000802 /* Sources */,
			);
			buildRules = (
			);
			dependencies = (
				000000000000000000000302 /* PBXTargetDependency */,
			);
			name = JarvisUITests;
			productName = JarvisUITests;
			productReference = 000000000000000000000502 /* JarvisUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		000000000000000000000001 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1640;
				LastUpgradeCheck = 1640;
				TargetAttributes = {
					000000000000000000000401 = {
						CreatedOnToolsVersion = 16.4;
					};
					000000000000000000000402 = {
						CreatedOnToolsVersion = 16.4;
						TestTargetID = 000000000000000000000401;
					};
				};
			};
			buildConfigurationList = 000000000000000000000900 /* Build configuration list for PBXProject "JarvisUITest" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 000000000000000000000601;
			productRefGroup = 000000000000000000000702 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				000000000000000000000401 /* Jarvis */,
				000000000000000000000402 /* JarvisUITests */,
			);
		};
/* End PBXProject section */

/* Begin PBXShellScriptBuildPhase section */
		000000000000000000000801 /* Copy SwiftPM executable */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
			);
			name = "Copy SwiftPM executable";
			outputPaths = (
				"$(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/MacOS/Jarvis",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/bash;
			shellScript = "set -euo pipefail\nREPO_ROOT=\"$(cd \"$SRCROOT/../..\" && pwd)\"\ncd \"$REPO_ROOT\"\nswift build -c debug --product Jarvis\nmkdir -p \"$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/MacOS\"\ncp \"$REPO_ROOT/.build/debug/Jarvis\" \"$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/MacOS/Jarvis\"\nchmod +x \"$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/MacOS/Jarvis\"\n";
		};
/* End PBXShellScriptBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		000000000000000000000802 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				000000000000000000000101 /* JarvisOnboardingUITests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		000000000000000000000302 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 000000000000000000000401 /* Jarvis */;
			targetProxy = 000000000000000000000301 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		000000000000000000001001 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				SDKROOT = macosx;
			};
			name = Debug;
		};
		000000000000000000001002 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				SDKROOT = macosx;
			};
			name = Release;
		};
		000000000000000000001101 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Jarvis;
				INFOPLIST_KEY_LSMinimumSystemVersion = 14.0;
				INFOPLIST_KEY_LSUIElement = YES;
				INFOPLIST_KEY_NSHighResolutionCapable = YES;
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.infinitestack.jarvis.mac.uitesthost;
				PRODUCT_NAME = Jarvis;
				SKIP_INSTALL = NO;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		000000000000000000001102 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Jarvis;
				INFOPLIST_KEY_LSMinimumSystemVersion = 14.0;
				INFOPLIST_KEY_LSUIElement = YES;
				INFOPLIST_KEY_NSHighResolutionCapable = YES;
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.infinitestack.jarvis.mac.uitesthost;
				PRODUCT_NAME = Jarvis;
				SKIP_INSTALL = NO;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
		000000000000000000001201 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.infinitestack.jarvis.mac.uitests;
				PRODUCT_NAME = JarvisUITests;
				SWIFT_VERSION = 5.0;
				TEST_TARGET_NAME = Jarvis;
			};
			name = Debug;
		};
		000000000000000000001202 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				PRODUCT_BUNDLE_IDENTIFIER = dev.infinitestack.jarvis.mac.uitests;
				PRODUCT_NAME = JarvisUITests;
				SWIFT_VERSION = 5.0;
				TEST_TARGET_NAME = Jarvis;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		000000000000000000000900 /* Build configuration list for PBXProject "JarvisUITest" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000000000000000001001 /* Debug */,
				000000000000000000001002 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		};
		000000000000000000000901 /* Build configuration list for PBXNativeTarget "Jarvis" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000000000000000001101 /* Debug */,
				000000000000000000001102 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		};
		000000000000000000000902 /* Build configuration list for PBXNativeTarget "JarvisUITests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				000000000000000000001201 /* Debug */,
				000000000000000000001202 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Debug;
		};
/* End XCConfigurationList section */
	};
	rootObject = 000000000000000000000001 /* Project object */;
}
PBX

cat > "$SCHEME_DIR/JarvisUITests.xcscheme" <<'SCHEME'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1640"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "000000000000000000000401"
               BuildableName = "Jarvis.app"
               BlueprintName = "Jarvis"
               ReferencedContainer = "container:JarvisUITest.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "000000000000000000000402"
               BuildableName = "JarvisUITests.xctest"
               BlueprintName = "JarvisUITests"
               ReferencedContainer = "container:JarvisUITest.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "000000000000000000000402"
               BuildableName = "JarvisUITests.xctest"
               BlueprintName = "JarvisUITests"
               ReferencedContainer = "container:JarvisUITest.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "000000000000000000000401"
            BuildableName = "Jarvis.app"
            BlueprintName = "Jarvis"
            ReferencedContainer = "container:JarvisUITest.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "YES"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "000000000000000000000401"
            BuildableName = "Jarvis.app"
            BlueprintName = "Jarvis"
            ReferencedContainer = "container:JarvisUITest.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>
SCHEME

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme JarvisUITests \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  test "$@"
