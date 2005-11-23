# This module contains helper methods for displaying and uploading files
# for attributes created by +FileColumn+'s +file_column+ method. It will be
# automatically included into ActionView::Base, thereby making this module's
# methods available in all your views.
module FileColumnHelper
  
  # Use this helper to create an upload field for a file_column attribute. This will generate
  # an additional hidden field to keep uploaded files during form-redisplays. For example,
  # when called with
  #
  #   <%= file_column_field("entry", "image") %>
  #
  # the following HTML will be generated (assuming the form is redisplayed and something has
  # already been uploaded):
  #
  #   <input type="hidden" name="entry[image_temp]" value="..." />
  #   <input type="file" name="entry[image]" />
  #
  # You can use the +option+ argument to pass additional options to the file-field tag.
  #
  # Be sure to set the enclosing form's encoding to 'multipart/form-data', by
  # using something like this:
  #
  #    <%= form_tag {:action => "create", ...}, :multipart => true %>
  def file_column_field(object, method, options={})
    result = ActionView::Helpers::InstanceTag.new(object.dup, method.to_s+"_temp", self).to_input_field_tag("hidden", {})
    result << ActionView::Helpers::InstanceTag.new(object.dup, method, self).to_input_field_tag("file", options)
  end
  
  # Creates an URL where an uploaded file can be accessed. When called for an Entry object with
  # id 42 (stored in <tt>@entry</tt>) like this
  #
  #   <%= url_for_file_column(@entry, "image")
  #
  # the following URL will be produced, assuming the file "test.png" has been stored in
  # the "image"-column of an Entry object stored in <tt>@entry</tt>:
  #
  #  /entry/image/42/test.png
  #
  # This will produce a valid URL even for temporary uploaded files, e.g. files where the object
  # they are belonging to has not been saved in the database yet.
  #
  # If there is currently no uploaded file stored in the object's column this method will
  # return +nil+.
  #
  # If your +options+ parameter contains a key <tt>:version</tt> this will
  # access a different version of an image that will be produced by
  # RMagick. You can use the following types of versions:
  #
  # * <tt>:version => :symbol</tt> will select a version defined in the model
  #   via FileColumn::Magick's version feature.
  # * <tt>:version => geometry_string</tt> will dynamically create an
  #   image resized as specified by <tt>geometry_string</tt>. The image will
  #   be stored so that it does not have to be recomputed the next time the
  #   same version string is used.
  # * <tt>:version => some_hash</tt> will dynamically create an image
  #   that is created according to the options in <tt>some_hash</tt>. This
  #   accepts exactly the same options as Magick's version feature.
  #
  # Note that if you pass a string or a symbol as the +object+ parameter,
  # the file_column will be looked up in instance variable named +object+.
  def url_for_file_column(object, method, options=nil)
    case object
    when String, Symbol
      object = instance_variable_get("@#{object.to_s}")
    end
    subdir = nil
    if options and options[:version]
      subdir = object.send("#{method}_state").create_magick_version_if_needed(options[:version])
    end
    relative_path = object.send("#{method}_relative_path", subdir)
    return nil unless relative_path
    url = ""
    url << @request.relative_url_root.to_s << "/"
    url << object.send("#{method}_options")[:base_url] << "/"
    url << relative_path
  end
end
