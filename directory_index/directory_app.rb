require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

get "/" do
  sort_order = params["sort"]
  contents = Dir.glob("public/*")
  @filenames = contents.map {|path| File.basename(path)}
  @filenames.reverse! if sort_order == "descending"
  erb :index
end

# get "/:path" do
#   File.read(params['path'])
# end
