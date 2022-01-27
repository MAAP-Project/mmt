require_relative 'piq_to_draft.rb'

piq_ip = 'http://ec2-18-211-240-139.compute-1.amazonaws.com:3000'
api_key = ENV['PIQ_API_KEY']
namespace :drafts do
  task :from_piq => :environment do
    client = Cmr::BaseClient.new(piq_ip, '')
    piq_data = client.send(:get, 'api/v1/questionnaires.json', {}, {
        'x-api-key': api_key
    }).body
    user = User.create({
      urs_uid: 'piq_user',
      provider_id: 'NASA_MAAP'
    })
    user.save!
    piq_data.each do |piq_entry|
      piq_entry.deep_symbolize_keys!
      native_id = piq_entry[:dataset][:title]
      draft = CollectionDraft.find_or_create_by(native_id: native_id)
      draft.draft = {}
      draft.provider_id = 'NASA_MAAP'
      converted_draft = PiqToDraft.convert(piq_entry)
      draft.update_draft(converted_draft, user.id)
      if draft.save!
        print("Saved draft with native id: \'#{native_id}\'!\n")
      else
        print("Failed to save draft with with native_id: #{native_id}.\n")
      end
    end
  end
end
