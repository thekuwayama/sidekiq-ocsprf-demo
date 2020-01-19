# sidekiq-ocsprf-demo

Run the following command to start `ocsprf`(OCSP Response Fetch) task scheduler.

```bash
$ bundle install

$ redis-server &

$ export OCSPRF_SUBJECT_CERT_PATH=/path/to/subject/certificate

$ export OCSPRF_ISSUER_CERT_PATH=/path/to/issuer/certificate

$ bundle exec sidekiq -r ./worker.rb
```

And, you can get a DER-encoded OCSP Response corresponding to the subject certificate.

```bash
$ redis-cli GET sidekiq-ocsprf-demo
```
