import Foundation
import SwiftData

@Model
class JournalEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String
    var plantName: String?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        note: String,
        plantName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.plantName = plantName
    }
}
