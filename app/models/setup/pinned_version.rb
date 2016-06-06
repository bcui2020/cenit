module Setup
  class PinnedVersion
    include CenitScoped

    build_in_data_type

    class_attribute :models

    field :record_model, type: String

    self.models = {}

    Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |r|
      if (klass = r.klass).include?(Trackable)
        models[klass] =
          {
            model_name: r.name.to_s.singularize.capitalize.gsub('_', ' '),
            property: property = r.name.to_s.singularize.to_sym
          }
        belongs_to property, class_name: klass.to_s, inverse_of: nil
      end
    end

    field :version, type: Integer

    before_save do
      errors.add(:record_model, "can't be blank") unless record_model.present?
      errors.add(:version, "can't be blank") unless version.present?
      if errors.blank?
        record_property = nil
        record = nil
        self.class.models.values.each do |m_data|
          record_property = m_data[:property] if m_data[:model_name] == record_model
          if (value = send(record_property))
            if m_data[:model_name] == record_model
              record = value
            else
              send("#{m_data[:property]}=", nil)
            end
          end
        end
        errors.add(record_property, "can't be blank") unless record
      end
      errors.blank?
    end

    def record_model_enum
      self.class.models.values.collect { |m_data| m_data[:model_name] }
    end

    def model
      self.class.models.keys.detect { |m| self.class.models[m][:model_name] == record_model }
    end

    def record
      relations.keys.each do |r|
        if (value = send(r))
          return value
        end
      end
      nil
    end

    def version_enum
      (record && record.version && (1..record.version).to_a.reverse) || []
    end

    def ready_to_save?
      record.present?
    end

    def can_be_restarted?
      ready_to_save?
    end

    def to_s
      "#{record_model} #{record.try(:custom_title) || record.to_s} v#{version}"
    end

    class << self

      def for(object)
        if (m_data = models[object.class])
          where("#{m_data[:property]}_id" => object.id).first
        else
          nil
        end
      end
    end
  end
end