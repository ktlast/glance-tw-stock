require "http/client"
require "json"
require "colorize"


def color_split(input_num : Int32 | Float32, digit=3)
  puts

end



class Portfolio
  # property exchange_table : Hash(String, String)
  # property positions : Hash(String, Hash(String, String | Int32 | Float32))

  def initialize()
    @exchange_table = Hash(String, String).new
    @positions = Hash(String, Hash(String, Int32 | Float32)).new
    @code_params = Set(String).new
    @total_pl = 0
    # @positions = Hash(String, Int32 | Hash(String, String)).new

    File.read("../.exchange_table.csv").each_line do |line|
      entry = line.split(",")
      @exchange_table[entry[0]] = entry[1]
    end
  end


  def add_position(stock_code : String, shares : Int32, at_cost : Float32)
    puts stock_code
    # puts "#{@exchange_table[stock_code]}_#{stock_code}.tw"
    @code_params.add("#{@exchange_table[stock_code]}_#{stock_code}.tw")
    @positions[stock_code] = {
      "shares" => shares,
      "at_cost" => at_cost,
      "bid" => 0,
      "ask" => 0,
      "PL" => 0,
    }
  end

  def remove_position(stock_code : String)
    @code_params.delete("#{@exchange_table[stock_code]}_#{stock_code}.tw")
    @positions.delete(stock_code)
  end

  def update_quote()
    @total_pl = 0
    response = HTTP::Client.get "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=#{@code_params.join("|")}&json=1&delay=0"
    result_arr = JSON.parse(response.body)["msgArray"].as_a
    result_arr.each do |symbol|
      #  puts  symbol["b"].to_s.split("_")[0].to_f32
      #  puts @positions[stock_code]["bid"] = symbol["b"]
      stock_code = symbol["c"]
      bid_price = symbol["b"].to_s.split("_")[0].to_f32
      ask_price = symbol["a"].to_s.split("_")[0].to_f32
      @positions[stock_code]["bid"] = bid_price
      @positions[stock_code]["ask"] = ask_price
      raw_pl = ((bid_price - @positions[stock_code]["at_cost"]) * @positions[stock_code]["shares"])
      @positions[stock_code]["PL"] = raw_pl.floor.to_i
      @total_pl += raw_pl.floor.to_i
    end
  end

  def print_out()
    # Title
    puts "#{"Code".ljust(8)}#{"# shares".rjust(9)}#{"@ Cost".rjust(10)}#{"Bid".rjust(9)}#{"Ask".rjust(10)}#{"P/L".rjust(12)}"
    
    # entries
    @positions.keys.each do |stock_code|
      entry_line = "#{stock_code.ljust(8)}\
        #{@positions[stock_code]["shares"].to_s.rjust(9)}\
        #{@positions[stock_code]["at_cost"].to_s.rjust(10)}\
        #{@positions[stock_code]["bid"].to_s.rjust(9)}\
        #{@positions[stock_code]["ask"].to_s.rjust(10)}\
        #{@positions[stock_code]["PL"].to_s.rjust(12)}"
      puts entry_line
    end
    puts "-"*58
    puts @total_pl.to_s.rjust(58)
  end
end

pp = Portfolio.new
# puts pp.@exchange_table
pp.add_position("9933", 4000, 46.1)
pp.add_position("6248", 10000, 20.95)

while true
  puts "\33c\e[3J"
  pp.update_quote
  pp.print_out
  sleep 30
end

