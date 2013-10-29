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

        def available?(package)
          !compute(package).zero?
        rescue Spree::ShippingError
          false
        end

        def compute_package(package)
          order           = package.order
          stock_location  = package.stock_location
          origin          = build_location(stock_location)
          destination     = build_location(order.ship_address)

          # check if you can ship this package first
          country_weight_error?(package)

          # get the rates from the api
          rate            = retrieve_rate_from_cache(package, origin, destination)

          # process handling fees
          # and make sure we don't return nil anymore (nil.to_f == 0.0)
          rate = rate.to_f + (Spree::ActiveShipping::Config[:handling_fee].to_f || 0.0)
          # divide by 100 since active_shipping rates are expressed as cents
          return rate/100.0
        end

        def timing(line_items)
          order           = line_items.first.order
          # TODO: Figure out where stock_location is supposed to come from.
          origin          = build_location(stock_location)
          destination     = build_location(order.ship_address)
          timings_result  = Rails.cache.fetch(cache_key(package) + "-timings") do
            retrieve_timings(origin, destination, packages(order))
          end
          raise timings_result if timings_result.kind_of?(Spree::ShippingError)
          return nil if timings_result.nil? || !timings_result.is_a?(Hash) || timings_result.empty?
          return timings_result[self.description]
        end

        protected
        # weight limit in ounces or zero (if there is no limit)
        def max_weight_for_country(country)
          0
        end

        private
        def empty_rates_exception
          raise Spree::ShippingError.new "#{I18n.t(:shipping_error)}: empty rates from api"
        end

        def country_weight_error? package
          max_weight = max_weight_for_country(package.order.ship_address.country)
          raise Spree::ShippingError.new("#{I18n.t(:shipping_error)}: The maximum per package weight for the selected service from the selected country is #{max_weight} ounces.") if package.weight > max_weight && max_weight > 0
        end

        def cache_key(package)
          stock_location  = package.stock_location.nil? ? "" : "#{package.stock_location.id}-"
          order           = package.order
          ship_address    = package.order.ship_address
          contents_hash   = Digest::MD5.hexdigest(package.contents.map {|content_item| content_item.variant.id.to_s + "_" + content_item.quantity.to_s }.join("|"))
          @cache_key      = "#{stock_location}#{carrier.name}-#{order.number}-#{ship_address.country.iso}-#{fetch_best_state_from_address(ship_address)}-#{ship_address.city}-#{ship_address.zipcode}-#{contents_hash}-#{I18n.locale}".gsub(" ","")
        end

        def fetch_best_state_from_address address
          address.state ? address.state.abbr : address.state_name
        end

        def build_location address
          Location.new(:country => address.country.iso,
                       :state   => fetch_best_state_from_address(address),
                       :city    => address.city,
                       :zip     => address.zipcode)
        end

        def retrieve_rate_from_cache package, origin, destination
          rates_result = Rails.cache.fetch(cache_key(package)) do
            if package.to_active_package.empty?
              {}
            else
              retrieve_rates(origin, destination, package.to_active_package)
            end
          end

          # raise the exception in case its stored inside the cache from before
          # the exception message comes directly from the API response
          raise rates_result if rates_result.kind_of? Spree::ShippingError
          # or raise an empty rates exception if no rates
          raise empty_rates_exception if rates_result.nil?
          get_specific_rate_for_service(rates_result)
        end

        def process_api_rates_response response
          # this is a customization point for different shipping services
          response.rates.collect do |rate|
            service_name = rate.service_name.encode("UTF-8")
            [CGI.unescapeHTML(service_name), rate.price]
          end
        end

        def get_specific_rate_for_service rates_result
          # this is a customization point for different shipping services
          rates_result[self.class.description]
        end

        def retrieve_rates(origin, destination, shipment_packages)
          begin
            response  = carrier.find_rates(origin, destination, shipment_packages)
            rates     = process_api_rates_response response
            return Hash[*rates.flatten]
          rescue ActiveMerchant::ActiveMerchantError => exception
            exception_message = exception.message

            if is_active_merchant_error?(exception.response) && is_active_merchant_response?(exception.response)
              # better errors from api
              exception_message = exception.response.params["Response"]["Error"]["ErrorDescription"] if has_error_description?(exception.response.params)
              exception_message = exception.response.params["eparcel"]["error"]["statusMessage"] if has_error_description_from_canada_post?(exception.response.params)
            end

            rates_error = raise Spree::ShippingError.new "#{I18n.t(:shipping_error)}: #{exception_message}"
            Rails.cache.write @cache_key, rates_error #write error to cache to prevent constant re-lookups
            raise rates_error
          end
        end

        def retrieve_timings(origin, destination, packages)
          begin
            if carrier.respond_to?(:find_time_in_transit)
              return carrier.find_time_in_transit(origin, destination, packages)
            end
          rescue ActiveMerchant::Shipping::ResponseError => exception
            exception_message = exception.message
            if is_active_merchant_response?(exception.response) && has_error_description?(exception.response.params)
              # better error from api
              exception_message = exception.response.params["Response"]["Error"]["ErrorDescription"]
            end

            rates_error = raise Spree::ShippingError.new "#{I18n.t(:shiping_error)}: #{exception_message}"
            Rails.cache.write @cache_key + "-timings", rates_error #write error to cache to prevent constant re-lookups
            raise rates_error
          end
        end

        def is_active_merchant_error? error
          [ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError].include?(error.class)
        end

        def is_active_merchant_response? response
          response.is_a?(ActiveMerchant::Shipping::Response)
        end

        def has_error_description? response
          response.has_key?("Response") && response["Response"].has_key?("Error") && response["Response"]["Error"].has_key?("ErrorDescription")
        end

        def has_error_description_from_canada_post? response
          response.has_key?("eparcel") && response["eparcel"].has_key?("error") && response["eparcel"]["error"].has_key?("statusMessage")
        end
      end
    end
  end
end
