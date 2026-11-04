module RoutineMcp
  # JSON shapes for each item type. `summary` is for lists; `detail` adds
  # linked items and computed values (series, alert status) for one item.
  module Serialize
    module_function

    def summary(record)
      case record
      when Form then form(record)
      when Section then section(record)
      when Question then question(record)
      when Answer then answer(record)
      when Response then response(record)
      when Metric then metric(record)
      when Alert then alert(record)
      when Report then report(record)
      when Remember then remember(record)
      else raise ArgumentError, "Can't serialize #{record.class}"
      end
    end

    def detail(record)
      case record
      when Form
        form(record).merge(
          sections: record.sections.not_deleted.map { |s| section(s).merge(questions: s.questions.not_deleted.map { |q| question(q) }) },
          response_count: record.responses.not_deleted.count
        )
      when Section
        section(record).merge(
          questions: record.questions.not_deleted.map { |q| question(q) },
          forms: record.forms.not_deleted.map { |f| ref(f) }
        )
      when Question
        last = record.answers.not_deleted.order(created_at: :desc).first
        question(record).merge(
          sections: record.sections.not_deleted.map { |s| ref(s) },
          metrics: record.metrics.not_deleted.map { |m| ref(m) },
          answer_count: record.answers.not_deleted.count,
          last_answer: last && answer(last)
        )
      when Response
        response(record).merge(answers: record.answers.not_deleted.includes(:question).map { |a| answer(a) })
      when Metric
        series = record.series
        metric(record).merge(
          questions: record.questions.map { |q| ref(q) },
          child_metrics: record.child_metrics.map { |m| ref(m) },
          point_count: series.length,
          latest_point: series.last && point(series.last)
        )
      when Alert
        status, current_value = record.disabled? ? [ false, nil ] : record.calculate_status_uncached
        alert(record).merge(
          metric: ref(record.metric),
          status: record.disabled? ? "disabled" : (status ? "activated" : "deactivated"),
          current_value: number(current_value),
          activation_progress: record.disabled? ? nil : record.activation_progress
        )
      when Report
        remembers = record.remember_namespace.nil? ? [] : Remember.visible_today_recursive(record.user, record.remember_namespace)
        report(record).merge(
          next_send_time: time(record.next_send_time),
          alerts: record.alerts.map { |a| alert(a).merge(activated: a.activated?) },
          metrics: record.metrics.map { |m| metric(m) },
          visible_remembers: remembers.map { |r| remember(r) }
        )
      else
        summary(record)
      end
    end

    def ref(record)
      return nil unless record

      { id: record.id, name: record.respond_to?(:display_name) ? record.display_name : record.name, namespace: record.namespace }
    end

    def form(f)
      { type: "form", id: f.id, name: f.name, namespace: f.namespace, created_at: time(f.created_at) }
    end

    def section(s)
      { type: "section", id: s.id, name: s.name, prompt: s.prompt, namespace: s.namespace }
    end

    def question(q)
      data = { type: "question", id: q.id, name: q.name, question_type: q.question_type, namespace: q.namespace }
      data.merge!(range_min: number(q.range_min), range_max: number(q.range_max)) if q.question_type == "range"
      data
    end

    def answer(a)
      {
        type: "answer", id: a.id, question_id: a.question_id, question_name: a.question&.name,
        answer_type: a.answer_type, value: a.answer_type == "string" || a.answer_type == "bool" ? a.value : number(a.value),
        response_id: a.response_id, namespace: a.namespace, recorded_at: time(a.created_at)
      }
    end

    def response(r)
      { type: "response", id: r.id, form_id: r.form_id, form_name: r.form&.name, namespace: r.namespace, recorded_at: time(r.created_at) }
    end

    def metric(m)
      {
        type: "metric", id: m.id, name: m.display_name, function: m.function, resolution: m.resolution,
        width: m.width, wrap: m.wrap, fill: m.fill, scale: number(m.scale), first_metric_id: m.first_metric_id,
        namespace: m.namespace, question_ids: m.question_ids, child_metric_ids: m.child_metric_ids
      }
    end

    def alert(a)
      {
        type: "alert", id: a.id, name: a.display_name, metric_id: a.metric_id, threshold: number(a.threshold),
        direction: a.direction, delay: a.delay, message: a.message, disabled: a.disabled, namespace: a.namespace
      }
    end

    def report(r)
      {
        type: "report", id: r.id, name: r.name, namespace: r.namespace,
        time_of_day: r.time_of_day&.strftime("%H:%M"), interval_type: r.interval_type,
        interval_config: r.interval_config, remember_namespace: r.remember_namespace,
        last_sent_at: time(r.last_sent_at),
        alert_ids: r.report_alerts.map(&:alert_id), metric_ids: r.report_metrics.map(&:metric_id)
      }
    end

    def remember(r)
      {
        type: "remember", id: r.id, description: r.description, background: r.background,
        state: r.state, decay: number(r.decay), namespace: r.namespace, visible_today: r.visible_today?
      }
    end

    # A series point is [timestamp, value]
    def point((timestamp, value))
      { at: time(timestamp.is_a?(String) ? Time.zone.parse(timestamp) : timestamp), value: number(value) }
    end

    def time(value)
      value&.in_time_zone&.iso8601
    end

    def number(value)
      return nil if value.nil?

      float = value.to_f
      float == float.round ? float.round : float.round(4)
    end
  end
end
