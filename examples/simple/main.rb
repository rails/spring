#!/usr/bin/env ruby
require 'expedite'

Expedite.agent("development/abc").invoke("info")
