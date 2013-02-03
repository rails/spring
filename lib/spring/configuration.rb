module Spring
  class << self
    attr_accessor :application_root

    def application_root_path
      Pathname.new(File.expand_path(application_root))
    end
  end
  self.application_root = '.'

end
