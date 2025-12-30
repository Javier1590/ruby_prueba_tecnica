# easy_broker_client.rb
require 'net/http'
require 'uri'
require 'json'

class EasyBrokerClient
  DEFAULT_BASE = 'https://api.stagingeb.com/v1'.freeze

  RetryableError = Class.new(StandardError)

  def initialize(api_key:, base_url: DEFAULT_BASE, per_page: 50,
                 http_client: nil, max_retries: 3, backoff_factor: 0.5, sleep_proc: nil)
    raise ArgumentError, "api_key is required" if api_key.nil? || api_key.strip.empty?

    @api_key = api_key
    @base_url = base_url.chomp('/')
    @per_page = per_page
    @http_client = http_client
    @max_retries = max_retries
    @backoff_factor = backoff_factor
    @sleep_proc = sleep_proc || ->(s) { Kernel.sleep(s) }
  end

  def fetch_all_properties
    page = 1
    all = []

    loop do
      data = fetch_page_with_retries(page)
      items = extract_items(data)

      break if items.empty?

      all.concat(items)
      break if items.length < @per_page
      page += 1
    end

    all
  end

  def print_titles
    fetch_all_properties.each do |prop|
      title = prop['title'] || prop['name'] || prop['public_id'] || prop['id'] || '(sin título)'
      puts title
    end
  end

  private

  def fetch_page_with_retries(page)
    attempts = 0

    begin
      attempts += 1
      resp = fetch_page_raw(page)
      code = resp.code.to_i

      if code == 429
        wait = parse_retry_after(resp) || compute_backoff(attempts)
        raise RetryableError, "429 Too Many Requests (wait #{wait}s)"
      end

      if code >= 500
        raise RetryableError, "Server error #{code}"
      end

      unless code.between?(200, 299)
        raise StandardError, "HTTP error #{code}: #{resp.body}"
      end

      parse_json(resp.body)

    rescue RetryableError => e
      if attempts <= @max_retries
        @sleep_proc.call(compute_backoff(attempts))
        retry
      else
        raise "Failed after #{@max_retries} retries: #{e.message}"
      end

    rescue JSON::ParserError => e
      raise "Response is not valid JSON: #{e.message}"
    end
  end

  def fetch_page_raw(page)
    uri = URI.parse("#{@base_url}/properties?page=#{page}&limit=#{@per_page}")
    req = Net::HTTP::Get.new(uri)
    req['accept'] = 'application/json'
    req['X-Authorization'] = @api_key

    if @http_client
      @http_client.request(req)
    else
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.request(req)
    end
  end

  def parse_json(body)
    JSON.parse(body)
  end

  def extract_items(data)
    return [] if data.nil?

    if data.is_a?(Array)
      data
    elsif data.is_a?(Hash)
      data['content'] || data['data'] || data['properties'] || []
    else
      []
    end
  end

  def compute_backoff(attempts)
    @backoff_factor * (2 ** (attempts - 1))
  end

  def parse_retry_after(resp)
    return nil unless resp.respond_to?(:[])

    header = resp['Retry-After']
    return nil if header.nil?

    header.to_i if header =~ /^\d+$/
  end
end