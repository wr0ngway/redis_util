# RedisUtil

An aggregation of redis utility code, including:

* A factory which allows you to define redis connections in a config file, and keeps track of them for reconnecting in forks
* Test helpers

## Installation

Add this line to your application's Gemfile:

    gem 'redis_util'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis_util

Then setup a config file in config/redis.yml that could look like:

    common: &common
      host: localhost
      port: 6379
      thread_safe: true
    
    development:
      resque:
        <<: *common
        db: 0
      redis_objects:
        <<: *common
        db: 1
    
    test:
      resque:
        <<: *common
        db: 10
      redis_objects:
        <<: *common
        db: 11

If not running in rails, an additional step is needed to set the config_file and env:

    RedisUtil::Factory.config_file = "#{root}/config/redis.yml"
    RedisUtil::Factory.env = "development"
  
## Usage

    redis = RedisUtil::Factory.connect(:foo)
    redis.keys('*')
