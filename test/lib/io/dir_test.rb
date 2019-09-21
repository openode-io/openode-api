require 'test_helper'

class IoDirTest < ActiveSupport::TestCase
  test "modified_or_created_files with new created file in the client" do
  	client_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	results = Io::Dir.modified_or_created_files(client_files, server_files)
  	assert_equal results.length, 1
  	assert_equal results[0]["path"], "asdf/test.txt"
  	assert_equal results[0]["change"], "C"
  end

  test "modified_or_created_files with modified and created files in the client" do
  	client_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441236"
  		}
  	]

  	results = Io::Dir.modified_or_created_files(client_files, server_files)
  	assert_equal results.length, 2
  	assert_equal results[0]["path"], "asdf/test.txt"
  	assert_equal results[0]["change"], "C"
  	assert_equal results[1]["path"], "asdf/test2.txt"
  	assert_equal results[1]["change"], "M"
  end

  test "modified_or_created_files with no modification" do
  	client_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	results = Io::Dir.modified_or_created_files(client_files, server_files)
  	assert_equal results.length, 0
  end

  test "deleted_files with one deletion" do
  	client_files = [
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	results = Io::Dir.deleted_files(client_files, server_files, [])
  	assert_equal results.length, 1
  	assert_equal results[0]["path"], "asdf/test.txt"
  	assert_equal results[0]["change"], "D"
  end

  test "deleted_files without deletion" do
  	client_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	results = Io::Dir.deleted_files(client_files, server_files, [])
  	assert_equal results.length, 0
  end

  test "diff properly" do
  	client_files = [
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441236"
  		}
  	]

  	results = Io::Dir.diff(client_files, server_files, [])
  	assert_equal results.length, 2
  	assert_equal results[0]["path"], "asdf/test2.txt"
  	assert_equal results[0]["change"], "M"
  	assert_equal results[1]["path"], "asdf/test.txt"
  	assert_equal results[1]["change"], "D"
  end

  test "diff with exclusions" do
  	client_files = [
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441235"
  		}
  	]

  	server_files = [
  		{
  			"path" => "asdf/test.txt",
  			"checksum" => "123441234"
  		},
  		{
  			"path" => "asdf/test2.txt",
  			"checksum" => "123441236"
  		}
  	]

  	results = Io::Dir.diff(client_files, server_files, ["asdf/"])
  	assert_equal results.length, 1
  	assert_equal results[0]["path"], "asdf/test2.txt"
  	assert_equal results[0]["change"], "M"
  end
end
