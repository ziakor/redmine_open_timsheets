# frozen_string_literal: true

module TimesheetCalendarHelper
  DAY_STATUS_CLASSES = {
    off: 'ots-off',
    future: 'ots-future',
    missing: 'ots-missing',
    logged: 'ots-logged',
    unscored: 'ots-unscored',
    outside: 'ots-outside'
  }.freeze

  # fetch, not [], so an unknown status raises instead of silently producing a
  # cell with no class and a display bug nobody notices.
  # Redmine's day_css_classes greys days belonging to another month, which is
  # right in a month grid. In week mode every displayed day belongs to the
  # period, so a week straddling two months must not grey half of itself.
  def calendar_day_classes(calendar, day, period)
    classes = calendar.day_css_classes(day)
    return classes unless period == :week

    classes.sub('other-month', 'this-month')
  end

  def day_status_class(status)
    DAY_STATUS_CLASSES.fetch(status)
  end

  # Hours are shown as information, never against a target. Nothing is rendered
  # on a day with no entry.
  def day_hours_badge(summary, day)
    hours = summary.logged_hours_on(day)
    return nil if hours.zero?

    format_hours(hours)
  end

  # The reason a day is not owed, when there is one to show.
  def day_note(summary, day)
    holiday = summary.holiday_name(day)
    return l(holiday) if holiday

    absence = summary.absence_on(day)
    return nil unless absence

    label = l("absence_type_#{absence.absence_type}")
    absence.full_day? ? label : "#{label} (#{l(:field_open_timesheets_absence_half_day)})"
  end

  # Mirrors RoutesHelper#_time_entries_path, which already applies this
  # project-or-global pattern.
  def timesheet_calendar_path_for(project, params = {})
    if project
      project_timesheet_calendar_path(project, params)
    else
      timesheet_calendar_path(params)
    end
  end

  # Navigation moves by one period: a week in week mode, a month otherwise.
  def calendar_step_params(date, period, direction)
    moved = period == :week ? date + (7 * direction) : date >> direction
    { date: moved.iso8601, period: period }
  end

  def calendar_period_params(date, period)
    { date: date.iso8601, period: period }
  end

  # "juillet 2026", or "Semaine 37 : 7 - 13 septembre 2026".
  def calendar_period_label(calendar, date, period)
    return "#{month_name(date.month)} #{date.year}" if period == :month

    "#{l(:label_week)} #{calendar.week_number(calendar.startdt)} : " \
      "#{format_date(calendar.startdt)} - #{format_date(calendar.enddt)}"
  end
end
