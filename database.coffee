Datastore = require('nedb')
async = require('async')
moment = require('moment')
_ = require('underscore')

config = require('./config')

class Nedb

	constructor: () ->

		that = @

		that.db = config.db

		that.logIndex = 0

		_.each that.db, (dbObj, dbName) ->

			that.db[dbName] = new Datastore({
				filename: './db/' + dbName + '.db',
				autoload: true
			})

		# that.db.circle.insert {
		# 	circle_name: '前端开发',
		# 	circle_description: '分享前端开发技术文章',
		# 	circle_tag: 'frontend',
		# 	circle_members: []
		# }, (err, result) ->
		# 	console.log('分享前端开发技术文章')

	log: (info) ->

		if not info
			return

		if not _.isString(info)
			info = JSON.stringify(info)

		that = @

		if that.logIndex >= config.max_log_num
			_.each that.db, (dbObj) ->
				dbObj.persistence.compactDatafile()
			that.logIndex = 0

		that.db.log.update {index: that.logIndex}, {
			index: that.logIndex++,
			time: moment().format(),
			info: info
		}, {upsert: true}

	regUser: (accessToken, userName, callback) ->

		that = @

		dataObj =
			access_token: accessToken,
			user_name: userName

		async.waterfall([

			(callback) ->
				that.db.user.update dataObj, _.extend({
					reg_time: new Date()
				}, dataObj), {upsert: true} , (err, count, result) ->
					callback(err, result)

		], (err, result) ->
			callback(err, result)
		)

	findUser: (accessToken, callback) ->

		that = @

		that.db.user.findOne {access_token: accessToken}, (err, result) ->
			callback(err, result)

	joinCircle: (accessToken, circleTag, callback) ->

		that = @

		async.waterfall([

			(callback) ->
				that.db.circle.findOne {circle_tag: circleTag}, (err, result) ->
					callback(err, result)

			, (result, callback) ->
				if result
					if not result.circle_members
						result.circle_members = []
					newMembers = _.union(result.circle_members, accessToken)
					that.db.circle.update {circle_tag: circleTag}, {
						$set: {circle_members: newMembers}
					}, (err, result) ->
						callback(err, result)

		], (err, result) ->
			callback(err, result)
		)

	quitCircle: (accessToken, circleTag, callback) ->

		that = @

		async.waterfall([

			(callback) ->
				that.db.circle.findOne {circle_tag: circleTag}, (err, result) ->
					callback(err, result)

			, (result, callback) ->
				if result
					if not result.circle_members
						result.circle_members = []
					newMembers = _.without(result.circle_members, accessToken)
					that.db.circle.update {circle_tag: circleTag}, {
						$set: {circle_members: newMembers}
					}, (err, result) ->
						callback(err, result)

		], (err, result) ->
			callback(err, result)
		)

	listCircle: (callback) ->

		that = @
		that.db.circle.find {}, (err, results) ->
			callback(err, results)

	listUser: (callback) ->

		that = @

		that.db.user.find {}, (err, results) ->
			callback(err, results)

	recordArticle: (articleAry, callback) ->

		that = @
		that.db.article.insert articleAry, (err, results) ->
			if not err
				callback(results)

	findArticle: (articleID, callback) ->

		that = @
		that.db.article.findOne {article_id: articleID}, (err, result) ->
			callback(result)

module.exports = new Nedb()