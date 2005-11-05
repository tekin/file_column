module FileColumn # :nodoc:
  
  class BaseUploadedFile # :nodoc:
    def transform_with_magick
      if needs_resize?
        begin
          img = ::Magick::Image::read(absolute_path).first
        rescue ::Magick::ImageMagickError
          @magick_errors ||= []
          @magick_errors << "invalid image"
          return
        end
          
        if @options[:magick][:versions]
          @options[:magick][:versions].each_pair do |name, version_options|
            resize_image(img, version_options[:geometry], absolute_path(name))
          end
        end
        if @options[:magick][:geometry]
          resize_image(img, @options[:magick][:geometry], absolute_path)
        end
      end
    end
      
    attr_reader :magick_errors
    
    def has_magick_errors?
      @magick_errors and !@magick_errors.empty?
    end

    private
    
    def needs_resize?
      @options[:magick] and just_uploaded? and 
        (@options[:magick][:geometry] or@options[:magick][:versions])
    end

    def resize_image(img, geometry, path)
      new_img = img.change_geometry(geometry) do |c, r, i|
        i.resize(c, r)
      end
      new_img.write path
    end
  end

  # If you are using file_column to upload images, you can
  # directly process the images with RMagick,
  # a ruby extension
  # for accessing the popular imagemagick libraries. You can find
  # more information about RMagick at http://rmagick.rubyforge.org.
  #
  # You can control what to do by adding a <tt>:magick</tt> option
  # to your options hash. All operations are performed immediately
  # after a new file is assigned to the file_column attribute.
  #
  # To resize the uploaded image according to an imagemagick geometry
  # string, just use the <tt>:geometry</tt> option:
  #
  #    file_column :image, :magick => {:geometry => "800x600>"}
  #
  # You can also create additional versions of your image, for example
  # thumb-nails, like this:
  #    file_column :image, :magick => {:versions => 
  #      { "thumb" => "50x50", "medium" => "640x480>" }
  #    }
  #
  # These versions can later be accessed via file_column's <em>suffix</em>
  # mechanism. So if the uploaded image was named "vancouver.jpg", you can
  # access the additional versions like this:
  #
  #    o.image("thumb") # produces ".../vancouver-thumb.jpg"
  #    o.image_relative_path("medium") # produces ".../vancouver-medium.jpg"
  #
  # The same mechanism can be used in the +url_for_file_column+ helper:
  #
  #    <%= url_for_file_column "entry", "image", "thumb" %>
  #
  # <b>Note:</b> You'll need the
  # rmagick extension installed as a gem in order to use file_column's
  # rmagick integration.
  module Magick

    def self.file_column(klass, attr, options) # :nodoc:
      require 'RMagick'
      if options[:magick][:versions]
        options[:magick][:versions].each_pair do |name, value|
          if value.kind_of?(String)
            options[:magick][:versions][name] = {:geometry => value}
          end
        end
      end
      state_method = "#{attr}_state".to_sym
      after_assign_method = "#{attr}_magick_after_assign".to_sym
      
      klass.send(:define_method, after_assign_method) do
        self.send(state_method).transform_with_magick
      end
      
      options[:after_assign] ||= []
      options[:after_assign] << after_assign_method
      
      klass.validate do |record|
        state = record.send(state_method)
        if state.has_magick_errors?
          state.magick_errors.each do |error|
            record.errors.add attr, error
          end
        end
      end
    end
    
  end
end
