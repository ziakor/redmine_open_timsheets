# frozen_string_literal: true

class CreateOpenTimesheetsAbsences < ActiveRecord::Migration[7.2]
  def change
    create_table :open_timesheets_absences do |t|
      t.integer :user_id, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :absence_type, limit: 30, null: false
      t.boolean :half_day, null: false, default: false
      t.string :comments, limit: 255, null: true
      t.timestamps
    end

    add_index :open_timesheets_absences, %i[user_id start_date end_date],
              name: 'index_ot_absences_on_user_and_dates'
  end
end
