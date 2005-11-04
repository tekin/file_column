require 'abstract_unit'
require_gem 'rmagick'

class Entry < ActiveRecord::Base
end

class AbstractRMagickTest < Test::Unit::TestCase
  def teardown
    FileUtils.rm_rf File.dirname(__FILE__)+"/public/entry/"
  end

  def test_truth
    assert true
  end

  private

  def read_image(path)
    Magick::Image::read(path).first
  end

  def assert_max_image_size(img, s)
    assert img.columns <= s, "img has #{img.columns} columns, expected: #{s}"
    assert img.rows <= s, "img has #{img.rows} rows, expected: #{s}"
    assert_equal s, [img.columns, img.rows].max
  end
end

class RMagickSimpleTest < AbstractRMagickTest
  def setup
    Entry.file_column :image, :magick => { :geometry => "100x100" }
  end

  def test_simple_resize_without_save
    e = Entry.new
    e.image = upload("kerb.jpg")
    
    img = read_image(e.image)
    assert_max_image_size img, 100
  end

  def test_simple_resize_with_save
    e = Entry.new
    e.image = upload("kerb.jpg")
    assert e.save
    e.reload
    
    img = read_image(e.image)
    assert_max_image_size img, 100
  end

  def test_resize_on_saved_image
    Entry.file_column :image, :magick => { :geometry => "100x100" }
    
    e = Entry.new
    e.image = upload("skanthak.png")
    assert e.save
    e.reload
    old_path = e.image
    
    e.image = upload("kerb.jpg")
    assert e.save
    assert "kerb.jpg", File.basename(e.image)
    assert !File.exists?(old_path), "old image '#{old_path}' still exists"

    img = read_image(e.image)
    assert_max_image_size img, 100
  end

  def test_invalid_image
    e = Entry.new
    assert_nothing_raised { e.image = upload("invalid-image.jpg") }
    assert !e.valid?
  end

  def test_serializable
    e = Entry.new
    e.image = upload("skanthak.png")
    assert_nothing_raised {
      flash = Marshal.dump(e)
      e = Marshal.load(flash)
    }
    assert File.exists?(e.image)
  end
end

class RMagickAlternativesTest < AbstractRMagickTest
  def setup
    Entry.file_column :image, :magick => {:geometry => "200x200",
      :versions => {
        "thumb" => "50x50", 
        "medium" => {:geometry => "100x100"}
      }
    }
  end

  def test_thumb_created
    e = Entry.new("image" => upload("kerb.jpg"))
    
    thumb_path = File.join(File.dirname(e.image), "kerb-thumb.jpg")
    assert_equal thumb_path, e.image("thumb")
    assert File.exists?(e.image("thumb")), "thumb-nail not created"
    
    assert_max_image_size read_image(e.image("thumb")), 50
  end
end
