# frozen_string_literal: true

require_relative 'storage_backend'

class LocalStorageBackend
  def initialize(data_path: DataLayout::DATA_PATH)
    @data_path = File.expand_path(data_path)
  end

  def name
    'local'
  end

  # rubocop:disable Naming/PredicateMethod -- bang API returns success boolean for callers/specs
  def check!
    StorageBackend.ensure_writable_data_path!(@data_path)
    true
  end

  def flush!(_message = nil)
    true
  end
  # rubocop:enable Naming/PredicateMethod

  alias commit flush!

  def pull!
    { status: :ok }
  end
end
