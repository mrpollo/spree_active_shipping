require 'spec_helper'
require 'pry'
include ActiveMerchant::Shipping

module ActiveShipping
  describe Spree::Calculator::Shipping do
    WebMock.disable_net_connect!
    # NOTE: All specs will use the bogus calculator (no login information needed)

    let(:address) { FactoryGirl.create(:address) }
    let!(:order) do
      order = FactoryGirl.create(:order_with_line_items, :ship_address => address, :line_items_count => 2)
      order.line_items.first.tap do |line_item|
        line_item.quantity = 2
        line_item.variant.save
        line_item.variant.weight = 1
        line_item.variant.save
        line_item.save
        # product packages?
      end
      order.line_items.last.tap do |line_item|
        line_item.quantity = 2
        line_item.variant.save
        line_item.variant.weight = 2
        line_item.variant.save
        line_item.save
        # product packages?
      end
      order
    end

    let(:carrier) { ActiveMerchant::Shipping::USPS.new(:login => "FAKEFAKEFAKE") }
    let(:calculator) { Spree::Calculator::Shipping::Usps::ExpressMail.new }

    before(:each) do
      order.create_proposed_shipments
      order.shipments.count.should == 1
      Spree::ActiveShipping::Config.set(:units => "imperial")
      Spree::ActiveShipping::Config.set(:unit_multiplier => 1)
      calculator.stub(:carrier).and_return(carrier)
      Rails.cache.clear
    end

    let(:package) do
      order.shipments.first.to_package
    end

    def sample_stub_request
      stub_request(:get, /http:\/\/production.shippingapis.com\/ShippingAPI.dll.*/).
        to_return(:body => fixture(:normal_rates_request))
    end

    def calculator_precompute
      sample_stub_request
      calculator.compute(package)
    end

    describe "compute" do

      it "should use the carrier supplied in the initializer" do
        sample_stub_request
        calculator.compute(package).should == 14.1
      end

      xit "should ignore variants that have a nil weight" do
        variant = order.line_items.first.variant
        variant.weight = nil
        variant.save
        calculator.compute(package)
      end

      xit "should create a package with the correct total weight in ounces" do
        # (10 * 2 + 5.25 * 1) * 16 = 404
        Package.should_receive(:new).with(404, [], :units => :imperial)
        calculator.compute(package)
      end

      it "should check the cache first before finding rates" do
        calculator_precompute
        
        Rails.cache.fetch(calculator.send(:cache_key)) { Hash.new }
        carrier.should_not_receive(:find_rates)
        calculator.compute(package)
      end

      context "with valid response" do
        before do
          # carrier.should_receive(:find_rates).and_return(response)
          sample_stub_request
        end

        it "should return rate based on calculator's target_node" do
          calculator.should_receive(:target_node).and_return("3")
          rate = calculator.compute(package)
          rate.should == 14.10
        end

        it "should include handling_fee when configured" do
          calculator.should_receive(:target_node).and_return("3")
          Spree::ActiveShipping::Config.set(:handling_fee => 100)
          rate = calculator.compute(package)
          rate.should == 15.10
        end

        it "should return nil if target is not found in rate_hash" do
          calculator.should_receive(:target_node).and_return("Extra-Super Fast")
          rate = calculator.compute(package)
          rate.should be_nil
        end
      end
    end
  end
end
