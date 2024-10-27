# frozen_string_literal: true
module CacheFailover
  class Store < ::ActiveSupport::Cache::Store
    MARK_BR_COMPRESSED = "\x02".b

    class BrotliCompressor
      def self.deflate(payload)
        ::Brotli.deflate(payload, quality: 1)
      end

      def self.inflate(payload)
        ::Brotli.inflate(payload)
      end
    end

    DEFAULT_OPTIONS = {
      timeout: 5,
      compress: true,
      cache_db: 'cache'
    }

    attr_reader :core_store

    def initialize(cache_stores)
      _core_store = cache_stores.find do |cs|
        options(cs[:options])
        Logger.new("log/#{CONFIG[:RAILS_ENV]}.log").info("CacheFailover: caching_up?: #{cs[:store].class.name}")
        Logger.new("log/#{CONFIG[:RAILS_ENV]}.log").info("CacheFailover: caching_up?: #{options}")
        Logger.new("log/#{CONFIG[:RAILS_ENV]}.log").info("#{caching_up?(cs[:store], options)}")
        caching_up?(cs[:store], options)
      end
      @core_store = _core_store[:store]
    end

    def options(init_options = {})
      return @init_options if defined?(@init_options) && init_options.blank?
      @init_options = init_options.reverse_merge(DEFAULT_OPTIONS)
    end

    def fetch(name, init_options = nil, &block)
      options(init_options)

      if !block_given? && options[:force]
        raise ArgumentError, "Missing block: Calling `Cache#fetch` with `force: true` requires a block."
      end

      get_value(
        @core_store.fetch(expanded_cache_key(name), options.merge(compress: false)) do
          if block_given?
            store_value(block.call, options)
          else
            nil
          end
        end,
        options
      )
    end

    def write(name, value, init_options = nil)
      options(init_options)

      payload = store_value(value, options)

      @core_store.write(
        expanded_cache_key(name),
        payload,
        options.merge(compress: false)
      )
    end

    def read(name, init_options = nil)
      options(init_options)

      payload = @core_store.read(
        expanded_cache_key(name),
        options
      )

      get_value(payload, options)
    end

    def write_multi(hash, init_options = nil)
      options(init_options)

      new_hash = hash.map do |key, val|
        [
          expanded_cache_key(key),
          store_value(val, options),
        ]
      end

      @core_store.write_multi(
        new_hash,
        options.merge(compress: false)
      )
    end

    def read_multi(*names)
      options = names.extract_options!
      names = names.map { |name| expanded_cache_key(name) }
      options(options)

      core_store.read_multi(*names, options).map do |key, val|
        [key, get_value(val, options)]
      end.to_h
    end

    def fetch_multi(*names)
      options = names.extract_options!
      expanded_names = names.map { |name| expanded_cache_key(name) }
      options(options)

      reads = core_store.send(:read_multi_entries, expanded_names, **options)
      reads.map do |key, val|
        [key, store_value(val, options)]
      end.to_h

      writes = {}
      ordered = names.index_with do |name|
        reads.fetch(name) { writes[name] = yield(name) }
      end

      write_multi(writes)
      ordered
    end

    def exist?(name, init_options = {})
      @core_store.exist?(expanded_cache_key(name), init_options)
    end

    def delete(name, init_options = {})
      @core_store.delete(expanded_cache_key(name), init_options)
    end

    def clear(init_options = {})
      @core_store.clear(**init_options)
    end

    def increment(name, amount = 1, **init_options)
      @core_store.increment(expanded_cache_key(name), amount, **init_options)
    end

    def decrement(name, amount = 1, **init_options)
      @core_store.decrement(expanded_cache_key(name), amount, **init_options)
    end

    def self.supports_cache_versioning?
      true
    end

    REDIS ||=

      private

    def redis_cnxn(init_options)
      @redis_cache_client ||=
        RedisClient.config(
          url: CONFIG[:REDIS_URL],
          password: CONFIG[:REDIS_PASSWORD],
          driver: init_options[:adapter] || :hiredis,
          timeout: init_options[:timeout] || 1,
          inherit_socket: true,
          ).new_pool
    end

    def cache_db_cnxn(init_options)
      @db_cache_client ||=
        ActiveRecord::Base.
          establish_connection(
            Rails.configuration.database_configuration[Rails.env.to_s][init_options[:cache_db]]
          )
    end

    def caching_up?(store, init_options)
      begin
        Timeout.timeout((init_options[:timeout] || 1)) do
          case store.class.name
          when 'ActiveSupport::Cache::RedisCacheStore'
            (redis_cnxn(init_options).call('ping') == 'PONG' rescue false)
          when 'ActiveSupport::Cache::MemCacheStore'
          when 'SolidCache::Store'
            cache_db_cnxn(init_options).with_connection { ActiveRecord::Base.connection.select_value('SELECT 1=1') == 1 }
          when 'ActiveSupport::Cache::MemoryStore'
          when 'ActiveSupport::Cache::FileStore'
          when 'ActiveSupport::Cache::NullStore'
          end
        end
      rescue => ex
        false
      end
    end

    def serialized(value)
      mpval = (value.try(:to_msgpack) rescue nil)
      msval = (Marshal.dump(value) rescue nil)
      if mpval.present? && mpval.bytesize < msval.bytesize
        mpval
      else
        msval
      end
    end

    def unserialized(payload)
      begin
        MessagePack.unpack(payload)
      rescue => ex
        Marshal.load(payload)
      end
    end

    def compressed(value)
      begin
        BrotliCompressor.deflate(value)
      rescue Brotli::Error => ex
        Rails.logger.info("CacheFailover Error: BrotliCompressor.deflate: #{ex.message}")
        value
      end
    end

    def uncompressed(payload)
      begin
        BrotliCompressor.inflate(payload.byteslice(1..-1))
      rescue Brotli::Error => ex
        Rails.logger.info("CacheFailover Error: BrotliCompressor.inflate: #{ex.message}")
        payload
      end
    end

    def store_value(value, init_options)
      return value if value.is_a?(Integer)
      value = serialized(value)
      if init_options.blank? || init_options[:compress].blank? || !options[:compress] == false
        value = compressed(value)
        MARK_BR_COMPRESSED + value
      else
        value
      end
    end

    def get_value(payload, init_options)
      return nil unless payload.present?
      return payload if payload.is_a?(Integer)
      payload =
        if payload.start_with?(MARK_BR_COMPRESSED)
          uncompressed(payload)
        else
          payload
        end
      payload = unserialized(payload)
      payload
    end

    def expanded_cache_key(name)
      "#{::ActiveSupport::Cache.expand_cache_key(name)}"
    end

  end
end

