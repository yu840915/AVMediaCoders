protocol TSTableSection: Equatable, Sendable {
  var tableHeader: TSTableHeader { get }
  var bytes: [UInt8] { get }
}
