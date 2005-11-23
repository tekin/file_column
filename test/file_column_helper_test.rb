require 'abstract_unit'
require 'fixtures/entry'

class UrlForFileColumnTest < Test::Unit::TestCase
  include FileColumnHelper

  def setup
    Entry.file_column :image
    @request = RequestMock.new
  end

  def test_url_for_file_column_with_temp_entry
    @e = Entry.new(:image => upload("skanthak.png"))
    url = url_for_file_column("e", "image")
    assert_match %r{^/entry/image/tmp/\d+(\.\d+)+/skanthak.png$}, url
  end

  def test_url_for_file_column_with_saved_entry
    @e = Entry.new(:image => upload("skanthak.png"))
    assert @e.save

    url = url_for_file_column("e", "image")
    assert_equal "/entry/image/#{@e.id}/skanthak.png", url
  end

  def test_url_for_file_column_works_with_symbol
    @e = Entry.new(:image => upload("skanthak.png"))
    assert @e.save

    url = url_for_file_column(:e, :image)
    assert_equal "/entry/image/#{@e.id}/skanthak.png", url
  end
  
  def test_url_for_file_column_works_with_object
    e = Entry.new(:image => upload("skanthak.png"))
    assert e.save

    url = url_for_file_column(e, "image")
    assert_equal "/entry/image/#{e.id}/skanthak.png", url
  end

  def test_url_for_file_column_should_return_nil_on_no_uploaded_file
    e = Entry.new
    assert_nil url_for_file_column(e, "image")
  end
end

