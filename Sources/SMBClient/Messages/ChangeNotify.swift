import Foundation

public enum ChangeNotify {
  public struct Request: Message.Request {
    public typealias Response = ChangeNotify.Response

    public let header: Header
    public let structureSize: UInt16
    public let flags: Flags
    public let outputBufferLength: UInt32
    public let fileId: Data
    public let completionFilter: CompletionFilter
    public let reserved: UInt32

    public init(
      creditCharge: UInt16 = 1,
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      flags: Flags = [],
      outputBufferLength: UInt32 = 65535,
      fileId: Data,
      completionFilter: CompletionFilter
    ) {
      header = Header(
        creditCharge: creditCharge,
        command: .changeNotify,
        creditRequest: 256,
        flags: headerFlags,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 32
      self.flags = flags
      self.outputBufferLength = outputBufferLength
      self.fileId = fileId
      self.completionFilter = completionFilter
      self.reserved = 0
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      data += structureSize
      data += flags.rawValue
      data += outputBufferLength
      data += fileId
      data += completionFilter.rawValue
      data += reserved

      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let outputBufferOffset: UInt16
    public let outputBufferLength: UInt32
    public let buffer: Data

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      outputBufferOffset = reader.read()
      outputBufferLength = reader.read()
      buffer = reader.read(from: Int(outputBufferOffset), count: Int(outputBufferLength))
    }

    public func notifyInformation() -> [FileNotifyInformation] {
      var notifications = [FileNotifyInformation]()
      if outputBufferLength > 0 {
        var data = Data(buffer)
        repeat {
          let info = FileNotifyInformation(data: data)
          notifications.append(info)
          data = Data(data[(Int(info.nextEntryOffset))...])
        } while notifications.last!.nextEntryOffset != 0
      }

      return notifications
    }
  }

  public struct Flags: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let watchTree = Flags(rawValue: 0x0001)
  }

  public struct CompletionFilter: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let fileName = CompletionFilter(rawValue: 0x0000_0001)
    public static let dirName = CompletionFilter(rawValue: 0x0000_0002)
    public static let attributes = CompletionFilter(rawValue: 0x0000_0004)
    public static let size = CompletionFilter(rawValue: 0x0000_0008)
    public static let lastWrite = CompletionFilter(rawValue: 0x0000_0010)
    public static let lastAccess = CompletionFilter(rawValue: 0x0000_0020)
    public static let creation = CompletionFilter(rawValue: 0x0000_0040)
    public static let ea = CompletionFilter(rawValue: 0x0000_0080)
    public static let security = CompletionFilter(rawValue: 0x0000_0100)
    public static let streamName = CompletionFilter(rawValue: 0x0000_0200)
    public static let streamSize = CompletionFilter(rawValue: 0x0000_0400)
    public static let streamWrite = CompletionFilter(rawValue: 0x0000_0800)
  }
}

public struct FileNotifyInformation {
  public let nextEntryOffset: UInt32
  public let action: Action
  public let fileNameLength: UInt32
  public let fileName: String

  public init(data: Data) {
    let reader = ByteReader(data)

    nextEntryOffset = reader.read()
    action = Action(rawValue: reader.read()) ?? .added
    fileNameLength = reader.read()

    let nameData = reader.read(count: Int(fileNameLength))
    fileName = String(data: nameData, encoding: .utf16LittleEndian) ?? ""
  }

  public enum Action: UInt32 {
    case added = 0x0000_0001
    case removed = 0x0000_0002
    case modified = 0x0000_0003
    case renamedOldName = 0x0000_0004
    case renamedNewName = 0x0000_0005
  }
}
