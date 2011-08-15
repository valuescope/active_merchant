module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paypal
        class Helper < ActiveMerchant::Billing::Integrations::Helper
         CANADIAN_PROVINCES = {  'AB' => 'Alberta',
                                 'BC' => 'British Columbia',
                                 'MB' => 'Manitoba',
                                 'NB' => 'New Brunswick',
                                 'NL' => 'Newfoundland',
                                 'NS' => 'Nova Scotia',
                                 'NU' => 'Nunavut',
                                 'NT' => 'Northwest Territories',
                                 'ON' => 'Ontario',
                                 'PE' => 'Prince Edward Island',
                                 'QC' => 'Quebec',
                                 'SK' => 'Saskatchewan',
                                 'YT' => 'Yukon'
                               } 
          # See https://www.paypal.com/IntegrationCenter/ic_std-variable-reference.html for details on the following options.
          mapping :order, [ 'item_number', 'custom' ]

          def initialize(order, account, options = {})
            super
            # indecate we are using thirdparty shopping cart
            add_field('cmd', '_cart')
            add_field('upload', '1')
            add_field('no_shipping', '1')
            add_field('no_note', '1')
            add_field('charset', 'utf-8')
            add_field('address_override', '0')
            add_field('bn', application_id.to_s.slice(0,32)) unless application_id.blank?
          end

          # pass the shipping cost for whole cart
          mapping :shipping, 'handling_cart'

          # mapping header image
          mapping :cpp_header_image, 'cpp_header_image'

          # add line item details, note the amount_x should be price instead of line total
          def line_items(items = [])
            items.each_with_index do |line, index|
              add_field("item_name_#{index+1}", line.item.item_name)
              add_field("amount_#{index+1}", line.price.value_without_unit)
              add_field("quantity_#{index+1}", line.quantity)
            end
          end

          mapping :amount, 'amount'
          mapping :account, 'business'
          mapping :currency, 'currency_code'
          mapping :notify_url, 'notify_url'
          mapping :return_url, 'return'
          mapping :cancel_return_url, 'cancel_return'
          mapping :invoice, 'invoice'
          mapping :item_name, 'item_name'
          mapping :quantity, 'quantity'
          mapping :no_shipping, 'no_shipping'
          mapping :no_note, 'no_note'
          mapping :address_override, 'address_override'

          mapping :application_id, 'bn'

          mapping :customer, :first_name => 'first_name',
                             :last_name  => 'last_name',
                             :email      => 'email'

          mapping :shipping_address,  :city    => 'city',
                                      :address1 => 'address1',
                                      :address2 => 'address2',
                                      :state   => 'state',
                                      :zip     => 'zip',
                                      :country => 'country'
          
          def shipping_address(params = {})

            # Get the country code in the correct format
            # Use what we were given if we can't find anything
            country_code = lookup_country_code(params.delete(:country))
            add_field(mappings[:shipping_address][:country], country_code)
            
            if params.has_key?(:phone)
              phone = params.delete(:phone).to_s
          
              # Whipe all non digits
              phone.gsub!(/\D+/, '')
              
              if ['US', 'CA'].include?(country_code) && phone =~ /(\d{3})(\d{3})(\d{4})$/
                add_field('night_phone_a', $1) 
                add_field('night_phone_b', $2) 
                add_field('night_phone_c', $3) 
              else
                add_field('night_phone_b', phone)                
              end
            end
              
            province_code = params.delete(:state)
                       
            case country_code
            when 'CA'
              add_field(mappings[:shipping_address][:state], CANADIAN_PROVINCES[province_code.upcase]) unless province_code.nil?
            when 'US'
              add_field(mappings[:shipping_address][:state], province_code)
            else
              add_field(mappings[:shipping_address][:state], province_code.blank? ? 'N/A' : province_code)
            end
              
            # Everything else 
            params.each do |k, v|
              field = mappings[:shipping_address][k]
              add_field(field, v) unless field.nil?
            end
          end
          
          mapping :tax, 'tax'
          mapping :shipping, 'shipping'
          mapping :cmd, 'cmd'
          mapping :custom, 'custom'
          mapping :src, 'src'
          mapping :sra, 'sra'
          %w(a p t).each do |l|
            (1..3).each do |i|
              mapping "#{l}#{i}".to_sym, "#{l}#{i}"
            end
          end
        end
      end
    end
  end
end


