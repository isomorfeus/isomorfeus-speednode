require 'test_helper'

class TestIsomorfeusSpeednode < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ISomorfeus::Speednode::VERSION
  end
end
