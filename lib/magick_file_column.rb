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
          options[:magick][:versions].each_pair do |version, version_options|
            next if version_options[:lazy]
            dirname = version_options[:name]
            FileUtils.mkdir File.join(@dir, dirname)
            resize_image(img, version_options, absolute_path(dirname))
          end
        end
        if options[:magick][:size] or options[:magick][:crop]
          resize_image(img, options[:magick], absolute_path)
        end

        GC.start
      end
    end

    def create_magick_version_if_needed(version)
      # RMagick might not have been loaded so far.
      # We do not want to require it on every call of this method
      # as this might be fairly expensive, so we just try if ::Magick
      # exists and require it if not.
      begin 
        ::Magick 
      rescue NameError
        require 'RMagick'
      end

      if version.is_a?(Symbol)
        version_options = options[:magick][:versions][version]
      else
        version_options = MagickExtension::process_options(version)
      end

      unless File.exists?(absolute_path(version_options[:name]))
        img = ::Magick::Image::read(absolute_path).first
        dirname = version_options[:name]
        FileUtils.mkdir File.join(@dir, dirname)
        resize_image(img, version_options, absolute_path(dirname))
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
        (options[:magick][:size] or options[:magick][:versions])
    end
    
    def resize_image(img, img_options, dest_path)
      begin
        if img_options[:crop]
          dx, dy = img_options[:crop].split(':').map { |x| x.to_f }
          w, h = (img.rows * dx / dy), (img.columns * dy / dx)
          img = img.crop(::Magick::CenterGravity, [img.columns, w].min, 
                         [img.rows, h].min)
        end

        if img_options[:size]
          img = img.change_geometry(img_options[:size]) do |c, r, i|
            i.resize(c, r)
          end
        end
      ensure
        File.open(dest_path, "wb", options[:permissions]) {|f| img.write f}
      end
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
  # after a new file is assigned to the file_column attribute (i.e.,
  # when a new file has been uploaded).
  #
  # To resize the uploaded image according to an imagemagick geometry
  # string, just use the <tt>:size</tt> option:
  #
  #    file_column :image, :magick => {:size => "800x600>"}
  #
  # You can also create additional versions of your image, for example
  # thumb-nails, like this:
  #    file_column :image, :magick => {:versions => {
  #         :thumb => {:size => "50x50"},
  #         :medium => {:size => "640x480>"}
  #       }
  #
  # If you wish to crop your images with a size ratio before scaling
  # them according to your version geometry, you can use the :crop directive.
  #    file_column :image, :magick => {:versions => {
  #         :square => {:crop => "1:1", :size => "50x50", :name => "thumb"},
  #         :screen => {:crop => "4:3", :size => "640x480>"},
  #         :widescreen => {:crop => "16:9", :size => "640x360!"},
  #       }
  #    }
  #
  # These versions will be stored in separate sub-directories, named like the
  # symbol you used to identify the version. So in the previous example, the
  # image versions will be stored in "thumb", "screen" and "widescreen"
  # directories, resp. 
  # A name different from the symbol can be set via the <tt>:name</tt> option.
  #
  # These versions can be accessed via FileColumnHelper's +url_for_image_column+
  # method like this:
  #
  #    <%= url_for_image_column "entry", "image", :thumb %>
  #
  # <b>Note:</b> You'll need the
  # RMagick extension being installed  in order to use file_column's
  # imagemagick integration.
  module MagickExtension

    def self.file_column(klass, attr, options) # :nodoc:
      require 'RMagick'
      options[:magick] = process_options(options[:magick],false) if options[:magick]
      if options[:magick][:versions]
        options[:magick][:versions].each_pair do |name, value|
          options[:magick][:versions][name] = process_options(value, name.to_s)
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

    
    def self.process_options(options,create_name=true)
      options = {:size => options } if options.kind_of?(String)
      if options[:geometry]
        options[:size] = options.delete(:geometry)
      end
      if options[:name].nil? and create_name
        if create_name == true
          hash = 0
          for key in [:size, :crop]
            hash = hash ^ options[key].hash if options[key]
          end
          options[:name] = hash.abs.to_s(36)
        else
          options[:name] = create_name
        end
      end
      options
    end

  end
end
