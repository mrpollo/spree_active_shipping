# Digest::MD5 is used for cache_key generation.
require 'digest/md5'

Spree::Shipment.class_eval do
  def cache_key carrier = nil
    raise Exception.new('No cache_key for non rate calcualtor shipping_methods') if carrier.nil? && shipping_method.try(:calculator).try(:carrier).nil?
    content_digest  = create_hash_of_contents
    ship_address    = order.ship_address
    state           = ship_address.state ? ship_address.state.abbr : ship_address.state_name
    carrier         = (carrier.nil?) ? shipping_method.calculator.carrier : carrier


    @cache_key = "#{stock_location.try(:id)}-#{carrier.try(:name)}-"
    @cache_key += "#{order.number}-#{ship_address.to_s.gsub(' ', '_')}-"
    @cache_key += "#{ship_address.country.iso}-#{state}-"
    @cache_key += "#{ship_address.city}-#{ship_address.zipcode.strip.delete(' ')}-"
    @cache_key += "#{content_digest}-#{I18n.locale}"
    @cache_key.gsub ' ', ''
  end

  def cache_keys
    get_rate_calculator_names.map do |carrier|
      cache_key OpenStruct.new(name: carrier)
    end
  end

  def remove_cached_carrier_messages
    cache_keys.map do |key|
      Rails.cache.delete key
    end
  end

  def get_cached_carrier_messages
    cache_keys.map do |key|
      Rails.cache.fetch key
    end
  end

  private
  def create_hash_of_contents
    Digest::MD5.hexdigest inventory_units.map {|iu| iu.variant.id.to_s}.join("|")
  end

  def get_rate_calculators
    shipping_methods.map(&:calculator).select{|c| c.try(:carrier)}.map(&:carrier)
  end

  def get_rate_calculator_names
    get_rate_calculators.map(&:name).uniq
  end
end
