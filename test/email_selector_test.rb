require 'email_selector'

require 'minitest/autorun'
require 'minitest/reporters'

require_relative 'test_helper'

Minitest::Reporters.use!

class EmailSelectorTest < Minitest::Test
  def setup
    @config = 'test/email_conf.txt'
    @map = 'test/email_map.txt'
    @store = {}
    @selector = EmailSelector::Selector.new(config: @config, map: @map,
                                            store: @store)
  end

  def test_that_it_has_a_version_number
    refute_nil ::EmailSelector::VERSION
  end

  def test_config
    expected_domains = %w[
      @university.ac.uk
      @exchange.univ.ac.uk
      @exchange.university.ac.uk
      university.edu
      @live.univ.ac.uk
      @live.university.ac.uk
      .nhs.uk
    ]
    assert_equal expected_domains, @selector.config[:domain]
    assert_equal 2, @selector.config[:sub].length
  end

  def test_email
    emails = [
      %w[alice.test@domain.org a.test@university.ac.uk atest@univ.ac.uk
         a.test@university.edu alice.test@gmail.com],
      %w[bob.test@domain.org b.test@university.ac.uk btest@univ.ac.uk
         bob.test@gmail.com],
      %w[cath.test@domain.org c.test@university.edu ctest@univ.ac.uk
         cath.test@gmail.com],
      %w[dave.test@domain.org dtest@otheruniv.ac.uk dtest@univ.ac.uk
         dave.test@gmail.com],
      %w[ellen.test@domain.org etest@otheruniv.ac.uk e.test@university.edu
         e.test@gmail.com],
      %w[frank.test@domain.org ftest@univ.ac.uk frank.test@gmail.com],
      %w[gill.test@domain.org gill.test@gmail.com]
    ]
    assert_email('a.test@university.ac.uk', emails[0])
    assert_email('b.test@university.ac.uk', emails[1])
    assert_email('c.test@university.edu', emails[2])
    assert_email('dtest@university.ac.uk',  emails[3])
    assert_email('e.test@university.edu', emails[4])
    assert_email('ftest@university.ac.uk', emails[5])
    assert_email('gill.test@domain.org', emails[6])
  end

  private

  def assert_email(expected, emails)
    # Check that the expected email is selected from the set
    assert_equal(expected, @selector.email(emails))
    # Check that each email in the set individually gives the expected email
    # (using the map to resolve non-domain addresses)
    emails.each { |email| assert_equal(expected, @selector.email([email])) }
  end
end