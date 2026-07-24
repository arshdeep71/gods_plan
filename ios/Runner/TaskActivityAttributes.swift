import ActivityKit
import Foundation

/// ActivityAttributes model matching Flutter Live Activity payloads for "God's Plan"
public struct TaskActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var taskId: String
        public var occurrenceId: String
        public var taskTitle: String
        public var deadline: Date
        public var headerStatus: String
        public var progress: Double
        public var streakDays: Int
        public var completedRatio: String
        public var xpAmount: Int
        public var subtitle: String
        public var footerText: String

        public init(
            taskId: String,
            occurrenceId: String,
            taskTitle: String,
            deadline: Date,
            headerStatus: String,
            progress: Double = 0.0,
            streakDays: Int = 0,
            completedRatio: String = "",
            xpAmount: Int = 0,
            subtitle: String = "",
            footerText: String = ""
        ) {
            self.taskId = taskId
            self.occurrenceId = occurrenceId
            self.taskTitle = taskTitle
            self.deadline = deadline
            self.headerStatus = headerStatus
            self.progress = progress
            self.streakDays = streakDays
            self.completedRatio = completedRatio
            self.xpAmount = xpAmount
            self.subtitle = subtitle
            self.footerText = footerText
        }
    }

    public var name: String

    public init(name: String = "TaskActivity") {
        self.name = name
    }
}
