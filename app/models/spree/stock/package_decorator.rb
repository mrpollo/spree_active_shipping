Spree::Stock::Package.class_eval do
  def weight
    multiplier      = Spree::ActiveShipping::Config[:unit_multiplier]
    default_weight  = Spree::ActiveShipping::Config[:default_weight]
    contents.map{|content| ( content.variant.try(:weight) || default_weight ) * content.quantity }.sum * multiplier
  end
  def to_active_package
    [ActiveMerchant::Shipping::Package.new(weight, [], :units => Spree::ActiveShipping::Config[:units])]
  end
end
