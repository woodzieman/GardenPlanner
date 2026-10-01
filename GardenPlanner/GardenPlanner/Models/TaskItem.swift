import Foundation
import SwiftData

@Model
class TaskItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var dueDate: Date
    var completed: Bool
    var isManual: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date = Date(),
        completed: Bool = false,
        isManual: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.completed = completed
        self.isManual = isManual
    }
}
