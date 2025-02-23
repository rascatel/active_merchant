require 'test_helper'

class RemoteAuthorizeNetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetGateway.new(fixtures(:authorize_net))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @check = check
    @declined_card = credit_card('400030001111222')

    @payment_token = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: 'dGVzdGNyeXB0b2dyYW1YWFhYWFhYWFhYWFg9PQ==',
      brand: 'visa',
      eci: '05',
      month: '09',
      year: '2030',
      first_name: 'Longbob',
      last_name: 'Longsen'
    )

    @options = {
      order_id: '1',
      email: 'anet@example.com',
      duplicate_window: 0,
      billing_address: address,
      description: 'Store Purchase'
    }

    @level_2_options = {
      tax: {
        amount: '100',
        name: 'tax name',
        description: 'tax description'
      },
      duty: {
        amount: '200',
        name: 'duty name',
        description: 'duty description'
      },
      shipping: {
        amount: '300',
        name: 'shipping name',
        description: 'shipping description'
      },
      tax_exempt: 'false',
      po_number: '123'
    }

    @level_3_options = {
      ship_from_address: {
        zip: '27701',
        country: 'US'
      },
      summary_commodity_code: 'CODE'
    }

    @level_2_and_3_options = @level_2_options.merge(@level_3_options)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_google_pay
    @payment_token.source = :google_pay
    response = @gateway.purchase(@amount, @payment_token, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_apple_pay
    @payment_token.source = :apple_pay
    response = @gateway.purchase(@amount, @payment_token, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card, duplicate_window: 0, email: 'anet@example.com', billing_address: address)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_email_customer
    response = @gateway.purchase(@amount, @credit_card, duplicate_window: 0, email_customer: true, email: 'anet@example.com', billing_address: address)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_false_email_customer
    response = @gateway.purchase(@amount, @credit_card, duplicate_window: 0, email_customer: false, email: 'anet@example.com', billing_address: address)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_header_email_receipt
    response = @gateway.purchase(@amount, @credit_card, duplicate_window: 0, header_email_receipt: 'subject line', email: 'anet@example.com', billing_address: address)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_line_items
    additional_options = {
      email: 'anet@example.com',
      line_items: [
        {
          item_id: '1',
          name: 'mug',
          description: 'coffee',
          quantity: '100',
          unit_price: '10'
        },
        {
          item_id: '2',
          name: 'vase',
          description: 'floral',
          quantity: '200',
          unit_price: '20'
        }
      ]
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(additional_options))
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_level_3_line_item_data
    additional_options = {
      email: 'anet@example.com',
      line_items: [
        {
          item_id: '1',
          name: 'mug',
          description: 'coffee',
          quantity: '100',
          unit_price: '10',
          unit_of_measure: 'yards',
          total_amount: '1000',
          product_code: 'coupon'
        }
      ]
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(additional_options))
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_level_2_and_3_data
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@level_2_and_3_options))
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_purchase_with_customer
    response = @gateway.purchase(@amount, @credit_card, @options.merge(customer: 'abcd_123'))
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
    assert_equal 'incorrect_number', response.error_code
  end

  def test_successful_purchase_with_utf_character
    card = credit_card('4000100011112224', last_name: 'Wåhlin')
    response = @gateway.purchase(@amount, card, @options)
    assert_success response
    assert_match %r{This transaction has been approved}, response.message
  end

  def test_successful_echeck_purchase_with_checking_account_type
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_echeck_purchase_with_savings_account_type
    savings_account = check(account_type: 'savings')
    response = @gateway.purchase(@amount, savings_account, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_card_present_purchase_with_no_data
    no_data_credit_card = ActiveMerchant::Billing::CreditCard.new
    response = @gateway.purchase(@amount, no_data_credit_card, @options)
    assert_failure response
    assert_match %r{invalid}, response.message
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired', response.message
    assert_equal 'expired_card', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_purchase_with_disable_partial_authorize
    purchase = @gateway.purchase(46225, @credit_card, @options.merge(disable_partial_auth: true))
    assert_success purchase
  end

  def test_successful_auth_and_capture_with_recurring_stored_credential
    stored_credential_params = {
      initial_transaction: true,
      reason_type: 'recurring',
      initiator: 'cardholder',
      network_transaction_id: nil
    }
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_params }))
    assert_success auth
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:stored_credential] = {
      initial_transaction: false,
      reason_type: 'recurring',
      initiator: 'merchant',
      network_transaction_id: auth.params['network_trans_id']
    }

    assert next_auth = @gateway.authorize(@amount, @credit_card, @options)
    assert next_auth.authorization

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_auth_and_capture_with_unscheduled_stored_credential
    stored_credential_params = {
      initial_transaction: true,
      reason_type: 'unscheduled',
      initiator: 'cardholder',
      network_transaction_id: nil
    }
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_params }))
    assert_success auth
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:stored_credential] = {
      initial_transaction: false,
      reason_type: 'unscheduled',
      initiator: 'merchant',
      network_transaction_id: auth.params['network_trans_id']
    }

    assert next_auth = @gateway.authorize(@amount, @credit_card, @options)
    assert next_auth.authorization

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_auth_and_capture_with_installment_stored_credential
    stored_credential_params = {
      initial_transaction: true,
      reason_type: 'installment',
      initiator: 'cardholder',
      network_transaction_id: nil
    }
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_params }))
    assert_success auth
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:stored_credential] = {
      initial_transaction: false,
      reason_type: 'installment',
      initiator: 'merchant',
      network_transaction_id: auth.params['network_trans_id']
    }

    assert next_auth = @gateway.authorize(@amount, @credit_card, @options)
    assert next_auth.authorization

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_authorize_with_email_and_ip
    options = @options.merge({ email: 'hello@example.com', ip: '127.0.0.1' })
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
  end

  def test_card_present_authorize_and_capture_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(track_data: '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    assert authorization = @gateway.authorize(@amount, track_credit_card, @options)
    assert_success authorization

    capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture

    assert_equal 'This transaction has been approved', capture.message
  end

  def test_successful_echeck_authorization
    response = @gateway.authorize(@amount, @check, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_failed_echeck_authorization
    response = @gateway.authorize(@amount, check(routing_number: '121042883'), @options)
    assert_failure response
    assert_equal 'The ABA code is invalid', response.message
    assert response.authorization
  end

  def test_card_present_purchase_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(track_data: '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    response = @gateway.purchase(@amount, track_credit_card, @options)
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_moto_retail_type
    @credit_card.manual_entry = true
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end

  def test_successful_authorization_with_moto_retail_type
    @credit_card.manual_entry = true
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_phone_number
    @options[:billing_address][:phone] = nil
    @options[:billing_address][:phone_number] = '5554443210'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal response.responses.count, 2
  end

  def test_successful_verify_with_no_address
    @options[:billing_address] = nil
    response = @gateway.verify(@credit_card, @options)

    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal response.responses.count, 2
  end

  def test_successful_verify_with_verify_amount_and_billing_address
    @options[:verify_amount] = 1
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert_equal response.responses.count, 2
  end

  def test_successful_verify_after_store_with_custom_verify_amount
    @options[:verify_amount] = 1
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    response = @gateway.verify(store.authorization, @options)
    assert_success response
    assert_equal response.responses.count, 2
  end

  def test_successful_verify_with_apple_pay
    credit_card = network_tokenization_credit_card('4242424242424242', payment_cryptogram: '111111111100cryptogram')
    response = @gateway.verify(credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_verify_with_check
    response = @gateway.verify(@check, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_successful_verify_with_nil_custom_verify_amount
    @options[:verify_amount] = nil
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_verify_tpt_with_custom_verify_amount_and_no_address
    @options[:verify_amount] = 100
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    @options[:billing_address] = nil
    response = @gateway.verify(store.authorization, @options)
    assert_success response
  end

  def test_failed_verify
    bogus_card = credit_card('4424222222222222')
    response = @gateway.verify(bogus_card, @options)
    assert_failure response
    assert_match %r{The credit card number is invalid}, response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert response.authorization
    assert_equal 'Successful', response.message
    assert_equal '1', response.params['message_code']
  end

  def test_successful_store_new_payment_profile
    assert store = @gateway.store(@credit_card)
    assert_success store
    assert store.authorization

    new_card = credit_card('4424222222222222')
    customer_profile_id, = store.authorization.split('#')

    assert response = @gateway.store(new_card, customer_profile_id: customer_profile_id)
    assert_success response
    assert_equal 'Successful', response.message
    assert_equal '1', response.params['message_code']
  end

  def test_failed_store_new_payment_profile
    assert store = @gateway.store(@credit_card)
    assert_success store
    assert store.authorization

    new_card = credit_card('141241')
    customer_profile_id, = store.authorization.split('#')

    assert response = @gateway.store(new_card, customer_profile_id: customer_profile_id)
    assert_failure response
    assert_equal 'The field length is invalid for Card Number', response.message
  end

  def test_failed_store
    assert response = @gateway.store(credit_card('141241'))
    assert_failure response
    assert_equal 'The field length is invalid for Card Number', response.message
    assert_equal '15', response.params['message_code']
  end

  def test_successful_purchase_using_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
  end

  def test_successful_purchase_using_stored_card_with_delimiter
    response = @gateway.store(@credit_card, @options.merge(delimiter: '|'))
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options.merge(delimiter: '|', description: 'description, with, commas'))
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
    assert_equal 'description, with, commas', response.params['order_description']
  end

  def test_failed_purchase_using_stored_card
    response = @gateway.store(@declined_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid.', response.message
    assert_equal 'incorrect_number', response.error_code
    assert_equal '27', response.params['message_code']
    assert_equal '6', response.params['response_reason_code']
    assert_match %r{Address not verified}, response.avs_result['message']
  end

  def test_successful_purchase_using_stored_card_new_payment_profile
    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.authorization

    new_card = credit_card('4007000000027')
    customer_profile_id, = store.authorization.split('#')

    assert response = @gateway.store(new_card, customer_profile_id: customer_profile_id, email: 'anet@example.com', billing_address: address)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
  end

  def test_successful_purchase_with_stored_card_and_level_2_and_3_data
    store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.authorization, @options.merge(@level_2_and_3_options))
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
  end

  def test_successful_authorize_and_capture_using_stored_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth
    assert_equal 'This transaction has been approved.', auth.message

    capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'This transaction has been approved.', capture.message
  end

  def test_successful_authorize_and_capture_using_stored_card_with_level_2_and_3_data
    store = @gateway.store(@credit_card, @options)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options.merge(@level_2_and_3_options))
    assert_success auth
    assert_equal 'This transaction has been approved.', auth.message

    capture = @gateway.capture(@amount, auth.authorization, @options.merge(@level_2_and_3_options))
    assert_success capture
    assert_equal 'This transaction has been approved.', capture.message
  end

  def test_failed_authorize_using_stored_card
    response = @gateway.store(@declined_card)
    assert_success response

    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_failure response

    assert_equal 'The credit card number is invalid.', response.message
    assert_equal 'incorrect_number', response.error_code
    assert_equal '27', response.params['message_code']
    assert_equal '6', response.params['response_reason_code']
    assert_match %r{Address not verified}, response.avs_result['message']
  end

  def test_failed_authorize_using_wrong_token
    response = @gateway.store(@declined_card)
    assert_success response

    responseA = @gateway.authorize(@amount, response.authorization, @options.merge(customer_payment_profile_id: 12345))
    responseB = @gateway.authorize(@amount, response.authorization, @options.merge(customer_profile_id: 12345))
    assert_failure responseA
    assert_failure responseB

    assert_equal 'Customer Profile ID or Customer Payment Profile ID not found', responseA.message
    assert_equal 'Customer Profile ID or Customer Payment Profile ID not found', responseB.message
  end

  def test_failed_capture_using_stored_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth

    capture = @gateway.capture(@amount + 4000, auth.authorization, @options)
    assert_failure capture
    assert_match %r{The amount requested for settlement cannot be greater}, capture.message
  end

  def test_faux_successful_refund_with_billing_address
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options.merge(first_name: 'Jim', last_name: 'Smith'))
    assert_failure refund
    assert_match %r{does not meet the criteria for issuing a credit}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_faux_successful_refund_without_billing_address
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @options[:billing_address] = nil

    refund = @gateway.refund(@amount, purchase.authorization, @options.merge(first_name: 'Jim', last_name: 'Smith'))
    assert_failure refund
    assert_match %r{does not meet the criteria for issuing a credit}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_faux_successful_refund_using_stored_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_failure refund
    assert_match %r{does not meet the criteria for issuing a credit}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_faux_successful_refund_using_stored_card_and_level_2_and_3_data
    store = @gateway.store(@credit_card, @options)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options.merge(@level_2_and_3_options))
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options.merge(@level_2_and_3_options))
    assert_failure refund
    assert_match %r{does not meet the criteria for issuing a credit}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_failed_refund_using_stored_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase

    unknown_authorization = '2235494048#XXXX2224#cim_purchase'
    refund = @gateway.refund(@amount, unknown_authorization, @options)
    assert_failure refund
    assert_equal 'The record cannot be found', refund.message
  end

  def test_successful_void_using_stored_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth

    void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal 'This transaction has been approved.', void.message
  end

  def test_failed_void_using_stored_card
    store = @gateway.store(@credit_card, @options)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options)
    assert_success auth

    void = @gateway.void(auth.authorization, @options)
    assert_success void

    another_void = @gateway.void(auth.authorization, @options)
    assert_failure another_void
    assert_equal 'This transaction has already been voided.', another_void.message
  end

  def test_bad_login
    gateway = AuthorizeNetGateway.new(
      login: 'X',
      password: 'Y'
    )

    response = gateway.purchase(@amount, @credit_card)
    assert_failure response

    assert_equal %w(
      account_number
      action
      authorization_code
      avs_result_code
      card_code
      cardholder_authentication_code
      full_response_code
      network_trans_id
      response_code
      response_reason_code
      response_reason_text
      test_request
      transaction_id
    ), response.params.keys.sort

    assert_equal 'User authentication failed due to invalid authentication values', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(20, '23124#1234')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = 'A1000000'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  ensure
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = nil
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_successful_echeck_credit
    response = @gateway.credit(@amount, @check, @options)
    assert_equal 'The transaction is currently under review', response.message
    assert response.authorization
  end

  def test_successful_echeck_refund
    purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    @options.update(transaction_id: purchase.params['transaction_id'], test_request: true)
    refund = @gateway.credit(@amount, @check, @options)
    assert_failure refund
    assert_match %r{The transaction cannot be found}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_successful_echeck_refund_truncates_long_account_name
    check_with_long_name = check(name: 'Michelangelo Donatello-Raphael')
    purchase = @gateway.purchase(@amount, check_with_long_name, @options)
    assert_success purchase

    @options.update(first_name: check_with_long_name.first_name, last_name: check_with_long_name.last_name, routing_number: check_with_long_name.routing_number,
                    account_number: check_with_long_name.account_number, account_type: check_with_long_name.account_type)
    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_failure refund
    assert_match %r{The transaction cannot be found}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid', response.message
    assert response.authorization
  end

  def test_bad_currency
    response = @gateway.purchase(@amount, @credit_card, currency: 'XYZ')
    assert_failure response
    assert_equal 'The supplied currency code is either invalid, not supported, not allowed for this merchant or doesn\'t have an exchange rate', response.message
  end

  def test_usd_currency
    @options[:currency] = 'USD'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
  end

  def test_dump_transcript
    # dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_successful_authorize_and_capture_with_network_tokenization
    credit_card = network_tokenization_credit_card(
      '4000100011112224',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil
    )
    auth = @gateway.authorize(@amount, credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_refund_with_network_tokenization
    credit_card = network_tokenization_credit_card(
      '4000100011112224',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil
    )

    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    @options[:billing_address] = nil

    refund = @gateway.refund(@amount, purchase.authorization, @options.merge(first_name: 'Jim', last_name: 'Smith'))
    assert_failure refund
    assert_match %r{does not meet the criteria for issuing a credit}, refund.message, 'Only allowed to refund transactions that have settled.  This is the best we can do for now testing wise.'
  end

  def test_successful_credit_with_network_tokenization
    credit_card = network_tokenization_credit_card(
      '4000100011112224',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      verification_value: nil
    )

    response = @gateway.credit(@amount, credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_network_tokenization_transcript_scrubbing
    credit_card = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_purchase_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_account_number_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, clean_transcript)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = AuthorizeNetGateway.new(login: 'unknown_login', password: 'not_right')
    assert !gateway.verify_credentials
  end
end
