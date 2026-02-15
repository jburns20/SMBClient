import XCTest

@testable import SMBClient

final class ChangeNotifyTests: XCTestCase {
  func testRequest() {
    let request = ChangeNotify.Request(
      messageId: 1,
      treeId: 1,
      sessionId: 1,
      flags: [.watchTree],
      fileId: Data(repeating: 0, count: 16),
      completionFilter: [.fileName, .dirName, .lastWrite]
    )

    let encoded = request.encoded()

    let header = Header(data: encoded)
    XCTAssertEqual(header.command, Header.Command.changeNotify.rawValue)
    XCTAssertEqual(header.flags, [])
    XCTAssertEqual(header.messageId, 1)
    XCTAssertEqual(header.treeId, 1)
    XCTAssertEqual(header.sessionId, 1)

    // Verify structure size (32)
    XCTAssertEqual(encoded[64], 32)
    XCTAssertEqual(encoded[65], 0)

    // Verify flags (watchTree = 0x0001)
    XCTAssertEqual(encoded[66], 1)
    XCTAssertEqual(encoded[67], 0)

    // Verify outputBufferLength (default 65535)
    let length = encoded[68..<72].withUnsafeBytes { $0.load(as: UInt32.self) }
    XCTAssertEqual(length, 65535)

    // Verify fileId (16 zeros)
    XCTAssertEqual(encoded[72..<88], Data(repeating: 0, count: 16))

    // Verify completionFilter
    // fileName (1) | dirName (2) | lastWrite (16) = 19 (0x13)
    XCTAssertEqual(encoded[88], 0x13)
    XCTAssertEqual(encoded[89], 0)
    XCTAssertEqual(encoded[90], 0)
    XCTAssertEqual(encoded[91], 0)
  }

  func testResponseParsing() {
    // Construct a fake response buffer simulating FileNotifyInformation
    // Entry 1: "file1.txt", Added
    // Entry 2: "file2.txt", Modified

    var buffer = Data()

    // --- Entry 1 ---
    var entry1 = Data()
    let name1 = "file1.txt".data(using: .utf16LittleEndian)!
    // NextEntryOffset: unknown yet
    entry1.append(Data(count: 4))
    // Action: Added (1)
    entry1.append(contentsOf: [1, 0, 0, 0])
    // FileNameLength: 18 bytes (9 chars)
    entry1.append(contentsOf: [18, 0, 0, 0])
    // FileName
    entry1.append(name1)
    // Padding to 4-byte boundary if needed? The spec says "The file name... MUST be padded to a 4-byte boundary if the NextEntryOffset is not zero."
    // 4 (offset) + 4 (action) + 4 (len) + 18 (name) = 30 bytes.
    // Need 2 bytes padding.
    entry1.append(contentsOf: [0, 0])

    let entry1Size = UInt32(entry1.count)
    // Write NextEntryOffset at start
    let entry1SizeBytes = withUnsafeBytes(of: entry1Size) { Data($0) }
    entry1.replaceSubrange(0..<4, with: entry1SizeBytes)

    // --- Entry 2 ---
    var entry2 = Data()
    let name2 = "file2.txt".data(using: .utf16LittleEndian)!
    // NextEntryOffset: 0 (last entry)
    entry2.append(contentsOf: [0, 0, 0, 0])
    // Action: Modified (3)
    entry2.append(contentsOf: [3, 0, 0, 0])
    // FileNameLength: 18 bytes
    entry2.append(contentsOf: [18, 0, 0, 0])
    // FileName
    entry2.append(name2)
    // No padding needed for last entry typically, but good practice.

    buffer.append(entry1)
    buffer.append(entry2)

    // Create response object manually (bypassing full decode for unit test of parsing logic)
    // Actually, we need to test `Response(data:)` but constructing a full response packet is tedious.
    // Let's test `FileNotifyInformation(data:)` logic if possible, but it's internal/private?
    // Wait, FileNotifyInformation is public in my implementation? Yes.

    let info1 = FileNotifyInformation(data: buffer)
    XCTAssertEqual(info1.fileName, "file1.txt")
    XCTAssertEqual(info1.action, .added)
    XCTAssertEqual(info1.nextEntryOffset, entry1Size)

    let info2 = FileNotifyInformation(
      data: buffer.subdata(in: Int(info1.nextEntryOffset)..<buffer.count))
    XCTAssertEqual(info2.fileName, "file2.txt")
    XCTAssertEqual(info2.action, .modified)
    XCTAssertEqual(info2.nextEntryOffset, 0)
  }
}
