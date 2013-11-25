require 'sinatra'
require 'rest_client'

configure do
	set :thisHost, "localhost:4567"         
	set :githubHost, "api.github.com"			# extract these to configuration / have them passed in with request
	set :username, "username"
	set :password, "password"
end

get '/api/v3/*' do
	content_type :json
	results = RestClient.get(buildUri(request))
	# check if there is a link for pagination
	link = results.headers[:link]
	unless link.nil?
		response.headers["link"] = link.gsub!(settings.githubHost, settings.thisHost)
	end
	results
end

def buildUri(request)
	"http://" + settings.username + ":" + settings.password + "@" + settings.githubHost + request.path_info + "?" + request.query_string
end