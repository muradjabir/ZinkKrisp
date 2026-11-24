import AppKit
import Foundation
import UniformTypeIdentifiers

public enum PEArchitecture: String, Codable {
    case x64 = "64-bit"
    case x86 = "32-bit"
    case unknown = "Unknown"
}

public struct PEMetadata {
    public let productName: String?
    public let fileDescription: String?
    public let icon: NSImage
    public let architecture: PEArchitecture

    public init(
        productName: String?,
        fileDescription: String?,
        icon: NSImage,
        architecture: PEArchitecture = .unknown
    ) {
        self.productName = productName
        self.fileDescription = fileDescription
        self.icon = icon
        self.architecture = architecture
    }
}

public enum PEIconExtractor {
    private struct Section {
        let virtualAddress: UInt32
        let virtualSize: UInt32
        let rawOffset: UInt32
        let rawSize: UInt32
    }

    private struct ResourceData {
        let offset: Int
        let size: Int
    }

    private struct GroupIconEntry {
        let width: UInt8
        let height: UInt8
        let colorCount: UInt8
        let planes: UInt16
        let bitCount: UInt16
        let bytesInRes: UInt32
        let resourceID: UInt16
    }

    public static func extractMetadata(from exeURL: URL) -> PEMetadata {
        let fallbackIcon = NSWorkspace.shared.icon(for: .applicationBundle)
        guard let data = try? Data(contentsOf: exeURL, options: .mappedIfSafe),
              let parsed = parsePE(data: data) else {
            return PEMetadata(productName: nil, fileDescription: nil, icon: fallbackIcon)
        }

        let icons = extractIcon(data: data, parsed: parsed) ?? fallbackIcon
        let (productName, fileDescription) = extractVersionStrings(data: data, parsed: parsed)
        return PEMetadata(
            productName: productName,
            fileDescription: fileDescription,
            icon: icons,
            architecture: parsed.architecture
        )
    }

    private struct ParsedPE {
        let sections: [Section]
        let rsrcRVA: UInt32
        let rsrcBaseOffset: Int
        let architecture: PEArchitecture
    }

    private static func parsePE(data: Data) -> ParsedPE? {
        guard data.count >= 0x40,
              readUInt16(data, at: 0) == 0x5A4D else { // "MZ"
            return nil
        }

        let peOffset = Int(readUInt32(data, at: 0x3C))
        guard peOffset >= 0,
              peOffset + 24 <= data.count,
              readUInt32(data, at: peOffset) == 0x00004550 else { // "PE\0\0"
            return nil
        }

        let numberOfSections = Int(readUInt16(data, at: peOffset + 6))
        let machine = readUInt16(data, at: peOffset + 4)
        let architecture: PEArchitecture
        switch machine {
        case 0x8664, 0xAA64, 0xA641: // AMD64, ARM64, ARM64EC
            architecture = .x64
        case 0x014C: // i386
            architecture = .x86
        default:
            architecture = .unknown
        }

        let sizeOfOptionalHeader = Int(readUInt16(data, at: peOffset + 20))
        let optionalOffset = peOffset + 24
        guard optionalOffset + sizeOfOptionalHeader <= data.count,
              sizeOfOptionalHeader >= 2 else {
            return nil
        }

        let magic = readUInt16(data, at: optionalOffset)
        let dataDirOffset: Int
        if magic == 0x010B {
            dataDirOffset = optionalOffset + 96
        } else if magic == 0x020B {
            dataDirOffset = optionalOffset + 112
        } else {
            return nil
        }

        let rsrcEntryOffset = dataDirOffset + 2 * 8
        guard rsrcEntryOffset + 8 <= optionalOffset + sizeOfOptionalHeader else {
            return nil
        }

        let rsrcRVA = readUInt32(data, at: rsrcEntryOffset)
        let rsrcSize = readUInt32(data, at: rsrcEntryOffset + 4)
        guard rsrcRVA != 0, rsrcSize != 0 else {
            return nil
        }

        let sectionTableOffset = optionalOffset + sizeOfOptionalHeader
        var sections: [Section] = []
        sections.reserveCapacity(numberOfSections)
        for i in 0..<numberOfSections {
            let off = sectionTableOffset + i * 40
            guard off + 40 <= data.count else { break }
            let vSize = readUInt32(data, at: off + 8)
            let vAddr = readUInt32(data, at: off + 12)
            let rSize = readUInt32(data, at: off + 16)
            let rPtr = readUInt32(data, at: off + 20)
            sections.append(Section(virtualAddress: vAddr, virtualSize: vSize, rawOffset: rPtr, rawSize: rSize))
        }

        guard let rsrcBaseOffset = rvaToOffset(rsrcRVA, sections: sections) else {
            return nil
        }

        return ParsedPE(sections: sections, rsrcRVA: rsrcRVA, rsrcBaseOffset: rsrcBaseOffset, architecture: architecture)
    }

    private static func rvaToOffset(_ rva: UInt32, sections: [Section]) -> Int? {
        for sec in sections {
            let span = max(sec.virtualSize, sec.rawSize)
            if rva >= sec.virtualAddress && rva < sec.virtualAddress &+ span {
                let delta = rva - sec.virtualAddress
                if delta < sec.rawSize {
                    return Int(sec.rawOffset + delta)
                }
            }
        }
        return nil
    }

    private static func collectResources(
        data: Data,
        parsed: ParsedPE,
        targetTypeID: UInt32
    ) -> [(id: UInt32, res: ResourceData)] {
        let root = parsed.rsrcBaseOffset
        guard root + 16 <= data.count else { return [] }

        let namedCount = Int(readUInt16(data, at: root + 12))
        let idCount = Int(readUInt16(data, at: root + 14))
        let total = namedCount + idCount

        var results: [(UInt32, ResourceData)] = []
        for i in 0..<total {
            let entryOff = root + 16 + i * 8
            guard entryOff + 8 <= data.count else { break }
            let nameOrId = readUInt32(data, at: entryOff)
            let offsetToData = readUInt32(data, at: entryOff + 4)
            let isName = (nameOrId & 0x80000000) != 0
            if isName || nameOrId != targetTypeID { continue }
            guard (offsetToData & 0x80000000) != 0 else { continue }

            let typeDirOff = parsed.rsrcBaseOffset + Int(offsetToData & 0x7FFFFFFF)
            guard typeDirOff + 16 <= data.count else { continue }
            let tNamed = Int(readUInt16(data, at: typeDirOff + 12))
            let tIds = Int(readUInt16(data, at: typeDirOff + 14))

            for j in 0..<(tNamed + tIds) {
                let itemOff = typeDirOff + 16 + j * 8
                guard itemOff + 8 <= data.count else { break }
                let itemID = readUInt32(data, at: itemOff)
                let itemDataOff = readUInt32(data, at: itemOff + 4)
                guard (itemDataOff & 0x80000000) != 0 else { continue }

                let langDirOff = parsed.rsrcBaseOffset + Int(itemDataOff & 0x7FFFFFFF)
                guard langDirOff + 16 <= data.count else { continue }
                let lNamed = Int(readUInt16(data, at: langDirOff + 12))
                let lIds = Int(readUInt16(data, at: langDirOff + 14))
                guard lNamed + lIds > 0 else { continue }

                let firstLangEntry = langDirOff + 16
                guard firstLangEntry + 8 <= data.count else { continue }
                let dataEntryRel = readUInt32(data, at: firstLangEntry + 4)
                guard (dataEntryRel & 0x80000000) == 0 else { continue }

                let dataEntryOff = parsed.rsrcBaseOffset + Int(dataEntryRel)
                guard dataEntryOff + 16 <= data.count else { continue }
                let dataRVA = readUInt32(data, at: dataEntryOff)
                let dataSize = Int(readUInt32(data, at: dataEntryOff + 4))
                if let fileOff = rvaToOffset(dataRVA, sections: parsed.sections),
                   fileOff >= 0, dataSize > 0, fileOff + dataSize <= data.count {
                    results.append((itemID & 0x7FFFFFFF, ResourceData(offset: fileOff, size: dataSize)))
                }
            }
        }
        return results
    }

    private static func extractIcon(data: Data, parsed: ParsedPE) -> NSImage? {
        let groupResources = collectResources(data: data, parsed: parsed, targetTypeID: 14) // RT_GROUP_ICON
        let iconResources = collectResources(data: data, parsed: parsed, targetTypeID: 3)   // RT_ICON
        guard !iconResources.isEmpty else { return nil }

        var iconMap: [UInt16: Data] = [:]
        for (id, res) in iconResources {
            if id <= UInt32(UInt16.max) {
                iconMap[UInt16(id)] = data.subdata(in: res.offset..<(res.offset + res.size))
            }
        }

        if let firstGroup = groupResources.first?.res, firstGroup.size >= 6 {
            let base = firstGroup.offset
            let idType = readUInt16(data, at: base + 2)
            let count = Int(readUInt16(data, at: base + 4))
            if idType == 1 && count > 0 {
                var entries: [GroupIconEntry] = []
                for i in 0..<count {
                    let eOff = base + 6 + i * 14
                    guard eOff + 14 <= firstGroup.offset + firstGroup.size else { break }
                    entries.append(GroupIconEntry(
                        width: data[eOff],
                        height: data[eOff + 1],
                        colorCount: data[eOff + 2],
                        planes: readUInt16(data, at: eOff + 4),
                        bitCount: readUInt16(data, at: eOff + 6),
                        bytesInRes: readUInt32(data, at: eOff + 8),
                        resourceID: readUInt16(data, at: eOff + 12)
                    ))
                }

                let sorted = entries.sorted { a, b in
                    let aw = a.width == 0 ? 256 : Int(a.width)
                    let ah = a.height == 0 ? 256 : Int(a.height)
                    let bw = b.width == 0 ? 256 : Int(b.width)
                    let bh = b.height == 0 ? 256 : Int(b.height)
                    if aw * ah != bw * bh { return aw * ah > bw * bh }
                    if a.bitCount != b.bitCount { return a.bitCount > b.bitCount }
                    return a.bytesInRes > b.bytesInRes
                }

                for entry in sorted {
                    if let payload = iconMap[entry.resourceID],
                       let img = imageFromRTIcon(payload: payload, entry: entry) {
                        return img
                    }
                }
            }
        }

        // Fallback: try largest raw RT_ICON directly
        for (_, payload) in iconMap.sorted(by: { $0.value.count > $1.value.count }) {
            if isPNG(payload), let img = NSImage(data: payload) {
                return img
            }
        }
        return nil
    }

    private static func imageFromRTIcon(payload: Data, entry: GroupIconEntry) -> NSImage? {
        if isPNG(payload) {
            return NSImage(data: payload)
        }
        // Reconstruct 22-byte .ico container around Windows DIB payload
        var ico = Data(capacity: 22 + payload.count)
        // ICONDIR (6 bytes)
        ico.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x01, 0x00])
        // ICONDIRENTRY (16 bytes)
        ico.append(entry.width)
        ico.append(entry.height)
        ico.append(entry.colorCount)
        ico.append(0x00)
        appendUInt16(&ico, entry.planes)
        appendUInt16(&ico, entry.bitCount)
        appendUInt32(&ico, UInt32(payload.count))
        appendUInt32(&ico, 22)
        ico.append(payload)
        return NSImage(data: ico)
    }

    private static func isPNG(_ data: Data) -> Bool {
        data.count >= 8 &&
        data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47
    }

    private static func extractVersionStrings(data: Data, parsed: ParsedPE) -> (String?, String?) {
        let verResources = collectResources(data: data, parsed: parsed, targetTypeID: 16) // RT_VERSION
        guard let res = verResources.first?.res else { return (nil, nil) }
        let verData = data.subdata(in: res.offset..<(res.offset + res.size))

        let productName = readVersionString(in: verData, key: "ProductName")
        let fileDesc = readVersionString(in: verData, key: "FileDescription")
        return (productName, fileDesc)
    }

    private static func readVersionString(in verData: Data, key: String) -> String? {
        var keyData = key.data(using: .utf16LittleEndian) ?? Data()
        keyData.append(contentsOf: [0x00, 0x00])
        guard let range = verData.range(of: keyData) else { return nil }

        // VS_VERSION_INFO String node has 6-byte header before szKey: wLength, wValueLength, wType
        let headerOffset = range.lowerBound - 6
        guard headerOffset >= 0 else { return nil }
        let valueWordLength = Int(readUInt16(verData, at: headerOffset + 2))
        let valueType = readUInt16(verData, at: headerOffset + 4)
        guard valueType == 1, valueWordLength > 0 else { return nil }

        // Value starts at 4-byte aligned offset after keyData
        let afterKey = range.upperBound
        let valueStart = (afterKey + 3) & ~3
        let byteLen = valueWordLength * 2
        guard valueStart + byteLen <= verData.count else { return nil }

        let valSlice = verData.subdata(in: valueStart..<(valueStart + byteLen))
        let str = String(data: valSlice, encoding: .utf16LittleEndian)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 \t\r\n"))
        return (str?.isEmpty == false) ? str : nil
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func appendUInt16(_ data: inout Data, _ val: UInt16) {
        data.append(UInt8(val & 0xFF))
        data.append(UInt8((val >> 8) & 0xFF))
    }

    private static func appendUInt32(_ data: inout Data, _ val: UInt32) {
        data.append(UInt8(val & 0xFF))
        data.append(UInt8((val >> 8) & 0xFF))
        data.append(UInt8((val >> 16) & 0xFF))
        data.append(UInt8((val >> 24) & 0xFF))
    }
}
