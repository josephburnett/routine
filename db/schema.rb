# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_02_063301) do
  create_table "alerts", force: :cascade do |t|
    t.string "name", null: false
    t.integer "metric_id", null: false
    t.decimal "threshold", precision: 10, scale: 2, null: false
    t.string "direction", null: false
    t.integer "user_id", null: false
    t.string "namespace", default: ""
    t.boolean "deleted", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "delay", default: 1, null: false
    t.text "message"
    t.index ["metric_id"], name: "index_alerts_on_metric_id"
    t.index ["namespace"], name: "index_alerts_on_namespace"
    t.index ["user_id", "deleted"], name: "index_alerts_on_user_id_and_deleted"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "answers", force: :cascade do |t|
    t.integer "question_id", null: false
    t.string "answer_type"
    t.string "string_value"
    t.float "number_value"
    t.boolean "bool_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "response_id"
    t.integer "user_id"
    t.boolean "deleted", default: false, null: false
    t.string "namespace", default: "", null: false
    t.index ["namespace"], name: "index_answers_on_namespace"
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["response_id"], name: "index_answers_on_response_id"
    t.index ["user_id"], name: "index_answers_on_user_id"
  end

  create_table "dashboard_alerts", force: :cascade do |t|
    t.integer "dashboard_id", null: false
    t.integer "alert_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id"], name: "index_dashboard_alerts_on_alert_id"
    t.index ["dashboard_id", "position"], name: "index_dashboard_alerts_on_dashboard_id_and_position"
    t.index ["dashboard_id"], name: "index_dashboard_alerts_on_dashboard_id"
  end

  create_table "dashboard_dashboards", force: :cascade do |t|
    t.integer "dashboard_id", null: false
    t.integer "linked_dashboard_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id", "linked_dashboard_id"], name: "idx_on_dashboard_id_linked_dashboard_id_bc8e1ca434", unique: true
    t.index ["dashboard_id"], name: "index_dashboard_dashboards_on_dashboard_id"
    t.index ["linked_dashboard_id"], name: "index_dashboard_dashboards_on_linked_dashboard_id"
  end

  create_table "dashboard_forms", force: :cascade do |t|
    t.integer "dashboard_id", null: false
    t.integer "form_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id", "form_id"], name: "index_dashboard_forms_on_dashboard_id_and_form_id", unique: true
    t.index ["dashboard_id"], name: "index_dashboard_forms_on_dashboard_id"
    t.index ["form_id"], name: "index_dashboard_forms_on_form_id"
  end

  create_table "dashboard_metrics", force: :cascade do |t|
    t.integer "dashboard_id", null: false
    t.integer "metric_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", default: 0
    t.index ["dashboard_id"], name: "index_dashboard_metrics_on_dashboard_id"
    t.index ["metric_id"], name: "index_dashboard_metrics_on_metric_id"
  end

  create_table "dashboard_questions", force: :cascade do |t|
    t.integer "dashboard_id", null: false
    t.integer "question_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_id", "question_id"], name: "index_dashboard_questions_on_dashboard_id_and_question_id", unique: true
    t.index ["dashboard_id"], name: "index_dashboard_questions_on_dashboard_id"
    t.index ["question_id"], name: "index_dashboard_questions_on_question_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.string "name"
    t.integer "user_id", null: false
    t.boolean "deleted", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "namespace", default: "", null: false
    t.index ["namespace"], name: "index_dashboards_on_namespace"
    t.index ["user_id"], name: "index_dashboards_on_user_id"
  end

  create_table "form_drafts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "form_id", null: false
    t.json "draft_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_id"], name: "index_form_drafts_on_form_id"
    t.index ["user_id", "form_id"], name: "index_form_drafts_on_user_id_and_form_id", unique: true
    t.index ["user_id"], name: "index_form_drafts_on_user_id"
  end

  create_table "forms", force: :cascade do |t|
    t.string "name"
    t.integer "user_id"
    t.boolean "deleted", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "namespace", default: "", null: false
    t.index ["namespace"], name: "index_forms_on_namespace"
  end

  create_table "forms_sections", id: false, force: :cascade do |t|
    t.integer "form_id", null: false
    t.integer "section_id", null: false
  end

  create_table "metric_metrics", force: :cascade do |t|
    t.integer "parent_metric_id", null: false
    t.integer "child_metric_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_metric_id"], name: "index_metric_metrics_on_child_metric_id"
    t.index ["parent_metric_id", "child_metric_id"], name: "index_metric_metrics_on_parent_and_child", unique: true
    t.index ["parent_metric_id"], name: "index_metric_metrics_on_parent_metric_id"
  end

  create_table "metric_questions", force: :cascade do |t|
    t.integer "metric_id", null: false
    t.integer "question_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_id", "question_id"], name: "index_metric_questions_on_metric_id_and_question_id", unique: true
    t.index ["metric_id"], name: "index_metric_questions_on_metric_id"
    t.index ["question_id"], name: "index_metric_questions_on_question_id"
  end

  create_table "metrics", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "resolution"
    t.string "width"
    t.string "function"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "deleted", default: false, null: false
    t.string "name"
    t.decimal "scale", precision: 10, scale: 4, default: "1.0"
    t.integer "first_metric_id"
    t.string "namespace", default: "", null: false
    t.string "wrap", default: "none", null: false
    t.index ["first_metric_id"], name: "index_metrics_on_first_metric_id"
    t.index ["namespace"], name: "index_metrics_on_namespace"
    t.index ["user_id"], name: "index_metrics_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "question_type"
    t.float "range_min"
    t.float "range_max"
    t.boolean "deleted", default: false, null: false
    t.string "namespace", default: "", null: false
    t.index ["namespace"], name: "index_questions_on_namespace"
    t.index ["user_id"], name: "index_questions_on_user_id"
  end

  create_table "questions_sections", id: false, force: :cascade do |t|
    t.integer "question_id", null: false
    t.integer "section_id", null: false
  end

  create_table "report_alerts", force: :cascade do |t|
    t.integer "report_id", null: false
    t.integer "alert_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id"], name: "index_report_alerts_on_alert_id"
    t.index ["report_id"], name: "index_report_alerts_on_report_id"
  end

  create_table "report_metrics", force: :cascade do |t|
    t.integer "report_id", null: false
    t.integer "metric_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_id"], name: "index_report_metrics_on_metric_id"
    t.index ["report_id"], name: "index_report_metrics_on_report_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name"
    t.time "time_of_day"
    t.string "interval_type"
    t.json "interval_config"
    t.datetime "last_sent_at"
    t.boolean "deleted", default: false
    t.string "namespace"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "deleted", default: false, null: false
    t.integer "form_id"
    t.string "namespace", default: "", null: false
    t.index ["namespace"], name: "index_responses_on_namespace"
    t.index ["user_id"], name: "index_responses_on_user_id"
  end

  create_table "sections", force: :cascade do |t|
    t.string "name"
    t.string "prompt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "deleted", default: false, null: false
    t.string "namespace", default: "", null: false
    t.index ["namespace"], name: "index_sections_on_namespace"
    t.index ["user_id"], name: "index_sections_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
  end

  add_foreign_key "alerts", "metrics"
  add_foreign_key "alerts", "users"
  add_foreign_key "answers", "questions"
  add_foreign_key "answers", "responses"
  add_foreign_key "answers", "users"
  add_foreign_key "dashboard_alerts", "alerts"
  add_foreign_key "dashboard_alerts", "dashboards"
  add_foreign_key "dashboard_dashboards", "dashboards"
  add_foreign_key "dashboard_dashboards", "dashboards", column: "linked_dashboard_id"
  add_foreign_key "dashboard_forms", "dashboards"
  add_foreign_key "dashboard_forms", "forms"
  add_foreign_key "dashboard_metrics", "dashboards"
  add_foreign_key "dashboard_metrics", "metrics"
  add_foreign_key "dashboard_questions", "dashboards"
  add_foreign_key "dashboard_questions", "questions"
  add_foreign_key "dashboards", "users"
  add_foreign_key "form_drafts", "forms"
  add_foreign_key "form_drafts", "users"
  add_foreign_key "metric_metrics", "metrics", column: "child_metric_id"
  add_foreign_key "metric_metrics", "metrics", column: "parent_metric_id"
  add_foreign_key "metric_questions", "metrics"
  add_foreign_key "metric_questions", "questions"
  add_foreign_key "metrics", "metrics", column: "first_metric_id"
  add_foreign_key "metrics", "users"
  add_foreign_key "questions", "users"
  add_foreign_key "report_alerts", "alerts"
  add_foreign_key "report_alerts", "reports"
  add_foreign_key "report_metrics", "metrics"
  add_foreign_key "report_metrics", "reports"
  add_foreign_key "reports", "users"
  add_foreign_key "responses", "users"
  add_foreign_key "sections", "users"
end
