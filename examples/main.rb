require "discorb"
require "discorb/voice"

client = Discorb::Client.new

client.once :ready do
  puts "Logged in as #{client.user}"
  vc = client.connect_to(client.channels["867704702577278996"])
  binding.irb
end

client.run("ODA0ODE4NjcwOTc0NDAyNTkx.YBR3yw.V2iJi7ul1OfNTBminlCG3V8nvUc")
