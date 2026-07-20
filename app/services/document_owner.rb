# frozen_string_literal: true

require_relative '../i18n'

module DocumentOwner # rubocop:disable Metrics/ModuleLength
  KEYS = %w[owner_name owner_email].freeze
  EMAIL_PATTERN = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  module_function

  def owner_name_key
    'owner_name'
  end

  def owner_email_key
    'owner_email'
  end

  def owner_key?(key)
    KEYS.include?(key.to_s)
  end

  def extract_params(params)
    {
      owner_name_key => params[owner_name_key].to_s.strip,
      owner_email_key => params[owner_email_key].to_s.strip
    }
  end

  def from_fields(fields)
    fields ||= {}
    {
      owner_name_key => fields[owner_name_key].to_s.strip,
      owner_email_key => fields[owner_email_key].to_s.strip
    }
  end

  def from_rows(rows)
    row = Array(rows).find { |r| r[owner_name_key].to_s.strip != '' } || Array(rows).first
    return empty_owner unless row

    {
      owner_name_key => row[owner_name_key].to_s.strip,
      owner_email_key => row[owner_email_key].to_s.strip
    }
  end

  def empty_owner
    { owner_name_key => '', owner_email_key => '' }
  end

  def validate!(owner)
    name = owner[owner_name_key].to_s.strip
    email = owner[owner_email_key].to_s.strip
    raise ArgumentError, IsooI18n.t('owner.name_required') if name.empty?
    raise ArgumentError, IsooI18n.t('owner.email_required') if email.empty?
    return if email.match?(EMAIL_PATTERN)

    raise ArgumentError, IsooI18n.t('owner.email_invalid')
  end

  def validate_text_fields!(fields, schema: nil)
    return unless schema && needs_owner_sections?(schema) && schema_has_owner?(schema)

    validate!(from_fields(fields))
  end

  def validate_table_owner!(owner, schema: nil)
    return unless schema && needs_owner_columns?(schema) && schema_has_owner?(schema)

    validate!(owner)
  end

  def propagate_to_rows(rows, owner)
    name = owner[owner_name_key].to_s
    email = owner[owner_email_key].to_s
    Array(rows).map do |row|
      row.merge(owner_name_key => name, owner_email_key => email)
    end
  end

  def data_columns(schema)
    Array(schema&.fetch('columns', nil)).reject { |col| owner_key?(col['key']) }
  end

  def owner_column_definitions
    [
      { 'key' => owner_name_key, 'label' => 'Document owner', 'type' => 'text', 'required' => true },
      { 'key' => owner_email_key, 'label' => 'Owner email', 'type' => 'email', 'required' => true }
    ]
  end

  def owner_section_definitions
    [
      {
        'level' => 'h2',
        'key' => owner_name_key,
        'label' => 'Document owner',
        'role' => 'body',
        'editable' => true,
        'field_type' => 'text',
        'required' => true
      },
      {
        'level' => 'h2',
        'key' => owner_email_key,
        'label' => 'Owner email',
        'role' => 'body',
        'editable' => true,
        'field_type' => 'email',
        'required' => true
      }
    ]
  end

  def export_line(owner)
    name = owner[owner_name_key].to_s.strip
    email = owner[owner_email_key].to_s.strip
    return '' if name.empty?

    IsooI18n.t('owner.export_footer', name: name, email: email)
  end

  def text_document?(schema)
    schema&.fetch('kind', nil) == 'text'
  end

  def table_document?(schema)
    schema&.fetch('kind', nil) == 'table'
  end

  def form_text?(schema)
    schema&.fetch('kind', nil) == 'form' && schema&.fetch('response_kind', nil) == 'text'
  end

  def form_table?(schema)
    schema&.fetch('kind', nil) == 'form' && schema&.fetch('response_kind', nil) == 'table'
  end

  def needs_owner_sections?(schema)
    text_document?(schema) || form_text?(schema)
  end

  def needs_owner_columns?(schema)
    table_document?(schema) || form_table?(schema)
  end

  def schema_has_owner?(schema)
    if needs_owner_sections?(schema)
      keys = Array(schema['sections']).map { |sec| sec['key'].to_s }
      return keys.include?(owner_name_key) && keys.include?(owner_email_key)
    end
    if needs_owner_columns?(schema)
      keys = Array(schema['columns']).map { |col| col['key'].to_s }
      return keys.include?(owner_name_key) && keys.include?(owner_email_key)
    end

    false
  end
end
