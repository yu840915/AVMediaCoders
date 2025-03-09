enum HEVCNALUnitType: UInt8, Equatable {
  //Coded slice segment
  case trialN = 0
  case trailR = 1
  case tsaN = 2
  case tsaR = 3
  case stsaN = 4
  case stsaR = 5
  case radlN = 6
  case radlR = 7
  case raslN = 8
  case raslR = 9
  //Reserved non-IRAP
  case rsvVclN10 = 10
  case rsvVclR11 = 11
  case rsvVclN12 = 12
  case rsvVclR13 = 13
  case rsvVclN14 = 14
  case rsvVclR15 = 15
  //Coded slice segment
  case blaWLp = 16
  case blaWRadl = 17
  case blaNLP = 18
  //Coded slice segment of an IDR picture
  case idrWRadl = 19
  case idrNLp = 20
  case cra = 21
  //Reserved IRAP
  case rsvIrapVclN22 = 22
  case rsvIrapVclR23 = 23
  //Metadata
  case vps = 32
  case sps = 33
  case pps = 34
  case aud = 35
  case eos = 36
  case eob = 37
  case fillerData = 38
  case prefixSEI = 39
  case suffixSEI = 40
  //Reserved non-VCL
  case rsvNVcl41 = 41
  case rsvNVcl42 = 42
  case rsvNVcl43 = 43
  case rsvNVcl44 = 44
  case rsvNVcl45 = 45
  case rsvNVcl46 = 46
  case rsvNVcl47 = 47
  //Unspecified
  case unspecified = 48
}

struct HEVCNALUnitHeader: Equatable {
  let type: HEVCNALUnitType
  let layerID: UInt8
  let temporalIDPlus1: UInt8

  var bytes: [UInt8] {
    [type.rawValue << 1 | (layerID & 0b00111111) >> 5, layerID << 3 | temporalIDPlus1]
  }

  init(type: HEVCNALUnitType, layerID: UInt8, temporalIDPlus1: UInt8) {
    self.type = type
    self.layerID = layerID
    self.temporalIDPlus1 = temporalIDPlus1
  }

  init(bytes: [UInt8]) throws {
    guard bytes.count >= 2 else {
      throw AVMediaCodersError.invalidHEVC(.invalidNALUnitHeaderLength)
    }
    let byte0 = bytes[0]
    guard byte0 & 0b10000000 == 0 else {
      throw AVMediaCodersError.invalidHEVC(.nonZeroForbiddenBit)
    }
    let byte1 = bytes[1]
    guard let type = HEVCNALUnitType(rawValue: byte0 >> 1) else {
      throw AVMediaCodersError.invalidHEVC(.invalidNALUnitType)
    }
    self.type = type
    layerID = (byte0 & 0b00000001) << 5 | byte1 >> 3
    temporalIDPlus1 = byte1 & 0b00000111
  }
}

struct HEVCNALUnit {
  let header: HEVCNALUnitHeader
  let payload: [UInt8]

  var bytes: [UInt8] {
    header.bytes + payload
  }

  init(header: HEVCNALUnitHeader, payload: [UInt8]) {
    self.header = header
    self.payload = payload
  }

  init(bytes: [UInt8]) throws {
    guard bytes.count >= 2 else {
      throw AVMediaCodersError.invalidHEVC(.invalidNALUnitHeaderLength)
    }
    let header = try HEVCNALUnitHeader(bytes: Array(bytes.prefix(2)))
    self.header = header
    payload = Array(bytes.dropFirst(2))
  }
}
