class QuestionsHttpClient

  def initialize(base_url = Settings.pq_rest_api.url, username = Settings.pq_rest_api.username, password = Settings.pq_rest_api.password)
    @base_url = base_url
    @username = username
    @password = password

    @client = HTTPClient.new
    @client.set_auth(@base_url, @username, @password)
    @client.connect_timeout = Settings.http_client_timeout
    @client.receive_timeout = Settings.http_client_timeout
  end

  def questions(options = {})
    endpoint = URI::join(@base_url, '/api/qais/questions')
    begin
      response = @client.get(endpoint, options)
      if response.status_code==200
        response.content
      else
        rails_log_error "Import API call returned #{response.status_code}"
        email_params={
            code: response.status_code,
            time: Time.now
        }
        PqMailer.import_fail_email(email_params).deliver
        raise 'API response non-valid'
      end
    rescue HTTPClient::ConnectTimeoutError
      rails_log_error "Connecting to API timed out after #{Settings.http_client_timeout}"

    rescue HTTPClient::ReceiveTimeoutError
      rails_log_error "Receiving from API timed out after #{Settings.http_client_timeout}"
    end
  end

  def question(uin)
    endpoint = URI::join(@base_url, "/api/qais/questions/#{uin}")
    response = @client.get(endpoint)
    response.content
  end

  def answer(uin, body)
    endpoint = URI::join(@base_url, "/api/qais/answers/#{uin}")
    response = @client.put(endpoint, body)
    {content: response.content, status: response.status}
  end

  private
  def rails_log_error(msg)
    Rails.logger.info msg
    $statsd.increment "#{StatsHelper::IMPORT_ERROR}"
  end
end