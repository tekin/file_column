class Entry < ActiveRecord::Base
  attr_accessor :validation_should_fail

  def validate
    errors.add("image","some stupid error") if @validation_should_fail
  end
  
  def after_assign
    @after_assign_called = true
  end
  
  def after_assign_called?
    @after_assign_called
  end
  
  def after_save
    @after_save_called = true
  end

  def after_save_called?
    @after_save_called
  end

  def my_store_dir
    File.expand_path(File.join(RAILS_ROOT, "public", "my_store_dir"))
  end
end
