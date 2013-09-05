# This is a base calculator for shipping calcualations using the ActiveShipping plugin.  It is not intended to be
# instantiated directly.  Create subclass for each specific shipping method you wish to support instead.
#
# Digest::MD5 is used for cache_key generation.
require 'digest/md5'
require_dependency 'spree/calculator'

module Spree
  module Calculator::Shipping
    module ActiveShipping
      class Base < ShippingCalculator
        include ActiveMerchant::Shipping

        def self.service_name
          self.description
        end

        # get the corresponding value to match against
        # in the rates_result hash response from retrieve_rates
        # this has been added since not all of the calculators
        # match against the service name the case being USPS
        # which uses dynamic names depending of time to delivery
        # eg: Priority Mail {0}™ where {0} is the number
        # in days that it takes for delivery, in those cases
        # we need to match against something else, that is
        # what needs to be called inside target_node
        # default is calculator description, called from
        # service_name
        def target_node
          self.class.service_name
        end

        def compute package
          extract_package_attributes package

          rates_result = retrieve_rates
          rate         = retrieve_rates[target_node]

          return nil unless rate
          rate = rate.to_f + (Spree::ActiveShipping::Config[:handling_fee].to_f || 0.0)

          # divide by 100 since active_shipping rates are expressed as cents
          return rate/100.0
        end

        def timing package
          extract_package_attributes package
          
          timings_result = Rails.cache.fetch(cache_key + "-timings") do
            retrieve_timings packages
          end
          raise timings_result if timings_result.kind_of?(Spree::ShippingError)
          return nil if timings_result.nil? || !timings_result.is_a?(Hash) || timings_result.empty?
          return timings_result[target_node]
        end

        protected
        # weight limit in ounces or zero (if there is no limit)
        def max_weight_for_country(country)
          0
        end

        private
        def extract_package_attributes package
          @package         = package
          @order           = @package.order
          @stock_location  = @package.stock_location
          @origin          = build_location @stock_location
          @destination     = build_location @order.ship_address
        end

        # this is the new retrieve_rates
        # this method fetches the rates from cache
        # or adds them if they aren't cached already
        # it gets the rates from the calculator
        # carrier from retrieve_carrier_rates
        def retrieve_rates
          rates_result = Rails.cache.fetch(cache_key) do
            shipping_packages = packages
            if shipping_packages.empty?
              {}
            else
              binding.pry
              retrieve_carrier_rates shipping_packages
            end
          end
          return nil if rates_result.kind_of?(Spree::ShippingError)
          return nil if rates_result.empty?
          return rates_result
        end

        # previously retrieve_rates
        # renamed to make more sense of what
        # this is actually doing instead
        # of the generic *do it all* method
        # that it used to be
        def retrieve_carrier_rates packages
          begin
            # binding.pry
            response = carrier.find_rates(@origin, @destination, packages)
            return process_rates_response response
          rescue ActiveMerchant::ActiveMerchantError => e

            get_carrier_error_message e

            error = Spree::ShippingError.new("#{I18n.t(:shipping_error)}: #{message}")
            Rails.cache.write @cache_key, error #write error to cache to prevent constant re-lookups
            raise error
          end
        end
        
        def get_carrier_error_message error
          return error.response.params["Response"]["Error"]["ErrorDescription"] unless is_response_error_description? error
          return error.response.params["eparcel"]["error"]["statusMessage"] unless is_response_parcel_error_status_message? error
          return error.message
        end

        def is_valid_response? error
          is_type_response_error?( error.class ) && error.response.is_a?(ActiveMerchant::Shipping::Response)
        end

        def is_type_response_error? error_class
          [ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError].include?(error_class)
        end

        def is_response_error_description? error
          return false unless is_valid_response?( error )
          error.params.try(:[], "Response").try(:[], "Error").try(:[], "ErrorDescription").present?
        end

        def is_response_parcel_error_status_message error
          return false unless is_valid_response?( error )
          error.params.try(:[], "eparcel").try(:[], "error").try(:[], "statusMessage").present?
        end

        # loop trough the rates response object
        # and return a hash of {:name => :value}
        # items to match against
        def process_rates_response(response)
          # turn this beastly array into a nice little hash
          # and make sure we collect the identifiers we need
          rates = response.rates.collect do |rate|
            service_name = rate.service_name.encode("UTF-8")
            [CGI.unescapeHTML(service_name), rate.price]
          end
          rate_hash = Hash[*rates.flatten]
        end

        def retrieve_timings packages
          begin
            if carrier.respond_to?(:find_time_in_transit)
              response = carrier.find_time_in_transit(@origin, @destination, packages)
              return response
            end
          rescue ActiveMerchant::Shipping::ResponseError => re
            if re.response.is_a?(ActiveMerchant::Shipping::Response)
              params = re.response.params
              if params.has_key?("Response") && params["Response"].has_key?("Error") && params["Response"]["Error"].has_key?("ErrorDescription")
                message = params["Response"]["Error"]["ErrorDescription"]
              else
                message = re.message
              end
            else
              message = re.message
            end

            error = Spree::ShippingError.new("#{I18n.t(:shipping_error)}: #{message}")
            Rails.cache.write @cache_key+"-timings", error #write error to cache to prevent constant re-lookups
            raise error
          end
        end

        def convert_package_to_weights_array
          multiplier     = Spree::ActiveShipping::Config[:unit_multiplier]
          default_weight = Spree::ActiveShipping::Config[:default_weight]
          max_weight     = get_max_weight

          weights = @package.contents.map do |content_item|
            # ContentItem = Struct.new(:variant, :quantity, :state)
            item_weight = content_item.variant.weight.to_f
            item_weight = default_weight if item_weight <= 0
            item_weight *= multiplier

            quantity = content_item.quantity
            if max_weight <= 0
              item_weight * quantity
            elsif item_weight == 0
              0
            else
              if item_weight < max_weight
                max_quantity = (max_weight/item_weight).floor
                if quantity < max_quantity
                  item_weight * quantity
                else
                  new_items = []
                  while quantity > 0 do
                    new_quantity = [max_quantity, quantity].min
                    new_items << (item_weight * new_quantity)
                    quantity -= new_quantity
                  end
                  new_items
                end
              else
                raise Spree::ShippingError.new("#{I18n.t(:shipping_error)}: The maximum per package weight for the selected service from the selected country is #{max_weight} ounces.")
              end
            end
          end
          weights.flatten.compact.sort
        end

        def convert_package_to_item_packages_array
          multiplier = Spree::ActiveShipping::Config[:unit_multiplier]
          max_weight = get_max_weight
          packages = []

          @package.contents.each do |content_item|
            variant  = content_item.variant
            quantity = content_item.quantity
            product  = variant.product

            # ContentItem = Struct.new(:variant, :quantity, :state)
            product.product_packages.each do |product_package|
              # attr_accessible :length, :width, :height, :weight
              if product_package.weight.to_f <= max_weight or max_weight == 0
                quantity.times do |idx|
                  packages << [product_package.weight * multiplier, product_package.length, product_package.width, product_package.height]
                end
              else
                raise Spree::ShippingError.new("#{I18n.t(:shipping_error)}: The maximum per package weight for the selected service from the selected country is #{max_weight} ounces.")
              end
            end
          end

          packages
        end

        # Generates an array of ActiveMerchant::Shipping::Package objects based on
        # the quantities and weights of the variants inside the computed Package element
        def packages
          units                  = Spree::ActiveShipping::Config[:units].to_sym
          packages               = []
          weights                = convert_package_to_weights_array
          max_weight             = get_max_weight
          item_specific_packages = convert_package_to_item_packages_array

          if max_weight <= 0
            packages << Package.new(weights.sum, [], :units => units)
          else
            package_weight = 0
            weights.each do |li_weight|
              if package_weight + li_weight <= max_weight
                package_weight += li_weight
              else
                packages << Package.new(package_weight, [], :units => units)
                package_weight = li_weight
              end
            end
            packages << Package.new(package_weight, [], :units => units) if package_weight > 0
          end

          item_specific_packages.each do |package|
            packages << Package.new(package.at(0), [package.at(1), package.at(2), package.at(3)], :units => :imperial)
          end

          packages
        end

        def get_max_weight
          max_weight             = max_weight_for_country(@order.ship_address.country)
          
          # Assuming we entered this value in Oz, so no need to multiply
          # max_weight_per_package = Spree::ActiveShipping::Config[:max_weight_per_package] * Spree::ActiveShipping::Config[:unit_multiplier]
          max_weight_per_package = Spree::ActiveShipping::Config[:max_weight_per_package]

          if max_weight == 0 and max_weight_per_package > 0
            max_weight = max_weight_per_package
          elsif max_weight > 0 and max_weight_per_package < max_weight and max_weight_per_package > 0
            max_weight = max_weight_per_package
          end

          max_weight
        end

        def cache_key
          stock_location = @stock_location.nil? ? "" : "#{@stock_location.id}-"
          ship_address   = @order.ship_address
          contents_hash  = Digest::MD5.hexdigest(@package.contents.map {|content_item| content_item.variant.id.to_s + "_" + content_item.quantity.to_s }.join("|"))
          @cache_key     = "#{@stock_location}#{carrier.name}-#{@order.number}-#{ship_address.country.iso}-#{fetch_best_state_from_address(ship_address)}-#{ship_address.city}-#{ship_address.zipcode}-#{contents_hash}-#{I18n.locale}".gsub(" ","")
        end
        
        def fetch_best_state_from_address address
          address.state ? address.state.abbr : address.state_name
        end
        
        def build_location address
          Location.new(:country => address.country.iso, :state => fetch_best_state_from_address(address), :city => address.city, :zip => address.zipcode)
        end

      end
    end
  end
end
