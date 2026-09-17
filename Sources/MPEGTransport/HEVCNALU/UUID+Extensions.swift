import Foundation

extension UUID {
  var bytes: [UInt8] {
    withUnsafeBytes(of: uuid) { Array($0) }
  }

  init?(bytes: [UInt8]) {
    guard bytes.count == 16 else { return nil }
    let tuple = (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    )
    self.init(uuid: tuple)
  }
}
