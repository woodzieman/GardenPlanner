import SwiftUI
import SwiftData

/// Tasks view — derived from calendar + manual tasks.
/// Shows "do this now" list with push notification support (Phase 2).
struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var showingNewTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDueDate = Date()
    
    private let today = Calendar.current.startOfDay(for: Date())
    
    var body: some View {
        NavigationStack {
            List {
                // Overdue
                overdueTasksSection
                
                // Today
                todayTasksSection
                
                // Future (manual and calendar-derived tasks both live here)
                futureTasksSection
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingNewTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTask) {
                NewTaskSheet()
            }
        }
    }
    
    @ViewBuilder
    private var overdueTasksSection: some View {
        let overdue = tasks.filter { Calendar.current.startOfDay(for: $0.dueDate) < today && !$0.completed }
        if !overdue.isEmpty {
        Section("Overdue") {
            ForEach(overdue) { task in
                TaskRow(task: task)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                deleteTasks(at: indexSet)
            }
        }
        }
    }
    
    @ViewBuilder
    private var todayTasksSection: some View {
        let todayTasks = tasks.filter { Calendar.current.startOfDay(for: $0.dueDate) == today && !$0.completed }
        if !todayTasks.isEmpty {
        Section("Today") {
            ForEach(todayTasks) { task in
                TaskRow(task: task)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                deleteTasks(at: indexSet)
            }
        }
        }
    }
    
    @ViewBuilder
    private var futureTasksSection: some View {
        let future = tasks.filter { Calendar.current.startOfDay(for: $0.dueDate) > today && !$0.completed }
        if !future.isEmpty {
        Section("Upcoming") {
            ForEach(future) { task in
                TaskRow(task: task)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                deleteTasks(at: indexSet)
            }
        }
        }
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            if let task = tasks[safe: index] {
                modelContext.delete(task)
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.completed ? .green : (Calendar.current.startOfDay(for: task.dueDate) < today ? .red : .gray))
                .onTapGesture {
                    task.completed.toggle()
                }
            
            Text(task.title)
                .font(.body)
                .strikethrough(task.completed, color: .gray)
                .foregroundStyle(task.completed ? .secondary : .primary)
            
            Spacer()
            
            if !task.isManual {
                Text(task.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Image(systemName: task.isManual ? "plus.circle.fill" : "calendar.badge.clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - New Task Sheet

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(86400) // Tomorrow
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $title)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveTask() {
        let task = TaskItem(
            title: title,
            dueDate: dueDate,
            completed: false,
            isManual: true
        )
        modelContext.insert(task)
        
        title = ""
        dismiss()
    }
}

