require_relative '../../test_helper.rb'

module RedisUtil
  class FactoryTest < MiniTest::Should::TestCase

    setup do
      @config = "config/redis.yml"
      RedisUtil::Factory.config_file = @config
      RedisUtil::Factory.env = "test"
      RedisUtil::Factory.clients = nil
      RedisUtil::Factory.configuration = nil
      @config_file_data = <<-EOF
        test:
            resque:
              db: 1
              host: localhost
              port: 6379
              thread_safe: true
            cache:
              db: 2
              host: localhost
              port: 6379
              thread_safe: true
            namespaced:
              db: 3
              host: localhost
              port: 6379
              thread_safe: true
              namespace: foobar
        development:
            resque:
              host: bar
      EOF
      IO.stubs(:read).with(@config).returns(@config_file_data)
    end

    context "#configuration" do

      should "read in redis yml" do
        config = RedisUtil::Factory.configuration
        assert_equal [:resque, :cache, :namespaced], config.keys
        assert_equal({:db=>1, :host=>"localhost", :port=>6379, :thread_safe=>true}, config[:resque])
      end

      should "read in redis yml for different env" do
        RedisUtil::Factory.env = "development"
        assert_equal({:resque => {:host=>"bar"}}, RedisUtil::Factory.configuration)
      end

      should "use defaults with Rails" do
        begin
          RedisUtil::Factory.config_file = nil
          RedisUtil::Factory.env = nil
          Object.const_set(:Rails, Class.new)
          ::Rails.stubs(:env).returns "development"
          ::Rails.stubs(:root).returns "/root"
          IO.stubs(:read).with("/root/config/redis.yml").returns(@config_file_data)
          RedisUtil::Factory.configuration
          assert_equal "development", RedisUtil::Factory.env
          assert_equal "/root/config/redis.yml", RedisUtil::Factory.config_file
        ensure
          Object.send(:remove_const, "Rails")
        end
      end
    end

    context "#connect" do

      should "return client for symbol" do
        assert_equal 1, RedisUtil::Factory.connect(:resque).client.db
        assert_equal 2, RedisUtil::Factory.connect(:cache).client.db
      end

      should "reuse client for same symbol" do
        assert_equal RedisUtil::Factory.connect(:resque).object_id, RedisUtil::Factory.connect(:resque).object_id
      end

      should "return a standard client if namespace is not present" do
        client = RedisUtil::Factory.connect(:cache)
        assert client.instance_of?(Redis)
      end

      should "return a namespaced client if namespace is present" do
        client = RedisUtil::Factory.connect(:namespaced)
        assert client.instance_of?(Redis::Namespace)
        assert_equal client.namespace, :foobar
      end

    end

    context "#disconnect" do

      should "disconnect specific client" do
        resque_client = RedisUtil::Factory.connect(:resque)
        cache_client = RedisUtil::Factory.connect(:cache)

        resque_client.expects(:quit)
        cache_client.expects(:quit).never
        RedisUtil::Factory.disconnect(:resque)
      end

      should "disconnect all clients" do
        resque_client = RedisUtil::Factory.connect(:resque)
        cache_client = RedisUtil::Factory.connect(:cache)

        resque_client.expects(:quit)
        cache_client.expects(:quit)
        RedisUtil::Factory.disconnect
      end

    end

    context "#reconnect" do

      should "reconnect specific client" do
        resque_client = RedisUtil::Factory.connect(:resque)
        cache_client = RedisUtil::Factory.connect(:cache)

        resque_client.expects(:client).returns(mock('redis', :reconnect => nil))
        cache_client.expects(:client).never
        RedisUtil::Factory.reconnect(:resque)
      end

      should "reconnect all clients" do
        resque_client = RedisUtil::Factory.connect(:resque)
        cache_client = RedisUtil::Factory.connect(:cache)

        resque_client.expects(:client).returns(mock('redis', :reconnect => nil))
        cache_client.expects(:client).returns(mock('redis', :reconnect => nil))
        RedisUtil::Factory.reconnect
      end

      should "be able to connect succesfully when it fails to connect the first time" do
        mock_client = mock('redis')
        mock_client.expects(:reconnect).twice.raises(StandardError).then.returns(nil)
        resque_client = RedisUtil::Factory.connect(:resque)

        resque_client.stubs(:client).returns(mock_client)

        # Stub sleep so we don't wait forever
        RedisUtil::Factory.stubs(:sleep)

        RedisUtil::Factory.reconnect
      end

      should "retry on failure" do
        mock_client = mock('redis')
        mock_client.expects(:reconnect).at_least(3).raises(StandardError)
        resque_client = RedisUtil::Factory.connect(:resque)

        resque_client.stubs(:client).returns(mock_client)

        # Stub sleep so we don't wait forever
        RedisUtil::Factory.stubs(:sleep)

        RedisUtil::Factory.reconnect
      end
    end

  end
end
