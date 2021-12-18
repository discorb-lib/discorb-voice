# discorb-voice

This adds a voice support to discorb.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'discorb-voice'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install discorb-voice

### Install libsodium

#### Windows

Get libsodium from [here](https://download.libsodium.org/libsodium/releases/).
I've checked `libsodium-1.0.17-stable-mingw.tar.gz` works.

Then, if you are using x64 ruby (Check with `ruby -e 'puts RUBY_PLATFORM'`), extract `libsodium-win64`, then copy the `libsodium-23.dll` in `bin` to `C:/Windows/System32/sodium.dll`.
If you are using x86 ruby, extract `libsodium-win32`, then copy the `libsodium-23.dll` in `bin` to `C:/Windows/SysWOW64/sodium.dll`.

#### Linux

    $ sudo apt-get install libsodium-dev

Get libsodium with your package manager.

#### Mac

    $ brew install libsodium

### Install ffmpeg

#### Windows

Get ffmpeg from [here](https://ffmpeg.org/download.html).
And put the `ffmpeg.exe` on your PATH.

Or, you can use Chocolatey to install ffmpeg:

    $ choco install ffmpeg

#### Linux

    $ sudo apt-get install ffmpeg

Use your package manager to install ffmpeg.

#### Mac

    $ brew install ffmpeg

## Usage

```ruby
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
  interaction.guild.voice_client.play(Discorb::Voice::FFmpegAudio.new("./very-nice-song.mp3"))
  interaction.post "Playing Your very nice song!"
end

client.slash "stop", "Stops the current audio" do |interaction|
  interaction.guild.voice_client.stop
  interaction.post "Stopped"
end

client.run(ENV["DISCORD_BOT_TOKEN"])
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/discorb-lib/discorb-voice.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
