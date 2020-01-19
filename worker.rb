# frozen_string_literal: true

require 'ocsp_response_fetch'
require 'openssl'
require 'sidekiq'

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379' }
end

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379' }
end

class FetchWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform
    subject_cert, issuer_cert = FetchWorker.read_certs
    fetcher = OCSPResponseFetch::Fetcher.new(subject_cert, issuer_cert)

    ocsp_response = nil
    begin
      ocsp_response = fetcher.run
    rescue OCSPResponseFetch::Error::RevokedError
      # TODO: alert
      FetchWorker.perform_in(1.hours)
      return
    rescue OCSPResponseFetch::Error::Error
      # re-schedule: retry
      FetchWorker.perform_in(1.hours)
      return
    end

    FetchWorker.write_cache(ocsp_response.to_der)

    # re-schedule: next update
    cid = OpenSSL::OCSP::CertificateId.new(subject_cert, issuer_cert)
    next_schedule = FetchWorker.sub_next_update(ocsp_response, cid)
    next_schedule = 7.days if next_schedule.negative?
    FetchWorker.perform_in(next_schedule)
  end

  class << self
    # @return [Array of OpenSSL::X509::Certificate]
    def read_certs
      subject_cert = OpenSSL::X509::Certificate.new(
        File.read(ENV['OCSPRF_SUBJECT_CERT_PATH'])
      )
      issuer_cert = OpenSSL::X509::Certificate.new(
        File.read(ENV['OCSPRF_ISSUER_CERT_PATH'])
      )

      [subject_cert, issuer_cert]
    end

    # @param der [String]
    def write_cache(der)
      File.binwrite(
        ENV.fetch('OCSPRF_CACHE_FILE_PATH', '/tmp/ocsp_response.der'),
        der
      )
    end

    # @param ocsp_response [OpenSSL::OCSP::Response]
    # @param cid [OpenSSL::OCSP::CertificateId]
    # @param now [Time]
    #
    # @return [Float] How many seconds later OCSP Response next update is?
    def sub_next_update(ocsp_response, cid, now = Time.now)
      next_update = ocsp_response.basic.find_response(cid).next_update
      next_update - now
    end
  end
end

# init schedule
FetchWorker.perform_async
