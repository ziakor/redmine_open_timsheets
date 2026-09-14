# Redmine Open Timesheets

A monthly calendar view of spent time for Redmine, built around one question:
which working days have not been declared yet.

Tracking is **day based**. There is no expected number of hours, no target and
no partial day: a day is either declared or it is not. Hours logged in Redmine
stay visible as context, and are never compared to anything.

## Requirements

- Redmine 6.0 or higher
- Ruby 3.1 or higher

Developed and tested against Redmine 6.0.6, Ruby 3.3, Rails 7.2.2.1, MariaDB
10.11.

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/ziakor/redmine_open_timesheets.git redmine_open_timesheets
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart Redmine. No new gem, no JavaScript build, no npm dependency: the plugin
only uses what Redmine already ships.

## Uninstallation

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=redmine_open_timesheets VERSION=0 RAILS_ENV=production
rm -rf plugins/redmine_open_timesheets
```

Restart Redmine.

## Settings

Administration then Plugins then Configure:

- **Public holidays**: France, or France with the Alsace-Moselle variant, which
  adds Good Friday and 26 December.

Administration then Day tracking lists active users with one checkbox each.
Everyone is tracked by default; unchecking someone records an exemption and
their days stop being reported as missing.

## Permissions

The plugin declares **no new permission and no project module**. Reading the
calendar reuses `view_time_entries`: whoever can see the spent time list can
see the calendar. Absences are managed by each user for themselves, and by
administrators for anyone.

The team screen is open to Redmine administrators and to users ticked on the
administration screen. That restriction is deliberate but not a data barrier:
anyone holding `view_time_entries` already sees other people's entries in
Redmine. What the list gates is the aggregated "who is late" reading, which is
a management artefact rather than new data. The screen also counts only the
entries the viewer is allowed to see, so a viewer without access to a project
may see overstated missing counts.

## Views

- **Calendar**, month or week, global at `/open_timesheets/calendar` or per project at `/projects/<identifier>/open_timesheets/calendar`. Reachable from a third tab next to Details and Report.
- **Team tracking** at `/open_timesheets/team`, listing missing, declared and owed days per person, worst first.
- **User profile shortcut** for administrators and designated team viewers, opening the calendar already filtered on that person.

Both accept `date=YYYY-MM-DD` and `period=month|week`.

## Reminders

Redmine ships no scheduler for plugins, so the reminder is a rake task meant to be driven by cron:

```cron
0 9 * * 1-5 cd /opt/redmine && RAILS_ENV=production bundle exec rake redmine:open_timesheets:remind
```

It emails anyone with undeclared working days inside the configured window, which defaults to the seven previous days. The current day is never counted.

Delivery goes through Redmine's own mailer rather than `redmine_open_notifications`: that plugin's `user_notifications` table requires `project_id` and `issue_id` to be NOT NULL, and a reminder has neither. The coupling becomes possible the day those columns accept null.

## API and exports

```
GET /open_timesheets/calendar.json?date=2026-07-15&period=month&key=<api key>
GET /open_timesheets/calendar.csv?date=2026-07-15
GET /open_timesheets/team.csv?date=2026-07-15
```

The JSON payload carries the period bounds, the counters and one object per day with its status and entries. The CSV carries one row per day: Redmine already exports the entries themselves, so what this adds is the status of each day.

Redmine ignores the session on API requests, so the JSON endpoint needs an API key or basic authentication.

## Day states

| State | Meaning |
|---|---|
| declared | the day carries at least one time entry |
| missing | a working day that is owed and carries nothing |
| off | weekend, public holiday, full day absence, or exempt user |
| future | a day still to come; Redmine forbids logging in the future by default |

A day carrying an entry always reads as declared, even on a weekend: that is
what the data says.

## Upgrade warning, please read

Redmine's spent time screen renders its Details and Report tabs from
`timelog/_date_range.html.erb`, which **exposes no hook**. Overriding that
partial would mean that any change to it in a future Redmine release breaks the
spent time screen itself. The plugin injects its tab from the client instead.

The consequence: after every Redmine upgrade, check that the Calendar tab still
appears on the spent time screen. If Redmine changes the markup of its tab
strip, the tab silently disappears. That failure mode is deliberate and
contained: the native screens keep working, only the plugin tab is lost, and
the calendar stays reachable at `/open_timesheets/calendar`.

## Development

The test harness lives outside this repository, in `redmine6-test`. The
official `redmine:6.0.6` image installs its gems without the development and
test groups and strips the build toolchain, so a derived image is required.

```bash
cd ../redmine6-test
./run-tests.sh                                  # whole suite
./run-tests.sh test/unit/holidays_test.rb       # one file
./lint.sh                                       # RuboCop
```

`lint.sh` mounts the plugin outside the Redmine tree on purpose: Redmine's own
`.rubocop.yml` excludes `**/plugins/**/*`, so running RuboCop from the usual
plugin location silently inspects zero files.

## License

MIT. See [LICENSE](LICENSE).
