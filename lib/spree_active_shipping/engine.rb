module Spree::ActiveShipping
end
module SpreeActiveShippingExtension
  class Engine < Rails::Engine

    initializer "spree.active_shipping.preferences", :before => :load_config_initializers do |app|
      Spree::ActiveShipping::Config = Spree::ActiveShippingConfiguration.new
    end

    def self.activate
      Dir[File.join(File.dirname(__FILE__), "../../app/models/spree/calculator/**/base.rb")].sort.each do |c|
        Rails.env.production? ? require(c) : load(c)
      end

      Dir.glob(File.join(File.dirname(__FILE__), "../../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # Fix Canada Post "Ready to ship" package
      ActiveMerchant::Shipping::CanadaPost.send(:include, Spree::ActiveShipping::CanadaPostOverride)
    end

    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &method(:activate).to_proc

    initializer "spree_active_shipping.register.calculators" do |app|
      Dir[File.join(File.dirname(__FILE__), "../../app/models/spree/calculator/**/*.rb")].sort.each do |c|
        Rails.env.production? ? require(c) : load(c)
      end

      app.config.spree.calculators.shipping_methods.concat(
        Spree::Calculator::Shipping::Fedex::Base.descendants +
        Spree::Calculator::Shipping::CanadaPost::Base.descendants +
        Spree::Calculator::Shipping::Ups::Base.descendants +
        Spree::Calculator::Shipping::Usps::Base.descendants
      )
    end
  end

end
