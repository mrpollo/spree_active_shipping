# Digest::MD5 is used for cache_key generation.
require 'digest/md5'

Spree::Shipment.class_eval do
  def cache_key
    content_digest   = create_hash_of_contents
    ship_address    = order.ship_address
    state           = ship_address.state ? ship_address.state.abbr : ship_address.state_name

    @cache_key = "#{stock_location.try(:id)}-#{shipping_method.try(:name)}-"
    @cache_key += "#{order.number}-#{number}-#{ship_address.to_s.gsub(' ', '_')}-"
    @cache_key += "#{ship_address.country.iso}-#{state}-"
    @cache_key += "#{ship_address.city}-#{ship_address.zipcode.strip.delete(' ')}-"
    @cache_key += "#{content_digest}-#{I18n.locale}"
    @cache_key.gsub ' ', ''

  end

  private
  def create_hash_of_contents
    Digest::MD5.hexdigest inventory_units.map {|iu| iu.variant.id.to_s}.join("|")
  end

end
