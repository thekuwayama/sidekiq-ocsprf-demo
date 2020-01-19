# sidekiq-ocsprf

```bash
$ bundle install

$ redis-server &

$ export OCSPRF_SUBJECT_CERT_PATH=/path/to/subject/certificate

$ export OCSPRF_ISSUER_CERT_PATH=/path/to/issuer/certificate

$ bundle exec sidekiq -r ./worker.rb
```
