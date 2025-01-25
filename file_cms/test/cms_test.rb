ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "file.txt", "Test doc 1."
    create_document "about.md", "# Test markdown doc."

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "file.txt"
    assert_includes last_response.body, "about.md"

  end

  def test_viewing_text_document
    create_document "file.txt", "Test doc 1."

    get "/file.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes(last_response.body, "Test doc 1.")
  end
  
  def test_viewing_markdown_file
    create_document "about.md", "# Test markdown doc."
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Test markdown doc.</h1>"
  end

  def test_document_not_found
    get "/notafile.ext"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"

    get "/" # Reload the page
    refute_includes last_response.body, "notafile.ext does not exist"
  end


  def test_editing_document
    create_document "changes.txt", "Test doc changes."

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "Test doc changes."
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt/edit", content: "User wrote this stuff."

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt" # Reload the page
    assert_equal 200, last_response.status
    assert_includes last_response.body, "User wrote this stuff."
  end

  def test_new_document_page
    get "/document/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_valid_new_document
    post "/document/new", filename: "new_document.txt"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "new_document.txt was created"
    assert_includes last_response.body, "new_document.txt"
  end

  def test_create_invalid_new_document
    post "/document/new", filename: "       "

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_delete_file
    create_document "test.txt", "Test doc 1."

    post "/test.txt/delete"

    assert_equal 302, last_response.status

    get last_response["location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "test.txt was deleted."

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_login_page
    get "/user/login"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
    assert_includes last_response.body, %q(<button type="submit")

  end

  def test_successful_login
    post "/user/login"

    session[:user]

  end

end