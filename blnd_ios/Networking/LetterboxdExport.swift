import Foundation
import zlib

/// A Letterboxd file the import screen can turn into the zip the API accepts.
struct PreparedLetterboxdUpload: Equatable {
    let zipData: Data
    /// Ratings found in the file. The API summary has no ratings field.
    /// shortcut: a film TMDB cannot match still counts here.
    let ratingsCount: Int
}

/// Why a chosen file was not uploaded.
struct LetterboxdExportError: Error, Equatable {
    let message: String

    static let wrongFile = LetterboxdExportError(
        message: "Choose the .zip Letterboxd saved to Files, or watched.csv or ratings.csv."
    )

    static let tooLarge = LetterboxdExportError(
        message: "That file is too big. Letterboxd exports are usually just a few megabytes."
    )

    static let unreadable = LetterboxdExportError(
        message: "That file didn't open. Try the .zip from Letterboxd again."
    )
}

/// Builds the zip `POST /import/letterboxd` accepts.
///
/// The backend rejects anything that is not a zip. Inside the zip it only
/// reads `watched.csv`, `ratings.csv`, `reviews.csv`, `watchlist.csv`, and
/// `likes/films.csv` when those paths sit at the archive root. A Letterboxd
/// export nests them in a folder, so this flattens them. A single CSV is zipped.
/// A rating is stored only when that film is also watched, so a ratings-only
/// file also gets a watched list made from those rows.
enum LetterboxdExport {
    static let pageURL = URL(string: "https://letterboxd.com/settings/data/")!
    static let maxUploadBytes = 10 * 1024 * 1024

    /// - Parameters:
    ///   - data: Bytes of the file the user picked.
    ///   - filename: Last path component, used to tell a CSV from a zip.
    /// - Returns: A root-level Letterboxd zip and how many ratings it contains.
    static func prepare(data: Data, filename: String) throws -> PreparedLetterboxdUpload {
        guard data.count <= maxUploadBytes else { throw LetterboxdExportError.tooLarge }

        let files = try sourceFiles(data: data, filename: filename)
        let packaged = package(files)
        guard packaged["watched.csv"] != nil || packaged["ratings.csv"] != nil else {
            throw LetterboxdExportError.wrongFile
        }

        let zip = ZipArchive.store(packaged)
        guard zip.count <= maxUploadBytes else { throw LetterboxdExportError.tooLarge }
        return PreparedLetterboxdUpload(zipData: zip, ratingsCount: countRatings(in: packaged))
    }

    private static func sourceFiles(data: Data, filename: String) throws -> [String: Data] {
        if ZipArchive.looksLikeZip(data) {
            return try ZipArchive.extractLetterboxdFiles(data)
        }
        guard let name = singleCSVName(filename) else { throw LetterboxdExportError.wrongFile }
        guard table(data, requires: requiredColumns(for: name)) != nil else {
            throw LetterboxdExportError.wrongFile
        }
        return [name: data]
    }

    private static func singleCSVName(_ filename: String) -> String? {
        let name = filename.lowercased()
        if name == "watched.csv" || name.hasSuffix("/watched.csv") { return "watched.csv" }
        if name == "ratings.csv" || name.hasSuffix("/ratings.csv") { return "ratings.csv" }
        return nil
    }

    /// Copies ratings onto `ratings.csv` and rated films onto `watched.csv`
    /// so the current API, which ignores a rating with no watched row, keeps both.
    private static func package(_ files: [String: Data]) -> [String: Data] {
        var packaged: [String: Data] = [:]
        for name in ZipArchive.letterboxdNames {
            guard let data = files[name], table(data, requires: requiredColumns(for: name)) != nil else {
                continue
            }
            packaged[name] = data
        }
        copyRatingsFromWatched(into: &packaged)
        copyRatedFilmsToWatched(in: &packaged)
        return packaged
    }

    private static func requiredColumns(for name: String) -> [String] {
        if name == "ratings.csv" || name == "reviews.csv" {
            return ["Name", "Letterboxd URI", "Rating"]
        }
        return ["Name", "Letterboxd URI"]
    }

    private static func copyRatingsFromWatched(into files: inout [String: Data]) {
        guard let watched = files["watched.csv"], let watchedTable = table(watched, requires: ["Rating"]) else {
            return
        }
        let ratingsTable = files["ratings.csv"].flatMap { table($0, requires: ["Letterboxd URI"]) }
        var known = Set(ratingsTable?.rows.compactMap { uri(in: $0) } ?? [])
        var additions: [[String: String]] = []
        for row in watchedTable.rows {
            guard let filmURI = uri(in: row), !known.contains(filmURI) else { continue }
            let rating = field(row, "Rating").trimmingCharacters(in: .whitespaces)
            guard !rating.isEmpty else { continue }
            known.insert(filmURI)
            additions.append(row)
        }
        guard !additions.isEmpty else { return }
        let headers = ratingsTable?.headers ?? ["Date", "Name", "Year", "Letterboxd URI", "Rating"]
        files["ratings.csv"] = append(additions, headers: headers, to: files["ratings.csv"])
    }

    private static func copyRatedFilmsToWatched(in files: inout [String: Data]) {
        guard let ratings = files["ratings.csv"], let ratingsTable = table(ratings, requires: ["Letterboxd URI"]) else {
            return
        }
        let watchedTable = files["watched.csv"].flatMap { table($0, requires: ["Letterboxd URI"]) }
        var known = Set(watchedTable?.rows.compactMap { uri(in: $0) } ?? [])
        var additions: [[String: String]] = []
        for row in ratingsTable.rows {
            guard let filmURI = uri(in: row), !known.contains(filmURI) else { continue }
            let rating = field(row, "Rating").trimmingCharacters(in: .whitespaces)
            guard !rating.isEmpty else { continue }
            known.insert(filmURI)
            additions.append(row)
        }
        guard !additions.isEmpty else { return }
        let headers = watchedTable?.headers ?? ["Date", "Name", "Year", "Letterboxd URI"]
        files["watched.csv"] = append(additions, headers: headers, to: files["watched.csv"])
    }

    private static func countRatings(in files: [String: Data]) -> Int {
        let watched = files["watched.csv"].flatMap { table($0, requires: ["Letterboxd URI"]) }
        let liked = files["likes/films.csv"].flatMap { table($0, requires: ["Letterboxd URI"]) }
        var stored = Set(watched?.rows.compactMap { uri(in: $0) } ?? [])
        stored.formUnion(liked?.rows.compactMap { uri(in: $0) } ?? [])

        var ratings: [String: String] = [:]
        for name in ["watched.csv", "ratings.csv", "reviews.csv"] {
            guard let data = files[name], let parsed = table(data, requires: ["Letterboxd URI"]) else { continue }
            for row in parsed.rows {
                guard let filmURI = uri(in: row), stored.contains(filmURI) else { continue }
                let rating = field(row, "Rating").trimmingCharacters(in: .whitespaces)
                guard !rating.isEmpty else { continue }
                ratings[filmURI] = rating
            }
        }
        return ratings.count
    }
}

// MARK: - CSV

private struct CSVTable {
    var headers: [String]
    var rows: [[String: String]]
}

private func table(_ data: Data, requires columns: [String]) -> CSVTable? {
    guard var text = String(data: data, encoding: .utf8) else { return nil }
    if text.hasPrefix("\u{feff}") { text.removeFirst() }
    let records = csvRecords(in: text)
    guard let headerRecord = records.first else { return nil }
    let headers = csvFields(in: headerRecord).map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let headerSet = Set(headers.map { $0.lowercased() })
    guard columns.allSatisfy({ headerSet.contains($0.lowercased()) }) else { return nil }

    var rows: [[String: String]] = []
    for record in records.dropFirst() {
        if record.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
        let fields = csvFields(in: record)
        var row: [String: String] = [:]
        for (index, header) in headers.enumerated() where index < fields.count {
            row[header] = fields[index]
        }
        rows.append(row)
    }
    return CSVTable(headers: headers, rows: rows)
}

private func uri(in row: [String: String]) -> String? {
    let value = field(row, "Letterboxd URI").trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : value
}

private func field(_ row: [String: String], _ name: String) -> String {
    row.first { $0.key.compare(name, options: .caseInsensitive) == .orderedSame }?.value ?? ""
}

private func append(_ rows: [[String: String]], headers: [String], to existing: Data?) -> Data {
    var data = existing ?? Data((headers.joined(separator: ",") + "\n").utf8)
    if let last = data.last, last != 0x0A { data.append(0x0A) }
    for row in rows {
        let line = headers.map { csvField(field(row, $0)) }.joined(separator: ",")
        data.append(Data((line + "\n").utf8))
    }
    return data
}

private func csvField(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
}

private func csvRecords(in text: String) -> [String] {
    var records: [String] = []
    var current = ""
    var inQuotes = false
    let chars = Array(text)
    var index = 0
    while index < chars.count {
        let char = chars[index]
        if char == "\"" {
            if inQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                current.append("\"\"")
                index += 2
                continue
            }
            inQuotes.toggle()
            current.append(char)
            index += 1
        } else if !inQuotes, char == "\n" || char == "\r" {
            records.append(current)
            current = ""
            if char == "\r", index + 1 < chars.count, chars[index + 1] == "\n" {
                index += 2
            } else {
                index += 1
            }
        } else {
            current.append(char)
            index += 1
        }
    }
    if !current.isEmpty { records.append(current) }
    return records
}

private func csvFields(in record: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    let chars = Array(record)
    var index = 0
    while index < chars.count {
        let char = chars[index]
        if char == "\"" {
            if inQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                current.append("\"")
                index += 2
                continue
            }
            inQuotes.toggle()
            index += 1
        } else if char == ",", !inQuotes {
            fields.append(current)
            current = ""
            index += 1
        } else {
            current.append(char)
            index += 1
        }
    }
    fields.append(current)
    return fields
}

// MARK: - Zip

/// Reads and writes the small set of Letterboxd CSV paths. Not a general unzipper.
enum ZipArchive {
    static let letterboxdNames = [
        "watched.csv",
        "ratings.csv",
        "reviews.csv",
        "watchlist.csv",
        "likes/films.csv",
    ]

    static func looksLikeZip(_ data: Data) -> Bool {
        data.count >= 4 && data[0] == 0x50 && data[1] == 0x4B
            && (data[2] == 0x03 || data[2] == 0x05 || data[2] == 0x07)
    }

    /// Uncompresses the Letterboxd CSVs from a zip, including files nested in a folder.
    static func extractLetterboxdFiles(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        guard let eocd = findEOCD(bytes) else { throw LetterboxdExportError.unreadable }
        if u16(bytes, eocd + 4) != 0 || u16(bytes, eocd + 6) != 0 {
            throw LetterboxdExportError.unreadable
        }
        let entryCount = Int(u16(bytes, eocd + 10))
        let directorySize = Int(u32(bytes, eocd + 12))
        let directoryOffset = Int(u32(bytes, eocd + 16))
        guard entryCount <= 2_000 else { throw LetterboxdExportError.tooLarge }
        guard directoryOffset >= 0, directorySize >= 0,
              directoryOffset + directorySize <= bytes.count else {
            throw LetterboxdExportError.unreadable
        }

        var files: [String: Data] = [:]
        var cursor = directoryOffset
        let directoryEnd = directoryOffset + directorySize
        var uncompressedTotal = 0
        for _ in 0 ..< entryCount {
            guard cursor + 46 <= directoryEnd, u32(bytes, cursor) == 0x02014B50 else {
                throw LetterboxdExportError.unreadable
            }
            let method = u16(bytes, cursor + 10)
            let flag = u16(bytes, cursor + 8)
            let compressedSize = Int(u32(bytes, cursor + 20))
            let uncompressedSize = Int(u32(bytes, cursor + 24))
            let nameLength = Int(u16(bytes, cursor + 28))
            let extraLength = Int(u16(bytes, cursor + 30))
            let commentLength = Int(u16(bytes, cursor + 32))
            let localOffset = Int(u32(bytes, cursor + 42))
            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd + extraLength + commentLength <= directoryEnd else {
                throw LetterboxdExportError.unreadable
            }
            let name = String(bytes: bytes[nameStart ..< nameEnd], encoding: .utf8) ?? ""
            cursor = nameEnd + extraLength + commentLength

            guard let canonical = canonicalName(name), !name.hasSuffix("/") else { continue }
            if compressedSize == Int(UInt32.max) || uncompressedSize == Int(UInt32.max) {
                throw LetterboxdExportError.tooLarge
            }
            if flag & 0x1 != 0 { throw LetterboxdExportError.unreadable }
            uncompressedTotal += uncompressedSize
            if uncompressedTotal > LetterboxdExport.maxUploadBytes * 2 {
                throw LetterboxdExportError.tooLarge
            }
            let payload = try entryBytes(
                bytes,
                localOffset: localOffset,
                method: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize
            )
            if files[canonical] == nil { files[canonical] = payload }
        }
        return files
    }

    static func store(_ files: [String: Data]) -> Data {
        archive(files, method: 0)
    }

    /// Writes a zip. `method` 8 (deflate) exists so tests can build a real Letterboxd-shaped archive.
    static func archive(_ files: [String: Data], method: UInt16) -> Data {
        let names = letterboxdNames.filter { files[$0] != nil } + files.keys.filter { !letterboxdNames.contains($0) }.sorted()
        var locals = Data()
        var central = Data()
        for name in names {
            guard let payload = files[name] else { continue }
            let compressed = method == 8 ? deflate(payload) : nil
            let usedMethod: UInt16 = compressed == nil ? 0 : 8
            let body = compressed ?? payload
            let offset = UInt32(locals.count)
            let nameData = Data(name.utf8)
            let crc = checksum(payload)
            var local = Data()
            appendU32(0x04034B50, to: &local)
            appendU16(20, to: &local)
            appendU16(0, to: &local)
            appendU16(usedMethod, to: &local)
            appendU16(0, to: &local)
            appendU16(0, to: &local)
            appendU32(crc, to: &local)
            appendU32(UInt32(body.count), to: &local)
            appendU32(UInt32(payload.count), to: &local)
            appendU16(UInt16(nameData.count), to: &local)
            appendU16(0, to: &local)
            local.append(nameData)
            local.append(body)
            locals.append(local)

            var item = Data()
            appendU32(0x02014B50, to: &item)
            appendU16(20, to: &item)
            appendU16(20, to: &item)
            appendU16(0, to: &item)
            appendU16(usedMethod, to: &item)
            appendU16(0, to: &item)
            appendU16(0, to: &item)
            appendU32(crc, to: &item)
            appendU32(UInt32(body.count), to: &item)
            appendU32(UInt32(payload.count), to: &item)
            appendU16(UInt16(nameData.count), to: &item)
            appendU16(0, to: &item)
            appendU16(0, to: &item)
            appendU16(0, to: &item)
            appendU16(0, to: &item)
            appendU32(0, to: &item)
            appendU32(offset, to: &item)
            item.append(nameData)
            central.append(item)
        }

        var end = Data()
        appendU32(0x06054B50, to: &end)
        appendU16(0, to: &end)
        appendU16(0, to: &end)
        appendU16(UInt16(names.count), to: &end)
        appendU16(UInt16(names.count), to: &end)
        appendU32(UInt32(central.count), to: &end)
        appendU32(UInt32(locals.count), to: &end)
        appendU16(0, to: &end)
        var zip = Data()
        zip.append(locals)
        zip.append(central)
        zip.append(end)
        return zip
    }

    private static func canonicalName(_ path: String) -> String? {
        let parts = path.replacingOccurrences(of: "\\", with: "/").lowercased().split(separator: "/").map(String.init)
        guard let base = parts.last else { return nil }
        if parts.count >= 2, parts[parts.count - 2] == "likes", base == "films.csv" {
            return "likes/films.csv"
        }
        if ["watched.csv", "ratings.csv", "reviews.csv", "watchlist.csv"].contains(base) {
            return base
        }
        return nil
    }

    private static func entryBytes(
        _ bytes: [UInt8],
        localOffset: Int,
        method: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) throws -> Data {
        guard localOffset >= 0, localOffset + 30 <= bytes.count, u32(bytes, localOffset) == 0x04034B50 else {
            throw LetterboxdExportError.unreadable
        }
        let nameLength = Int(u16(bytes, localOffset + 26))
        let extraLength = Int(u16(bytes, localOffset + 28))
        let start = localOffset + 30 + nameLength + extraLength
        let end = start + compressedSize
        guard start >= 0, end <= bytes.count else { throw LetterboxdExportError.unreadable }
        let compressed = Data(bytes[start ..< end])
        switch method {
        case 0:
            return compressed
        case 8:
            return try inflate(compressed, expectedSize: uncompressedSize)
        default:
            throw LetterboxdExportError.unreadable
        }
    }

    private static func findEOCD(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        let lower = max(0, bytes.count - 22 - 65_535)
        var index = bytes.count - 22
        while index >= lower {
            if bytes[index] == 0x50, bytes[index + 1] == 0x4B, bytes[index + 2] == 0x05, bytes[index + 3] == 0x06 {
                return index
            }
            if index == 0 { break }
            index -= 1
        }
        return nil
    }

    private static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        guard offset + 1 < bytes.count else { return 0 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 3 < bytes.count else { return 0 }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}

private func checksum(_ data: Data) -> UInt32 {
    data.withUnsafeBytes { buffer in
        guard let base = buffer.bindMemory(to: Bytef.self).baseAddress else { return 0 }
        return UInt32(truncatingIfNeeded: crc32(0, base, uInt(data.count)))
    }
}

private func inflate(_ data: Data, expectedSize: Int) throws -> Data {
    var stream = z_stream()
    let opened = inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard opened == Z_OK else { throw LetterboxdExportError.unreadable }
    defer { inflateEnd(&stream) }

    let capacity = max(expectedSize, data.count) + 64
    var output = Data(count: min(capacity, LetterboxdExport.maxUploadBytes * 2))
    var produced = 0
    let status: Int32 = data.withUnsafeBytes { source in
        guard let base = source.bindMemory(to: Bytef.self).baseAddress else { return Z_DATA_ERROR }
        stream.next_in = UnsafeMutablePointer(mutating: base)
        stream.avail_in = uInt(data.count)
        var code = Z_OK
        while code == Z_OK {
            if produced >= output.count {
                guard output.count < LetterboxdExport.maxUploadBytes * 2 else { return Z_BUF_ERROR }
                output.count += 65_536
            }
            let room = output.count - produced
            code = output.withUnsafeMutableBytes { destination in
                stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress?.advanced(by: produced)
                stream.avail_out = uInt(room)
                let result = inflate(&stream, Z_NO_FLUSH)
                produced += room - Int(stream.avail_out)
                return result
            }
        }
        return code
    }
    guard status == Z_STREAM_END else { throw LetterboxdExportError.unreadable }
    output.count = produced
    return output
}

private func deflate(_ data: Data) -> Data? {
    var stream = z_stream()
    let opened = deflateInit2_(
        &stream,
        Z_DEFAULT_COMPRESSION,
        Z_DEFLATED,
        -15,
        8,
        Z_DEFAULT_STRATEGY,
        ZLIB_VERSION,
        Int32(MemoryLayout<z_stream>.size)
    )
    guard opened == Z_OK else { return nil }
    defer { deflateEnd(&stream) }

    var output = Data(count: data.count + 64)
    var produced = 0
    let status: Int32 = data.withUnsafeBytes { source in
        guard let base = source.bindMemory(to: Bytef.self).baseAddress else { return Z_DATA_ERROR }
        stream.next_in = UnsafeMutablePointer(mutating: base)
        stream.avail_in = uInt(data.count)
        var code = Z_OK
        while code == Z_OK {
            if produced >= output.count { output.count += 65_536 }
            let room = output.count - produced
            code = output.withUnsafeMutableBytes { destination in
                stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress?.advanced(by: produced)
                stream.avail_out = uInt(room)
                let result = deflate(&stream, Z_FINISH)
                produced += room - Int(stream.avail_out)
                return result
            }
        }
        return code
    }
    guard status == Z_STREAM_END else { return nil }
    output.count = produced
    return output
}

private func appendU16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
}

private func appendU32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
    data.append(UInt8(truncatingIfNeeded: value >> 16))
    data.append(UInt8(truncatingIfNeeded: value >> 24))
}
