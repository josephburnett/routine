module Positionable
  extend ActiveSupport::Concern

  included do
    scope :ordered, -> { order(:position) }
  end

  # Swap with the item above (lower position number)
  def move_higher!
    scope = self.class.where(scope_conditions)
    above = scope.where("position < ?", position).order(position: :desc).first
    return unless above

    self.class.transaction do
      my_pos = position
      update!(position: above.position)
      above.update!(position: my_pos)
    end
  end

  # Swap with the item below (higher position number)
  def move_lower!
    scope = self.class.where(scope_conditions)
    below = scope.where("position > ?", position).order(position: :asc).first
    return unless below

    self.class.transaction do
      my_pos = position
      update!(position: below.position)
      below.update!(position: my_pos)
    end
  end

  class_methods do
    def next_position_for(scope_hash)
      where(scope_hash).maximum(:position).to_i + 1
    end

    # Reorder join records by an attribute on the associated entity.
    # scope_hash: e.g. { section_id: 5 }
    # association: the belongs_to name, e.g. :question
    # sort_by: attribute on the associated model, e.g. "name" or "created_at"
    # direction: "asc" or "desc"
    def apply_sort!(scope_hash, association, sort_by, direction = "asc")
      direction = direction.to_s == "desc" ? "desc" : "asc"
      join_records = where(scope_hash).includes(association).to_a

      join_records.sort_by! do |jr|
        value = jr.send(association).send(sort_by)
        value = value.to_s.downcase if value.is_a?(String)
        value
      end

      join_records.reverse! if direction == "desc"

      transaction do
        join_records.each_with_index do |jr, idx|
          jr.update_columns(position: idx)
        end
      end
    end
  end

  private

  # Returns a hash of the scope columns (all belongs_to foreign keys except the "child" one).
  # For FormSection: { form_id: X }, for SectionQuestion: { section_id: X }, etc.
  def scope_conditions
    # Each positionable model defines its scope column
    { self.class.position_scope_column => send(self.class.position_scope_column) }
  end
end
