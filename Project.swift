import ProjectDescription

let displayName = "Recoreon"
let version = "0.1.0"

let project = Project(
  name: "Recoreon",
  settings: .settings(
    base: [
      "INFOPLIST_KEY_CFBundleDisplayName": .string(displayName)
    ]
    .automaticCodeSigning(
      devTeam: "4HMJS6J4MZ"
    )
    .currentProjectVersion("1")
    .marketingVersion("0.1.0"),
  ),
  targets: [
    .target(
      name: "Recoreon",
      destinations: [.iPhone, .iPad],
      product: .app,
      bundleId: "tokyo.kaito.Recoreon",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .extendingDefault(
        with: [
          "CFBundleDisplayName": .string(displayName),
          "CFBundleShortVersionString": "$(MARKETING_VERSION)",
          "UILaunchScreen": [:],
        ]
      ),
      buildableFolders: [
        "Recoreon/Sources",
        "Recoreon/Resources",
      ],
      entitlements: .dictionary([
        "com.apple.security.application-groups": [
          "group.tokyo.kaito.Recoreon"
        ]
      ]),
      dependencies: [
        .target(name: "RecoreonCommon"),
        .target(name: "RecoreonBroadcastUploadExtension"),
      ],
    ),

    .target(
      name: "RecoreonBroadcastUploadExtension",
      destinations: [.iPhone, .iPad],
      product: .appExtension,
      bundleId: "tokyo.kaito.Recoreon.RecoreonBroadcastUploadExtension",
      deploymentTargets: .iOS("18.0"),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": .string(displayName),
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "NSExtension": [
          "NSExtensionPointIdentifier":
            "com.apple.broadcast-services-upload",
          "NSExtensionPrincipalClass":
            "$(PRODUCT_MODULE_NAME).SampleHandler",
          "RPBroadcastProcessMode":
            "RPBroadcastProcessModeSampleBuffer",
        ],
      ]),
      buildableFolders: [
        "RecoreonBroadcastUploadExtension/Sources"
      ],
      entitlements: .dictionary([
        "com.apple.security.application-groups": [
          "group.tokyo.kaito.Recoreon"
        ]
      ]),
      dependencies: [
        .target(name: "FragmentedRecordWriter"),
        .target(name: "RecoreonCommon"),
        .external(name: "Logging"),
      ],
    ),

    .target(
      name: "RecoreonTests",
      destinations: [.iPhone, .iPad],
      product: .unitTests,
      bundleId:
        "tokyo.kaito.Recoreon.RecoreonTests",
      deploymentTargets: .iOS("18.0"),
      buildableFolders: [
        "RecoreonTests/Sources"
      ],
      dependencies: [
        .target(name: "Recoreon")
      ],
      settings: .settings(
        base: SettingsDictionary().swiftObjcBridgingHeaderPath(
          "RecoreonTests/Sources/RecoreonTests-Bridging-Header.h"
        )
      )
    ),

    .target(
      name: "RecoreonUITests",
      destinations: [.iPhone, .iPad],
      product: .uiTests,
      bundleId:
        "tokyo.kaito.Recoreon.RecoreonUITests",
      deploymentTargets: .iOS("18.0"),
      buildableFolders: [
        "RecoreonUITests/Sources"
      ],
      dependencies: [
        .target(name: "Recoreon")
      ],
      settings: .settings(
        base: SettingsDictionary().swiftObjcBridgingHeaderPath(
          "RecoreonTests/Sources/RecoreonTests-Bridging-Header.h"
        )
      )
    ),

    // MARK: - Internal libraries

    .target(
      name: "FragmentedRecordWriter",
      destinations: [.iPhone, .iPad],
      product: .staticLibrary,
      bundleId: "tokyo.kaito.Recoreon.FragmentedRecordWriter",
      deploymentTargets: .iOS("18.0"),
      buildableFolders: [
        "FragmentedRecordWriter/Sources"
      ],
      settings: .settings(
        base: SettingsDictionary().swiftObjcBridgingHeaderPath(
          "FragmentedRecordWriter/Sources/FragmentedRecordWriter-Bridging-Header.h"
        )
      )
    ),

    .target(
      name: "RecoreonCommon",
      destinations: [.iPhone, .iPad],
      product: .staticLibrary,
      bundleId: "tokyo.kaito.Recoreon.RecoreonCommon",
      deploymentTargets: .iOS("18.0"),
      buildableFolders: [
        "RecoreonCommon/Sources"
      ],
    ),
  ],
)
