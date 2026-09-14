# frozen_string_literal: true

# Presence of a row means the user is exempt from day tracking. Absence means
# tracked. Modelling it as a list rather than a boolean lets the unique index
# carry the invariant instead of application code.
class CreateOpenTimesheetsExemptions < ActiveRecord::Migration[7.2]
  def change
    create_table :open_timesheets_exemptions do |t|
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :open_timesheets_exemptions, :user_id, unique: true
  end
end
