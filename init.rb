#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'worker'

if ARGV.length != 2
  warn 'error: number of arguments is not 2'
  exit 1
end

subject, issuer = ARGV
if !File.exist?(subject) || !File.exist?(issuer)
  warn 'error: file not founde'
  exit 1
end

FetchWorker.perform_async(subject, issuer)
