# frozen_string_literal: true

module OkfPaths
  module_function

  def basename(doc_path)
    File.basename(doc_path.to_s)
  end

  def md(doc_path)
    base = doc_path.to_s
    "#{base}/#{basename(base)}.md"
  end

  def schema(doc_path)
    base = doc_path.to_s
    "#{base}/#{basename(base)}.schema.yaml"
  end

  def csv(doc_path)
    base = doc_path.to_s
    "#{base}/#{basename(base)}.csv"
  end
end
