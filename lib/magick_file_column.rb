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
          
        if options[:magick][:versions]
          options[:magick][:versions].each_pair do |name, version_options|
            next if version_options[:lazy]
            dirname = version_options[:name]
            FileUtils.mkdir File.join(@dir, dirname)
            resize_image(img, version_options[:geometry], absolute_path(dirname))
          end
        end
        if options[:magick][:geometry]
          resize_image(img, options[:magick][:geometry], absolute_path)
        end
      end
    end

    def create_magick_version_if_needed(version)
      case version
      when Symbol
        version_options = options[:magick][:versions][version]
      when String
        version_options = {:geometry => version}
      else
        version_options = version
      end
      version_options[:name] = version_options.hash.abs.to_s(36) unless version_options[:name]

      unless File.exists?(absolute_path(version_options[:name]))
        img = ::Magick::Image::read(absolute_path).first
        dirname = version_options[:name]
        FileUtils.mkdir File.join(@dir, dirname)
        resize_image(img, version_options[:geometry], absolute_path(dirname))
      end

      version_options[:name]
    end

    attr_reader :magick_errors
    
    def has_magick_errors?
      @magick_errors and !@magick_errors.empty?
    end

    private
    
    def needs_resize?
      options[:magick] and just_uploaded? and 
        (options[:magick][:geometry] or options[:magick][:versions])
    end

    def resize_image(img, geometry, dest_path)
      new_img = img.change_geometry(geometry) do |c, r, i|
        i.resize(c, r)
      end
      new_img.write dest_path
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
  #      { :thumb => "50x50", :medium => "640x480>" }
  #    }
  #
  # These versions will be stored in separate sub-directories and cann
  # be accessed via FileColumnHelper's +url_for_file_column+ method
  # like this:
  #
  #    <%= url_for_file_column "entry", "image", :thumb %>
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
            value = {:geometry => value}
          end
          value[:name] = value.hash.abs.to_s(36) unless value[:name]
          options[:magick][:versions][name] = value
        end
      end
      state_method = "#{attr}_state".to_sym
      after_assign_method = "#{attr}_magick_after_assign".to_sym
      
      klass.send(:define_method, after_assign_method) do
        self.send(state_method).transform_with_magick
      end
      
      options[:after_upload] ||= []
      options[:after_upload] << after_assign_method
      
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
