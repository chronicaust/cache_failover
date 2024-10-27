# Cache Failover Gem

## Installation

`Gemfile`

```ruby
  gem 'cache_failover'
```

You will need at least 2 cache stores for failover capability.

```ruby
  gem 'solid_cache' #  optional, but you will need at least 2 cache stores
  gem 'redis' # optional, but you will need at least 2 cache stores
  gem 'hiredis' # optional, only for redis
  gem 'dalli' # optional, but you will need at least 2 cache stores (WIP)
  gem 'cache_failover'
```

## Configuration

Configure your cache_store normally, but use `CacheFailover::Store` with one argument, an array of hashes with the keys `store` and `options` in the order you would like to failover. Example is shown below:

```ruby
config.cache_store = CacheFailover::Store.new(
  [
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
- Dalli/Memcached support
- Memory Cache Support
- File Cache support
- More options
- Tests