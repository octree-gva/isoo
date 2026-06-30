# frozen_string_literal: true

require 'yaml'
require 'json'

class SchemaLoader
  def initialize(store, schema_json_path)
    @store = store
    @schema = JSON.parse(File.read(schema_json_path))
  end

  def load(relative)
    data = YAML.safe_load(@store.read(relative))
    validate!(data)
    data
  end

  private

  def validate!(data)
    kind = data['kind']
    raise ArgumentError, 'missing kind' unless kind

    case kind
    when 'text'
      raise ArgumentError, 'text requires sections' unless data['sections'].is_a?(Array)
    when 'table'
      %w[primary_key columns _internal].each do |k|
        raise ArgumentError, "table requires #{k}" unless data[k]
      end
    when 'form'
      response_kind = data['response_kind']
      raise ArgumentError, 'form requires response_kind' unless response_kind

      case response_kind
      when 'text'
        raise ArgumentError, 'form text requires sections' unless data['sections'].is_a?(Array)
      when 'table'
        %w[primary_key columns _internal].each do |k|
          raise ArgumentError, "form table requires #{k}" unless data[k]
        end
      else
        raise ArgumentError, "unknown response_kind: #{response_kind}"
      end
    end
  end
end
