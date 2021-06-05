module Expedite
  module LoadHelper
    def load_helper
      helper = "expedite_helper.rb"
      if File.exist?(helper)
        log "loading #{helper}"
        load(helper)
      end
    end
  end
end
