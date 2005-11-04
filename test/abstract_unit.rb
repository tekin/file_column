require 'test/unit'
require 'rubygems'
require_gem 'activesupport'
require_gem 'activerecord'
require 'connection'
require 'stringio'

RAILS_ROOT = File.dirname(__FILE__)

$: << "../lib"

require 'file_column.rb'

# do not use the file executable normally in our tests as
# it may not be present on the machine we are running on
FileColumn::ClassMethods::DEFAULT_OPTIONS = 
  FileColumn::ClassMethods::DEFAULT_OPTIONS.merge({:file_exec => nil})

class ActiveRecord::Base
    include FileColumn
end


class Test::Unit::TestCase
  private
  
  def uploaded_file(path, content_type, filename, type=:tempfile)
    if type == :tempfile
      t = Tempfile.new(File.basename(filename))
      FileUtils.copy_file(path, t.path)
    else
      if path
        t = StringIO.new(IO.read(path))
      else
        t = StringIO.new
      end
    end
    (class << t; self; end).class_eval do
      alias local_path path if type == :tempfile
      define_method(:local_path) { "" } if type == :stringio
      define_method(:original_filename) {filename}
      define_method(:content_type) {content_type}
    end
    return t
  end

  def upload(basename, content_type="image/jpeg")
    uploaded_file(file_path(basename), content_type, basename)
  end

  def file_path(filename)
    File.expand_path("#{File.dirname(__FILE__)}/fixtures/#{filename}")
  end

end
