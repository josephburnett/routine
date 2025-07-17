require "openssl"
require "json"
require "base64"

class BackupService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def generate_backup_data
    backup_data = {
      user: user_data,
      forms: forms_data,
      sections: sections_data,
      questions: questions_data,
      responses: responses_data,
      answers: answers_data,
      metrics: metrics_data,
      alerts: alerts_data,
      reports: reports_data,
      dashboards: dashboards_data,
      generated_at: Time.current.iso8601
    }

    backup_data.to_json
  end

  def encrypt_backup(data, encryption_key)
    cipher = OpenSSL::Cipher.new("AES-256-GCM")
    cipher.encrypt

    # Use the provided key directly (it's already base64 encoded)
    key = Base64.decode64(encryption_key)
    cipher.key = key

    # Generate a random IV
    iv = cipher.random_iv
    cipher.iv = iv

    # Encrypt the data
    encrypted = cipher.update(data) + cipher.final
    auth_tag = cipher.auth_tag

    # Combine IV, auth_tag, and encrypted data
    encrypted_data = {
      iv: Base64.encode64(iv),
      auth_tag: Base64.encode64(auth_tag),
      data: Base64.encode64(encrypted)
    }

    encrypted_data.to_json
  end

  def self.decrypt_backup(encrypted_json, encryption_key)
    encrypted_data = JSON.parse(encrypted_json)

    cipher = OpenSSL::Cipher.new("AES-256-GCM")
    cipher.decrypt

    key = Base64.decode64(encryption_key)
    cipher.key = key
    cipher.iv = Base64.decode64(encrypted_data["iv"])
    cipher.auth_tag = Base64.decode64(encrypted_data["auth_tag"])

    decrypted = cipher.update(Base64.decode64(encrypted_data["data"])) + cipher.final
    decrypted
  end

  private

  def user_data
    {
      id: user.id,
      name: user.name,
      email: user.email,
      created_at: user.created_at.iso8601
    }
  end

  def forms_data
    user.forms.not_deleted.map do |form|
      {
        id: form.id,
        name: form.name,
        namespace: form.namespace,
        created_at: form.created_at.iso8601
      }
    end
  end

  def sections_data
    user.sections.not_deleted.map do |section|
      {
        id: section.id,
        name: section.name,
        prompt: section.prompt,
        form_ids: section.form_ids,
        namespace: section.namespace,
        created_at: section.created_at.iso8601
      }
    end
  end

  def questions_data
    user.questions.not_deleted.map do |question|
      {
        id: question.id,
        name: question.name,
        question_type: question.question_type,
        section_ids: question.sections.pluck(:id),
        namespace: question.namespace,
        created_at: question.created_at.iso8601
      }
    end
  end

  def responses_data
    user.responses.not_deleted.map do |response|
      {
        id: response.id,
        form_id: response.form_id,
        namespace: response.namespace,
        created_at: response.created_at.iso8601
      }
    end
  end

  def answers_data
    user.answers.not_deleted.map do |answer|
      {
        id: answer.id,
        question_id: answer.question_id,
        response_id: answer.response_id,
        answer_type: answer.answer_type,
        string_value: answer.string_value,
        number_value: answer.number_value,
        bool_value: answer.bool_value,
        namespace: answer.namespace,
        created_at: answer.created_at.iso8601
      }
    end
  end

  def metrics_data
    user.metrics.not_deleted.map do |metric|
      {
        id: metric.id,
        name: metric.name,
        function: metric.function,
        resolution: metric.resolution,
        width: metric.width,
        wrap: metric.wrap,
        scale: metric.scale,
        first_metric_id: metric.first_metric_id,
        namespace: metric.namespace,
        created_at: metric.created_at.iso8601
      }
    end
  end

  def alerts_data
    user.alerts.not_deleted.map do |alert|
      {
        id: alert.id,
        name: alert.name,
        metric_id: alert.metric_id,
        threshold: alert.threshold,
        direction: alert.direction,
        delay: alert.delay,
        message: alert.message,
        namespace: alert.namespace,
        created_at: alert.created_at.iso8601
      }
    end
  end

  def reports_data
    user.reports.not_deleted.map do |report|
      {
        id: report.id,
        name: report.name,
        interval_type: report.interval_type,
        interval_config: report.interval_config,
        time_of_day: report.time_of_day&.iso8601,
        last_sent_at: report.last_sent_at&.iso8601,
        namespace: report.namespace,
        created_at: report.created_at.iso8601
      }
    end
  end

  def dashboards_data
    user.dashboards.not_deleted.map do |dashboard|
      {
        id: dashboard.id,
        name: dashboard.name,
        namespace: dashboard.namespace,
        created_at: dashboard.created_at.iso8601
      }
    end
  end
end
