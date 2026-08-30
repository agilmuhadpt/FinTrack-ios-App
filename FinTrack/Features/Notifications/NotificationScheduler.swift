//
//  NotificationScheduler.swift
//  FinTrack — real twice-daily local reminders.
//
//  The prototype only *simulates* the push (see PushBannerView). The shipping app schedules
//  two repeating local notifications at `data.reminders.am` / `data.reminders.pm`, with the
//  same copy the Settings screen lists under "Notifications"
//  (FinTrack.dc.html lines 1087-1088):
//
//      AM  "Morning check-in"  — "Log yesterday's spending before the day starts."
//      PM  "Evening review"    — "2 minutes with <coach> to close the day."
//
//  Both requests use fixed identifiers, so rescheduling replaces them rather than piling up.
//
//  CALL SITES
//  ----------
//  • PushBannerView bootstraps this once per launch (`NotificationScheduler.bootstrap`).
//  • Settings should call `await NotificationScheduler.reschedule(reminders:coach:)` after a
//    reminder time, the coach name, or the coach emoji changes — the pending requests are not
//    re-derived from the store on their own.
//

import Foundation
import UserNotifications

enum NotificationScheduler {

    // MARK: - Identifiers

    /// The morning reminder. Fixed so a reschedule replaces it in place.
    static let morningIdentifier = "fintrack.reminder.am"

    /// The evening reminder. Fixed so a reschedule replaces it in place.
    static let eveningIdentifier = "fintrack.reminder.pm"

    private static var identifiers: [String] { [morningIdentifier, eveningIdentifier] }

    // MARK: - Copy (character-for-character with the Settings notification list)

    private static let morningTitle = "Morning check-in"
    private static let morningBody = "Log yesterday's spending before the day starts."
    private static let eveningTitle = "Evening review"

    /// `'2 minutes with ' + data.coach.name + ' to close the day.'`
    private static func eveningBody(coach: Coach) -> String {
        "2 minutes with " + coach.name + " to close the day."
    }

    // MARK: - Authorization

    /// Asks for alert + sound + badge. Returns `false` on denial or on any error — the app
    /// never depends on the result, so a refusal simply means no reminders are delivered.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// True only when the user has already granted permission. Never prompts.
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// Call from a place where the user has just expressed intent about reminders
    /// (changing a reminder time, finishing onboarding). Prompts if still undetermined,
    /// then schedules. Denial is a no-op rather than an error.
    @discardableResult
    static func enableAndSchedule(reminders: Reminders, coach: Coach) async -> Bool {
        let granted = await requestAuthorization()
        if granted { await reschedule(reminders: reminders, coach: coach) }
        return granted
    }

    /// Keeps the two pending requests in step with current data WITHOUT ever prompting.
    /// Safe to call on launch: a user who has not opted in is left alone.
    static func refreshIfAuthorized(reminders: Reminders, coach: Coach) async {
        guard await isAuthorized() else { return }
        await reschedule(reminders: reminders, coach: coach)
    }

    // MARK: - Scheduling

    /// Removes the two previously-scheduled reminders and adds them back for the current
    /// times and coach. A malformed `"HH:mm"` string simply skips that one reminder.
    static func reschedule(reminders: Reminders, coach: Coach) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        await add(
            identifier: morningIdentifier,
            time: reminders.am,
            title: morningTitle,
            body: morningBody,
            center: center
        )
        await add(
            identifier: eveningIdentifier,
            time: reminders.pm,
            title: eveningTitle,
            body: eveningBody(coach: coach),
            center: center
        )
    }

    /// Drops both reminders without adding anything back.
    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func add(
        identifier: String,
        time: String,
        title: String,
        body: String,
        center: UNUserNotificationCenter
    ) async {
        // A time we cannot parse is skipped, never forced into a default and never fatal.
        guard let components = dateComponents(from: time) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // `add` throws on a malformed request; there is nothing useful to do but carry on.
        try? await center.add(request)
    }

    // MARK: - "HH:mm" parsing

    /// Parses the stored 24h `"HH:mm"` string with a fixed `en_US_POSIX` formatter, so the
    /// device locale (12h clocks, non-Gregorian calendars, Arabic-Indic digits) cannot change
    /// how the persisted value is read. Returns `nil` for anything that is not a real time.
    static func dateComponents(from time: String) -> DateComponents? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"

        guard let date = formatter.date(from: time.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else { return nil }

        var out = DateComponents()
        out.hour = hour
        out.minute = minute
        return out
    }
}
