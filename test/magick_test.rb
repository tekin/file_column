require File.dirname(__FILE__) + '/abstract_unit'
require 'RMagick'
require File.dirname(__FILE__) + '/fixtures/entry'


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

  def test_imagemagick_still_usable
    e = Entry.new
    assert_nothing_raised {
      img = e.load_image_with_rmagick(file_path("skanthak.png"))
      assert img.kind_of?(Magick::Image)
    }
  end
end

class RMagickVersionsTest < AbstractRMagickTest
  def setup
    Entry.file_column :image, :magick => {:geometry => "200x200",
      :versions => {
        :thumb => "50x50",
        :medium => {:geometry => "100x100", :name => "100_100"},
        :large => {:geometry => "150x150", :lazy => true}
      }
    }
  end


  def test_should_create_thumb
    e = Entry.new("image" => upload("skanthak.png"))
    
    assert File.exists?(e.image("thumb")), "thumb-nail not created"
    
    assert_max_image_size read_image(e.image("thumb")), 50
  end

  def test_version_name_can_be_different_from_key
    e = Entry.new("image" => upload("skanthak.png"))
    
    assert File.exists?(e.image("100_100"))
    assert !File.exists?(e.image("medium"))
  end

  def test_should_not_create_lazy_versions
    e = Entry.new("image" => upload("skanthak.png"))
    assert !File.exists?(e.image("large")), "lazy versions should not be created unless needed"
  end

  def test_should_create_lazy_version_on_demand
    e = Entry.new("image" => upload("skanthak.png"))
    
    e.send(:image_state).create_magick_version_if_needed(:large)
    
    assert File.exists?(e.image("large")), "lazy version should be created on demand"
    
    assert_max_image_size read_image(e.image("large")), 150
  end

  def test_generated_name_should_not_change
    e = Entry.new("image" => upload("skanthak.png"))
    
    name1 = e.send(:image_state).create_magick_version_if_needed("50x50")
    name2 = e.send(:image_state).create_magick_version_if_needed("50x50")
    name3 = e.send(:image_state).create_magick_version_if_needed(:geometry => "50x50")
    assert_equal name1, name2, "hash value has changed"
    assert_equal name1, name3, "hash value has changed"
  end

  def test_should_create_version_with_string
    e = Entry.new("image" => upload("skanthak.png"))
    
    name = e.send(:image_state).create_magick_version_if_needed("32x32")
    
    assert File.exists?(e.image(name))

    assert_max_image_size read_image(e.image(name)), 32
  end

  def test_should_create_safe_auto_id
    e = Entry.new("image" => upload("skanthak.png"))

    name = e.send(:image_state).create_magick_version_if_needed("32x32")

    assert_match /^[a-zA-Z0-9]+$/, name
  end
end

class RMagickCroppingTest < AbstractRMagickTest
  def setup
    Entry.file_column :image, :magick => {:geometry => "200x200",
      :versions => {
        :thumb => {:crop => "1:1", :geometry => "50x50"}
      }
    }
  end
  
  def test_should_crop_image_on_upload
    e = Entry.new("image" => upload("skanthak.png"))
    
    img = read_image(e.image("thumb"))
    
    assert_equal 50, img.rows 
    assert_equal 50, img.columns
  end
    
end

class UrlForImageColumnTest < AbstractRMagickTest
  include FileColumnHelper

  def setup
    Entry.file_column :image, :magick => {
      :versions => {:thumb => "50x50"} 
    }
    @request = RequestMock.new
  end
    
  def test_should_use_version_on_symbol_option
    e = Entry.new(:image => upload("skanthak.png"))
    
    url = url_for_image_column(e, "image", :thumb)
    assert_match %r{^/entry/image/tmp/.+/thumb/skanthak.png$}, url
  end

  def test_should_use_string_as_size
    e = Entry.new(:image => upload("skanthak.png"))

    url = url_for_image_column(e, "image", "50x50")
    
    assert_match %r{^/entry/image/tmp/.+/.+/skanthak.png$}, url
    
    url =~ /\/([^\/]+)\/skanthak.png$/
    dirname = $1
    
    assert_max_image_size read_image(e.image(dirname)), 50
  end

  def test_should_accept_version_hash
    e = Entry.new(:image => upload("skanthak.png"))

    url = url_for_image_column(e, "image", :size => "50x50", :crop => "1:1", :name => "small")

    assert_match %r{^/entry/image/tmp/.+/small/skanthak.png$}, url

    img = read_image(e.image("small"))
    assert_equal 50, img.rows
    assert_equal 50, img.columns
  end
end

class RMagickPermissionsTest < AbstractRMagickTest
  def setup
    Entry.file_column :image, :magick => {:geometry => "200x200",
      :versions => {
        :thumb => {:crop => "1:1", :geometry => "50x50"}
      }
    }, :permissions => 0641
  end
  
  def check_permissions(e)
    assert_equal 0641, (File.stat(e.image).mode & 0777)
    assert_equal 0641, (File.stat(e.image("thumb")).mode & 0777)
  end

  def test_permissions_with_rmagick
    e = Entry.new(:image => upload("skanthak.png"))
    
    check_permissions e

    assert e.save

    check_permissions e
  end
end
