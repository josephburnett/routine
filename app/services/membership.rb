# Ordered parent/child links: sections in a form, questions in a section, and
# alerts and metrics in a report. Adds, removes, moves and sorts them the same
# way for the web pages and the MCP tools.
module Membership
  Relation = Struct.new(:join_model, :parent_key, :child_key, keyword_init: true) do
    def parent_column = :"#{parent_key}_id"
    def child_column = :"#{child_key}_id"
  end

  RELATIONS = {
    form_sections: Relation.new(join_model: FormSection, parent_key: :form, child_key: :section),
    section_questions: Relation.new(join_model: SectionQuestion, parent_key: :section, child_key: :question),
    report_alerts: Relation.new(join_model: ReportAlert, parent_key: :report, child_key: :alert),
    report_metrics: Relation.new(join_model: ReportMetric, parent_key: :report, child_key: :metric)
  }.freeze

  SORT_FIELDS = %w[name created_at].freeze
  SORT_DIRECTIONS = %w[asc desc].freeze

  class Error < StandardError; end

  module_function

  def relation(name)
    RELATIONS.fetch(name.to_sym) { raise Error, "Unknown relation: #{name}" }
  end

  # Returns false if the child is already linked.
  def add(relation_name, parent, child)
    rel = relation(relation_name)
    return false if rel.join_model.exists?(rel.parent_key => parent, rel.child_key => child)

    rel.join_model.create!(
      rel.parent_key => parent,
      rel.child_key => child,
      position: rel.join_model.next_position_for(rel.parent_column => parent.id)
    )
    true
  end

  # Returns false if the child wasn't linked.
  def remove(relation_name, parent, child)
    rel = relation(relation_name)
    join = rel.join_model.find_by(rel.parent_key => parent, rel.child_key => child)
    return false unless join

    join.destroy
    true
  end

  # direction: :up (earlier) or :down (later)
  def move(relation_name, parent, child_id, direction)
    rel = relation(relation_name)
    join = rel.join_model.find_by(rel.parent_key => parent, rel.child_column => child_id)
    raise Error, "Not linked: #{rel.child_key} #{child_id}" unless join

    direction.to_s == "up" ? join.move_higher! : join.move_lower!
  end

  def sort(relation_name, parent, sort_by, direction)
    raise Error, "Can only sort by #{SORT_FIELDS.join(' or ')}" unless SORT_FIELDS.include?(sort_by.to_s)

    rel = relation(relation_name)
    direction = SORT_DIRECTIONS.include?(direction.to_s) ? direction.to_s : "asc"
    rel.join_model.apply_sort!({ rel.parent_column => parent.id }, rel.child_key, sort_by.to_s, direction)
  end
end
