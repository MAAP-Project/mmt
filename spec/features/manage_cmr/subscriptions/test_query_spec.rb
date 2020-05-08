describe 'Testing Queries when creating', js: true do
  before do
    login
    allow_any_instance_of(SubscriptionPolicy).to receive(:create?).and_return(true)
    allow_any_instance_of(SubscriptionPolicy).to receive(:show?).and_return(true)
    @ingest_response, @concept_response = publish_collection_draft
    visit new_subscription_path
  end

  context 'when the form is incomplete' do
    before do
      click_on 'Test Subscription'
    end

    it 'validates the form' do
      expect(page).to have_content('Subscriber is required.')
      expect(page).to have_content('Query is required.')
      expect(page).to have_content('Subscription Name is required.')
      expect(page).to have_content('Collection Concept ID is required.')
    end

    it 'displays a modal with an informative message' do
      expect(page).to have_content('Please enter a valid subscription and try again.')
    end
  end

  context 'when the form is complete' do
    before do
      fill_in 'Name', with: 'valid_test_name'
      fill_in 'Query', with: 'day_night_flag=day&updated_since=2020-05-06T16:23:09Z&production_date[]=2000-01-01T10:00:00Z,2021-03-10T12:00:00Z'
      fill_in 'Collection Concept ID', with: @ingest_response['concept-id']

      VCR.use_cassette('urs/search/rarxd5taqea', record: :none) do
        within '.subscriber-group' do
          all('.select2-container .select2-selection').first.click
          # page.find('.select2-selection--single').click
        end
        page.find('.select2-search__field').native.send_keys('rarxd5taqea')

        page.find('ul#select2-subscriber-results li.select2-results__option--highlighted').click
      end
    end

    context 'when the query starts with a "?"' do
      before do
        fill_in 'Query', with: '?day_night_flag=day&updated_since=2020-05-06T16:23:09Z&production_date[]=2000-01-01T10:00:00Z,2021-03-10T12:00:00Z'
        click_on 'Test Subscription'
      end

      it 'can succeed' do
        expect(page).to have_content("Estimate Done!\n0 granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated 0.0 emails per day.")
      end
    end

    context 'when there is an error communicating with CMR' do
      before do
        cmr_response = Cmr::Response.new(Faraday::Response.new(status: 401, body: JSON.parse('{"errors": ["One of parameters [user_type] or [user_id] are required."]}'), response_headers: {}))
        allow_any_instance_of(Cmr::CmrClient).to receive(:check_user_permissions).and_return(cmr_response)
        click_on 'Test Subscription'
      end

      it 'displays an error message on the modal' do
        expect(page).to have_content("An error occurred while checking the user's permissions: One of parameters [user_type] or [user_id] are required.")
      end
    end

    context 'when the test succeeds' do
      context 'when more than max granules are found' do
        before do
          @granules_in_test = 5_000_000
          allow_any_instance_of(Cmr::CmrClient).to receive(:test_query).and_return(Cmr::Response.new(Faraday::Response.new(status: 200, body: { 'hits' => @granules_in_test } )))
          click_on 'Test Subscription'
        end

        it 'displays the right count of e-mails' do
          granule_count = (24 * 3600 / Rails.configuration.cmr_email_frequency).round(2)
          expect(page).to have_content("Estimate Done!\n#{@granules_in_test} granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated #{granule_count} emails per day.")
        end
      end

      context 'when fewer than max granules are found' do
        before do
          @granules_in_test = 20
          ingest_granules(@concept_response.body['EntryTitle'], @granules_in_test, 'MMT_2')
          wait_for_cmr
          click_on 'Test Subscription'
        end

        it 'displays the right amount of e-mails' do
          granule_count = (@granules_in_test / 30.0 * 3600 / Rails.configuration.cmr_email_frequency).round(2)
          expect(page).to have_content("Estimate Done!\n#{@granules_in_test} granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated #{granule_count} emails per day.")
        end
      end

      context 'when no granules are found' do
        before do
          click_on 'Test Subscription'
        end

        it 'displays the right amount of e-mails' do
          expect(page).to have_content("Estimate Done!\n0 granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated 0.0 emails per day.")
        end
      end
    end
  end

  context 'when the user does not have permissions to view a collection' do
    before do
      @ingest_response2, _concept_response = publish_collection_draft(provider_id: 'NSIDC_ECS', suppress_concept_query_error: true)
      fill_in 'Name', with: 'valid_test_name'
      fill_in 'Query', with: 'day_night_flag=day&updated_since=2020-05-06T16:23:09Z&production_date[]=2000-01-01T10:00:00Z,2021-03-10T12:00:00Z'
      fill_in 'Collection Concept ID', with: @ingest_response2['concept-id']

      VCR.use_cassette('urs/search/rarxd5taqea', record: :none) do
        within '.subscriber-group' do
          all('.select2-container .select2-selection').first.click
          # page.find('.select2-selection--single').click
        end
        page.find('.select2-search__field').native.send_keys('rarxd5taqea')

        page.find('ul#select2-subscriber-results li.select2-results__option--highlighted').click
      end

      click_on 'Test Subscription'
    end

    it 'displays the correct error message to the user' do
      expect(page).to have_content("Estimate failed.\nThe subscriber does not have access to the specified collection.")
    end
  end
end

describe 'Testing Queries when editing', js: true do
  before do
    login
    allow_any_instance_of(SubscriptionPolicy).to receive(:create?).and_return(false)
    allow_any_instance_of(SubscriptionPolicy).to receive(:update?).and_return(true)
    allow_any_instance_of(SubscriptionPolicy).to receive(:show?).and_return(true)
    @ingest_response, @concept_response = publish_collection_draft
    @ingest_subscription_response, @search_response, _subscription = publish_new_subscription(collection_concept_id: @ingest_response['concept-id'])
    VCR.use_cassette('urs/rarxd5taqea', record: :none) do
      visit edit_subscription_path(@ingest_subscription_response['concept_id'])
    end
  end

  after do
    delete_response = cmr_client.delete_subscription('MMT_2', @search_response.body['items'].first['meta']['native-id'], 'token')

    raise unless delete_response.success?
  end

  context 'when the form is incomplete' do
    before do
      fill_in 'Query', with: ''
      click_on 'Test Subscription'
    end

    it 'validates the form' do
      expect(page).to have_content('Query is required.')
    end

    it 'displays a modal with an informative message' do
      expect(page).to have_content('Please enter a valid subscription and try again.')
    end
  end

  context 'when the form is complete' do
    before do
      fill_in 'Query', with: 'day_night_flag=day&updated_since=2020-05-06T16:23:09Z&production_date[]=2000-01-01T10:00:00Z,2021-03-10T12:00:00Z'
    end

    context 'when the query starts with a "?"' do
      before do
        fill_in 'Query', with: '?day_night_flag=day&updated_since=2020-05-06T16:23:09Z&production_date[]=2000-01-01T10:00:00Z,2021-03-10T12:00:00Z'
        click_on 'Test Subscription'
      end

      it 'can succeed' do
        expect(page).to have_content("Estimate Done!\n0 granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated 0.0 emails per day.")
      end
    end

    context 'when there is an error communicating with CMR' do
      before do
        cmr_response = Cmr::Response.new(Faraday::Response.new(status: 401, body: JSON.parse('{"errors": ["One of parameters [user_type] or [user_id] are required."]}'), response_headers: {}))
        allow_any_instance_of(Cmr::CmrClient).to receive(:check_user_permissions).and_return(cmr_response)
        click_on 'Test Subscription'
      end

      it 'displays an error message on the modal' do
        expect(page).to have_content("An error occurred while checking the user's permissions: One of parameters [user_type] or [user_id] are required.")
      end
    end

    context 'when the test succeeds' do
      context 'when more than max granules are found' do
        before do
          @granules_in_test = 5_000_000
          allow_any_instance_of(Cmr::CmrClient).to receive(:test_query).and_return(Cmr::Response.new(Faraday::Response.new(status: 200, body: { 'hits' => @granules_in_test } )))
          click_on 'Test Subscription'
        end

        it 'displays the right count of e-mails' do
          granule_count = (24 * 3600 / Rails.configuration.cmr_email_frequency).round(2)
          expect(page).to have_content("Estimate Done!\n#{@granules_in_test} granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated #{granule_count} emails per day.")
        end
      end

      context 'when fewer than max granules are found' do
        before do
          @granules_in_test = 20
          ingest_granules(@concept_response.body['EntryTitle'], @granules_in_test, 'MMT_2')
          wait_for_cmr
          click_on 'Test Subscription'
        end

        it 'displays the right amount of e-mails' do
          granule_count = (@granules_in_test / 30.0 * 3600 / Rails.configuration.cmr_email_frequency).round(2)
          expect(page).to have_content("Estimate Done!\n#{@granules_in_test} granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated #{granule_count} emails per day.")
        end
      end

      context 'when no granules are found' do
        before do
          click_on 'Test Subscription'
        end

        it 'displays the right amount of e-mails' do
          expect(page).to have_content("Estimate Done!\n0 granules related to this query were updated over the last 30 days. Assuming an even distribution of granule updates across that time, this would have generated 0.0 emails per day.")
        end
      end
    end
  end

  context 'when the user does not have permissions to view a collection' do
    before do
      @ingest_response2, _concept_response = publish_collection_draft(provider_id: 'NSIDC_ECS', suppress_concept_query_error: true)
      @ingest_subscription_response2, @search_response2, _subscription = publish_new_subscription(collection_concept_id: @ingest_response2['concept-id'])
      VCR.use_cassette('urs/rarxd5taqea', record: :none) do
        visit edit_subscription_path(@ingest_subscription_response2['concept_id'])
      end

      click_on 'Test Subscription'
    end

    after do
      delete_response = cmr_client.delete_subscription('MMT_2', @search_response2.body['items'].first['meta']['native-id'], 'token')

      raise unless delete_response.success?
    end

    it 'displays the correct error message to the user' do
      expect(page).to have_content("Estimate failed.\nThe subscriber does not have access to the specified collection.")
    end
  end
end