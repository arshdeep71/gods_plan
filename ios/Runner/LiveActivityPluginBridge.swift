import Foundation
import Flutter
import ActivityKit

@objc public class LiveActivityPluginBridge: NSObject {
    private static let CHANNEL_NAME = "com.godsplan.app/live_activity"
    private static var activeActivityId: String?
    private static var activeTaskId: String?

    @objc public static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: messenger)
        let instance = LiveActivityPluginBridge()
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            instance.handle(call, result: result)
        }
        print("[LIVE_ACTIVITY] Native MethodChannel '\(CHANNEL_NAME)' registered successfully.")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else {
            print("[LIVE_ACTIVITY_WARNING] Live Activities are only supported on iOS 16.1 or later.")
            result(FlutterError(code: "UNSUPPORTED_OS", message: "iOS 16.1+ required", details: nil))
            return
        }

        switch call.method {  
        case "startTaskActivity":
            startTaskActivity(call: call, result: result)
        case "updateTaskActivity":
            updateTaskActivity(call: call, result: result)
        case "endTaskActivity":
            endTaskActivity(call: call, result: result)
        case "restoreTaskActivity":
            restoreTaskActivity(call: call, result: result)
        case "endAllActivities":
            endAllActivities(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 16.1, *)
    private func startTaskActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String,
              let taskTitle = args["taskTitle"] as? String,
              let deadlineStr = args["deadline"] as? String else {
            print("[LIVE_ACTIVITY_ERROR] Invalid arguments passed to startTaskActivity.")
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required parameters", details: nil))
            return
        }

        print("[LIVE_ACTIVITY] Activity Requested for task '\(taskTitle)' (ID: \(taskId), Deadline: \(deadlineStr))")

        let occurrenceId = args["occurrenceId"] as? String ?? taskId
        let headerStatus = args["headerStatus"] as? String ?? "Starts in"
        let progress = args["progress"] as? Double ?? 0.0
        let streakDays = args["streakDays"] as? Int ?? 0
        let completedRatio = args["completedRatio"] as? String ?? ""
        let xpAmount = args["xpAmount"] as? Int ?? 0
        let subtitle = args["subtitle"] as? String ?? ""
        let footerText = args["footerText"] as? String ?? ""

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var deadlineDate = formatter.date(from: deadlineStr)
        if deadlineDate == nil {
            let fallbackFormatter = ISO8601DateFormatter()
            deadlineDate = fallbackFormatter.date(from: deadlineStr)
        }

        let finalDeadline = deadlineDate ?? Date().addingTimeInterval(900)

        // End any active activity first (Single Activity Priority Policy)
        endExistingActivitiesSync()

        let attributes = TaskActivityAttributes(name: taskTitle)
        let initialContentState = TaskActivityAttributes.ContentState(
            taskId: taskId,
            occurrenceId: occurrenceId,
            taskTitle: taskTitle,
            deadline: finalDeadline,
            headerStatus: headerStatus,
            progress: progress,
            streakDays: streakDays,
            completedRatio: completedRatio,
            xpAmount: xpAmount,
            subtitle: subtitle,
            footerText: footerText
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialContentState,
                pushType: nil
            )

            LiveActivityPluginBridge.activeActivityId = activity.id
            LiveActivityPluginBridge.activeTaskId = taskId

            print("[LIVE_ACTIVITY] Activity Started")
            print("[LIVE_ACTIVITY] Activity ID: \(activity.id)")
            print("[LIVE_ACTIVITY] Task ID: \(taskId)")
            print("[LIVE_ACTIVITY] Header Status: \(headerStatus)")

            result([
                "status": "started",
                "activityId": activity.id,
                "taskId": taskId
            ])
        } catch {
            print("[LIVE_ACTIVITY_ERROR] Exception: \(error.localizedDescription)")
            result(FlutterError(code: "ACTIVITY_REQUEST_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    @available(iOS 16.1, *)
    private func updateTaskActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing", details: nil))
            return
        }

        let activities = Activity<TaskActivityAttributes>.activities
        guard let currentActivity = activities.first else {
            print("[LIVE_ACTIVITY_WARNING] No active TaskActivity found to update.")
            result(["status": "no_activity"])
            return
        }

        var state = currentActivity.contentState
        if let headerStatus = args["headerStatus"] as? String {
            state.headerStatus = headerStatus
        }
        if let progress = args["progress"] as? Double {
            state.progress = progress
        }
        if let taskTitle = args["taskTitle"] as? String {
            state.taskTitle = taskTitle
        }

        Task {
            await currentActivity.update(using: state)
            print("[LIVE_ACTIVITY] Activity Updated successfully for activity ID \(currentActivity.id)")
        }

        result(["status": "updated", "activityId": currentActivity.id])
    }

    @available(iOS 16.1, *)
    private func endTaskActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let activities = Activity<TaskActivityAttributes>.activities
        for activity in activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
                print("[LIVE_ACTIVITY] Activity Ended | Activity ID: \(activity.id)")
            }
        }

        LiveActivityPluginBridge.activeActivityId = nil
        LiveActivityPluginBridge.activeTaskId = nil
        result(["status": "ended", "count": activities.count])
    }

    @available(iOS 16.1, *)
    private func restoreTaskActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let activities = Activity<TaskActivityAttributes>.activities
        print("[LIVE_ACTIVITY] Active count: \(activities.count)")

        if let active = activities.first {
            print("[LIVE_ACTIVITY] Restored active activity ID: \(active.id) for task '\(active.contentState.taskTitle)'")
            result([
                "status": "restored",
                "activityId": active.id,
                "taskId": active.contentState.taskId,
                "taskTitle": active.contentState.taskTitle
            ])
        } else {
            print("[LIVE_ACTIVITY] No active activity to restore.")
            result(["status": "none"])
        }
    }

    @available(iOS 16.1, *)
    private func endAllActivities(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let activities = Activity<TaskActivityAttributes>.activities
        for activity in activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        LiveActivityPluginBridge.activeActivityId = nil
        LiveActivityPluginBridge.activeTaskId = nil
        print("[LIVE_ACTIVITY] Ended all active activities.")
        result(["status": "ended_all", "count": activities.count])
    }

    @available(iOS 16.1, *)
    private func endExistingActivitiesSync() {
        let activities = Activity<TaskActivityAttributes>.activities
        for activity in activities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
