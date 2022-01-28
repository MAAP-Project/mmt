class CumulusApi
  def self.trigger_ingest(collection_data)
    Rails.logger.info "Triggering ingest"
    token = generate_token
    headers = {
      'Content-Type': 'application/json',
      'Authorization': "Bearer #{token}"
    }
    collection = cumulus_collection(collection_data)[:collection]
    body = {
      workflow: 'DiscoverAndQueueGranulesWorkflow',
      collection: {
        name: collection[:name],
        version: collection[:version]
      },
      provider: 'maap-landing-zone',
      name: "mmt___#{collection[:name]}_#{DateTime.now().to_default_s.gsub(/\D/, '_')}",
      rule: {
        type: 'onetime',
        value: ''
      },
      meta: {},
      state: 'ENABLED'
    }.to_json
    response = HTTParty.post(
      ingest_url,
      body: body,
      headers: headers
    )
    response
  end

  def self.cumulus_collection(collection_data)
    return {
      collection: {
        name: collection_data['ShortName'],
        version: collection_data['Version']
      }
    }
  end

  def self.generate_token
    response = Net::HTTP.post(
      URI(get_redirect_url),
      { credentials: auth_string }.to_json,
      { 'Content-Type': 'application/json', 'User-Agent': 'Net:HTTP', Origin: 'localhost'}
    )
    return JSON.parse(HTTParty.get(response['Location']).body)['message']['token']
  end

  def self.get_redirect_url
    response = HTTParty.get(authorize_url, follow_redirects: false)
    response.headers['location']
  end

  def self.authorize_url
    "#{ENV['CUMULUS_REST_API']}/token"
  end

  def self.ingest_url
    "#{ENV['CUMULUS_REST_API']}/rules"
  end

  def self.auth_string
    string = "#{ENV['EARTHDATA_USERNAME']}:#{ENV['EARTHDATA_PASSWORD']}"
    Base64.encode64(string).gsub("\n", '')
  end
end
