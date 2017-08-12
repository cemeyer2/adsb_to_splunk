require 'net/telnet'
require 'httparty'

queue = Queue.new

Thread.new do
  server = Net::Telnet::new('Host' => '192.168.1.176',
                            'Port' => 30003,
                            'Telnetmode' => false)


  server.waitfor(/thiswillneverbeoutput/) do |data|
    queue.push data
  end
end

consumer = Thread.new do
  loop do
    datas = []
    50.times do
      datas.push queue.pop.to_s.split("\n")
    end
    data = datas.flatten

    buffer = []
    data.each do |datum|
      buffer << {
          event: datum,
          time: Time.now.to_f.round(1),
          host: 'piaware.charliemeyer.net',
          sourcetype: 'adsb',
          index: 'adsb',
          source: 'adsb'
      }
    end
    response = HTTParty.post('https://192.168.1.1:8088/services/collector',
                             body: buffer.map {|hash| hash.to_json}.join(''),
                             headers: {'Authorization' => 'Splunk HTTP-EVENT-COLLECTOR-KEY'},
                             verify: false
    )
    raise "splunk indexing error: #{response.inspect}" unless response.code.to_i < 400
    puts "indexed #{data.size} records to splunk"
  end
end

consumer.join