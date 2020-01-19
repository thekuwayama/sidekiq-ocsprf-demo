# sidekiq-ocsprf-demo

Run the following command to start `ocsprf`(OCSP Response Fetch) task scheduler.

```bash
$ bundle install

$ redis-server &

$ bundle exec sidekiq -r ./worker.rb &

$ bundle exec init.rb /path/to/subject/certificate /path/to/issuer/certificate
```

And, you can get a DER-encoded OCSP Response corresponding to the subject certificate.

```bash
$ redis-cli GET sidekiq-ocsprf-demo
```
