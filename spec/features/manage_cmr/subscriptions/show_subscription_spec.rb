describe 'When Viewing Subscription Show Page' do
  before do
    login
    allow_any_instance_of(SubscriptionPolicy).to receive(:create?).and_return(true)
    allow_any_instance_of(SubscriptionPolicy).to receive(:show?).and_return(true)
  end

  context 'when visiting the show page with read access' do
    before do
      # make a record
      @native_id = 'test_native_id'
      @ingest_response, _concept_response, @subscription = publish_new_subscription(native_id: @native_id)
      # go to show page
      VCR.use_cassette('urs/rarxd5taqea', record: :none) do
        visit subscription_path(@ingest_response['concept_id'])
      end
    end

    after do
      delete_response = cmr_client.delete_subscription('MMT_2', @native_id, 'token')

      raise unless delete_response.success?
    end

    it 'has the correct information' do
      expect(page).to have_content(@subscription['Name'])
      expect(page).to have_content(@subscription['Query'])
      expect(page).to have_content(@subscription['CollectionConceptId'])
      within '#subscriber' do
        expect(page).to have_content(@subscription['SubscriberId'])
        expect(page).to have_content(@subscription['EmailAddress'])
        expect(page).to have_content('Rvrhzxhtra Vetxvbpmxf')
      end
    end

    it 'has the correct buttons' do
      expect(page).to have_no_link('Edit')
      expect(page).to have_no_link('Delete')
    end
  end

  context 'when visiting the show page with update/delete access' do
    before do
      allow_any_instance_of(SubscriptionPolicy).to receive(:edit?).and_return(true)
      allow_any_instance_of(SubscriptionPolicy).to receive(:destroy?).and_return(true)
      # make a record
      native_id = 'test_native_id'
      @ingest_response, _concept_response, @subscription = publish_new_subscription(native_id: native_id)
      # go to show page
      VCR.use_cassette('urs/rarxd5taqea', record: :none) do
        visit subscription_path(@ingest_response['concept_id'])
      end
    end

    it 'has the correct information' do
      expect(page).to have_content(@subscription['Name'])
      expect(page).to have_content(@subscription['Query'])
      expect(page).to have_content(@subscription['CollectionConceptId'])
      within '#subscriber' do
        expect(page).to have_content(@subscription['SubscriberId'])
        expect(page).to have_content(@subscription['EmailAddress'])
        expect(page).to have_content('Rvrhzxhtra Vetxvbpmxf')
      end
    end

    it 'has the correct buttons' do
      expect(page).to have_link('Edit')
      expect(page).to have_link('Delete')
    end
  end
end