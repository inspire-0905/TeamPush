https = require('https')
config = require('./config')

pocket = {

	REDIRECT_URI: "#{config.server_host}:#{config.server_port}/callback",
	PUSH_PAGE_URI: "#{config.server_host}:#{config.server_port}/",
	API_GET_REQUEST_TOKEN_PATH: '/v3/oauth/request',
	API_GET_ACCESS_TOKEN_PATH: '/v3/oauth/authorize',
	API_ADD_PATH: '/v3/add',
	API_GET_PATH: '/v3/get',

	_request: (path, reqObj, callback) ->

		reqStr = JSON.stringify(reqObj)
		options = {
			hostname: 'getpocket.com',
			path: path,
			method: 'POST',
			headers: {
				'Content-Length': reqStr.length,
				'Content-Type': 'application/json; charset=UTF-8',
				'X-Accept': 'application/json'
			}
		}

		request = https.request options, (response) ->
			result = ''
			response.on 'data', (data) ->
				result += data
			response.on 'end', () ->
				try
					resObj = JSON.parse(result)
					callback(resObj)
				catch err
					null

		request.end(reqStr)

		request.on 'error', (err) ->
			console.error(err)

	oAuth: {

		getReqToken: (callback) ->
			reqObj = {
				'consumer_key': config.consumer_key,
				'redirect_uri': pocket.REDIRECT_URI
			}
			pocket._request pocket.API_GET_REQUEST_TOKEN_PATH, reqObj, (resObj) ->
				reqToken = resObj.code
				callback(reqToken)

		getAccessToken: (reqToken, callback) ->
			reqObj = {
				'consumer_key': config.consumer_key,
				'code': reqToken
			}
			pocket._request pocket.API_GET_ACCESS_TOKEN_PATH, reqObj, (resObj) ->
				accessToken = resObj.access_token
				userName = resObj.username
				callback(accessToken, userName)
	},

	request: {

		addArticle: (accessToken, articleURL, articleTags, callback) ->
			reqObj = {
				'url': articleURL,
				'tags': articleTags,
				'consumer_key': config.consumer_key,
				'access_token': accessToken
			}
			pocket._request(pocket.API_ADD_PATH, reqObj, callback)

		listArticle: (accessToken, sinceTime, callback) ->
			reqObj = {
				'consumer_key': config.consumer_key,
				'access_token': accessToken,
				'since': sinceTime,
				'detailType': 'complete'
			}
			pocket._request(pocket.API_GET_PATH, reqObj, callback)
	}
}

module.exports = pocket