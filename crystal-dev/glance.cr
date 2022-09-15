require "http/client"
require "json"

response = HTTP::Client.get "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_9933.tw|otc_6248.tw&json=1&delay=0"
response.status_code      # => 200
result_arr = JSON.parse(response.body)["msgArray"]

#p! result_arr.size

#result_arr.size.times { |x| 
#  puts result_arr[x]["c"] 
#  puts result_arr[x]["b"] 
#  puts result_arr[x]["a"] 
#}


class Quote
  property quote_hash : Hash(String, Hash(String, String | Float32 | Int32))
  @init_stock_code_array : Array(String)
  
  def initialize(init_stock_code_array)
    @init_stock_code_array = init_stock_code_array
    @quote_hash = Hash(String, Hash(String, String | Float32 | Int32)).new
  end

  def update_price()
    @init_stock_code_array.size.times { |x|
      puts @init_stock_code_array[x]
    }

  end  
end


class Position
  property stock_code : String
  property shares : Int32
  property at_cost : Float32

  def initialize(stock_code : String)
    @stock_code = stock_code
    @shares = 0
    @at_cost = 0.0
  end
end


class Portfolio
  # property positions : Hash(String, Position)
  @positions : Hash(String, Position)
  
  def initialize()
    @positions = Hash(String, Position).new
  end

  def add_position(position : Position)
    @positions[position.stock_code] = position
  end

  def update_quote()
    puts ""
  end

  def go
    puts "Code  #Shares   @cost"
    puts "#{@positions}"
  end
end

qq = Quote.new ["9933", "2330"]
qq.update_price

my_port = Portfolio.new
pos_9933 = Position.new "9933"
pos_9933.shares = 1000
pos_9933.at_cost = 46.1
my_port.add_position(pos_9933)
my_port.go




