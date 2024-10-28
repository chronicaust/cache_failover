# Cache Failover

## Installation

This Gem allows you to configure multiple cache stores in a failover configuration. If the first cache store fails, this gem will attempt to use the next cache store in the list. If the first cache store comes back online, it will revert to using that store.

This gem also uses MessagePack when possible to store Hash/JSON objects rather than Marshal to store objects more efficiently before compressing them using Brotli compression (which is also more efficient than gzip). 

This is useful for high availability and redundancy, such as using a Redis Cache with SolidCache (DB) as a backup in case Redis goes down.

Keep in mind, if you use your cache as a session store, users will be logged out.

`Gemfile`

```ruby
  gem 'cache_failover'
```

You will need at least 2 cache stores for failover capability.

```ruby
  gem 'solid_cache' #  optional, but you will need at least 2 cache stores
  gem 'redis' # optional, but you will need at least 2 cache stores
  gem 'hiredis' # optional, only for redis
  gem 'dalli' # optional, but you will need at least 2 cache stores
  gem 'cache_failover'
```

## Configuration

Configure your cache_store normally, but use `CacheFailover::Store` with one argument, an array of hashes with the keys `store` and `options` in the order you would like to failover. Example is shown below:

```ruby
config.cache_store = CacheFailover::Store.new(
  [
    {
      store: ActiveSupport::Cache::MemCacheStore.new(
        CONFIG[:MEMCACHED_SERVERS]
      ),
      options: {}
    },
    {
      store: ActiveSupport::Cache::RedisCacheStore.new(
        url: CONFIG[:REDIS_URL],
        password: CONFIG[:REDIS_PASSWORD],
      ),
      options: {}
    },
    {
      store: SolidCache::Store.new(),
      options: {
        expiry_method: :job
      }
    }
  ]
)
```

## WIP
- Memory Cache Support
- File Cache support
- Sync cache stores
- Add option to not use cache stores after failure unless the application is rebooted.
- More options
- Tests
