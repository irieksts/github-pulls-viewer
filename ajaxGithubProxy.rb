require 'sinatra'
require 'rest_client'
require 'pp'
require 'json'
require 'link_header'  # see https://github.com/asplake/link_header

configure do
	set :thisHost, "localhost:4567"         
	set :githubHost, "api.github.com"			# extract these to configuration / have them passed in with request
	set :username, ""
	set :password, ""
end

# /users/:user/subscriptions     e.g. http://localhost:4567/api/users/jamestyack/subscriptions
# /repos/:owner/:repo/pulls      e.g. http://localhost:4567/repos/hmsonline/storm-cassandra/pulls
# /repos/:owner/:repo/issues     e.g. https://api.github.com/repos/hmsonline/storm-cassandra/issues

# main page erb for the subscriptions
get '/subscriptions' do
  user = settings.username;
  subs = fetchSubscriptions(user, true)
  erb :subscriptions, :locals => {:user => user, :subs => subs}
end

get '/api/user/:user/subscription/openpulls' do
  pulls_to_return = {}
  content_type :json
  user = params[:user];
  all_subs_with_open_issues = fetchSubscriptions(user, true)
  all_subs_with_open_issues.each do | subscription |
    pull_requests = []
    uri = buildApiUri("/repos/#{subscription}/pulls","state=open")
    results = RestClient.get(uri)
    resultsArray = JSON.parse(results)
    resultsArray.each do | pull |
      pull_requests << build_concise_pull_summary(pull)
    end
    pulls_to_return[subscription] = pull_requests
  end
  pulls_to_return.to_json
  # for each subscription get the pull request
end

def build_concise_pull_summary(pull)
  pull_summary = {}
  pull_summary["html_url"] = pull["html_url"]
  pull_summary["number"] = pull["number"]
  pull_summary["state"] = pull["state"]
  pull_summary["title"] = pull["title"]
  pull_summary["user"] = pull["user"]
  pull_summary
end
  
def fetchSubscriptions(user, hasOpenIssues) # !!! REFACTOR DUPLICAION
  subscriptionsToReturn = [];
  uri = buildApiUri("/users/#{user}/subscriptions","")
  results = RestClient.get(uri)
  resultsArray = JSON.parse(results)
  resultsArray.each do | result |
    open_issues = result["open_issues_count"]
    if (open_issues == 0 && hasOpenIssues) 
      # don't add to array because there are no open issues and we are not returning these subscriptions
    else
      puts result["full_name"] + " has " + open_issues.to_s + " open issues"
      subscriptionsToReturn << result
    end
  end
  next_link = getNextLink(results)
  while(!next_link.nil?) do
    results = RestClient.get(add_authentication(next_link.href))
    resultsArray = JSON.parse(results)
    resultsArray.each do | result |
      open_issues = result["open_issues_count"]
      if (open_issues == 0 && hasOpenIssues) 
        # don't add to array because there are no open issues and we are not returning these subscriptions
      else
        puts result["full_name"] + " has " + open_issues.to_s + " open issues"
        subscriptionsToReturn << result
      end
    end
    next_link = getNextLink(results)
  end
  subscriptionsToReturn
end

def getNextLink(results)
  link = results.headers[:link]
  link_header = LinkHeader.parse(link)
  link_header.find_link(["rel", "next"])
end

# Generic method for Github API
get '/api/*' do
	content_type :json
	results = RestClient.get(buildApiUri(request.path_info[4..-1], request.query_string))
	# check if there is a link for pagination
	link = results.headers[:link]
	unless link.nil?
		response.headers["link"] = link.gsub!(settings.githubHost, settings.thisHost)
	end
	results
end

def buildApiUri(path, query_string)
  authString = ""
  if ((defined? settings.username) && (defined? settings.password))
    authString = settings.username + ":" + settings.password + "@"
  end
	uri = "https://" + authString + settings.githubHost + path + "?" + query_string
	puts uri
	uri
end

def add_authentication(uri)
  if ((defined? settings.username) && (defined? settings.password))
    uri = uri.gsub('://', '://' + authString = settings.username + ":" + settings.password + "@")
  end
  puts uri
  uri
end
