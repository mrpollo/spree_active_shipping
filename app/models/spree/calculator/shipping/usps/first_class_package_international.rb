module Spree
  module Calculator::Shipping
    module Usps
      class FirstClassPackageInternational < Spree::Calculator::Shipping::Usps::Base
        AVAILABLE_COUNTRIES = [
          "AC", "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AN", "AO", "AR", "AT", "AU", "AW", "AZ", "BA", "BB", "BD",
          "BE", "BF", "BG", "BH", "BI", "BJ", "BM", "BN", "BO", "BR", "BS", "BT", "BW", "BY", "BZ", "CA", "CD", "CF",
          "CG", "CH", "CI", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ",
          "EC", "EE", "EG", "ER", "ES", "ET", "FI", "FJ", "FK", "FO", "FR", "GA", "GB", "GD", "GE", "GF", "GH", "GI",
          "GL", "GM", "GN", "GP", "GQ", "GR", "GT", "GW", "GY", "HK", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IN",
          "IQ", "IR", "IS", "IT", "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KR", "KW", "KY", "KZ", "LA",
          "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MD", "ME", "MG", "MK", "ML", "MM", "MN",
          "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NG", "NI", "NL",
          "NO", "NP", "NR", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PT", "PY", "QA", "RE",
          "RO", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SK", "SL", "SM", "SN", "SR", "ST",
          "SV", "SY", "SZ", "TC", "TD", "TG", "TH", "TJ", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG",
          "UY", "UZ", "VA", "VC", "VE", "VG", "VN", "VU", "WF", "WS", "YE", "ZA", "ZM", "ZW"
        ]

        def self.service_code
          15 # First-Class Package International Service™
        end

        def self.description
          I18n.t("usps.first_class_package_international")
        end

        protected
        # weight limit in ounces or zero (if there is no limit)
        def max_weight_for_country(country)
          # if weight in ounces > 64, then First Class Mail International Large Envelope is not available for the order
          # https://www.usps.com/ship/first-class-international.htm?
          return 64 if AVAILABLE_COUNTRIES.include?(country.iso) # 4lbs
          nil # ex. North Korea, Somalia, etc.
        end

        # SAMPLE API RESPONSE
        #  Pulled 21-Nov-2013
        #{
        #"ID": "15",
        #"Pounds": "0",
        #"Ounces": "11",
        #"MailType": "Package",
        #"Container": "RECTANGULAR",
        #"Size": "REGULAR",
        #"Width": "0.01",
        #"Length": "0.01",
        #"Height": "0.01",
        #"Girth": "0.01",
        #"Country": "SPAIN",
        #"Postage": "14.90",
        #"ExtraServices": null,
        #"ValueOfContents": "0.00",
        #"InsComment": "SERVICE",
        #"SvcCommitments": "Varies by destination",
        #"SvcDescription": "First-Class Package International Service&lt;sup&gt;&#8482;&lt;/sup&gt;**",
        #"MaxDimensions": "Other than rolls: Max. length 24\", max length, height and depth (thickness) combined 36\"<br>Rolls: Max. length 36\". Max length and twice the diameter combined 42\"",
        #"MaxWeight": "4"
        #}
      end
    end
  end
end
