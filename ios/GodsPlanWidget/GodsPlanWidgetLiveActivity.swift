import ActivityKit
import WidgetKit
import SwiftUI

/// Shared model for compatibility with live_activities plugin
public struct LiveActivitiesAppAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var taskId: String?
        public var occurrenceId: String?
        public var taskTitle: String?
        public var deadline: String?
        public var headerStatus: String?
        public var progress: Double?
        public var streakDays: Int?
        public var completedRatio: String?
        public var xpAmount: Int?
        public var subtitle: String?
        public var footerText: String?

        public init(
            taskId: String? = nil,
            occurrenceId: String? = nil,
            taskTitle: String? = nil,
            deadline: String? = nil,
            headerStatus: String? = nil,
            progress: Double? = 0.0,
            streakDays: Int? = 0,
            completedRatio: String? = "",
            xpAmount: Int? = 0,
            subtitle: String? = "",
            footerText: String? = ""
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

    public init(name: String = "LiveActivitiesApp") {
        self.name = name
    }
}

struct GodsPlanWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskActivityAttributes.self) { context in
            // Lock Screen Live Activity UI
            LockScreenLiveActivityView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(getTaskEmoji(title: context.state.taskTitle))
                            .font(.title2)
                        Text(context.state.taskTitle)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.headerStatus)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(getStatusColor(status: context.state.headerStatus))

                        Text(timerInterval: Date()...context.state.deadline, countsDown: true)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.heavy)
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if context.state.progress > 0 {
                            ProgressView(value: context.state.progress, total: 1.0)
                                .accentColor(Color.purple)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        }

                        HStack {
                            if context.state.streakDays > 0 {
                                Label("Streak: \(context.state.streakDays)d", systemImage: "flame.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }

                            Spacer()

                            if !context.state.completedRatio.isEmpty {
                                Text(context.state.completedRatio)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else if context.state.xpAmount > 0 {
                                Text("+\(context.state.xpAmount) XP")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                // Compact Leading View
                HStack(spacing: 4) {
                    Text(getTaskEmoji(title: context.state.taskTitle))
                        .font(.caption)
                    Text(context.state.taskTitle)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                // Compact Trailing View with Native Timer
                Text(timerInterval: Date()...context.state.deadline, countsDown: true)
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(getStatusColor(status: context.state.headerStatus))
                    .padding(.trailing, 4)
            } minimal: {
                // Minimal View
                Text(getTaskEmoji(title: context.state.taskTitle))
                    .font(.caption)
            }
        }
    }

    private func getTaskEmoji(title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("gym") || lower.contains("workout") || lower.contains("exercise") { return "🏋" }
        if lower.contains("read") || lower.contains("study") || lower.contains("book") { return "📖" }
        if lower.contains("code") || lower.contains("dev") || lower.contains("build") { return "💻" }
        if lower.contains("run") || lower.contains("walk") || lower.contains("cardio") { return "🏃" }
        if lower.contains("meditat") || lower.contains("yoga") || lower.contains("relax") { return "🧘" }
        return "🎯"
    }

    private func getStatusColor(status: String) -> Color {
        if status.contains("1 Minute") || status.contains("🚨") { return Color.red }
        if status.contains("Almost") || status.contains("🔥") { return Color.orange }
        if status.contains("Time") || status.contains("🎯") { return Color.green }
        if status.contains("Missed") || status.contains("⏳") { return Color.gray }
        return Color.purple
    }
}

/// Lock Screen SwiftUI Live Activity View
struct LockScreenLiveActivityView: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        ZStack {
            // Background with premium Apple glassmorphism gradient
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.18),
                            Color(red: 0.08, green: 0.08, blue: 0.12)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                // Header Row: Emoji + Title | Status Badge
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Text(getTaskEmoji(title: state.taskTitle))
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.taskTitle)
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if !state.subtitle.isEmpty {
                                Text(state.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    // Status Pill Badge
                    Text(state.headerStatus)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(getStatusColor(status: state.headerStatus).opacity(0.2))
                        )
                        .overlay(
                            Capsule()
                                .stroke(getStatusColor(status: state.headerStatus).opacity(0.5), lineWidth: 1)
                        )
                        .foregroundColor(getStatusColor(status: state.headerStatus))
                }

                // Center Main Section: Native Countdown Timer
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET TIME")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.4))
                            .tracking(1.0)

                        Text(state.deadline, style: .time)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(Color.white.opacity(0.8))
                    }

                    Spacer()

                    // Native SwiftUI Timer (No manual updates required!)
                    if state.headerStatus.contains("Missed") {
                        Text("⏳ Missed")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(.gray)
                    } else if state.headerStatus.contains("Time") {
                        Text("Start \(state.taskTitle) 💪")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(.green)
                    } else {
                        Text(timerInterval: Date()...state.deadline, countsDown: true)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                }

                // Footer Row: Progress / Streak / XP
                if state.progress > 0 {
                    ProgressView(value: state.progress, total: 1.0)
                        .accentColor(Color.purple)
                }

                HStack {
                    if state.streakDays > 0 {
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.caption2)
                            Text("\(state.streakDays) Day Streak")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    if !state.footerText.isEmpty {
                        Text(state.footerText)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 4)
    }

    private func getTaskEmoji(title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("gym") || lower.contains("workout") || lower.contains("exercise") { return "🏋" }
        if lower.contains("read") || lower.contains("study") || lower.contains("book") { return "📖" }
        if lower.contains("code") || lower.contains("dev") || lower.contains("build") { return "💻" }
        if lower.contains("run") || lower.contains("walk") || lower.contains("cardio") { return "🏃" }
        if lower.contains("meditat") || lower.contains("yoga") || lower.contains("relax") { return "🧘" }
        return "🎯"
    }

    private func getStatusColor(status: String) -> Color {
        if status.contains("1 Minute") || status.contains("🚨") { return Color.red }
        if status.contains("Almost") || status.contains("🔥") { return Color.orange }
        if status.contains("Time") || status.contains("🎯") { return Color.green }
        if status.contains("Missed") || status.contains("⏳") { return Color.gray }
        return Color.purple
    }
}
