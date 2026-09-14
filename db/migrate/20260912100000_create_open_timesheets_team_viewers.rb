# frozen_string_literal: true

# Presence of a row means the user may open the team view. Administrators are
# allowed without a row. Modelled as a list, like the exemptions, so the unique
# index carries the invariant instead of application code.
class CreateOpenTimesheetsTeamViewers < ActiveRecord::Migration[7.2]
  def change
    create_table :open_timesheets_team_viewers do |t|
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :open_timesheets_team_viewers, :user_id, unique: true
  end
end
