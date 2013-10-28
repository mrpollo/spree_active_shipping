module Spree
  module Calculator::Shipping
    module Usps
      class Base < Spree::Calculator::Shipping::ActiveShipping::Base

        def carrier
          carrier_details = {
            :login => Spree::ActiveShipping::Config[:usps_login],
            :test => Spree::ActiveShipping::Config[:test_mode]
          }

          ActiveMerchant::Shipping::USPS.new(carrier_details)
        end

        private
        def process_api_rates_response response
          response.rates.collect do |rate|
            service_code = rate.service_code.to_i
            [service_code, rate.price]
          end
        end

        def get_specific_rate_for_service rates_result
          rates_result[self.class.service_code]
        end

        protected
        # weight limit in ounces or zero (if there is no limit)
        def max_weight_for_country(country)
          1120  # 70 lbs
        end
      end
    end
  end
end
