# test_easy_broker_client.rb
require 'minitest/autorun'
require_relative 'easy_broker_client'
require 'json'

class FakeResponse
  attr_reader :code, :body
  def initialize(body_obj, code = '200', headers = {})
    @body = body_obj.is_a?(String) ? body_obj : body_obj.to_json
    @code = code.to_s
    @headers = headers.transform_keys { |k| k.to_s }
  end

  # Permite leer headers como resp['Retry-After']
  def [](key)
    @headers[key.to_s] || @headers[key.to_sym]
  end
end

# Cliente HTTP falso basado en path->secuencia de respuestas
class FakeHttpClient
  def initialize(responses_by_page_sequence = {})
    # responses_by_page_sequence: { page => [FakeResponse1, FakeResponse2, ...] }
    @sequences = {}
    responses_by_page_sequence.each do |page, seq|
      @sequences[page] = seq.dup
    end
  end

  # Recibe Net::HTTP::Get (req.path contiene query). Retorna el siguiente elemento de la secuencia para esa página.
  def request(req)
    query = (req.path.include?('?') ? req.path.split('?', 2).last : '')
    page_param = query.split('&').find { |p| p.start_with?('page=') }
    page = page_param ? page_param.split('=',2).last.to_i : 1

    seq = @sequences[page] || []
    if seq.empty?
      # por defecto responder array vacío (última página)
      FakeResponse.new({ "content" => [] })
    else
      seq.shift
    end
  end
end

class EasyBrokerClientTest < Minitest::Test
  def test_fetch_all_properties_multiple_pages
    page1 = { "content" => [ { "title" => "Casa A" }, { "title" => "Casa B" } ] }
    page2 = { "content" => [ { "title" => "Casa C" } ] }

    fake_http = FakeHttpClient.new({
      1 => [ FakeResponse.new(page1) ],
      2 => [ FakeResponse.new(page2) ]
    })

    client = EasyBrokerClient.new(api_key: 'test', base_url: 'https://api.test/v1',
                                 per_page: 2, http_client: fake_http,
                                 max_retries: 0, backoff_factor: 0, sleep_proc: ->(_) {})

    all = client.fetch_all_properties
    titles = all.map { |p| p['title'] }
    assert_equal ['Casa A', 'Casa B', 'Casa C'], titles
  end

  def test_extract_items_handles_array_response
    arr = [ { "title" => "X" }, { "title" => "Y" } ]
    fake_http = FakeHttpClient.new({ 1 => [ FakeResponse.new(arr) ] })
    client = EasyBrokerClient.new(api_key: 'test', base_url: 'https://api.test/v1',
                                 per_page: 10, http_client: fake_http,
                                 max_retries: 0, backoff_factor: 0, sleep_proc: ->(_) {})
    all = client.fetch_all_properties
    assert_equal 2, all.length
  end

  def test_retry_on_429
    # Página 1: primero 429, luego 200 con contenido
    resp_429 = FakeResponse.new({ "message" => "too many requests" }, '429')
    resp_ok  = FakeResponse.new({ "content" => [ { "title" => "Retry House" } ] }, '200')

    fake_http = FakeHttpClient.new({
      1 => [ resp_429, resp_ok ]
    })

    # sleep_proc no bloqueante para test
    client = EasyBrokerClient.new(api_key: 'test', base_url: 'https://api.test/v1',
                                 per_page: 10, http_client: fake_http,
                                 max_retries: 3, backoff_factor: 0.0, sleep_proc: ->(s) {})

    all = client.fetch_all_properties
    assert_equal 1, all.length
    assert_equal 'Retry House', all.first['title']
  end

  def test_retry_exhaustion_raises
    # Siempre 429
    resp_429 = FakeResponse.new({ "message" => "too many requests" }, '429')
    fake_http = FakeHttpClient.new({ 1 => [ resp_429, resp_429, resp_429, resp_429 ] })

    client = EasyBrokerClient.new(api_key: 'test', base_url: 'https://api.test/v1',
                                 per_page: 10, http_client: fake_http,
                                 max_retries: 2, backoff_factor: 0.0, sleep_proc: ->(s) {})

    err = assert_raises(RuntimeError) { client.fetch_all_properties }
    assert_match /Failed after 2 retries/, err.message
  end

  def test_malformed_json_raises
    # Respuesta 200 pero body no es JSON válido
    bad_body = "this is not json"
    resp_bad = FakeResponse.new(bad_body, '200')
    fake_http = FakeHttpClient.new({ 1 => [ resp_bad ] })

    client = EasyBrokerClient.new(api_key: 'test', base_url: 'https://api.test/v1',
                                 per_page: 10, http_client: fake_http,
                                 max_retries: 0, backoff_factor: 0.0, sleep_proc: ->(s) {})

    err = assert_raises(RuntimeError) { client.fetch_all_properties }
    assert_match /Response is not valid JSON/, err.message
  end
end
