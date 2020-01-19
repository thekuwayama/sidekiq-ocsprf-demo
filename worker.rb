# frozen_string_literal: true

require 'ocsp_response_fetch'
require 'openssl'
require 'redis'
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

  # @param subject [String] path to the subject certificate
  # @param issuer [String] path to the issuer certificate
  # @param key [String]
  def perform(subject, issuer, key = 'sidekiq-ocsprf-demo')
    subject_cert, issuer_cert = FetchWorker.read_certs(subject, issuer)
    fetcher = OCSPResponseFetch::Fetcher.new(subject_cert, issuer_cert)

    ocsp_response = nil
    begin
      ocsp_response = fetcher.run
    rescue OCSPResponseFetch::Error::RevokedError
      # TODO: alert
      FetchWorker.perform_in(1.hours, subject, issuer, key)
      return
    rescue OCSPResponseFetch::Error::Error
      # re-schedule: retry
      FetchWorker.perform_in(1.hours, subject, issuer, key)
      return
    end

    FetchWorker.write_cache(key, ocsp_response)

    # re-schedule: next update
    cid = OpenSSL::OCSP::CertificateId.new(subject_cert, issuer_cert)
    next_schedule = FetchWorker.sub_next_update(ocsp_response, cid)
    next_schedule = 7.days if next_schedule.negative?
    FetchWorker.perform_in(next_schedule, subject, issuer, key)
  end

  class << self
    # @param subject [String] path to the subject certificate
    # @param issuer [String] path to the issuer certificate
    #
    # @return [Array of OpenSSL::X509::Certificate]
    def read_certs(subject, issuer)
      subject_cert = OpenSSL::X509::Certificate.new(File.read(subject))
      issuer_cert = OpenSSL::X509::Certificate.new(File.read(issuer))

      [subject_cert, issuer_cert]
    end

    # @param key [String]
    # @param ocsp_response [OpenSSL::OCSP::Response]
    def write_cache(key, ocsp_response)
      redis = Redis.new(host: 'localhost', port: 6379)
      redis.set(key, ocsp_response.to_der)
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
