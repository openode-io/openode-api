require 'test_helper'

class RemoteDnsVultrTest < ActiveSupport::TestCase

  def setup

  end

  test "all root domains" do
  	dns = Remote::Dns::Base.instance
  	domains = dns.all_root_domains

  	assert_equal domains.length, 2
  	assert_equal domains[1], "openode.io"
  end

  test "add root domains" do
  	dns = Remote::Dns::Base.instance
  	result = dns.add_root_domain("whatistaht.com", "127.0.0.1")

  	assert_equal result, ""
  end

  test "domain record" do
  	dns = Remote::Dns::Base.instance
  	result = dns.domain_records("openode.io")

  	assert_equal result[0]["name"], "wsnewapp.us"
  	assert_equal result[0]["type"], "A"
  end

  test "add record" do
  	dns = Remote::Dns::Base.instance
  	result = dns.add_record("openode.io", "1234", "A", "127.0.0.1", 10)

  	assert_equal result, ""
  end

  test "delete record" do
  	dns = Remote::Dns::Base.instance
  	result = dns.delete_record("openode.io", { "RECORDID" => "123456" })

  	assert_equal result, ""
  end

  test "update record with new subdomain" do
  	dns = Remote::Dns::Base.instance

  	dns_entries = [
  		{
  			"domainName"=>"wsnewapp.us.openode.io",
  			"type"=>"A", 
  			"value"=>"173.208.152.130"
  		},
  		{
  			"domainName"=>"what.us.openode.io",
  			"type"=>"A", 
  			"value"=>"127.0.0.1"
  		}
  	]
  	result = dns.update("openode.io", "1234.openode.io", dns_entries, "127.0.0.1")

  	assert_equal result[:created].length, 1
  	assert_equal result[:created][0]["domainName"], "what.us.openode.io"
  end

  test "update record with entry to delete, one to create" do
  	dns = Remote::Dns::Base.instance

  	dns_entries = [
  		{
  			"domainName"=>"what.wsnewapp.us.openode.io",
  			"type"=>"A", 
  			"value"=>"127.0.0.2"
  		}
  	]
  	result = dns.update("openode.io", "wsnewapp.us.openode.io", dns_entries, "127.0.0.1")

  	assert_equal result[:created].length, 1
  	assert_equal result[:deleted].length, 1
  	assert_equal result[:created][0]["domainName"], "what.wsnewapp.us.openode.io"
  	assert_equal result[:deleted][0]["domainName"], "wsnewapp.us.openode.io"
  end
end
