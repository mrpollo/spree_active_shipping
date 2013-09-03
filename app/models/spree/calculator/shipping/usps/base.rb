module Spree
  module Calculator::Shipping
    module Usps
      class Base < Spree::Calculator::Shipping::ActiveShipping::Base

        def service_code
          0
        end

        def target_node
          # return as a string since the object it matches
          # from has been encoded to string from its 
          # API XML Response, this comes from active_shipping
          "#{self.service_code}"
        end

        def carrier
          carrier_details = {
            :login => Spree::ActiveShipping::Config[:usps_login],
            :test => Spree::ActiveShipping::Config[:test_mode]
          }

          ActiveMerchant::Shipping::USPS.new(carrier_details)
        end

        protected
        # weight limit in ounces or zero (if there is no limit)
        def max_weight_for_country(country)
          1120  # 70 lbs
        end

        private
        def process_rates_response(response)
          # turn this beastly array into a nice little hash
          # and make sure we collect the identifiers we need
          rates = response.rates.collect do |rate|
            service_code = rate.service_code.encode("UTF-8")
            [CGI.unescapeHTML(service_code), rate.price]
          end
          rate_hash = Hash[*rates.flatten]
        end
      end
    end
  end
end
