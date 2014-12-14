require 'oauth2'
require 'multi_json'

begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # continue assuming env is set manually
end

CLIENT_ID     = ENV['CLIENT_ID']
CLIENT_SECRET = ENV['CLIENT_SECRET']
ACCESS_TOKEN  = ENV['ACCESS_TOKEN']

class Client
  FA_URI = URI('https://api.freeagent.com/v2/')
  CONNECT_OPTS = { :headers => { :user_agent => "extract-receipts", :accept => "application/json", :content_type => "application/json" } }

  attr_reader :client, :access_token, :from_date, :to_date
  def initialize(from_date, to_date, id = CLIENT_ID, secret = CLIENT_SECRET, token = ACCESS_TOKEN)
    @client = OAuth2::Client.new(id, secret, site: FA_URI, authorize_url: 'approve_app', token_url: 'token_endpoint', connection_opts: CONNECT_OPTS)
    @access_token  = OAuth2::AccessToken.new(client, token)
    @from_date = from_date
    @to_date = to_date
  end

  def get(uri, params={})
    request(:get, uri, :params => params)
  end

  private

  def request(method, path, options = {})
    if @access_token
      options[:body] = MultiJson.encode(options[:data]) unless options[:data].nil?
      @access_token.send(method, path, options)
    else
      raise 'Access Token not set'
    end
  end
end

class Attachment
  def initialize(data)
    @data = data
  end

  def file_url
    @data["content_src"]
  end

  def filename
    @data["file_name"]
  end
end

class BankAccount
  def initialize(data)
    @data = data
  end

  def url
    @data["url"]
  end
end

class Expense
  def initialize(data)
    @data = data
  end

  def url
    @data["url"]
  end

  def dated_on
    @data["dated_on"]
  end

  def user
    @data["user"]
  end

  def category
    @data["category"]
  end

  def dated_on
    @data["dated_on"]
  end

  def native_gross_value
    @data["native_gross_value"]
  end

  def native_sales_tax_value
    @data["native_sales_tax_value"]
  end

  def description
    @data["description"]
  end

  def reference
    @data["reference"]
  end

  def attachment?
    @data.has_key?("attachment")
  end

  def attachment
    return unless attachment?
    Attachment.new(@data["attachment"])
  end

  def attachment_url
    return unless attachment?
    attachment.file_url
  end

  def attachment_filename
    return unless attachment?
    [dated_on, id, attachment.filename].join("-")
  end

  def id
    url.split("/").last
  end
end

class Bill
  def initialize(data)
    @data = data
  end

  def url
    @data["url"]
  end

  def dated_on
    @data["dated_on"]
  end

  def reference
    @data["reference"]
  end

  def attachment?
    @data.has_key?("attachment")
  end

  def attachment
    return unless attachment?
    Attachment.new(@data["attachment"])
  end

  def attachment_url
    return unless attachment?
    attachment.file_url
  end

  def attachment_filename
    return unless attachment?
    [dated_on, id, attachment.filename].join("-")
  end

  def id
    url.split("/").last
  end
end

class Explanation
  def initialize(data)
    @data = data
  end

  def url
    @data["url"]
  end

  def dated_on
    @data["dated_on"]
  end

  def description
    @data["description"]
  end

  def attachment?
    @data.has_key?("attachment")
  end

  def attachment
    return unless attachment?
    Attachment.new(@data["attachment"])
  end

  def attachment_url
    return unless attachment?
    attachment.file_url
  end

  def attachment_filename
    return unless attachment?
    [dated_on, id, attachment.filename].join("-")
  end

  def id
    url.split("/").last
  end
end

require 'link_header'
class Bills
  include Enumerable
  def initialize(client)
    @client = client
  end

  def each(&block)
    request = @client.get("#{Client::FA_URI}bills?per_page=10&from_date=#{@client.from_date}&to_date=#{@client.to_date}")

    link_headers = LinkHeader.parse(request.response.headers["link"])
    next_page = link_headers.find_link(["rel", "'next'"])
    request.parsed['bills'].each { |b| block.call(Bill.new(b)) }

    while next_page
      request = @client.get(next_page.href)
      request.parsed['bills'].each { |b| block.call(Bill.new(b)) }
      link_headers = LinkHeader.parse(request.response.headers["link"])
      next_page = link_headers.find_link(["rel", "'next'"])
    end
  end
end

class Expenses
  include Enumerable
  def initialize(client)
    @client = client
  end

  def each(&block)
    request = @client.get("#{Client::FA_URI}expenses?per_page=10&from_date=#{@client.from_date}&to_date=#{@client.to_date}")

    link_headers = LinkHeader.parse(request.response.headers["link"])
    next_page = link_headers.find_link(["rel", "'next'"])
    request.parsed['expenses'].each { |b| block.call(Expense.new(b)) }

    while next_page
      request = @client.get(next_page.href)
      request.parsed['expenses'].each { |b| block.call(Expense.new(b)) }
      link_headers = LinkHeader.parse(request.response.headers["link"])
      next_page = link_headers.find_link(["rel", "'next'"])
    end
  end
end

class BankTransactionExplanations
  include Enumerable
  attr_reader :bank_account

  def initialize(client, bank_account)
    @client = client
    @bank_account = bank_account
  end

  def each(&block)
    request = @client.get("#{Client::FA_URI}bank_transaction_explanations?bank_account=#{bank_account}&per_page=10&from_date=#{@client.from_date}&to_date=#{@client.to_date}")

    link_headers = LinkHeader.parse(request.response.headers["link"])
    next_page = link_headers.find_link(["rel", "'next'"])
    request.parsed['bank_transaction_explanations'].each { |b| block.call(Explanation.new(b)) }

    while next_page
      request = @client.get(next_page.href)
      request.parsed['bank_transaction_explanations'].each { |b| block.call(Explanation.new(b)) }
      link_headers = LinkHeader.parse(request.response.headers["link"])
      next_page = link_headers.find_link(["rel", "'next'"])
    end
  end
end

class BankAccounts
  include Enumerable
  def initialize(client)
    @client = client
  end

  def each(&block)
    request = @client.get("#{Client::FA_URI}bank_accounts?&per_page=10")

    link_headers = LinkHeader.parse(request.response.headers["link"])
    next_page = link_headers.find_link(["rel", "'next'"])
    request.parsed['bank_accounts'].each { |b| block.call(BankAccount.new(b)) }

    while next_page
      request = @client.get(next_page.href)
      request.parsed['bank_accounts'].each { |b| block.call(BankAccount.new(b)) }
      link_headers = LinkHeader.parse(request.response.headers["link"])
      next_page = link_headers.find_link(["rel", "'next'"])
    end
  end
end

require 'net/http'
require 'fileutils'

def download_file(url, file_path)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new uri

    http.request request do |response|
      open file_path, 'w' do |io|
        response.read_body do |chunk|
          io.write chunk
        end
      end
    end
  end
end

require 'csv'
def retrieve_bills(file_dir)
  file_path = Pathname.new(file_dir)
  FileUtils.mkdir_p(file_path)

  CSV.open(file_path.join("bills.csv"), "wb") do |csv|
    csv << ["url", "reference", "file"]
    @bills.each do |bill|
      if bill.attachment?
        download_file(bill.attachment_url, file_path.join(bill.attachment_filename)) 
        csv << [bill.url, bill.reference, bill.attachment_filename]
      end
      print "."
    end
  end
end

def retrieve_expenses(file_dir)
  file_path = Pathname.new(file_dir)
  FileUtils.mkdir_p(file_path)

  CSV.open(file_path.join("expenses.csv"), "wb") do |csv|
    csv << ["url", "user", "category", "dated_on", "native_gross_value", "native_sales_tax_value", "description", "reference", "file"]
    @expenses.each do |expense|
      if expense.attachment?
        download_file(expense.attachment_url, file_path.join(expense.attachment_filename)) 
        csv << [expense.url, expense.user, expense.category, expense.dated_on, expense.native_gross_value, expense.native_sales_tax_value, expense.description, expense.reference, expense.attachment_filename]
      end
      print "."
    end
  end
end

def retrieve_explanations(file_dir)
  file_path = Pathname.new(file_dir)
  FileUtils.mkdir_p(file_path)

  CSV.open(file_path.join("explanations.csv"), "wb") do |csv|
    csv << ["url", "description", "file"]
    @bank_accounts.each do |account|
      explanations = BankTransactionExplanations.new(@client, account.url)
      explanations.each do |explanation|
        if explanation.attachment?
          download_file(explanation.attachment_url, file_path.join(explanation.attachment_filename))
          csv << [explanation.url, explanation.description, explanation.attachment_filename]
        end
        print "."
      end
    end
  end
end

if __FILE__ == $0
  path = Pathname.new(ARGV[0] || "")
  from_date = ARGV[1] || '1970-1-31'
  to_date = ARGV[2] || '2099-1-31'

  path = path.join("#{from_date}_#{to_date}")

  @client = Client.new(from_date,to_date)
  @bills = Bills.new(@client)
  @bank_accounts = BankAccounts.new(@client)
  @expenses = Expenses.new(@client)

  puts "retrieving bill attachments"
  retrieve_bills(path.join("bills"))
  puts
  puts "done."
  puts

  puts "retrieving explanation attachments"
  retrieve_explanations(path.join("explanations"))
  puts
  puts "done."

  puts "retrieving expense attachments"
  retrieve_expenses(path.join("expenses"))
  puts
  puts "done."
   
end
