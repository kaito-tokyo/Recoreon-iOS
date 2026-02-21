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
            name: "RecoreonTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId:
                "tokyo.kaito.Recoreon.RecoreonTests",
            deploymentTargets: .iOS("17.4"),
            buildableFolders: [
                "RecoreonTests/Sources"
            ],
            dependencies: [
                .target(name: "Recoreon"),
            ],
            settings: .settings(
                base: SettingsDictionary().swiftObjcBridgingHeaderPath(
                    "RecoreonTests/Sources/RecoreonTests-Bridging-Header.h"
                )
            )
        ),

        .target(
            name: "RecoreonUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId:
                "tokyo.kaito.Recoreon.RecoreonUITests",
            deploymentTargets: .iOS("17.4"),
            buildableFolders: [
                "RecoreonUITests/Sources"
            ],
            dependencies: [
                .target(name: "Recoreon"),
            ],
            settings: .settings(
                base: SettingsDictionary().swiftObjcBridgingHeaderPath(
                    "RecoreonTests/Sources/RecoreonTests-Bridging-Header.h"
                )
            )
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

