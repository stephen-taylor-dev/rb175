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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { user: {username: "admin", password: "password" }}}
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
    assert_equal "notafile.ext does not exist.", session[:message]
  end


  def test_editing_document
    create_document "changes.txt", "Test doc changes."

    get "/changes.txt/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "Test doc changes."
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    post "/changes.txt/edit", {content: "User wrote this stuff."}, admin_session 

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get last_response["Location"]
    
    get "/changes.txt" # Reload the page
    assert_equal 200, last_response.status
    assert_includes last_response.body, "User wrote this stuff."
  end

  def test_updating_document_signed_out
    post "/changes.txt/edit", {content: "User wrote this stuff."}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_new_document_page
    get "/document/new", {}, admin_session 

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_new_document_page_signed_out
    get "/document/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_valid_new_document
    post "/document/new", {filename: "new_document.txt"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "new_document.txt was created.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "new_document.txt"
  end

  def test_create_valid_new_document_signed_out
    post "/document/new", {filename: "new_document.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_invalid_new_document
    post "/document/new", {filename: "       " }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_delete_file
    create_document "test.txt", "Test doc 1."

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was deleted.", session[:message]

    get last_response["location"]
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_delete_file_signed_out
    create_document "test.txt", "Test doc 1."

    post "/test.txt/delete", {}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_login_page
    get "/user/login"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
    assert_includes last_response.body, %q(<button type="submit")

  end

  def test_successful_login
    post "/user/login", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:user]

    get last_response["location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin."

  end

  def test_failed_login
    post "/user/login", username: "notadmin", password: "notsecret"

    assert_equal 422, last_response.status
    assert_nil session[:user]
    assert_includes last_response.body, "Invalid credentials."
  end

  def test_successful_logout
    get "/", {}, {"rack.session" => { user: "admin" } }
    assert_includes last_response.body, "Signed in as admin."

    post "/user/logout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]
    
    get last_response["location"]
    assert_nil session[:user]
    assert_includes last_response.body, "Sign In"

  end

end