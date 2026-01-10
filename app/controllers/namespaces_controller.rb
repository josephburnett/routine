class NamespacesController < ApplicationController
  before_action :require_login
  before_action :find_namespace, only: [ :show ]

  def index
    # Redirect to root namespace view
    redirect_to namespace_path("root")
  end

  def show
    if request.post?
      # Handle bulk move with cascading
      Rails.logger.info "Bulk move params: #{params.inspect}"
      target_namespace = params[:target_namespace] || ""
      entity_params = params[:entities] || {}
      skip_cascade = params[:skip_cascade] == "1"

      Rails.logger.info "Target namespace: #{target_namespace.inspect}"
      Rails.logger.info "Entity params: #{entity_params.inspect}"
      Rails.logger.info "Skip cascade: #{skip_cascade}"

      moved_count = 0

      # Process each entity type with cascading moves
      entity_params.each do |entity_type, entity_ids|
        next if entity_ids.blank?

        Rails.logger.info "Processing #{entity_type}: #{entity_ids.inspect}"
        model_class = entity_type.singularize.camelize.constantize
        entities = model_class.where(id: entity_ids, user: current_user)

        Rails.logger.info "Found #{entities.count} entities to update"

        # Move entities and optionally cascade to related entities
        entities.each do |entity|
          moved_count += move_entity_with_cascade(entity, target_namespace, skip_cascade)
        end
      end

      Rails.logger.info "Total moved count: #{moved_count}"

      if moved_count > 0
        target_display = target_namespace.present? ? target_namespace : "Root"
        redirect_to namespace_path(@namespace), notice: "Successfully moved #{moved_count} #{'item'.pluralize(moved_count)} to #{target_display}"
      else
        redirect_to namespace_path(@namespace), alert: "No items were selected for moving"
      end
    else
      # GET request - show the namespace with child namespaces and bulk move form
    end
  end

  private

  def move_entity_with_cascade(entity, target_namespace, skip_cascade = false)
    count = 0

    # Move the entity itself
    entity.update!(namespace: target_namespace)
    count += 1

    # If skip_cascade is true, only move the selected entity
    return count if skip_cascade

    case entity
    when Form
      # Cascade: Move all Responses
      entity.responses.each do |response|
        response.update!(namespace: target_namespace)
        count += 1

        # Also move Answers associated with the Response
        response.answers.each do |answer|
          answer.update!(namespace: target_namespace)
          count += 1
        end
      end

      # Cascade: Move all Sections associated with the Form
      entity.sections.each do |section|
        section.update!(namespace: target_namespace)
        count += 1

        # Move Questions in this Section and their Answers
        section.questions.each do |question|
          question.update!(namespace: target_namespace)
          count += 1

          # Move Answers for this Question
          question.answers.each do |answer|
            answer.update!(namespace: target_namespace)
            count += 1
          end
        end
      end

    when Section
      # Cascade: Move all Questions in this Section
      entity.questions.each do |question|
        question.update!(namespace: target_namespace)
        count += 1

        # Move Answers for this Question
        question.answers.each do |answer|
          answer.update!(namespace: target_namespace)
          count += 1
        end
      end

    when Question
      # Cascade: Move all Answers for this Question
      entity.answers.each do |answer|
        answer.update!(namespace: target_namespace)
        count += 1
      end
    end

    count
  end

  def find_namespace
    namespace_name = params[:id] == "root" ? "" : params[:id]
    @namespace = Namespace.find_for_user(current_user, namespace_name)
  rescue ActiveRecord::RecordNotFound
    redirect_to namespace_path("root"), alert: "Namespace not found"
  end
end
