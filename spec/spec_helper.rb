require 'rspec'

def require_files_from(paths = [])
  paths.each do |path|
    Dir[File.join(File.expand_path("#{path}*.rb", __FILE__))].each do |file|
      require file
    end
  end
end

RSpec.configure do |config|
  lib_file = File.expand_path('../../lib/wikipedia/vandalism_analyzer', __FILE__)
  require lib_file

  dirs = ["../support/**/", "../../lib/jobs/*/"]
  require_files_from dirs
end