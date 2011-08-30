require 'action_pack'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module ActionViewHelper
        # This helper allows the usage of different payment integrations
        # through a single form helper.  Payment integrations are the
        # type of service where the user is redirected to the secure
        # site of the service, like Paypal or Chronopay.
        #
        # The helper creates a scope around a payment service helper
        # which provides the specific mapping for that service.
        # 
        #  <% payment_service_for 1000, 'paypalemail@mystore.com',
        #                               :amount => 50.00, 
        #                               :currency => 'CAD', 
        #                               :service => :paypal, 
        #                               :html => { :id => 'payment-form' } do |service| %>
        #
        #    <% service.customer :first_name => 'Cody',
        #                       :last_name => 'Fauser',
        #                       :phone => '(555)555-5555',
        #                       :email => 'cody@example.com' %>
        #
        #    <% service.billing_address :city => 'Ottawa',
        #                              :address1 => '21 Snowy Brook Lane',
        #                              :address2 => 'Apt. 36',
        #                              :state => 'ON',
        #                              :country => 'CA',
        #                              :zip => 'K1J1E5' %>
        #
        #    <% service.invoice '#1000' %>
        #    <% service.shipping '0.00' %>
        #    <% service.tax '0.00' %>
        #
        #    <% service.notify_url url_for(:only_path => false, :action => 'notify') %>
        #    <% service.return_url url_for(:only_path => false, :action => 'done') %>
        #    <% service.cancel_return_url 'http://mystore.com' %>
        #  <% end %>
        #
        def payment_service_for(order, account, options = {}, &proc)          
          raise ArgumentError, "Missing block" unless block_given?

          integration_module = ActiveMerchant::Billing::Integrations.const_get(options.delete(:service).to_s.camelize)

          result = []
          result << form_tag(integration_module.service_url, options.delete(:html) || {})
          
          service_class = integration_module.const_get('Helper')
          service = service_class.new(order, account, options)

          result << capture(service, &proc)

          service.form_fields.each do |field, value|
            result << hidden_field_tag(field, value)
          end
         
          result << '</form>'
          result= result.join("\n")
          
          concat(result.respond_to?(:html_safe) ? result.html_safe : result)
          nil
        end

        # Paypal form helper, support encrypt data
        # If you want to encrypt data, pass the following params in options
        #   :encrypt => true,
        #   :certs_params => {
        #     :cert_id => cert_id,
        #     :cert_dir => 'cert_dir_path',
        #     :pubcert => 'pubic_cert_path',
        #     :prvkey => 'private_cert_path',
        #     :paypal_cert => 'paypal_cert_path'
        #   }
        def paypal_payment_service_for(order, account, options = {}, &proc)
          raise ArgumentError, "Missing block" unless block_given?

          integration_module = ActiveMerchant::Billing::Integrations.const_get(options.delete(:service).to_s.camelize)

          encrypt = options.delete(:encrypt)
          certs_params = options.delete(:certs_params)

          result = []
          result << form_tag(integration_module.service_url, options.delete(:html) || {})

          service_class = integration_module.const_get('Helper')
          service = service_class.new(order, account, options)

          result << capture(service, &proc)

          if encrypt
            paypal_params = { :cert_id => certs_params[:cert_id] }

            service.form_fields.each do |field, value|
              paypal_params.merge!(field => value)
            end

            result << hidden_field_tag(:cmd, "_s_xclick")
            result << "\n"
            result << hidden_field_tag(:encrypted, encrypt_for_paypal(paypal_params, certs_params))
          else
            service.form_fields.each do |field, value|
              result << hidden_field_tag(field, value)
            end
          end

          result << '</form>'
          result= result.join("\n")

          concat(result.respond_to?(:html_safe) ? result.html_safe : result)
          nil
        end

        # encrypt values
        # if you put you certs_params in:
        #   #{Rails.root}/config/paypal
        # and name them as:
        #   paypal-pubcert.pem
        #   paypal-prvkey.pem
        #   paypal-cert.pem
        # then you can use this without passing any params
        # or you should pass the path params to tell where to find the certs
        def encrypt_for_paypal(values, options = {})
          cert_dir = options[:cert_dir] || "#{Rails.root}/config/paypal"
          pubcert_file = options[:pubcert_file] || "paypal-pubcert.pem"
          prvcert_file = options[:prvcert_file] || "paypal-prvkey.pem"
          paypal_cert_file = options[:paypal_cert_file] || "paypal-cert.pem"

          app_cert_pem = File.read("#{cert_dir}/#{options[:pubcert_file]}")
          app_key_pem = File.read("#{cert_dir}/#{options[:prvcert_file]}")
          paypal_cert_pem = File.read("#{cert_dir}/#{options[:paypal_cert_file]}")

          signed = OpenSSL::PKCS7::sign(OpenSSL::X509::Certificate.new(app_cert_pem), OpenSSL::PKey::RSA.new(app_key_pem, ''), values.map { |k, v| "#{k}=#{v}" }.join("\n"), [], OpenSSL::PKCS7::BINARY)
          OpenSSL::PKCS7::encrypt([OpenSSL::X509::Certificate.new(paypal_cert_pem)], signed.to_der, OpenSSL::Cipher::Cipher::new("DES3"), OpenSSL::PKCS7::BINARY).to_s.gsub("\n", "")
        end
      end
    end
  end
end
