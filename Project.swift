import ProjectDescription

let project = Project(
    name: "Recoreon",
    targets: [
        .target(
            name: "Recoreon",
            destinations: .iOS,
            product: .app,
            bundleId: "tokyo.kaito.Recoreon",
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
            buildableFolders: [
                "RecoreonBroadcastUploadExtension/Sources"
            ],
            dependencies: [
                .target(name: "FragmentedRecordWriter"),
                .target(name: "RecoreonCommon"),
                .package(product: "Logging"),
            ]
        ),

        .target(
            name: "FragmentedRecordWriter",
            destinations: .iOS,
            product: .staticLibrary,
            bundleId: "tokyo.kaito.Recoreon.FragmentedRecordWriter",
            buildableFolders: [
                "FragmentedRecordWriter/Sources"
            ],
        ),

        .target(
            name: "RecoreonCommon",
            destinations: .iOS,
            product: .staticLibrary,
            bundleId: "tokyo.kaito.Recoreon.RecoreonCommon",
            buildableFolders: [
                "RecoreonCommon/Sources"
            ],
        ),
    ]
)
