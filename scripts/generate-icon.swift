#!/usr/bin/env swift

import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-icon.swift INPUT.iconset OUTPUT.icns\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let representations: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianBytes(_ value: UInt32) -> [UInt8] {
    let encoded = value.bigEndian
    return withUnsafeBytes(of: encoded) { Array($0) }
}

var elements = Data()
for representation in representations {
    let fileURL = iconsetURL.appendingPathComponent(representation.filename)
    let imageData = try Data(contentsOf: fileURL)
    guard let typeData = representation.type.data(using: .ascii), typeData.count == 4 else {
        fputs("error: invalid ICNS element type\n", stderr)
        exit(1)
    }
    elements.append(typeData)
    elements.append(contentsOf: bigEndianBytes(UInt32(imageData.count + 8)))
    elements.append(imageData)
}

var output = Data("icns".utf8)
output.append(contentsOf: bigEndianBytes(UInt32(elements.count + 8)))
output.append(elements)
try output.write(to: outputURL, options: .atomic)
