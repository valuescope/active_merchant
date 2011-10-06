require 'net/http'

# TODO: Write tests, check and implement recurring trial payments

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paypal
        # This is a @wip - currently it works for recurring subscription payments !!!
        # Parser and handler for incoming Recurring payment notifications from paypal.
        # The Example shows a typical handler in a rails application. Note that this
        # is an example, please read the Paypal API documentation for all the details
        # on creating a safe payment controller.
        #
        # Example
        #
        #   class BackendController < ApplicationController
        #     include ActiveMerchant::Billing::Integrations
        #
        #     def paypal_ipn
        #       notify = Paypal::RecurringNotification.new(request.raw_post)
        #
        #       order = Order.find(notify.item_id)
        #
        #       if notify.acknowledge
        #         begin
        #
        #           if notify.complete? and order.total == notify.amount
        #             order.status = 'success'
        #
        #             shop.ship(order)
        #           else
        #             logger.error("Failed to verify Paypal's notification, please investigate")
        #           end
        #
        #         rescue => e
        #           order.status        = 'failed'
        #           raise
        #         ensure
        #           order.save
        #         end
        #       end
        #
        #       render :nothing
        #     end
        #   end
        class RecurringNotification < ActiveMerchant::Billing::Integrations::Notification
          # Trial period subscription is not supported atm
          include PostsData

          def initialize(post, options = {})
            super(post, options)
            raise StandardError, "Not a recurring Payment" if params['recurring'] != '1' || type != 'subscr_signup'
          end

          # Was the transaction complete?
          def complete?
            status == "verified"
          end

          # is this a trial Recurring Payment
          def trial?
            params['period1'] || params['period2'] ? true : false
          end

          # When the client subscribed
          # sometimes it can happen that we get the notification much later.
          # One possible scenario is that our web application was down. In this case paypal tries several
          # times an hour to inform us about the notification
          def subscribed_at
            Time.parse params['subscr_date']
          end

          # Status of transaction. List of possible values:
          # <tt>verified</tt>::
          # <tt>unverified</tt>::
          def status
            params['payer_status']
          end

          # Id of this transaction (paypal number)
          def transaction_id
            params['subscr_id']
          end

          # What type of transaction are we dealing with?
          def type
            params['txn_type']
          end

          # the money amount we received in X.2 decimal.
          def gross
            params['mc_amount1'] || params['mc_amount2'] || params['mc_amount3']
          end

          # the markup paypal charges for the transaction
          def fee
            params['mc_fee']
          end

          # What currency have we been dealing with
          def currency
            params['mc_currency']
          end

          # This is the item number which we submitted to paypal
          # The custom field is also mapped to item_id because PayPal
          # doesn't return item_number in dispute notifications
          def item_id
            params['item_number'] || params['custom']
          end

          # This is the invoice which you passed to paypal
          def invoice
            params['invoice']
          end

          # Was this a test transaction?
          def test?
            params['test_ipn'] == '1'
          end

          def account
            params['business'] || params['receiver_email']
          end

          # Acknowledge the transaction to paypal. This method has to be called after a new
          # ipn arrives. Paypal will verify that all the information we received are correct and will return a
          # ok or a fail.
          #
          # Example:
          #
          #   def paypal_ipn
          #     notify = PaypalNotification.new(request.raw_post)
          #
          #     if notify.acknowledge
          #       ... process order ... if notify.complete?
          #     else
          #       ... log possible hacking attempt ...
          #     end
          def acknowledge
            payload =  raw

            response = ssl_post(Paypal.service_url + '?cmd=_notify-validate', payload,
              'Content-Length' => "#{payload.size}",
              'User-Agent'     => "Active Merchant -- http://activemerchant.org"
            )

            raise StandardError.new("Faulty paypal result: #{response}") unless ["VERIFIED", "INVALID"].include?(response)

            response == "VERIFIED"
          end

          alias :subscription_id :transaction_id
        end
      end
    end
  end
end
