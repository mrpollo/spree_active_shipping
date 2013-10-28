module Spree
  module Calculator::Shipping
    module Usps
      class FirstClassMailInternationalLargeEnvelope < Spree::Calculator::Shipping::Usps::Base

        def self.service_code
          14 #First-Class Mail® International Large Envelope
        end

        def self.description
          "USPS First-Class Mail International Large Envelope"
        end

        def available?(package)
          #if weight in ounces > 64, then First Class Mail International Large Envelope is not available for the order
          package.weight > 64 ? false : true
        end
      end
    end
  end
end


