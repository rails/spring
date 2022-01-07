require 'expedite'

Expedite.define do
  agent :parent do
    $parent_var = 1
  end

  agent "development/*", parent: :parent do |name|
    $development_var = name
  end

  action :info do
    puts "     Process.pid = #{Process.pid}"
    puts "    Process.ppid = #{Process.ppid}"
    puts "     $parent_var = #{$parent_var}"
    puts "$development_var = #{$development_var}"
  end
end