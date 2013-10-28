module Spree
  module Calculator::Shipping
    module Usps
      class FirstClassMailParcels < Spree::Calculator::Shipping::Usps::Base

        def self.service_code
          0 #First-Class Mail® Parcel
        end

        def self.description
          "USPS First-Class Mail Parcel"
        end

        def available?(package)
          #if weight in ounces > 13, then First Class Mail is not available for the order
          package.weight > 13 ? false : true
        end
      end
    end
  end
end
