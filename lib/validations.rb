module FileColumn
  module Validations
    
    def self.append_features(base)
      super
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      EXT_REGEXP = /\.([A-z0-9]+)$/
    
      # This validates the file type of one or more file_columns.  The list of file columns should be followed with an options hash.
      #
      # Valid options:
      # :in => list of extensions or mime types
      #
      # Examples:
      # validates_format_of :field, :in => ["gif", "png", "jpg"]
      # validates_format_of :field, :in => ["image/jpeg"]
      def validates_format_of(*attrs)
      
        options = attrs.pop if attrs.last.is_a?Hash
        raise ArgumentError, "Please include the :in option." if !options || !options[:in]
        options[:in] = [options[:in]] if options[:in].is_a?String
        raise ArgumentError, "Invalid value for option :in" unless options[:in].is_a?Array
      
        validates_each(attrs, options) do |record, attr, value|
          unless value.blank?
            mime_extensions = record.send("#{attr}_options")[:mime_extensions]
            extensions = options[:in].map{|o| mime_extensions[o] || o }
            record.errors.add attr, "is not a valid format." unless extensions.include?(value.scan(EXT_REGEXP).flatten.first)
          end
        end
      
      end
    
      # This validates the file size of one or more file_columns.  The list of file columns should be followed with an options hash.
      #
      # Valid options:
      # :in => A size range.  Note that you can use ActiveSupport's numeric extensions for kilobytes, etc.
      #
      # Examples:
      # validates_filesize_of :field, :in => 0..100.megabytes
      # validates_filesize_of :field, :in => 15.kilobytes..1.megabyte
      def validates_filesize_of(*attrs)  
      
        options = attrs.pop if attrs.last.is_a?Hash
        raise ArgumentError, "Please include the :in option." if !options || !options[:in]
        raise ArgumentError, "Invalid value for option :in" unless options[:in].is_a?Range
      
        validates_each(attrs, options) do |record, attr, value|
          unless value.blank?
            size = File.size(value)
            record.errors.add attr, "is smaller than the allowed size range." if size < options[:in].first
            record.errors.add attr, "is larger than the allowed size range." if size > options[:in].last
          end
        end
      
      end 
    end
  end
end
