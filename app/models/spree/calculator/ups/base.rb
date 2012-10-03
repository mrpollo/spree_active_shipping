require_dependency 'spree/calculator'

module Spree
  class Calculator < ActiveRecord::Base
    module Ups
      class Base < Spree::Calculator::ActiveShipping::Base
        def carrier
          carrier_details = {
            :login => Spree::ActiveShipping::Config[:ups_login],
            :password => Spree::ActiveShipping::Config[:ups_password],
            :key => Spree::ActiveShipping::Config[:ups_key],
            :test => Spree::ActiveShipping::Config[:test_mode]
          }

          if shipper_number = Spree::ActiveShipping::Config[:shipper_number]
            carrier_details.merge!(:origin_account => shipper_number)
          end

          ActiveMerchant::Shipping::UPS.new(carrier_details)
        end
        
        protected
        # weight limit in ounces http://www.ups.com/content/us/en/resources/prepare/oversize.html
        def max_weight_for_country(country)
          150*Spree::ActiveShipping::Config[:unit_multiplier]
        end
      end
    end
  end
end
