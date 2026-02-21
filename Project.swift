import ProjectDescription

let project = Project(
    name: "Recoreon",
    targets: [
        .target(
            name: "Recoreon",
            destinations: .iOS,
            product: .app,
            bundleId: "tokyo.kaito.Recoreon",
            deploymentTargets: .iOS("17.4"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ]
                ]
            ),
            buildableFolders: [
                "Recoreon/Sources",
                "Recoreon/Resources",
            ],
            dependencies: [
                .target(name: "RecoreonCommon"),
                .target(name: "RecoreonBroadcastUploadExtension"),
                .package(product: "HLSServer"),
            ],
        ),

        .target(
            name: "RecoreonBroadcastUploadExtension",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "tokyo.kaito.Recoreon.RecoreonBroadcastUploadExtension",
            deploymentTargets: .iOS("17.4"),
            buildableFolders: [
                "RecoreonBroadcastUploadExtension/Sources"
            ],
            dependencies: [
                .target(name: "FragmentedRecordWriter"),
                .target(name: "RecoreonCommon"),
                .package(product: "Logging"),
            ]
        ),

        // MARK: - Internal libraries

        .target(
            name: "FragmentedRecordWriter",
            destinations: .iOS,
            product: .staticLibrary,
            bundleId: "tokyo.kaito.Recoreon.FragmentedRecordWriter",
            deploymentTargets: .iOS("17.4"),
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
            name: "FragmentedRecordWriterTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "tokyo.kaito.Recoreon.FragmentedRecordWriterTests",
            deploymentTargets: .iOS("17.4"),
            buildableFolders: [
                "FragmentedRecordWriterTests/Sources"
            ],
            dependencies: [
                .target(name: "FragmentedRecordWriter")
            ],
            settings: .settings(
                base: SettingsDictionary().swiftObjcBridgingHeaderPath(
                    "FragmentedRecordWriterTests/Sources/FragmentedRecordWriterTests-Bridging-Header.h"
                )
            ),
        ),

        .target(
            name: "RecoreonCommon",
            destinations: .iOS,
            product: .staticLibrary,
            bundleId: "tokyo.kaito.Recoreon.RecoreonCommon",
            deploymentTargets: .iOS("17.4"),
            buildableFolders: [
                "RecoreonCommon/Sources"
            ],
        ),
    ]
)
