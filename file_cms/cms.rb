require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubi"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  # set :erb, :escape_html => true
end

# cms.rb
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials
  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end

end

def authenticate_user(session)
  unless session[:user]
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# Load main page
get "/" do
  p request.env
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

# Load a file page
get "/:filename" do
  file_path = File.join(data_path, File.basename(params[:filename]))

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Load page to Edit a file page
get "/:filename/edit" do
  authenticate_user(session)
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]
  @content = File.read(file_path)
  erb :edit
end

# Edit an file
post "/:filename/edit" do
  authenticate_user(session)
  content = params[:content]
  file_path = File.join(data_path, params[:filename])
  
  File.write(file_path, content)
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

# View new document page
get "/document/new" do
  authenticate_user(session)
  erb :new_document
end

# Create a new document
post "/document/new" do
  authenticate_user(session)
  filename = params[:filename].strip
  file_path = File.join(data_path, filename)
  error = error_for_filename(file_path, filename)
  if error
    status 422
    session[:message] = error
    erb :new_document
  else
    file_path = File.join(data_path, filename)
    File.new(file_path, "w")
    
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

post "/:filename/delete" do
  authenticate_user(session)
  filename = params[:filename]
  File.delete(File.join(data_path, filename))
  session[:message] = "#{filename} was deleted."
  redirect "/"
end

get "/user/login" do
  erb :login
end

post "/user/login" do
  username, input_password = params[:username], params[:password]
  
  if valid_credentials?(username, input_password)
    session[:user] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:message] = "Invalid credentials."
    erb :login
  end
end

post "/user/logout" do
  session.delete(:user)
  session[:message] = "You have been signed out."
  redirect "/"
end

def error_for_filename(path, filename)
  if filename.size < 1
    "A name is required."
  elsif !File.extname(path).match(/[.]+\S/)
    "A file extension is required."
  end
end

# Helper method to load a file based on type
def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

# Helper method to render markdown fiels as HTML
def render_markdown(contents)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(contents)
end
