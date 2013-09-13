module RedisUtil
  
  # Test helpers for working with redis in tests
  module TestHelper
    
    # flushes all redis connections that are configured for
    # this environment in redis.yml
    def redis_util_truncate_redis
      RedisUtil::Factory.configuration.keys.each do |k|
        RedisUtil::Factory.connect(k).flushdb()
      end
    end
    
    def redis_util_dump_redis
      result = {}
      RedisUtil::Factory.configuration.keys.each do |k|
        redis = RedisUtil::Factory.connect(k)
        result[k] = {}
        redis.keys("*").each do |key|
          type = redis.type(key)
          result[k]["#{key} (#{type})"] = case type
            when 'string' then redis.get(key)
            when 'list' then redis.lrange(key, 0, -1)
            when 'zset' then redis.zrange(key, 0, -1, :with_scores => true)
            when 'set' then redis.smembers(key)
            when 'hash' then redis.hgetall(key)
            else type
          end
        end
      end
      return result
    end
    
    
  end

end
