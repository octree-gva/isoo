# frozen_string_literal: true

# Per-document withhold flag. Independent of ISO classification.
# Text/table/annex/answers: iso27001.withheld in markdown front matter.
# Forms (no project .md stamp): withheld on the manifest form entry.
module DocumentWithhold
  PARAM_KEY = 'withheld'
  META_KEY = 'withheld'

  module_function

  def from_meta(meta)
    truthy?(meta.is_a?(Hash) && meta.dig('iso27001', META_KEY))
  end

  def from_params(params)
    truthy?(params[PARAM_KEY] || params[PARAM_KEY.to_sym])
  end

  def write_to_meta!(meta, withheld)
    meta = {} unless meta.is_a?(Hash)
    meta['iso27001'] = meta['iso27001'].is_a?(Hash) ? meta['iso27001'] : {}
    if withheld
      meta['iso27001'][META_KEY] = true
    else
      meta['iso27001'].delete(META_KEY)
    end
    meta
  end

  def document_withheld?(doc, store:, manifest: nil)
    return false unless doc

    return truthy?(doc[META_KEY]) if form_entry?(doc)

    path = doc['path'].to_s
    return false if path.empty?

    return true if path.include?('/responses/') && form_withheld?(doc, store: store, manifest: manifest)

    md = OkfPaths.md(path)
    return false unless store.exist?(md)

    meta, = FrontMatter.parse(store.read(md))
    from_meta(meta)
  rescue StandardError
    false
  end

  def form_withheld?(doc, store:, manifest:)
    form_id = doc['form_id']
    return false unless form_id && manifest

    form = manifest.find_form(form_id)
    return false unless form

    document_withheld?(form, store: store, manifest: nil)
  end

  def set_form_withheld!(manifest, form_id, withheld:)
    form = manifest.find_form(form_id)
    raise ArgumentError, "unknown form: #{form_id}" unless form

    if withheld
      form[META_KEY] = true
    else
      form.delete(META_KEY)
    end
    manifest.save!
  end

  def form_entry?(doc)
    doc.is_a?(Hash) && doc.key?('responses') && !doc['path'].to_s.include?('/responses/')
  end

  def truthy?(value)
    case value
    when true then true
    when false, nil then false
    else
      %w[1 true on yes].include?(value.to_s.strip.downcase)
    end
  end
end
