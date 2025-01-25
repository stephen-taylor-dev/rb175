require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubi"
require "redcarpet"

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

# Load main page
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

# Load a file page
get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Load page to Edit a file page
get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]
  @content = File.read(file_path)
  erb :edit
end

# Edit an file
post "/:filename/edit" do
  content = params[:content]
  file_path = File.join(data_path, params[:filename])
  
  File.write(file_path, content)
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

# Helper method to load a file based on type
def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

# Helper method to render markdown fiels as HTML
def render_markdown(contents)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(contents)
end
