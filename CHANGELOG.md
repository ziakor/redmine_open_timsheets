# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - unreleased

### Added
- **Monthly calendar view of spent time**, reachable from a third tab next to Details and Report on both the project and the global spent time screens. It reuses Redmine's own `TimeEntryQuery`, so the existing filters and saved queries apply to it unchanged.
- **Missing day detection.** Tracking is day based: a working day carrying no time entry at all is highlighted. There is no hour target and no partial day, because the team works under day-based contracts (forfait jours). Hours are displayed for context and never compared to anything.
- **French public holidays**, computed rather than stored, including the movable ones derived from Easter. Optional Alsace-Moselle variant, selectable in the plugin settings.
- **Absences**, declared by each user for themselves, or by an administrator for anyone. Full day absences remove the day from the expected ones; a half day leaves it expected, since the other half was worked.
- **Day tracking administration screen**, listing active users with a single checkbox. Everyone is tracked by default; unchecking someone records an exemption.
- **Personal and collective modes.** Completeness is only scored when the filter targets a single user. With several users in scope the grid stays informational, and says so, because summing the days owed by several people inside one cell produces an unreadable figure.

- **Week view.** A Month / Week switch on the calendar, reusing the period support already present in Redmine's calendar helper. Counters follow the displayed period.
- **Team tracking screen**, listing every tracked person with their missing, declared and owed days plus a completion rate, worst first. Open to Redmine administrators and to people designated on the administration screen.
- **User profile shortcut** for administrators and designated team viewers, opening the calendar already filtered on that person.
- **Reminder task**, `rake redmine:open_timesheets:remind`, emailing anyone with undeclared working days in a configurable recent window. Meant to be driven by cron, since Redmine ships no scheduler for plugins.
- **JSON API and CSV exports** for the calendar and the team screen. The CSV carries one row per day, since Redmine already exports the entries themselves; what this adds is the status of each day.

### Notes
- The calendar tab is injected client side, because Redmine's tab strip partial exposes no hook. See the README for what this implies on Redmine upgrades.
- The reminder is delivered by email rather than through `redmine_open_notifications`: that plugin's `user_notifications` table requires `project_id` and `issue_id` to be NOT NULL, and a reminder has neither.
- The plugin is **read only** on time entries. Logging, editing and deleting still happen on Redmine's own screens.
