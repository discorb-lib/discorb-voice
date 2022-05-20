require "discorb"
require "discorb-voice"

client.once :standby do
  puts "Logged in as #{client.user}"
end

client.slash "connect", "connect to a voice channel" do |interaction|
  channel = interaction.target.voice_state.channel
  interaction.post "Connecting to #{channel.name}"
  channel.connect.wait
  interaction.post "Connected to #{channel.name}"
end

client.slash "play", "Plays audio" do |interaction|
  interaction.guild.voice_client.play(Discorb::Voice::FFmpegAudio.new("./very_nice_song.mp3"))
  interaction.post "Playing Your very nice song!"
end

client.slash "stop", "Stops the current audio" do |interaction|
  interaction.guild.voice_client.stop
  interaction.post "Stopped"
end

client.run(ENV["DISCORD_BOT_TOKEN"])
