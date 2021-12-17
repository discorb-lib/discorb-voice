require "discorb"
require "discorb/voice"
require "open3"

client = Discorb::Client.new

client.once :standby do
  puts "Logged in as #{client.user}"
end

client.slash "connect", "connect to a voice channel" do |interaction|
  channel = interaction.target.voice_state.channel
  interaction.post "Connecting to #{channel.name}"
  channel.connect.wait
  interaction.post "Connected to #{channel.name}"
end

client.slash "play", "Plays YouTube audio", {
  "url" => {
    type: :string,
    description: "The URL of the YouTube video to play",
    required: true,
  },
} do |interaction, url|
  interaction.post "Querying #{url}..."
  stdout, _status = Open3.capture2("youtube-dl", "-j", url)
  data = JSON.parse(stdout, symbolize_names: true)
  url = data[:formats][0][:url]
  interaction.guild.voice_client.play(Discorb::Voice::FFmpegAudio.new(url))
  interaction.post "Playing `#{data[:title]}`"
end

client.run(ENV["DISCORD_BOT_TOKEN"])
