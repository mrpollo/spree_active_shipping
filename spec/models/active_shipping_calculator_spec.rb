require 'spec_helper'
require 'pry'
require 'pry-debugger'
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

      xit "should use the carrier supplied in the initializer" do
        sample_stub_request
        calculator.compute(package).should == 14.1
      end
      
      it "should use the carrier suplied to find rates for a package and return valid rates" do
        sample_stub_request
        # Package.should_receive(:new)
        calculator.carrier.should_receive(:find_rates).with(kind_of(Location), kind_of(Location), (expect(actual).should_not be_empty), hash_including(:login))
        calculator.compute(package)
      end

      xit "should ignore variants that have a nil weight" do
        sample_stub_request
        variant = order.line_items.first.variant
        variant.weight = nil
        variant.save
        Package.should_receive(:new).with(4, [], :units => :imperial)
        calculator.compute(package)
      end

      xit "should create a package with the correct total weight in ounces" do
        sample_stub_request
        # (2 * 1 + 2 * 2) = 6
        # binding.pry
        Package.should_receive(:new).with(6, [], :units => :imperial)
        calculator.compute(package)
      end

      xit "should check the cache first before finding rates" do
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

        xit "should return rate based on calculator's target_node" do
          calculator.should_receive(:target_node).and_return("3")
          rate = calculator.compute(package)
          rate.should == 14.10
        end

        xit "should include handling_fee when configured" do
          calculator.should_receive(:target_node).and_return("3")
          Spree::ActiveShipping::Config.set(:handling_fee => 100)
          rate = calculator.compute(package)
          rate.should == 15.10
        end

        xit "should return nil if target is not found in rate_hash" do
          calculator.should_receive(:target_node).and_return("Extra-Super Fast")
          rate = calculator.compute(package)
          rate.should be_nil
        end
      end
    end
  end
end
