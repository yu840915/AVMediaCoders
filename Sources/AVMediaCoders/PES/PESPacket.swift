struct PESHeader {
  let packetStartCodePrefix: UInt32
  let streamId: UInt8
  let pesPacketLength: UInt16
  let optionalHeader: PESOptionalHeader?
  let payload: [UInt8]
}

