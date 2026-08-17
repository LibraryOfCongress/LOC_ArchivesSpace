
module RESTHelpers
  class Endpoint
    # Allow plugins to find endpoints by uri and http
    # method(s). Useful for overriding permissions or
    # other attributes of core endpoints.
    def self.find_by_uri(uri, methods=[:get])
      @@endpoints.find { |e|
        e.instance_eval do
          @methods == methods && @uri == uri
        end
      }
    end
  end
end

