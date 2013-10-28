module Spree
  module Calculator::Shipping
    module Usps
      class FirstClassMailInternational < Spree::Calculator::Shipping::Usps::Base

        def self.service_code
          13 #First-Class Mail® International Letter
        end

        def self.description
          "USPS First-Class Mail International Letter"
        end

        def available?(package)
          #if weight in ounces > 3.5, then First Class Mail International is not available for the order
          package.weight > 3.5 ? false : true
        end
      end
    end
  end
end


