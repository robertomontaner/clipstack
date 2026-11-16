import Foundation

enum ClipKind: String, Codable {
    case text
    case image
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let kind: ClipKind
    var text: String?
    var imageFile: String?   // nombre del PNG dentro de Application Support/ClipStack/images
    var hash: String         // para evitar duplicados
    var date: Date
}
