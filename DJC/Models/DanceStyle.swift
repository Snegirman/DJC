import Foundation

enum DanceStyle: String, Codable, CaseIterable, Identifiable {
    case popping
    case animation
    case waving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popping:
            "Popping"
        case .animation:
            "Animation"
        case .waving:
            "Waving"
        }
    }
}
