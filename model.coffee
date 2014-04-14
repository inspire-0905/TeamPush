_ = require('underscore')
async = require('async')
moment = require('moment')

pocket = require('./pocket')
database = require('./database')
config = require('./config')

class Model

	constructor: () ->

		that = @

		(listArticleLoop = () ->
			setTimeout () ->
				that.listArticle((articleDataList) ->

					database.listCircle (err, circleDataList) ->
						
						if not err
					
							that._getUserNeedArticle articleDataList, circleDataList, (dataObj) ->

								allArticleMap = dataObj.allArticleMap
								userNeedArticleMap = dataObj.userNeedArticleMap
								# console.log('publishing article to all user')
								if _.keys(userNeedArticleMap).length
									console.log(JSON.stringify(userNeedArticleMap))
									that.publishArticle(userNeedArticleMap, (err, results) ->
										# console.log('find ' + results.length + ' article need to publish')
										# console.log('published article to all user')
										newArticleIDAry = _.map results, (result) ->
											if result and result.item and result.item.resolved_id
												return result.item.resolved_id
											return null
										that.recordPublishedArticle(allArticleMap, newArticleIDAry)
									)
				)
				listArticleLoop()
			, config.article_sync_period * 1000
		)()

	_getUserNeedArticle: (articleDataList, circleDataList, callback) ->

		that = @

		allArticleMap = {}
		userArticleMap = {}
		userNeedArticleMap = {}
		circleMap = {} # access_token: circle_tag

		# get all circle map
		_.each circleDataList, (circleData) ->

			circleTag = circleData.circle_tag
			circleMembers = circleData.circle_members

			_.each circleMembers, (accessToken) ->
				if not circleMap[accessToken]
					circleMap[accessToken] = []
				circleMap[accessToken].push(circleTag)

		# get all article in all user
		_.each articleDataList, (result) ->

			accessToken = result.access_token
			userName = result.user_name
			articleList = result.list
			userArticleMap[accessToken] = []

			_.each articleList, (article) ->

				# console.log(article)
				
				articleTags = _.keys(article.tags)

				if articleTags.length

					articleID = article.resolved_id
					resolvedURL = article.resolved_url

					if articleID and resolvedURL

						userArticleMap[accessToken].push(articleID)
						allArticleMap[articleID] = {
							access_token: accessToken,
							user_name: userName,
							article_url: resolvedURL,
							article_id: articleID,
							article_tags: articleTags
						}
				
				null

			null

		allArticleIDAry = _.keys(allArticleMap)

		# console.log(allArticleMap)

		# get all need article for each user
		allNeedArticleIDAry = []
		_.each userArticleMap, (articleIDAry, accessToken) ->

			userNeedArticleIDAry = _.difference(allArticleIDAry, articleIDAry)
			allNeedArticleIDAry = _.union allNeedArticleIDAry, userNeedArticleIDAry

			userNeedArticleObjAry = _.map userNeedArticleIDAry, (articleID) ->
				articleObj = allArticleMap[articleID]
				return articleObj

			# filter to focus circle's article
			userNeedArticleObjAry = _.filter userNeedArticleObjAry, (articleObj) ->

				articleTags = articleObj.article_tags
				reciverAccessToken = accessToken
				userFocusCircles = circleMap[reciverAccessToken]

				if not userFocusCircles
					return false

				isFocusArticle = false

				_.each articleTags, (articleTag) ->
					if articleTag in userFocusCircles
						isFocusArticle = true
					null

				return isFocusArticle

			if userNeedArticleObjAry.length
				userNeedArticleMap[accessToken] = userNeedArticleObjAry
			null

		# filter existed article
		that.findExistedArticle allNeedArticleIDAry, (existedArticleIDAry) ->
			# console.log('existedArticleIDAry', existedArticleIDAry)
			_.each userNeedArticleMap, (articleObjAry, articleID) ->
				userNeedArticleMap[articleID] = _.filter articleObjAry, (articleObj) ->
					if articleObj.article_id in existedArticleIDAry
						return false
					return true
				if not userNeedArticleMap[articleID].length
					delete userNeedArticleMap[articleID]
				null
			callback({
				allArticleMap: allArticleMap,
				userNeedArticleMap: userNeedArticleMap
			})

	getAccessToken: (req, res) ->

		that = @
		reqToken = req.session.request_token
		if reqToken
			pocket.oAuth.getAccessToken reqToken, (accessToken, userName) ->
				req.session.access_token = accessToken
				req.session.user_name = userName
				database.regUser accessToken, userName, (err, result) ->
					if result
						database.log("[register] #{result.user_name}")
						
						pushPageURL = config.server_host + '/info/' + accessToken
						pocket.request.addArticle accessToken, pushPageURL, '', (result) ->
							return null
							# console.log(result)

						res.render('welcome', {})
					else
						res.redirect('/')
		else
			res.redirect('/')

	getReqToken: (req, res) ->

		pocket.oAuth.getReqToken (reqToken) ->
			req.session = {
				request_token: reqToken
			}
			res.redirect('https://getpocket.com/auth/authorize?request_token=' + reqToken + '&redirect_uri=' + pocket.REDIRECT_URI)

	listArticle: (callback) ->

		that = @

		async.waterfall [

			(callback) ->
				database.listUser (err, results) ->
					callback(err, results)

			, (results, callback) ->

				currentTimestamp = moment().valueOf()
				sinceTimestamp = currentTimestamp - 1000 * 300 # 5 min
				momentTime = moment(sinceTimestamp)
				sinceUnixTimestamp = momentTime.unix()

				# console.log('collecting article before ' + momentTime.fromNow())

				listFunc = []

				_.each results, (result) ->

					accessToken = result.access_token
					userName = result.user_name

					listFunc.push((callback) ->
						pocket.request.listArticle accessToken, sinceUnixTimestamp, (dataObj) ->
							dataObj.access_token = accessToken
							dataObj.user_name = userName
							callback(null, dataObj)
					)

				async.parallel listFunc, (err, results) ->
					callback(err, results)

		], (err, results) ->
			callback(results)

	publishArticle: (userNeedArticleMap, callback) ->

		listFunc = []

		_.each userNeedArticleMap, (userNeedArticleObjAry, accessToken) ->

			reciverToken = accessToken

			_.each userNeedArticleObjAry, (articleObj) ->

				articleURL = articleObj.article_url
				senderUserName = articleObj.user_name
				originArticleTags = articleObj.article_tags

				tagStr = senderUserName + ',' + originArticleTags.join(',')

				# console.log('syncing ' + senderUserName + '\'s article to all user')

				listFunc.push((callback) ->
					pocket.request.addArticle reciverToken, articleURL, tagStr, (result) ->
						callback(null, result)
				)

				null

			null

		async.parallel listFunc, (err, results) ->
			callback(err, results)

	recordPublishedArticle: (allArticleMap, newArticleIDAry) ->

		recordArticleAry = []

		_.each newArticleIDAry, (articleID) ->

			if articleID

				articleObj = allArticleMap[articleID]
				recordArticleAry.push({
					article_id: articleID,
					access_token: articleObj.access_token,
					user_name: articleObj.user_name,
					article_url: articleObj.article_url
				})

			null

		database.recordArticle recordArticleAry, (results) ->
			null
			# console.log(results)

	findExistedArticle: (articleIDAry, callback) ->

		# console.log('articleIDAry', articleIDAry)

		listFunc = []

		_.each articleIDAry, (articleID) ->

			listFunc.push((callback) ->
				database.findArticle articleID, (result) ->
					callback(null, result)
			)

		async.parallel listFunc, (err, results) ->
			# console.log('articleIDAry', results)
			existedArticleIDAry = []
			_.each results, (result) ->
				if result and result.article_id
					existedArticleIDAry.push(result.article_id)
				null
			callback(existedArticleIDAry)

	joinCircle: (req, res) ->

		# console.log(req.body)
		accessToken = req.session.access_token

		if not accessToken
			res.end(JSON.stringify({
				success: false,
				data: '/auth'
			}))
		else
			database.findUser accessToken, (err, result) ->
				if result
					circleTag = req.body.circle_tag
					database.joinCircle accessToken, circleTag, (err, result) ->
						if result
							res.end(JSON.stringify({
								success: true,
								data: null
							}))
				else
					res.end(JSON.stringify({
						success: false,
						data: '/auth'
					}))

	quitCircle: (req, res) ->

		accessToken = req.session.access_token
		if accessToken
			circleTag = req.body.circle_tag
			database.quitCircle accessToken, circleTag, (err, result) ->
				if result
					res.end(JSON.stringify({
						success: true,
						data: null
					}))

	indexPage: (req, res) ->

		database.listCircle (err, results) ->
			
			if results

				userName = req.session.user_name
				accessToken = req.session.access_token

				if accessToken
					# console.log(accessToken)
					results = _.map results, (result) ->
						if accessToken in result.circle_members
							result.circle_joined = true
						return result
				res.render('index', {
					circles: results,
					user_name: userName
				})

	infoPage: (req, res) ->

		accessToken = req.params.accessToken
		if accessToken
			res.render('info', {})

	helpPage: (req, res) ->

		res.render('help', {})

module.exports = new Model()